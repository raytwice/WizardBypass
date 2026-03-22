// WizardBypass v56 — NUCLEAR (GBD-style)
// 1. jsafbSAHCN NOP (anti-tamper)
// 2. SCLAlertView dismissed (no key entry popup)
// 3. All config flags + auth enforcer
// 4. Call IKAFHFDSAJ (creates views + images)
// 5. Manually add views to keyWindow (replicate LABEL_538)
// 6. Call ASFGAHJFAHS (start 30fps timer)

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

// ============================================================
// SIGNAL HANDLER — catches 0xDEAD anti-tamper jumps
// ============================================================
static void anti_tamper_handler(int sig, siginfo_t *info, void *context) {
    ucontext_t *uc = (ucontext_t *)context;
    _STRUCT_MCONTEXT64 *mc = uc->uc_mcontext;
    uint64_t pc = mc->__ss.__pc;
    if (pc == 0xDEAD || pc == 0xdead) {
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

// ============================================================
// DYLIB HIDING
// ============================================================
static uint32_t g_hidden_index = 0;
static uint32_t (*orig_dyld_image_count)(void) = NULL;
static const char* (*orig_dyld_get_image_name)(uint32_t) = NULL;
static intptr_t (*orig_dyld_get_image_vmaddr_slide)(uint32_t) = NULL;

static uint32_t hooked_image_count(void) { return orig_dyld_image_count() - 1; }
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
        if (name && strstr(name, "WizardBypass")) { g_hidden_index = i; break; }
    }
    struct rebinding rebindings[] = {
        {"_dyld_image_count", (void *)hooked_image_count, (void **)&orig_dyld_image_count},
        {"_dyld_get_image_name", (void *)hooked_get_image_name, (void **)&orig_dyld_get_image_name},
        {"_dyld_get_image_vmaddr_slide", (void *)hooked_get_image_vmaddr_slide, (void **)&orig_dyld_get_image_vmaddr_slide},
    };
    rebind_symbols(rebindings, 3);
    NSLog(@"[WizardBypass] Dylib hidden (idx: %u)", g_hidden_index);
}

// ============================================================
// CONSTRUCTOR
// ============================================================
__attribute__((constructor))
static void wizard_bypass_init(void) {
    NSLog(@"[WizardBypass] === v56 NUCLEAR ===");

    // Signal handler
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = anti_tamper_handler;
    sa.sa_flags = SA_SIGINFO;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGBUS, &sa, NULL);
    sigaction(SIGSEGV, &sa, NULL);

    // Dylib hiding
    setup_dylib_hiding();

    // NOP jsafbSAHCN on Wksahfnasj (anti-tamper → Metal rendering works)
    Class wksClass = objc_getClass("Wksahfnasj");
    if (wksClass) {
        Method m = class_getInstanceMethod(wksClass, sel_registerName("jsafbSAHCN"));
        if (m) {
            method_setImplementation(m, imp_implementationWithBlock(^(id self) {}));
            NSLog(@"[WizardBypass] jsafbSAHCN NOP'd");
        }
    }

    // Block SCLAlertView — dismiss key entry popup + prevent showing
    Class sclClass = objc_getClass("SCLAlertView");
    if (sclClass) {
        // Hook showEdit to auto-dismiss after creation
        SEL btSel = sel_registerName("buttonTapped:");
        Method btMethod = class_getInstanceMethod(sclClass, btSel);
        if (btMethod) {
            method_setImplementation(btMethod, imp_implementationWithBlock(^(id self, id btn) {
                NSLog(@"[WizardBypass] buttonTapped: → hideView");
                if (((BOOL (*)(id, SEL))objc_msgSend)(self, sel_registerName("isVisible")))
                    ((void (*)(id, SEL))objc_msgSend)(self, sel_registerName("hideView"));
            }));
            NSLog(@"[WizardBypass] SCLAlertView.buttonTapped: hooked → auto-dismiss");
        }
    }

    // Block SCLButton validation
    Class sclBtnClass = objc_getClass("SCLButton");
    if (sclBtnClass) {
        Method m = class_getInstanceMethod(sclBtnClass, sel_registerName("validationBlock"));
        if (m) {
            method_setImplementation(m, imp_implementationWithBlock(^id(id self) { return nil; }));
            NSLog(@"[WizardBypass] SCLButton.validationBlock → nil");
        }
    }

    // ============================================================
    // DELAYED SETUP — wait for Wizard to load
    // ============================================================
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        NSLog(@"[WizardBypass] === DELAYED SETUP ===");

        // Find Wizard
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
        if (!found) { NSLog(@"[WizardBypass] ERROR: Wizard not found!"); return; }
        NSLog(@"[WizardBypass] Wizard slide: 0x%lx", (long)wizard_slide);

        uint64_t base = (uint64_t)wizard_slide;
        uint8_t *cfg = (uint8_t *)(base + 0x1B0B470);
        uint8_t *auth_flag = (uint8_t *)(base + 0x1B0B4A9);

        // Set ALL feature flags
        cfg[0] = 0x01; cfg[1] = 0x01; cfg[2] = 0x01; cfg[3] = 0x01;
        cfg[4] = 0x01; // ndguexteinesidel → picks qword_1E89788 (valid image!)
        cfg[5] = 0x01; cfg[6] = 0x00; cfg[7] = 0x01;

        // Float defaults from __const
        memcpy(cfg + 8,  (void *)(base + 0xFD6820), 16);
        memcpy(cfg + 24, (void *)(base + 0xFD6830), 16);
        memcpy((void *)(base + 0x1B0B498), (void *)(base + 0xFD6840), 16);
        memcpy((void *)(base + 0x1B0B4B0), (void *)(base + 0xFD6850), 16);
        memcpy((void *)(base + 0x1B0B4C0), (void *)(base + 0xFD6860), 16);

        *auth_flag = 1;
        NSLog(@"[WizardBypass] Config + auth set");

        // Auth enforcer
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            uint8_t *flag = (uint8_t *)(base + 0x1B0B4A9);
            while (1) {
                usleep(50000);
                if (*flag != 1) { *flag = 1; }
            }
        });

        // Get ABVJSMGADJS singleton
        Class wizardClass = objc_getClass("ABVJSMGADJS");
        if (!wizardClass) { NSLog(@"[WizardBypass] ERROR: ABVJSMGADJS not found!"); return; }

        id instance = ((id (*)(Class, SEL))objc_msgSend)(wizardClass, sel_registerName("ANDASFJSGX"));
        if (!instance) { NSLog(@"[WizardBypass] ERROR: singleton nil!"); return; }
        NSLog(@"[WizardBypass] Singleton: %p", instance);

        // Call IKAFHFDSAJ — creates all views + sets qword_1E89788 image
        NSLog(@"[WizardBypass] Calling IKAFHFDSAJ...");
        ((void (*)(id, SEL))objc_msgSend)(instance, sel_registerName("IKAFHFDSAJ"));
        NSLog(@"[WizardBypass] IKAFHFDSAJ complete");

        // Re-set auth (IKAFHFDSAJ might reset it)
        *auth_flag = 1;

        // Dismiss any SCLAlertView that's showing
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            // Try to find and dismiss SCLAlertView
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
            #pragma clang diagnostic pop
            for (UIView *subview in keyWindow.subviews) {
                if ([NSStringFromClass([subview class]) containsString:@"SCL"]) {
                    [subview removeFromSuperview];
                    NSLog(@"[WizardBypass] Removed SCL view: %@", NSStringFromClass([subview class]));
                }
            }

            // REPLICATE LABEL_538: Add views to keyWindow
            NSLog(@"[WizardBypass] Adding views to keyWindow...");

            SEL selectors[] = {
                sel_registerName("jdsghadurewmf"),
                sel_registerName("pJMSAFHSJSFV"),
                sel_registerName("AYtPSMFSKdfj"),
                sel_registerName("naJFSAKFNSMN"),
                sel_registerName("AYmpXkdajwND"),
            };
            const char *names[] = {"jdsghadurewmf", "pJMSAFHSJSFV", "AYtPSMFSKdfj", "naJFSAKFNSMN", "AYmpXkdajwND"};

            for (int i = 0; i < 5; i++) {
                id view = ((id (*)(id, SEL))objc_msgSend)(instance, selectors[i]);
                if (view) {
                    [keyWindow addSubview:view];
                    NSLog(@"[WizardBypass] Added %s to keyWindow ✓", names[i]);
                } else {
                    NSLog(@"[WizardBypass] WARNING: %s is nil!", names[i]);
                }
            }

            // Start 30fps timer (ASFGAHJFAHS)
            NSLog(@"[WizardBypass] Calling ASFGAHJFAHS (30fps timer)...");
            ((void (*)(id, SEL))objc_msgSend)(instance, sel_registerName("ASFGAHJFAHS"));
            NSLog(@"[WizardBypass] === v56 FULLY ACTIVE ===");
        });
    });

    NSLog(@"[WizardBypass] === INIT COMPLETE ===");
}
