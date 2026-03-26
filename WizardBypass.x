// WizardBypass v63 — BLOCK INTERCEPTOR
// Hook addButton:validationBlock:actionBlock: to capture the REAL validation block
// Log the block's invoke function pointer → gives us the address to decompile

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <mach-o/dyld.h>
#import <signal.h>

// Block internal layout (from Apple's Block ABI)
struct Block_layout {
    void *isa;
    int flags;
    int reserved;
    void (*invoke)(void *, ...);
    void *descriptor;
    // captured variables follow...
};

static uint64_t g_wizard_base = 0;
static intptr_t g_wizard_slide = 0;

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

static void log_block_info(const char *name, id block) {
    if (!block) {
        NSLog(@"[WizKey] %s: nil", name);
        return;
    }

    struct Block_layout *bl = (__bridge struct Block_layout *)block;
    uint64_t invoke_addr = (uint64_t)bl->invoke;
    uint64_t unslid = invoke_addr - g_wizard_slide;

    NSLog(@"[WizKey] %s: %p", name, block);
    NSLog(@"[WizKey]   isa: %p (%s)", bl->isa,
        bl->isa == (__bridge void *)objc_getClass("__NSGlobalBlock__") ? "GLOBAL" :
        bl->isa == (__bridge void *)objc_getClass("__NSStackBlock__") ? "STACK" :
        bl->isa == (__bridge void *)objc_getClass("__NSMallocBlock__") ? "MALLOC" : "UNKNOWN");
    NSLog(@"[WizKey]   flags: 0x%08X", bl->flags);
    NSLog(@"[WizKey]   invoke: %p (unslid: 0x%llX)", bl->invoke, unslid);

    // Check if it has captures (BLOCK_HAS_COPY_DISPOSE = 1<<25)
    if (bl->flags & (1 << 25)) {
        NSLog(@"[WizKey]   HAS CAPTURES (stack/heap block with captured vars)");
        // Dump first few captured values
        uint64_t *captured = (uint64_t *)((uint8_t *)bl + sizeof(struct Block_layout));
        for (int i = 0; i < 4; i++) {
            NSLog(@"[WizKey]   capture[%d]: 0x%llX", i, captured[i]);
        }
    } else {
        NSLog(@"[WizKey]   NO CAPTURES (global block)");
    }
}

__attribute__((constructor))
static void wizard_bypass_init(void) {
    NSLog(@"[WizKey] === v63 BLOCK INTERCEPTOR START ===");

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

    // ═══════════════════════════════════════════
    // HOOK addButton:validationBlock:actionBlock:
    // Intercept the REAL blocks when popup is created
    // ═══════════════════════════════════════════
    Class sclAlert = objc_getClass("SCLAlertView");
    if (sclAlert) {
        // Hook addButton:validationBlock:actionBlock: (3 params + self + _cmd = 5)
        SEL addBtnValSel = sel_registerName("addButton:validationBlock:actionBlock:");
        Method m = class_getInstanceMethod(sclAlert, addBtnValSel);
        if (m) {
            void (*orig_addBtnVal)(id, SEL, id, id, id) =
                (void (*)(id, SEL, id, id, id))method_getImplementation(m);

            method_setImplementation(m, imp_implementationWithBlock(
                ^(id self, id title, id valBlock, id actBlock) {
                    NSLog(@"[WizKey] *** addButton:validationBlock:actionBlock: CALLED ***");
                    NSLog(@"[WizKey] Button title: %@", title);

                    if (g_wizard_slide) {
                        log_block_info("validationBlock", valBlock);
                        log_block_info("actionBlock", actBlock);
                    } else {
                        NSLog(@"[WizKey] (slide not yet resolved, raw addrs)");
                        if (valBlock) {
                            struct Block_layout *vb = (__bridge struct Block_layout *)valBlock;
                            NSLog(@"[WizKey] valBlock invoke: %p", vb->invoke);
                        }
                        if (actBlock) {
                            struct Block_layout *ab = (__bridge struct Block_layout *)actBlock;
                            NSLog(@"[WizKey] actBlock invoke: %p", ab->invoke);
                        }
                    }

                    // Call original
                    orig_addBtnVal(self, addBtnValSel, title, valBlock, actBlock);
                }
            ));
            NSLog(@"[WizKey] addButton:validationBlock:actionBlock: HOOKED");
        } else {
            NSLog(@"[WizKey] addButton:validationBlock:actionBlock: NOT FOUND");
        }

        // Also hook addButton:actionBlock: (might be used instead)
        SEL addBtnActSel = sel_registerName("addButton:actionBlock:");
        Method m2 = class_getInstanceMethod(sclAlert, addBtnActSel);
        if (m2) {
            void (*orig_addBtnAct)(id, SEL, id, id) =
                (void (*)(id, SEL, id, id))method_getImplementation(m2);

            method_setImplementation(m2, imp_implementationWithBlock(
                ^(id self, id title, id actBlock) {
                    NSLog(@"[WizKey] *** addButton:actionBlock: CALLED ***");
                    NSLog(@"[WizKey] Button title: %@", title);

                    if (g_wizard_slide && actBlock) {
                        log_block_info("actionBlock", actBlock);
                    }

                    orig_addBtnAct(self, addBtnActSel, title, actBlock);
                }
            ));
            NSLog(@"[WizKey] addButton:actionBlock: HOOKED");
        }

        // Hook buttonTapped: too
        Method m3 = class_getInstanceMethod(sclAlert, sel_registerName("buttonTapped:"));
        if (m3) {
            void (*orig_tap)(id, SEL, id) = (void (*)(id, SEL, id))method_getImplementation(m3);
            method_setImplementation(m3, imp_implementationWithBlock(^(id self, id button) {
                NSLog(@"[WizKey] buttonTapped: fired");

                // Log the button's validationBlock and actionBlock
                @try {
                    id valBlock = ((id(*)(id,SEL))objc_msgSend)(button, sel_registerName("validationBlock"));
                    id actBlock = ((id(*)(id,SEL))objc_msgSend)(button, sel_registerName("actionBlock"));

                    if (g_wizard_slide) {
                        log_block_info("button.validationBlock", valBlock);
                        log_block_info("button.actionBlock", actBlock);
                    }

                    // DON'T clear validation this time — let it run so we can see what happens
                    // But log the result
                    if (valBlock) {
                        NSLog(@"[WizKey] Calling validationBlock to see result...");
                        BOOL result = ((BOOL(*)(id))valBlock)(valBlock);
                        NSLog(@"[WizKey] validationBlock returned: %d", result);
                    }
                } @catch (NSException *e) {
                    NSLog(@"[WizKey] block inspection error: %@", e);
                }

                // Now clear validation and call original
                ((void(*)(id,SEL,id))objc_msgSend)(button, sel_registerName("setValidationBlock:"), nil);
                orig_tap(self, sel_registerName("buttonTapped:"), button);
            }));
            NSLog(@"[WizKey] buttonTapped: hooked");
        }
    }

    // Delayed: resolve Wizard slide + set config
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

        // Config + auth
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

        NSLog(@"[WizKey] === READY — Wait for popup, type key, tap submit ===");
    });
}
