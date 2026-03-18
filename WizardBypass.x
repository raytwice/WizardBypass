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

    // Binary patch
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
        NSLog(@"[WizardBypass] Wizard slide: 0x%lx (NO binary patch — checksum protected)", (long)wizard_slide);
    }

    // ========================================
    // HOOK-BASED BYPASS: SCLAlertView error -> success
    // Instead of patching Wizard code (triggers checksum),
    // hook SCLAlertView to redirect error displays to success
    // ========================================
    Class sclClass = objc_getClass("SCLAlertView");
    if (sclClass) {
        NSLog(@"[WizardBypass] Found SCLAlertView class");

        // List all methods for diagnostics
        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(sclClass, &methodCount);
        for (unsigned int i = 0; i < methodCount; i++) {
            NSString *name = NSStringFromSelector(method_getName(methods[i]));
            if ([name containsString:@"show"] || [name containsString:@"Show"] ||
                [name containsString:@"error"] || [name containsString:@"Error"] ||
                [name containsString:@"success"] || [name containsString:@"Success"]) {
                NSLog(@"[WizardBypass] SCL method: %@", name);
            }
        }
        free(methods);

        // Hook showError: -> redirect to showSuccess:
        // SCLAlertView typically has: showError:subTitle:closeButtonTitle:duration:
        // and showSuccess:subTitle:closeButtonTitle:duration:
        SEL errorSel = sel_registerName("showError:");
        SEL successSel = sel_registerName("showSuccess:");
        Method errorMethod = class_getInstanceMethod(sclClass, errorSel);
        Method successMethod = class_getInstanceMethod(sclClass, successSel);

        if (errorMethod && successMethod) {
            method_exchangeImplementations(errorMethod, successMethod);
            NSLog(@"[WizardBypass] HOOKED: showError: <-> showSuccess: SWAPPED");
        } else {
            NSLog(@"[WizardBypass] showError:/showSuccess: not found, scanning variants...");

            // Try common SCLAlertView method signatures
            NSString *errorSelectors[] = {
                @"showError:subTitle:closeButtonTitle:duration:",
                @"showError:subTitle:completeText:duration:",
                @"showError:subTitle:duration:",
            };
            NSString *successSelectors[] = {
                @"showSuccess:subTitle:closeButtonTitle:duration:",
                @"showSuccess:subTitle:completeText:duration:",
                @"showSuccess:subTitle:duration:",
            };

            for (int i = 0; i < 3; i++) {
                SEL eSel = sel_registerName([errorSelectors[i] UTF8String]);
                SEL sSel = sel_registerName([successSelectors[i] UTF8String]);
                Method eM = class_getInstanceMethod(sclClass, eSel);
                Method sM = class_getInstanceMethod(sclClass, sSel);
                if (eM && sM) {
                    method_exchangeImplementations(eM, sM);
                    NSLog(@"[WizardBypass] HOOKED: %@ <-> %@ SWAPPED", errorSelectors[i], successSelectors[i]);
                }
            }
        }
    } else {
        NSLog(@"[WizardBypass] SCLAlertView NOT FOUND — checking for custom alert classes...");
        // Scan for any class with "Alert" or "SCL" in name
        unsigned int classCount = 0;
        Class *classes = objc_copyClassList(&classCount);
        for (unsigned int i = 0; i < classCount; i++) {
            NSString *name = NSStringFromClass(classes[i]);
            if ([name containsString:@"SCL"] || [name containsString:@"Alert"]) {
                // Check if it's from Wizard
                const char *imageName = class_getImageName(classes[i]);
                if (imageName && strstr(imageName, "Wizard")) {
                    NSLog(@"[WizardBypass] Wizard alert class: %@ (%s)", name, imageName);
                }
            }
        }
        free(classes);
    }

    // Also hook the success/error blocks via function pointer swap
    // sub_B1F7F8 (error) and sub_B1F270 (success) — call success directly
    if (found) {
        uint64_t success_func = 0xB1F270 + wizard_slide;
        uint64_t error_func   = 0xB1F7F8 + wizard_slide;
        NSLog(@"[WizardBypass] Success func at: 0x%llx", success_func);
        NSLog(@"[WizardBypass] Error func at: 0x%llx (NOT patched — checksum protected)", error_func);
    }

    NSLog(@"[WizardBypass] About to fake auth token...");
    [[NSUserDefaults standardUserDefaults] setObject:@"premium" forKey:@"auth-token-type"];
    NSLog(@"[WizardBypass] Auth token faked");

    NSLog(@"[WizardBypass] About to create ABVJSMGADJS...");
    Class abvClass = objc_getClass("ABVJSMGADJS");
    if (!abvClass) {
        NSLog(@"[WizardBypass] ERROR: ABVJSMGADJS class not found!");
        return;
    }

    id controller = [[abvClass alloc] init];
    NSLog(@"[WizardBypass] ABVJSMGADJS created: %@", controller);

    if (!controller) {
        NSLog(@"[WizardBypass] ERROR: controller is nil!");
        return;
    }

    // Kill timers BEFORE calling methods
    Ivar timerIvar1 = class_getInstanceVariable(abvClass, "_qmshnfuas");
    Ivar timerIvar2 = class_getInstanceVariable(abvClass, "_nvjsafhsa");
    if (timerIvar1) {
        NSTimer *t = object_getIvar(controller, timerIvar1);
        if (t) [t invalidate];
        object_setIvar(controller, timerIvar1, nil);
        NSLog(@"[WizardBypass] Timer 1 killed");
    }
    if (timerIvar2) {
        NSTimer *t = object_getIvar(controller, timerIvar2);
        if (t) [t invalidate];
        object_setIvar(controller, timerIvar2, nil);
        NSLog(@"[WizardBypass] Timer 2 killed");
    }

    NSLog(@"[WizardBypass] About to call PADSGFNDSAHJ...");
    SEL padSel = sel_registerName("PADSGFNDSAHJ");
    if ([controller respondsToSelector:padSel]) {
        ((void (*)(id, SEL))objc_msgSend)(controller, padSel);
        NSLog(@"[WizardBypass] PADSGFNDSAHJ returned OK");
    } else {
        NSLog(@"[WizardBypass] PADSGFNDSAHJ: does not respond!");
    }

    NSLog(@"[WizardBypass] About to call IKAFHFDSAJ...");
    SEL ikaSel = sel_registerName("IKAFHFDSAJ");
    if ([controller respondsToSelector:ikaSel]) {
        ((void (*)(id, SEL))objc_msgSend)(controller, ikaSel);
        NSLog(@"[WizardBypass] IKAFHFDSAJ returned OK");
    } else {
        NSLog(@"[WizardBypass] IKAFHFDSAJ: does not respond!");
    }

    NSLog(@"[WizardBypass] === DELAYED HOOK COMPLETE ===");
    NSLog(@"[WizardBypass] draws: %d, catches: %d", g_draw_count, g_dead_catches);
}

// ============================================================================
// CONSTRUCTOR
// ============================================================================
__attribute__((constructor))
static void wizard_bypass_init(void) {
    NSLog(@"[WizardBypass] === v40 DIAGNOSTIC BUILD ===");

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

    // Diagnostic hook on drawInMTKView
    setup_draw_diagnostic();

    // Watchdog (background thread)
    start_watchdog();

    // Delayed hook in 3 seconds
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        delayed_hook();
    });

    NSLog(@"[WizardBypass] === INIT COMPLETE ===");
}
