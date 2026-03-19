// WizardBypass v40 - DIAGNOSTIC BUILD
// Goal: find exactly what causes the freeze

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <libkern/OSCacheControl.h>
#import <dlfcn.h>
#import <signal.h>
#import <pthread.h>
#include "fishhook.h"

// ============================================================================
// SIGBUS HANDLER — captures caller info for debugging
// ============================================================================
static volatile int g_dead_catches = 0;

// Captured register state from signal handler (async-signal-safe globals)
static volatile uint64_t g_catch_fp = 0;
static volatile uint64_t g_catch_lr = 0;
static volatile uint64_t g_catch_sp = 0;
static volatile uint64_t g_catch_x0 = 0;
static volatile uint64_t g_catch_frames[10] = {0};  // FP chain: [saved_fp, saved_lr] pairs
static volatile int g_catch_frame_count = 0;
static volatile int g_catch_is_main = 0;

// Safe landing for background threads
static void safe_landing_sleep(void) {
    while (1) { sleep(9999); }
}

static void anti_tamper_handler(int sig, siginfo_t *info, void *context) {
    ucontext_t *uc = (ucontext_t *)context;
    _STRUCT_MCONTEXT64 *mc = uc->uc_mcontext;
    uint64_t pc = mc->__ss.__pc;

    if (pc == 0xDEAD || pc == 0xdead) {
        g_dead_catches++;

        // Capture register state for debugging
        g_catch_fp = mc->__ss.__fp;
        g_catch_lr = mc->__ss.__lr;
        g_catch_sp = mc->__ss.__sp;
        g_catch_x0 = mc->__ss.__x[0];
        g_catch_is_main = pthread_main_np();

        // Walk FP chain and save frames
        uint64_t fp = mc->__ss.__fp;
        g_catch_frame_count = 0;
        for (int i = 0; i < 5 && fp > 0x1000; i++) {
            uint64_t *frame = (uint64_t *)fp;
            g_catch_frames[i * 2] = frame[0];     // saved FP
            g_catch_frames[i * 2 + 1] = frame[1]; // saved LR
            g_catch_frame_count = i + 1;
            fp = frame[0];
        }

        if (g_catch_is_main) {
            // Main thread: try to return to caller's caller via FP chain
            // Skip frame 0 (anti-tamper func), use frame 1+ 
            for (int i = 0; i < g_catch_frame_count; i++) {
                uint64_t saved_lr = g_catch_frames[i * 2 + 1];
                if (saved_lr > 0x100000000 && saved_lr != 0xDEAD) {
                    mc->__ss.__pc = saved_lr;
                    mc->__ss.__fp = g_catch_frames[i * 2];
                    mc->__ss.__lr = saved_lr;
                    return;
                }
            }
            // Last resort: can't recover — just make it sleep too
            mc->__ss.__pc = (uint64_t)safe_landing_sleep;
            mc->__ss.__lr = (uint64_t)safe_landing_sleep;
        } else {
            // Background: sleep forever
            mc->__ss.__pc = (uint64_t)safe_landing_sleep;
            mc->__ss.__lr = (uint64_t)safe_landing_sleep;
        }
        return;
    }
}

// ============================================================================
// DYLIB HIDING
// ============================================================================
static uint32_t g_hidden_index = UINT32_MAX;
static uint32_t (*orig_dyld_image_count)(void);
static const char* (*orig_dyld_get_image_name)(uint32_t);
static const struct mach_header* (*orig_dyld_get_image_header)(uint32_t);
static intptr_t (*orig_dyld_get_image_vmaddr_slide)(uint32_t);

static uint32_t hooked_dyld_image_count(void) {
    if (g_hidden_index != UINT32_MAX) return orig_dyld_image_count() - 1;
    return orig_dyld_image_count();
}
static const char* hooked_dyld_get_image_name(uint32_t idx) {
    if (g_hidden_index != UINT32_MAX && idx >= g_hidden_index) return orig_dyld_get_image_name(idx + 1);
    return orig_dyld_get_image_name(idx);
}
static const struct mach_header* hooked_dyld_get_image_header(uint32_t idx) {
    if (g_hidden_index != UINT32_MAX && idx >= g_hidden_index) return orig_dyld_get_image_header(idx + 1);
    return orig_dyld_get_image_header(idx);
}
static intptr_t hooked_dyld_get_image_vmaddr_slide(uint32_t idx) {
    if (g_hidden_index != UINT32_MAX && idx >= g_hidden_index) return orig_dyld_get_image_vmaddr_slide(idx + 1);
    return orig_dyld_get_image_vmaddr_slide(idx);
}

static void setup_dylib_hiding(void) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "WizardBypass")) {
            g_hidden_index = i;
            break;
        }
    }
    struct rebinding rebindings[] = {
        {"_dyld_image_count", (void *)hooked_dyld_image_count, (void **)&orig_dyld_image_count},
        {"_dyld_get_image_name", (void *)hooked_dyld_get_image_name, (void **)&orig_dyld_get_image_name},
        {"_dyld_get_image_header", (void *)hooked_dyld_get_image_header, (void **)&orig_dyld_get_image_header},
        {"_dyld_get_image_vmaddr_slide", (void *)hooked_dyld_get_image_vmaddr_slide, (void **)&orig_dyld_get_image_vmaddr_slide},
    };
    rebind_symbols(rebindings, 4);
    NSLog(@"[WizardBypass] Dylib hiding active (idx: %u)", g_hidden_index);
}

// ============================================================================
// WATCHDOG — monitors main thread + dumps signal handler captures
// ============================================================================
static volatile BOOL g_main_thread_alive = NO;
static int g_last_reported_catches = 0;

static void start_watchdog(void) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Find Wizard slide for offset calculation
        intptr_t wizard_slide = 0;
        uint32_t real_count = orig_dyld_image_count ? orig_dyld_image_count() : _dyld_image_count();
        for (uint32_t i = 0; i < real_count; i++) {
            const char *name = orig_dyld_get_image_name ? orig_dyld_get_image_name(i) : _dyld_get_image_name(i);
            if (name && strstr(name, "Wizard.framework/Wizard")) {
                wizard_slide = orig_dyld_get_image_vmaddr_slide ?
                    orig_dyld_get_image_vmaddr_slide(i) : _dyld_get_image_vmaddr_slide(i);
                break;
            }
        }

        for (int i = 0; i < 30; i++) {
            sleep(2);
            g_main_thread_alive = NO;
            dispatch_async(dispatch_get_main_queue(), ^{
                g_main_thread_alive = YES;
            });
            sleep(1);

            if (g_main_thread_alive) {
                NSLog(@"[WizardBypass] WATCHDOG: main thread ALIVE (tick %d, catches: %d)", i, g_dead_catches);
            } else {
                NSLog(@"[WizardBypass] WATCHDOG: *** MAIN THREAD BLOCKED *** (tick %d, catches: %d)", i, g_dead_catches);
            }

            // Dump signal handler capture data when new catches appear
            if (g_dead_catches > g_last_reported_catches) {
                g_last_reported_catches = g_dead_catches;
                NSLog(@"[WizardBypass] === ANTI-TAMPER CATCH #%d ===", g_dead_catches);
                NSLog(@"[WizardBypass]   Thread: %s", g_catch_is_main ? "MAIN" : "BACKGROUND");
                NSLog(@"[WizardBypass]   FP: 0x%llx  LR: 0x%llx  SP: 0x%llx", 
                    (unsigned long long)g_catch_fp, 
                    (unsigned long long)g_catch_lr, 
                    (unsigned long long)g_catch_sp);
                NSLog(@"[WizardBypass]   Wizard slide: 0x%lx", (long)wizard_slide);
                for (int f = 0; f < g_catch_frame_count; f++) {
                    uint64_t saved_lr = g_catch_frames[f * 2 + 1];
                    uint64_t ida_offset = saved_lr - wizard_slide;
                    NSLog(@"[WizardBypass]   Frame %d: FP=0x%llx LR=0x%llx (IDA: 0x%llx)",
                        f,
                        (unsigned long long)g_catch_frames[f * 2],
                        (unsigned long long)saved_lr,
                        (unsigned long long)ida_offset);
                }
                NSLog(@"[WizardBypass] === END CATCH DATA ===");
            }
        }
    });
}

// ============================================================================
// drawInMTKView: diagnostic hook (log, don't NOP)
// ============================================================================
static int g_draw_count = 0;
static IMP g_orig_drawInMTKView = NULL;

static void setup_draw_diagnostic(void) {
    Class metalClass = objc_getClass("AJFADSHFSAJXN");
    if (!metalClass) {
        NSLog(@"[WizardBypass] DIAG: AJFADSHFSAJXN not found");
        return;
    }
    SEL drawSel = sel_registerName("drawInMTKView:");
    Method drawMethod = class_getInstanceMethod(metalClass, drawSel);
    if (!drawMethod) {
        NSLog(@"[WizardBypass] DIAG: drawInMTKView: method not found");
        return;
    }

    g_orig_drawInMTKView = method_getImplementation(drawMethod);
    IMP nopDraw = imp_implementationWithBlock(^(id self, id view) {
        g_draw_count++;
        if (g_draw_count <= 3 || g_draw_count % 1000 == 0) {
            NSLog(@"[WizardBypass] drawInMTKView NOP'd (call #%d)", g_draw_count);
        }
        // DO NOT call original — it infinite-loops (anti-tamper)
    });
    method_setImplementation(drawMethod, nopDraw);
    NSLog(@"[WizardBypass] drawInMTKView: NOP'd (anti-tamper infinite loop blocked)");
}

// ============================================================================
// DELAYED HOOK
// ============================================================================
static void delayed_hook(void) {
    NSLog(@"[WizardBypass] === DELAYED HOOK START ===");

    // Find Wizard slide
    intptr_t wizard_slide = 0;
    BOOL found = NO;
    uint32_t real_count = orig_dyld_image_count ? orig_dyld_image_count() : _dyld_image_count();
    for (uint32_t i = 0; i < real_count; i++) {
        const char *name = orig_dyld_get_image_name ? orig_dyld_get_image_name(i) : _dyld_get_image_name(i);
        if (name && strstr(name, "Wizard.framework/Wizard")) {
            wizard_slide = orig_dyld_get_image_vmaddr_slide ?
                orig_dyld_get_image_vmaddr_slide(i) : _dyld_get_image_vmaddr_slide(i);
            found = YES;
            break;
        }
    }

    if (found) {
        NSLog(@"[WizardBypass] Wizard slide: 0x%lx", (long)wizard_slide);
    }

    // ========================================
    // PLIST AUTH BYPASS (from IDA sub_B27940)
    // The license state is stored in a plist file:
    //   outerKey[innerKey] = NSNumber(100) = authenticated
    // Scan all plists in the app sandbox to find and modify it
    // ========================================
    
    // The encrypted CFSTR keys from IDA (used as NSDictionary keys in the plist)
    NSString *outerKey = [NSString stringWithFormat:@"%c%c%c%c%c", 0xC5, 0x5B, 0x21, 0xB1, 0x1A];
    NSString *innerKey = [NSString stringWithFormat:@"%c%c%c%c%c%c", 0x98, 0x3E, 0x28, 0xDA, 0x9C, 0x39];
    
    NSLog(@"[WizardBypass] PLIST BYPASS: searching for license plist...");
    NSLog(@"[WizardBypass]   outerKey length=%lu, innerKey length=%lu", 
        (unsigned long)outerKey.length, (unsigned long)innerKey.length);
    
    // Scan directories for plist files
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *homeDir = NSHomeDirectory();
    NSArray *searchDirs = @[
        [homeDir stringByAppendingPathComponent:@"Library/Preferences"],
        [homeDir stringByAppendingPathComponent:@"Library"],
        [homeDir stringByAppendingPathComponent:@"Documents"],
        [homeDir stringByAppendingPathComponent:@"Library/Application Support"],
        homeDir,
    ];
    
    BOOL plistFound = NO;
    for (NSString *dir in searchDirs) {
        NSArray *files = [fm contentsOfDirectoryAtPath:dir error:nil];
        for (NSString *file in files) {
            if (![file hasSuffix:@".plist"]) continue;
            
            NSString *fullPath = [dir stringByAppendingPathComponent:file];
            NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:fullPath];
            if (!dict) continue;
            
            // Log all plist files for diagnostics
            NSLog(@"[WizardBypass] PLIST: %@ (keys: %lu)", fullPath, (unsigned long)dict.allKeys.count);
            
            // Check if this plist has our outer key
            id outerVal = dict[outerKey];
            if (outerVal) {
                NSLog(@"[WizardBypass] *** FOUND LICENSE PLIST: %@ ***", fullPath);
                NSLog(@"[WizardBypass]   outerVal type: %@", [outerVal class]);
                
                if ([outerVal isKindOfClass:[NSDictionary class]]) {
                    NSMutableDictionary *inner = [outerVal mutableCopy];
                    id currentVal = inner[innerKey];
                    NSLog(@"[WizardBypass]   current innerKey value: %@", currentVal);
                    
                    // Set to 100 (authenticated)
                    inner[innerKey] = @100;
                    dict[outerKey] = inner;
                } else {
                    // Outer value exists but isn't a dict — set nested structure
                    dict[outerKey] = @{innerKey: @100};
                }
                
                BOOL written = [dict writeToFile:fullPath atomically:YES];
                NSLog(@"[WizardBypass]   Written with value 100: %@", written ? @"YES" : @"NO");
                plistFound = YES;
            }
            
            // Also dump ALL keys for any plist with non-standard key names
            for (NSString *key in dict.allKeys) {
                if (key.length <= 10 && key.length >= 3) {
                    // Log short keys that might be encrypted
                    NSLog(@"[WizardBypass]   KEY: [%@] len=%lu", key, (unsigned long)key.length);
                }
            }
        }
    }
    
    NSLog(@"[WizardBypass] === DELAYED HOOK COMPLETE ===");
}

// ============================================================================
// CONSTRUCTOR
// ============================================================================
__attribute__((constructor))
static void wizard_bypass_init(void) {
    NSLog(@"[WizardBypass] === v43 CLEAN BUILD (plist bypass only) ===");

    // Signal handler first
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = anti_tamper_handler;
    sa.sa_flags = SA_SIGINFO;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGBUS, &sa, NULL);
    sigaction(SIGSEGV, &sa, NULL);
    NSLog(@"[WizardBypass] Signal handler installed");

    // Dylib hiding
    setup_dylib_hiding();

    // drawInMTKView NOT NOP'd — menu needs Metal rendering
    // Signal handler protects if anti-tamper fires
    // setup_draw_diagnostic();

    // Watchdog (background thread)
    start_watchdog();

    // Delayed hook in 3 seconds
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        delayed_hook();
    });

    NSLog(@"[WizardBypass] === INIT COMPLETE ===");
}
