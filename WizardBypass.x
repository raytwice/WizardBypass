// WizardBypass v57 — Project DIH
// APPROACH: Don't force anything. Just flip the validation gate.
// User enters ANY key → taps submit → natural flow handles everything.
//
// 1. jsafbSAHCN NOP (anti-tamper on Metal view)
// 2. SCLButton.validationBlock → nil (any key accepted)
// 3. Config flags + auth enforcer
// 4. DO NOT call IKAFHFDSAJ — let the action block do it
// 5. DO NOT touch buttonTapped: — let it call actionBlock naturally

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <signal.h>
#import <pthread.h>

// ============================================================
// SIGNAL HANDLER — catches 0xDEAD anti-tamper
// ============================================================
static void anti_tamper_handler(int sig, siginfo_t *info, void *context) {
    ucontext_t *uc = (ucontext_t *)context;
    _STRUCT_MCONTEXT64 *mc = uc->uc_mcontext;
    uint64_t pc = mc->__ss.__pc;
    if (pc == 0xDEAD || pc == 0xdead) {
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
        mc->__ss.__pc = (uint64_t)&sleep;
    }
}

// ============================================================
// CONSTRUCTOR
// ============================================================
__attribute__((constructor))
static void wizard_bypass_init(void) {
    NSLog(@"[WizardBypass] === v57 Project DIH ===");

    // Signal handler for 0xDEAD
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = anti_tamper_handler;
    sa.sa_flags = SA_SIGINFO;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGBUS, &sa, NULL);
    sigaction(SIGSEGV, &sa, NULL);

    // ============================================================
    // HOOK 1: jsafbSAHCN NOP (anti-tamper on Wksahfnasj Metal view)
    // ============================================================
    Class wksClass = objc_getClass("Wksahfnasj");
    if (wksClass) {
        Method m = class_getInstanceMethod(wksClass, sel_registerName("jsafbSAHCN"));
        if (m) {
            method_setImplementation(m, imp_implementationWithBlock(^(id self) {}));
            NSLog(@"[WizardBypass] jsafbSAHCN NOP'd ✓");
        }
    }

    // ============================================================
    // HOOK 2: SCLButton.validationBlock → nil (any key accepted)
    // DO NOT hook buttonTapped: — let it call actionBlock naturally!
    // ============================================================
    Class sclBtnClass = objc_getClass("SCLButton");
    if (sclBtnClass) {
        Method m = class_getInstanceMethod(sclBtnClass, sel_registerName("validationBlock"));
        if (m) {
            method_setImplementation(m, imp_implementationWithBlock(^id(id self) {
                NSLog(@"[WizardBypass] validationBlock → nil (any key accepted)");
                return nil;
            }));
            NSLog(@"[WizardBypass] SCLButton.validationBlock hooked ✓");
        }
    }

    // ============================================================
    // DELAYED: Set config flags + auth after Wizard loads
    // ============================================================
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        NSLog(@"[WizardBypass] === DELAYED CONFIG ===");

        // Find Wizard.framework slide
        intptr_t wizard_slide = 0;
        uint32_t count = _dyld_image_count();
        for (uint32_t i = 0; i < count; i++) {
            const char *name = _dyld_get_image_name(i);
            if (name && strstr(name, "Wizard.framework/Wizard")) {
                wizard_slide = _dyld_get_image_vmaddr_slide(i);
                break;
            }
        }
        if (!wizard_slide) {
            NSLog(@"[WizardBypass] ERROR: Wizard not found!");
            return;
        }
        NSLog(@"[WizardBypass] Wizard slide: 0x%lx", (long)wizard_slide);

        uint64_t base = (uint64_t)wizard_slide;
        uint8_t *cfg = (uint8_t *)(base + 0x1B0B470);
        uint8_t *auth_flag = (uint8_t *)(base + 0x1B0B4A9);

        // Set feature flags
        cfg[0] = 0x01;  // main toggle
        cfg[1] = 0x01;
        cfg[2] = 0x01;
        cfg[3] = 0x01;
        cfg[4] = 0x01;  // CRITICAL: picks qword_1E89788 (valid Base64 image)
        cfg[5] = 0x01;
        cfg[6] = 0x00;
        cfg[7] = 0x01;

        // Float defaults from __const
        memcpy(cfg + 8,  (void *)(base + 0xFD6820), 16);
        memcpy(cfg + 24, (void *)(base + 0xFD6830), 16);
        memcpy((void *)(base + 0x1B0B498), (void *)(base + 0xFD6840), 16);
        memcpy((void *)(base + 0x1B0B4B0), (void *)(base + 0xFD6850), 16);
        memcpy((void *)(base + 0x1B0B4C0), (void *)(base + 0xFD6860), 16);

        // Auth flag
        *auth_flag = 1;
        NSLog(@"[WizardBypass] Config + auth set ✓");

        // Auth enforcer
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            uint8_t *flag = (uint8_t *)(base + 0x1B0B4A9);
            while (1) {
                usleep(50000); // 50ms
                if (*flag != 1) {
                    *flag = 1;
                }
            }
        });

        NSLog(@"[WizardBypass] === v57 READY — Enter any key and tap submit ===");
    });

    NSLog(@"[WizardBypass] === INIT COMPLETE ===");
}
