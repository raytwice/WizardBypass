// WizardBypass v61 — DIRECT CALL: Skip popup, call IKAFHFDSAJ directly
// The menu views are added UNCONDITIONALLY after LABEL_538
// With cfg[4]=1, the hardcoded Base64 icon is used — no valid key needed

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <mach-o/dyld.h>
#import <signal.h>

// ── Anti-tamper ──
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
    NSLog(@"[WizKey] === v61 START ===");

    // Signal handler
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = anti_tamper_handler;
    sa.sa_flags = SA_SIGINFO;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGBUS, &sa, NULL);
    sigaction(SIGSEGV, &sa, NULL);

    // Hook jsafbSAHCN NOP
    Class wksClass = objc_getClass("Wksahfnasj");
    if (wksClass) {
        Method m = class_getInstanceMethod(wksClass, sel_registerName("jsafbSAHCN"));
        if (m) {
            method_setImplementation(m, imp_implementationWithBlock(^(id self) {}));
            NSLog(@"[WizKey] jsafbSAHCN NOP'd");
        }
    }

    // Hook buttonTapped: (still useful if popup appears)
    Class sclAlert = objc_getClass("SCLAlertView");
    if (sclAlert) {
        Method m = class_getInstanceMethod(sclAlert, sel_registerName("buttonTapped:"));
        if (m) {
            void (*orig)(id, SEL, id) = (void (*)(id, SEL, id))method_getImplementation(m);
            method_setImplementation(m, imp_implementationWithBlock(^(id self, id button) {
                NSLog(@"[WizKey] buttonTapped: clearing validation");
                ((void(*)(id, SEL, id))objc_msgSend)(button, sel_registerName("setValidationBlock:"), nil);
                orig(self, sel_registerName("buttonTapped:"), button);
            }));
            NSLog(@"[WizKey] buttonTapped: hooked");
        }
    }

    // Delayed: set config + auth + call IKAFHFDSAJ directly
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        intptr_t wizard_slide = 0;
        uint32_t count = _dyld_image_count();
        for (uint32_t i = 0; i < count; i++) {
            const char *name = _dyld_get_image_name(i);
            if (name && strstr(name, "Wizard.framework/Wizard")) {
                wizard_slide = _dyld_get_image_vmaddr_slide(i);
                break;
            }
        }
        if (!wizard_slide) { NSLog(@"[WizKey] ERROR: Wizard not found!"); return; }
        NSLog(@"[WizKey] Wizard slide: 0x%lx", (long)wizard_slide);

        uint64_t base = (uint64_t)wizard_slide;
        uint8_t *cfg = (uint8_t *)(base + 0x1B0B470);
        uint8_t *auth = (uint8_t *)(base + 0x1B0B4A9);

        // Set config flags
        cfg[0]=1; cfg[1]=1; cfg[2]=1; cfg[3]=1;
        cfg[4]=1; // USE HARDCODED ICON — no valid key needed!
        cfg[5]=1; cfg[6]=0; cfg[7]=1;
        memcpy(cfg+8,  (void*)(base+0xFD6820), 16);
        memcpy(cfg+24, (void*)(base+0xFD6830), 16);
        memcpy((void*)(base+0x1B0B498), (void*)(base+0xFD6840), 16);
        memcpy((void*)(base+0x1B0B4B0), (void*)(base+0xFD6850), 16);
        memcpy((void*)(base+0x1B0B4C0), (void*)(base+0xFD6860), 16);

        *auth = 1;
        NSLog(@"[WizKey] Config + auth set");

        // Auth enforcer
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            while (1) { usleep(50000); if (*auth != 1) *auth = 1; }
        });

        // ═══════════════════════════════════════════════════════
        // DIRECT CALL: Find ABVJSMGADJS instance and call IKAFHFDSAJ
        // Bypass the popup entirely!
        // ═══════════════════════════════════════════════════════
        Class abvClass = objc_getClass("ABVJSMGADJS");
        if (!abvClass) {
            NSLog(@"[WizKey] ERROR: ABVJSMGADJS not found!");
            return;
        }

        // Try to find existing instance via sharedInstance or similar
        id abvInstance = nil;

        // Method 1: Check if there's a shared/singleton accessor
        if ([abvClass respondsToSelector:sel_registerName("sharedInstance")]) {
            abvInstance = ((id(*)(id, SEL))objc_msgSend)((id)abvClass, sel_registerName("sharedInstance"));
            NSLog(@"[WizKey] Found via sharedInstance");
        }

        // Method 2: alloc/init
        if (!abvInstance) {
            abvInstance = ((id(*)(id, SEL))objc_msgSend)(
                ((id(*)(id, SEL))objc_msgSend)((id)abvClass, sel_registerName("alloc")),
                sel_registerName("init")
            );
            NSLog(@"[WizKey] Created new ABVJSMGADJS instance");
        }

        if (abvInstance) {
            NSLog(@"[WizKey] *** CALLING IKAFHFDSAJ DIRECTLY ***");
            @try {
                ((void(*)(id, SEL))objc_msgSend)(abvInstance, sel_registerName("IKAFHFDSAJ"));
                NSLog(@"[WizKey] *** IKAFHFDSAJ returned! Menu should be visible! ***");
            } @catch (NSException *e) {
                NSLog(@"[WizKey] IKAFHFDSAJ exception: %@", e);
            }
        }
    });
}
