// WizardBypass v51 - CLEAN DIAGNOSTIC BUILD
// Only: auth flag bypass + drawInMTKView NOP + diagnostics
// No forced ObjC calls. Let normal app flow handle the menu.
//
// VULNERABILITY: Wizard stores auth state (byte_1B0B4A9) in writable
// __data segment without integrity checks. Any injected code can flip
// it. The license processor (sub_81E8B0) parses ASN1 cert data and
// writes the config — but the result sits unprotected in memory.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <signal.h>
#import <pthread.h>
#include "fishhook.h"

// ============================================================================
// SIGBUS/SIGSEGV HANDLER — catches anti-tamper 0xDEAD jumps
// ============================================================================
static volatile int g_dead_catches = 0;
static volatile uint64_t g_catch_lr = 0;
static volatile int g_catch_is_main = 0;

static void safe_landing_sleep(void) {
    while (1) { sleep(9999); }
}

static void anti_tamper_handler(int sig, siginfo_t *info, void *context) {
    ucontext_t *uc = (ucontext_t *)context;
    _STRUCT_MCONTEXT64 *mc = uc->uc_mcontext;
    uint64_t pc = mc->__ss.__pc;

    if (pc == 0xDEAD || pc == 0xdead) {
        g_dead_catches++;
        g_catch_lr = mc->__ss.__lr;
        g_catch_is_main = pthread_main_np();

        if (g_catch_is_main) {
            // Main thread: walk FP chain to find safe return
            uint64_t fp = mc->__ss.__fp;
            for (int i = 0; i < 5 && fp > 0x1000; i++) {
                uint64_t *frame = (uint64_t *)fp;
                uint64_t saved_lr = frame[1];
                if (saved_lr > 0x100000000 && saved_lr != 0xDEAD) {
                    mc->__ss.__pc = saved_lr;
                    mc->__ss.__fp = frame[0];
                    mc->__ss.__lr = saved_lr;
                    return;
                }
                fp = frame[0];
            }
            mc->__ss.__pc = (uint64_t)safe_landing_sleep;
            mc->__ss.__lr = (uint64_t)safe_landing_sleep;
        } else {
            mc->__ss.__pc = (uint64_t)safe_landing_sleep;
            mc->__ss.__lr = (uint64_t)safe_landing_sleep;
        }
        return;
    }
}

// ============================================================================
// DYLIB HIDING — hides WizardBypass from _dyld_image enumeration
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
// ANTI-TAMPER NOP — only NOP the jsafbSAHCN delegate call,
// NOT the entire drawInMTKView. This lets Metal render the cheat overlays.
// ============================================================================
static int g_draw_count = 0;

static void setup_draw_nop(void) {
    // Strategy: NOP jsafbSAHCN on ALL classes that implement it.
    // drawInMTKView calls [delegate jsafbSAHCN] which is the anti-tamper check.
    // The rest of drawInMTKView is normal Metal rendering — leave it alone.
    
    // NOP jsafbSAHCN on the delegate class (ABVJSMGADJS or similar)
    SEL antiTamperSel = sel_registerName("jsafbSAHCN");
    
    // Try known classes that might implement this
    const char *classNames[] = {"Wksahfnasj", "ABVJSMGADJS", "AJFADSHFSAJXN", "Pajdsakdfj", "Kmsjfaigh", NULL};
    int hooked = 0;
    
    for (int i = 0; classNames[i] != NULL; i++) {
        Class cls = objc_getClass(classNames[i]);
        if (!cls) continue;
        
        Method m = class_getInstanceMethod(cls, antiTamperSel);
        if (m) {
            IMP nop = imp_implementationWithBlock(^(id self) {
                g_draw_count++;
                if (g_draw_count <= 3 || g_draw_count % 10000 == 0) {
                    NSLog(@"[WizardBypass] jsafbSAHCN NOP'd (call #%d)", g_draw_count);
                }
            });
            method_setImplementation(m, nop);
            NSLog(@"[WizardBypass] jsafbSAHCN NOP'd on %s", classNames[i]);
            hooked++;
        }
    }
    
    if (hooked == 0) {
        // Fallback: NOP the entire drawInMTKView if we can't find jsafbSAHCN
        NSLog(@"[WizardBypass] jsafbSAHCN not found on known classes, falling back to drawInMTKView NOP");
        Class metalClass = objc_getClass("AJFADSHFSAJXN");
        if (metalClass) {
            SEL drawSel = sel_registerName("drawInMTKView:");
            Method drawMethod = class_getInstanceMethod(metalClass, drawSel);
            if (drawMethod) {
                IMP nopDraw = imp_implementationWithBlock(^(id self, id view) {
                    g_draw_count++;
                    if (g_draw_count <= 3 || g_draw_count % 5000 == 0) {
                        NSLog(@"[WizardBypass] drawInMTKView NOP'd (call #%d)", g_draw_count);
                    }
                });
                method_setImplementation(drawMethod, nopDraw);
                NSLog(@"[WizardBypass] drawInMTKView: NOP'd (fallback)");
            }
        }
    }
}

// ============================================================================
// WATCHDOG — monitors main thread health + reports anti-tamper catches
// ============================================================================
static volatile BOOL g_main_alive = NO;
static int g_last_catches = 0;

static void start_watchdog(intptr_t wizard_slide) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (int i = 0; i < 60; i++) {
            sleep(2);
            g_main_alive = NO;
            dispatch_async(dispatch_get_main_queue(), ^{ g_main_alive = YES; });
            sleep(1);

            // Read auth flag live
            uint8_t auth = *((uint8_t *)((uint64_t)wizard_slide + 0x1B0B4A9));

            if (g_main_alive) {
                NSLog(@"[WizardBypass] WATCHDOG tick %d: ALIVE | catches: %d | auth: %d",
                      i, g_dead_catches, auth);
            } else {
                NSLog(@"[WizardBypass] WATCHDOG tick %d: *** BLOCKED *** | catches: %d | auth: %d",
                      i, g_dead_catches, auth);
            }

            if (g_dead_catches > g_last_catches) {
                g_last_catches = g_dead_catches;
                NSLog(@"[WizardBypass] ANTI-TAMPER CATCH #%d (thread: %s, LR: 0x%llx, IDA: 0x%llx)",
                      g_dead_catches,
                      g_catch_is_main ? "MAIN" : "BG",
                      (unsigned long long)g_catch_lr,
                      (unsigned long long)(g_catch_lr - wizard_slide));
            }
        }
        NSLog(@"[WizardBypass] WATCHDOG done (60 ticks)");
    });
}

// ============================================================================
// CONSTRUCTOR
// ============================================================================
__attribute__((constructor))
static void wizard_bypass_init(void) {
    NSLog(@"[WizardBypass] === v53 COMBINED BYPASS ===");

    // 1. Signal handler (anti-tamper protection)
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = anti_tamper_handler;
    sa.sa_flags = SA_SIGINFO;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGBUS, &sa, NULL);
    sigaction(SIGSEGV, &sa, NULL);
    NSLog(@"[WizardBypass] Signal handler installed");

    // 2. Dylib hiding
    setup_dylib_hiding();

    // 3. NOP drawInMTKView (prevents anti-tamper infinite loop that freezes main thread)
    setup_draw_nop();

    // 4. Delayed bypass (5s — wait for Wizard to fully load)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        NSLog(@"[WizardBypass] === DELAYED BYPASS START ===");

        // Find Wizard slide
        intptr_t wizard_slide = 0;
        BOOL found = NO;
        uint32_t count = orig_dyld_image_count ? orig_dyld_image_count() : _dyld_image_count();
        for (uint32_t i = 0; i < count; i++) {
            const char *name = orig_dyld_get_image_name ? orig_dyld_get_image_name(i) : _dyld_get_image_name(i);
            if (name && strstr(name, "Wizard.framework/Wizard")) {
                wizard_slide = orig_dyld_get_image_vmaddr_slide ?
                    orig_dyld_get_image_vmaddr_slide(i) : _dyld_get_image_vmaddr_slide(i);
                found = YES;
                break;
            }
        }

        if (!found) {
            NSLog(@"[WizardBypass] ERROR: Wizard framework not found!");
            return;
        }

        NSLog(@"[WizardBypass] Wizard slide: 0x%lx", (long)wizard_slide);

        // Step A: Set auth flag + default config values
        // sub_81E8B0 normally sets these from __const, but it never runs.
        // Without them, menu panels have zero-size frames.
        uint64_t base_addr = (uint64_t)wizard_slide;
        
        // Auth flag
        uint8_t *auth_flag = (uint8_t *)(base_addr + 0x1B0B4A9);
        NSLog(@"[WizardBypass] byte_1B0B4A9 BEFORE: %d", *auth_flag);
        *auth_flag = 1;
        
        // Config region layout (from sub_81E8B0 init):
        //   xmmword_1B0B470[0..1] = 0x0100 (256), [2] = 1, [3..7] = 0
        //   xmmword_1B0B470+8  = xmmword_FD6820 (float positions)
        //   xmmword_1B0B480+8  = xmmword_FD6830
        //   xmmword_1B0B498    = xmmword_FD6840
        //   xmmword_1B0B4B0    = xmmword_FD6850
        //   xmmword_1B0B4C0    = xmmword_FD6860
        uint8_t *cfg = (uint8_t *)(base_addr + 0x1B0B470);
        
        // Byte flags — enable ALL features
        // cfg[0] = LOBYTE(xmmword_1B0B470) — toggled by play/pause button
        // cfg[1] = preddrawon, cfg[2] = shotdrawe, cfg[3] = screantiot
        // cfg[4] = ndguexteinesidel, cfg[5] = lassusecyle
        // cfg[6] = rmarwate, cfg[7] = playauto
        cfg[0] = 0x01; // Start with enabled
        cfg[1] = 0x01; // preddrawon
        cfg[2] = 0x01; // shotdrawe
        cfg[3] = 0x01; // screantiot
        cfg[4] = 0x01; // ndguexteinesidel (extended guidelines)
        cfg[5] = 0x01; // lassusecyle
        cfg[6] = 0x00; // rmarwate (watermark — leave OFF)
        cfg[7] = 0x01; // playauto
        
        // Copy float defaults from __const section
        memcpy(cfg + 8,  (void *)(base_addr + 0xFD6820), 16); // xmmword_FD6820
        memcpy(cfg + 24, (void *)(base_addr + 0xFD6830), 16); // xmmword_FD6830
        memcpy((void *)(base_addr + 0x1B0B498), (void *)(base_addr + 0xFD6840), 16);
        memcpy((void *)(base_addr + 0x1B0B4B0), (void *)(base_addr + 0xFD6850), 16);
        memcpy((void *)(base_addr + 0x1B0B4C0), (void *)(base_addr + 0xFD6860), 16);
        
        // Re-set auth flag (memcpy might have overwritten it)
        *auth_flag = 1;
        
        NSLog(@"[WizardBypass] Config defaults applied + byte_1B0B4A9 = 1");
        
        // Dump float values for diagnostics
        float *flt = (float *)(cfg + 8);
        NSLog(@"[WizardBypass] Float configs: %.1f %.1f %.1f %.1f",
              flt[0], flt[1], flt[2], flt[3]);

        // Step B: Auth enforcer (background thread, keeps flag at 1)
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            static int enforce_count = 0;
            static int restore_count = 0;
            uint8_t *flag = (uint8_t *)((uint64_t)wizard_slide + 0x1B0B4A9);
            
            NSLog(@"[WizardBypass] AUTH ENFORCER started (50ms interval)");
            while (1) {
                usleep(50000);
                if (*flag != 1) {
                    *flag = 1;
                    restore_count++;
                    NSLog(@"[WizardBypass] AUTH ENFORCER: restored (#%d)", restore_count);
                }
                enforce_count++;
                if (enforce_count % 200 == 0) {
                    NSLog(@"[WizardBypass] AUTH ENFORCER alive (%d checks, %d restores)", 
                          enforce_count, restore_count);
                }
            }
        });

        // Step C: Call IKAFHFDSAJ — the complete menu builder
        // This triggers the FULL success flow:
        //   1. Checks pJMSAFHSJSFV superview (first call → falls through)
        //   2. Builds key entry UI + container views
        //   3. Decrypts all menu strings (3 deterministic loops)
        //   4. Creates 5 menu views and adds to keyWindow
        //   5. Calls ASFGAHJFAHS internally (starts 30fps timer)
        // v50 proved this works (user saw icons). v52 NOP prevents the freeze.
        Class wizardClass = objc_getClass("ABVJSMGADJS");
        if (wizardClass) {
            NSLog(@"[WizardBypass] ABVJSMGADJS class found");
            
            SEL singletonSel = sel_registerName("ANDASFJSGX");
            id instance = ((id (*)(Class, SEL))objc_msgSend)(wizardClass, singletonSel);
            
            if (instance) {
                NSLog(@"[WizardBypass] Singleton: %p", instance);
                
                SEL menuSel = sel_registerName("IKAFHFDSAJ");
                NSLog(@"[WizardBypass] Calling IKAFHFDSAJ...");
                ((void (*)(id, SEL))objc_msgSend)(instance, menuSel);
                NSLog(@"[WizardBypass] *** IKAFHFDSAJ COMPLETE ***");
            } else {
                NSLog(@"[WizardBypass] ERROR: singleton nil!");
            }
        } else {
            NSLog(@"[WizardBypass] ERROR: class not found!");
        }

        NSLog(@"[WizardBypass] === FULL BYPASS ACTIVE ===");

        // Step D: KEY FORMAT DIAGNOSTIC
        // Monitor text field and config region to capture key format
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // Snapshot the config region BEFORE any key entry
            uint8_t snapshot[64];
            uint8_t *cfg_diag = (uint8_t *)(base_addr + 0x1B0B470);
            memcpy(snapshot, cfg_diag, 64);
            
            NSLog(@"[WizardBypass] KEY DIAG: monitoring started");
            
            for (int tick = 0; tick < 300; tick++) { // 5 minutes
                usleep(1000000); // 1 sec
                
                // Read text field content (qword_1E89780 style — try BOTH text fields)
                dispatch_sync(dispatch_get_main_queue(), ^{
                    // Try reading the visible text field
                    uint64_t *tf_ptr1 = (uint64_t *)(base_addr + 0x1E89780);
                    uint64_t *tf_ptr2 = (uint64_t *)(base_addr + 0x1E897C0);
                    
                    id textField1 = (__bridge id)(void *)*tf_ptr1;
                    id textField2 = (__bridge id)(void *)*tf_ptr2;
                    
                    if (textField1) {
                        NSString *text1 = ((NSString *(*)(id, SEL))objc_msgSend)(textField1, sel_registerName("text"));
                        if (text1 && [text1 length] > 0) {
                            NSLog(@"[WizardBypass] KEY DIAG TF1: \"%@\" (len=%lu)", text1, (unsigned long)[text1 length]);
                            
                            // Try Base64 decode
                            NSData *decoded = [[NSData alloc] initWithBase64EncodedString:text1 options:0];
                            if (decoded) {
                                const uint8_t *bytes = [decoded bytes];
                                NSUInteger len = [decoded length];
                                NSMutableString *hex = [NSMutableString string];
                                for (NSUInteger i = 0; i < len && i < 32; i++) {
                                    [hex appendFormat:@"%02X ", bytes[i]];
                                }
                                NSLog(@"[WizardBypass] KEY DIAG B64: %lu bytes = %@", (unsigned long)len, hex);
                            }
                        }
                    }
                    
                    if (textField2) {
                        NSString *text2 = ((NSString *(*)(id, SEL))objc_msgSend)(textField2, sel_registerName("text"));
                        if (text2 && [text2 length] > 0) {
                            NSLog(@"[WizardBypass] KEY DIAG TF2: \"%@\"", text2);
                        }
                    }
                });
                
                // Check if config region changed (means sub_81E8B0 ran)
                if (memcmp(snapshot, cfg_diag, 64) != 0) {
                    NSLog(@"[WizardBypass] KEY DIAG: *** CONFIG CHANGED *** sub_81E8B0 was called!");
                    // Dump the new config
                    NSMutableString *hex = [NSMutableString string];
                    for (int i = 0; i < 64; i++) {
                        [hex appendFormat:@"%02X ", cfg_diag[i]];
                        if (i % 16 == 15) {
                            NSLog(@"[WizardBypass] KEY DIAG cfg[%d..%d]: %@", i-15, i, hex);
                            hex = [NSMutableString string];
                        }
                    }
                    memcpy(snapshot, cfg_diag, 64); // Update snapshot
                    *auth_flag = 1; // Re-enforce
                }
            }
            NSLog(@"[WizardBypass] KEY DIAG: monitoring ended (300s)");
        });

        // Start watchdog
        start_watchdog(wizard_slide);
    });

    NSLog(@"[WizardBypass] === INIT COMPLETE ===");
}
