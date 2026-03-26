// WizardBypass v66 — DECISION POINT FINDER
// Captures stack trace when the error "Exit" popup is created
// This reveals which function in the obfuscation chain makes the valid/invalid decision

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <mach-o/dyld.h>
#import <signal.h>
#import <execinfo.h>
#import <dlfcn.h>

static uint64_t g_wizard_base = 0;
static intptr_t g_wizard_slide = 0;
static CFAbsoluteTime g_last_tap_time = 0;

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

// Walk the frame pointer chain manually for better results
static void log_stack_trace(void) {
    NSLog(@"[WizKey] === STACK TRACE (frame pointer walk) ===");
    void *fp = __builtin_frame_address(0);

    for (int i = 0; i < 30 && fp != NULL; i++) {
        void **frame = (void **)fp;
        void *ret_addr = frame[1];

        if ((uint64_t)ret_addr < 0x1000) break;

        uint64_t addr = (uint64_t)ret_addr;
        uint64_t unslid = addr - g_wizard_slide;

        // Check if address is in Wizard binary (rough range check)
        if (unslid > 0x100000 && unslid < 0x2000000) {
            NSLog(@"[WizKey]   frame[%d]: %p (WIZARD unslid: 0x%llX) <<<", i, ret_addr, unslid);
        } else {
            Dl_info info;
            if (dladdr(ret_addr, &info) && info.dli_fname) {
                const char *basename = strrchr(info.dli_fname, '/');
                basename = basename ? basename + 1 : info.dli_fname;
                NSLog(@"[WizKey]   frame[%d]: %p (%s)", i, ret_addr, basename);
            } else {
                NSLog(@"[WizKey]   frame[%d]: %p", i, ret_addr);
            }
        }

        fp = frame[0]; // next frame
    }
    NSLog(@"[WizKey] === END STACK TRACE ===");
}

__attribute__((constructor))
static void wizard_bypass_init(void) {
    NSLog(@"[WizKey] === v66 DECISION FINDER START ===");

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

    // Hook IKAFHFDSAJ (success detector)
    Class abvClass = objc_getClass("ABVJSMGADJS");
    if (abvClass) {
        Method m = class_getInstanceMethod(abvClass, sel_registerName("IKAFHFDSAJ"));
        if (m) {
            void (*orig_ik)(id, SEL) = (void (*)(id, SEL))method_getImplementation(m);
            method_setImplementation(m, imp_implementationWithBlock(^(id self) {
                NSLog(@"[WizKey] *** IKAFHFDSAJ CALLED! VALID KEY! ***");
                log_stack_trace();
                orig_ik(self, sel_registerName("IKAFHFDSAJ"));
            }));
        }
    }

    Class sclAlert = objc_getClass("SCLAlertView");
    if (sclAlert) {
        // Hook addButton:actionBlock: — when "Exit" is added DURING button tap,
        // capture stack trace to find the decision function
        SEL addBtnSel = sel_registerName("addButton:actionBlock:");
        Method m2 = class_getInstanceMethod(sclAlert, addBtnSel);
        if (m2) {
            void (*orig)(id, SEL, id, id) = (void (*)(id, SEL, id, id))method_getImplementation(m2);
            method_setImplementation(m2, imp_implementationWithBlock(
                ^(id self, id title, id actBlock) {
                    NSLog(@"[WizKey] addButton: '%@'", title);

                    // If "Exit" button created within 5s of button tap → error popup
                    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
                    if ([title isEqualToString:@"Exit"] && (now - g_last_tap_time) < 5.0 && g_last_tap_time > 0) {
                        NSLog(@"[WizKey] *** ERROR POPUP CREATED %.1fs AFTER TAP — CAPTURING DECISION POINT ***", now - g_last_tap_time);
                        log_stack_trace();
                    }

                    orig(self, addBtnSel, title, actBlock);
                }
            ));
            NSLog(@"[WizKey] addButton:actionBlock: HOOKED");
        }

        // Hook buttonTapped: with tap tracking
        Method m3 = class_getInstanceMethod(sclAlert, sel_registerName("buttonTapped:"));
        if (m3) {
            void (*orig_tap)(id, SEL, id) = (void (*)(id, SEL, id))method_getImplementation(m3);
            method_setImplementation(m3, imp_implementationWithBlock(^(id self, id button) {
                NSLog(@"[WizKey] buttonTapped: START");
                g_last_tap_time = CFAbsoluteTimeGetCurrent();
                orig_tap(self, sel_registerName("buttonTapped:"), button);
                NSLog(@"[WizKey] buttonTapped: END");
            }));
            NSLog(@"[WizKey] buttonTapped: hooked");
        }
    }

    // Delayed config
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
        if (!g_wizard_slide) return;
        NSLog(@"[WizKey] Wizard slide: 0x%lx", (long)g_wizard_slide);

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

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            while (1) { usleep(50000); if (*auth != 1) *auth = 1; }
        });

        NSLog(@"[WizKey] === READY — Type key, tap OK, watch for DECISION POINT ===");
    });
}
