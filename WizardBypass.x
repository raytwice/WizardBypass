// WizardBypass v67 — PROPER BYPASS (Any Key Works)
// Captures the real ABVJSMGADJS singleton, suppresses error popup,
// and calls IKAFHFDSAJ on the real instance after any key submission.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <mach-o/dyld.h>
#import <signal.h>

static uint64_t g_wizard_base = 0;
static intptr_t g_wizard_slide = 0;
static id g_real_singleton = nil;
static BOOL g_key_submitted = NO;

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

__attribute__((constructor))
static void wizard_bypass_init(void) {
    NSLog(@"[WizKey] === v67 PROPER BYPASS START ===");

    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = anti_tamper_handler;
    sa.sa_flags = SA_SIGINFO;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGBUS, &sa, NULL);
    sigaction(SIGSEGV, &sa, NULL);

    // NOP jsafbSAHCN
    Class wksClass = objc_getClass("Wksahfnasj");
    if (wksClass) {
        Method m = class_getInstanceMethod(wksClass, sel_registerName("jsafbSAHCN"));
        if (m) {
            method_setImplementation(m, imp_implementationWithBlock(^(id self) {}));
            NSLog(@"[WizKey] jsafbSAHCN NOP'd");
        }
    }

    // Hook ABVJSMGADJS init to capture the REAL singleton
    Class abvClass = objc_getClass("ABVJSMGADJS");
    if (abvClass) {
        Method initM = class_getInstanceMethod(abvClass, sel_registerName("init"));
        if (initM) {
            id (*orig_init)(id, SEL) = (id (*)(id, SEL))method_getImplementation(initM);
            method_setImplementation(initM, imp_implementationWithBlock(^id(id self) {
                id result = orig_init(self, sel_registerName("init"));
                g_real_singleton = result;
                NSLog(@"[WizKey] *** ABVJSMGADJS singleton captured: %p ***", result);
                return result;
            }));
            NSLog(@"[WizKey] ABVJSMGADJS init hooked");
        }
    }

    // Hook SCLAlertView to:
    // 1. Suppress the error "Exit" popup after key submission
    // 2. On OK button tap, trigger IKAFHFDSAJ on real singleton
    Class sclAlert = objc_getClass("SCLAlertView");
    if (sclAlert) {
        // Hook showError to suppress it after key submission
        SEL showErrSel = sel_registerName("showError:title:subTitle:closeButtonTitle:duration:");
        Method showErrM = class_getInstanceMethod(sclAlert, showErrSel);
        if (showErrM) {
            void (*orig_showErr)(id, SEL, id, id, id, id, float) =
                (void (*)(id, SEL, id, id, id, id, float))method_getImplementation(showErrM);
            method_setImplementation(showErrM, imp_implementationWithBlock(
                ^(id self, id vc, id title, id subtitle, id closeBtn, float duration) {
                    if (g_key_submitted) {
                        NSLog(@"[WizKey] *** SUPPRESSED error popup! ***");
                        g_key_submitted = NO;
                        // Don't show the error popup — silently discard it
                        return;
                    }
                    // Show non-key-related errors normally
                    orig_showErr(self, showErrSel, vc, title, subtitle, closeBtn, duration);
                }
            ));
            NSLog(@"[WizKey] showError: hooked (suppressor)");
        }

        // Hook buttonTapped: to detect OK tap and trigger IKAFHFDSAJ
        Method tapM = class_getInstanceMethod(sclAlert, sel_registerName("buttonTapped:"));
        if (tapM) {
            void (*orig_tap)(id, SEL, id) = (void (*)(id, SEL, id))method_getImplementation(tapM);
            method_setImplementation(tapM, imp_implementationWithBlock(^(id self, id button) {
                NSLog(@"[WizKey] buttonTapped: fired");
                g_key_submitted = YES;

                // Call original (chain will try to show error, but we suppress it)
                orig_tap(self, sel_registerName("buttonTapped:"), button);

                // After a short delay, call IKAFHFDSAJ on the real singleton
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                    dispatch_get_main_queue(), ^{
                    if (g_real_singleton) {
                        NSLog(@"[WizKey] *** Calling IKAFHFDSAJ on real singleton %p ***", g_real_singleton);
                        ((void(*)(id, SEL))objc_msgSend)(g_real_singleton, sel_registerName("IKAFHFDSAJ"));
                        NSLog(@"[WizKey] *** IKAFHFDSAJ called! Menu should appear! ***");
                    } else {
                        NSLog(@"[WizKey] ERROR: No singleton captured yet");
                    }
                });
            }));
            NSLog(@"[WizKey] buttonTapped: hooked (bypass trigger)");
        }
    }

    // Delayed config setup
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        uint32_t count = _dyld_image_count();
        for (uint32_t i = 0; i < count; i++) {
            const char *name = _dyld_get_image_name(i);
            if (name && strstr(name, "Wizard.framework/Wizard")) {
                g_wizard_slide = _dyld_get_image_vmaddr_slide(i);
                g_wizard_base = (uint64_t)g_wizard_slide;
                break;
            }
        }
        if (!g_wizard_slide) { NSLog(@"[WizKey] ERROR: Wizard not found!"); return; }
        NSLog(@"[WizKey] Wizard slide: 0x%lx", (long)g_wizard_slide);

        // Config bytes
        uint8_t *cfg = (uint8_t *)(g_wizard_base + 0x1B0B470);
        uint8_t *auth = (uint8_t *)(g_wizard_base + 0x1B0B4A9);
        cfg[0]=1; cfg[1]=1; cfg[2]=1; cfg[3]=1;
        cfg[4]=1; cfg[5]=1; cfg[6]=0; cfg[7]=1;
        memcpy(cfg+8,  (void*)(g_wizard_base+0xFD6820), 16);
        memcpy(cfg+24, (void*)(g_wizard_base+0xFD6830), 16);
        memcpy((void*)(g_wizard_base+0x1B0B498), (void*)(g_wizard_base+0xFD6840), 16);
        memcpy((void*)(g_wizard_base+0x1B0B4B0), (void*)(g_wizard_base+0xFD6850), 16);
        memcpy((void*)(g_wizard_base+0x1B0B4C0), (void*)(g_wizard_base+0xFD6860), 16);
        *auth = 1;
        NSLog(@"[WizKey] Config + auth set");

        // Auth enforcer
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            while (1) { usleep(50000); if (*auth != 1) *auth = 1; }
        });

        NSLog(@"[WizKey] === READY — Type anything, tap OK, menu will appear! ===");
    });
}
