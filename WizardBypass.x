// WizardBypass v55 — CLEAN BUILD
// Strategy: Skip SCLAlertView validation + set all config flags + NOP anti-tamper
//
// Key vulnerability: SCLAlertView's buttonTapped: checks if validationBlock is nil.
// If nil → skips validation → calls actionBlock → success path.

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

static void anti_tamper_handler(int sig, siginfo_t *info, void *context) {
    ucontext_t *uc = (ucontext_t *)context;
    _STRUCT_MCONTEXT64 *mc = uc->uc_mcontext;
    uint64_t pc = mc->__ss.__pc;

    if (pc == 0xDEAD || pc == 0xdead) {
        g_dead_catches++;
        if (pthread_main_np()) {
            uint64_t fp = mc->__ss.__fp;
            for (int i = 0; i < 5 && fp > 0x1000; i++) {
                uint64_t *frame = (uint64_t *)fp;
                uint64_t saved_lr = frame[1];
                if (saved_lr > 0x100000000 && saved_lr != 0xDEAD) {
                    mc->__ss.__pc = saved_lr;
                    mc->__ss.__fp = frame[0];
                    return;
                }
                fp = frame[0];
            }
        }
        mc->__ss.__pc = (uint64_t)&sleep;
    }
}

// ============================================================================
// DYLIB HIDING — hide from _dyld_image_count/_dyld_get_image_name
// ============================================================================
static uint32_t g_hidden_index = 0;
static uint32_t (*orig_dyld_image_count)(void) = NULL;
static const char* (*orig_dyld_get_image_name)(uint32_t) = NULL;
static intptr_t (*orig_dyld_get_image_vmaddr_slide)(uint32_t) = NULL;

static uint32_t hooked_image_count(void) {
    return orig_dyld_image_count() - 1;
}
static const char* hooked_get_image_name(uint32_t idx) {
    return orig_dyld_get_image_name(idx >= g_hidden_index ? idx + 1 : idx);
}
static intptr_t hooked_get_image_vmaddr_slide(uint32_t idx) {
    return orig_dyld_get_image_vmaddr_slide(idx >= g_hidden_index ? idx + 1 : idx);
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
        {"_dyld_image_count", (void *)hooked_image_count, (void **)&orig_dyld_image_count},
        {"_dyld_get_image_name", (void *)hooked_get_image_name, (void **)&orig_dyld_get_image_name},
        {"_dyld_get_image_vmaddr_slide", (void *)hooked_get_image_vmaddr_slide, (void **)&orig_dyld_get_image_vmaddr_slide},
    };
    rebind_symbols(rebindings, 3);
    NSLog(@"[WizardBypass] Dylib hidden (idx: %u)", g_hidden_index);
}

// ============================================================================
// ANTI-TAMPER NOP — NOP jsafbSAHCN on Wksahfnasj (Metal delegate)
// Lets drawInMTKView render normally while bypassing integrity checks
// ============================================================================
static void setup_antitamper_nop(void) {
    Class cls = objc_getClass("Wksahfnasj");
    if (!cls) {
        NSLog(@"[WizardBypass] Wksahfnasj not found");
        return;
    }
    SEL sel = sel_registerName("jsafbSAHCN");
    Method m = class_getInstanceMethod(cls, sel);
    if (m) {
        method_setImplementation(m, imp_implementationWithBlock(^(id self) {}));
        NSLog(@"[WizardBypass] jsafbSAHCN NOP'd");
    }
}

// ============================================================================
// VALIDATION SKIP — make SCLButton.validationBlock return nil
// SCLAlertView buttonTapped: checks if validationBlock is nil → skips validation
// ============================================================================
static void setup_validation_skip(void) {
    Class cls = objc_getClass("SCLButton");
    if (!cls) {
        NSLog(@"[WizardBypass] SCLButton not found");
        return;
    }
    SEL sel = sel_registerName("validationBlock");
    Method m = class_getInstanceMethod(cls, sel);
    if (m) {
        method_setImplementation(m, imp_implementationWithBlock(^id(id self) {
            NSLog(@"[WizardBypass] validationBlock → nil (SKIPPED)");
            return nil;
        }));
        NSLog(@"[WizardBypass] SCLButton.validationBlock hooked → nil");
    } else {
        NSLog(@"[WizardBypass] validationBlock method not found on SCLButton");
    }
}

// ============================================================================
// CONSTRUCTOR
// ============================================================================
__attribute__((constructor))
static void wizard_bypass_init(void) {
    NSLog(@"[WizardBypass] === v55 VALIDATION SKIP ===");

    // 1. Anti-tamper signal handler
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = anti_tamper_handler;
    sa.sa_flags = SA_SIGINFO;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGBUS, &sa, NULL);
    sigaction(SIGSEGV, &sa, NULL);

    // 2. Dylib hiding
    setup_dylib_hiding();

    // 3. Anti-tamper NOP (jsafbSAHCN → no-op)
    setup_antitamper_nop();

    // 4. Validation skip (SCLButton.validationBlock → nil)
    setup_validation_skip();

    // 5. Delayed config setup (wait for Wizard to load)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        NSLog(@"[WizardBypass] === DELAYED SETUP ===");

        // Find Wizard framework
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
            NSLog(@"[WizardBypass] ERROR: Wizard not found");
            return;
        }
        NSLog(@"[WizardBypass] Wizard slide: 0x%lx", (long)wizard_slide);

        uint64_t base = (uint64_t)wizard_slide;
        uint8_t *cfg = (uint8_t *)(base + 0x1B0B470);
        uint8_t *auth_flag = (uint8_t *)(base + 0x1B0B4A9);

        // Set all feature flags
        cfg[0] = 0x01; // enabled
        cfg[1] = 0x01; // preddrawon
        cfg[2] = 0x01; // shotdrawe
        cfg[3] = 0x01; // screantiot
        cfg[4] = 0x01; // ndguexteinesidel
        cfg[5] = 0x01; // lassusecyle
        cfg[6] = 0x00; // rmarwate (watermark OFF)
        cfg[7] = 0x01; // playauto

        // Copy float defaults from __const
        memcpy(cfg + 8,  (void *)(base + 0xFD6820), 16);
        memcpy(cfg + 24, (void *)(base + 0xFD6830), 16);
        memcpy((void *)(base + 0x1B0B498), (void *)(base + 0xFD6840), 16);
        memcpy((void *)(base + 0x1B0B4B0), (void *)(base + 0xFD6850), 16);
        memcpy((void *)(base + 0x1B0B4C0), (void *)(base + 0xFD6860), 16);

        // Auth flag
        *auth_flag = 1;
        NSLog(@"[WizardBypass] Config set + auth = 1");

        // Auth enforcer (background thread)
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            uint8_t *flag = (uint8_t *)(base + 0x1B0B4A9);
            while (1) {
                usleep(50000);
                if (*flag != 1) {
                    *flag = 1;
                    NSLog(@"[WizardBypass] AUTH RESTORED");
                }
            }
        });

        NSLog(@"[WizardBypass] === READY — enter any key and tap Submit ===");
    });

    NSLog(@"[WizardBypass] === INIT COMPLETE ===");
}
