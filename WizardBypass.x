// WizardBypass v64 — RUNTIME KEY TESTER
// Since static analysis hits obfuscation wall (indirect BR jumps),
// we test keys dynamically: hook the OK button handler (0x78702C),
// programmatically set text field values, and observe the outcome.
// We detect success by monitoring if IKAFHFDSAJ is called or if
// the menu views are created.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <mach-o/dyld.h>
#import <signal.h>

struct Block_layout {
    void *isa;
    int flags;
    int reserved;
    void (*invoke)(void *, ...);
    void *descriptor;
};

static uint64_t g_wizard_base = 0;
static intptr_t g_wizard_slide = 0;
static BOOL g_ikafhfdsaj_called = NO;
static id g_captured_textfield = nil;
static id g_captured_alert = nil;
static id g_ok_action_block = nil;

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
    NSLog(@"[WizKey] === v64 RUNTIME KEY TESTER START ===");

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

    // Hook IKAFHFDSAJ to detect when a valid key triggers it
    Class abvClass = objc_getClass("ABVJSMGADJS");
    if (abvClass) {
        Method m = class_getInstanceMethod(abvClass, sel_registerName("IKAFHFDSAJ"));
        if (m) {
            void (*orig_ik)(id, SEL) = (void (*)(id, SEL))method_getImplementation(m);
            method_setImplementation(m, imp_implementationWithBlock(^(id self) {
                NSLog(@"[WizKey] *** IKAFHFDSAJ CALLED! KEY IS VALID! ***");
                g_ikafhfdsaj_called = YES;
                orig_ik(self, sel_registerName("IKAFHFDSAJ"));
            }));
            NSLog(@"[WizKey] IKAFHFDSAJ hooked (success detector)");
        }
    }

    Class sclAlert = objc_getClass("SCLAlertView");
    if (sclAlert) {
        // Hook addButton:actionBlock: to capture the OK block + alert instance
        SEL addBtnActSel = sel_registerName("addButton:actionBlock:");
        Method m2 = class_getInstanceMethod(sclAlert, addBtnActSel);
        if (m2) {
            void (*orig_addBtnAct)(id, SEL, id, id) =
                (void (*)(id, SEL, id, id))method_getImplementation(m2);

            method_setImplementation(m2, imp_implementationWithBlock(
                ^(id self, id title, id actBlock) {
                    NSLog(@"[WizKey] addButton:actionBlock: '%@'", title);

                    if ([title isEqualToString:@"OK"] || [title isEqualToString:@"Submit"]) {
                        g_captured_alert = self;
                        g_ok_action_block = [actBlock copy];
                        NSLog(@"[WizKey] *** OK button captured! Alert: %p, Block: %p ***", self, actBlock);

                        // Find text field in alert
                        @try {
                            id view = ((id(*)(id,SEL))objc_msgSend)(self, sel_registerName("view"));
                            if (view) {
                                NSArray *subs = ((id(*)(id,SEL))objc_msgSend)(view, sel_registerName("subviews"));
                                for (id sv in subs) {
                                    NSArray *inner = ((id(*)(id,SEL))objc_msgSend)(sv, sel_registerName("subviews"));
                                    for (id isv in inner) {
                                        if ([isv isKindOfClass:[UITextField class]]) {
                                            g_captured_textfield = isv;
                                            NSLog(@"[WizKey] Text field captured: %p", isv);
                                        }
                                    }
                                }
                            }
                        } @catch (NSException *e) {}
                    }

                    orig_addBtnAct(self, addBtnActSel, title, actBlock);
                }
            ));
            NSLog(@"[WizKey] addButton:actionBlock: HOOKED");
        }

        // Hook hideView to detect popup dismissal
        Method m3 = class_getInstanceMethod(sclAlert, sel_registerName("hideView:"));
        if (m3) {
            void (*orig_hide)(id, SEL, id) = (void (*)(id, SEL, id))method_getImplementation(m3);
            method_setImplementation(m3, imp_implementationWithBlock(^(id self, id completion) {
                NSLog(@"[WizKey] hideView: called (popup closing)");
                orig_hide(self, sel_registerName("hideView:"), completion);
            }));
        }

        // Hook buttonTapped: to log and let through
        Method m4 = class_getInstanceMethod(sclAlert, sel_registerName("buttonTapped:"));
        if (m4) {
            void (*orig_tap)(id, SEL, id) = (void (*)(id, SEL, id))method_getImplementation(m4);
            method_setImplementation(m4, imp_implementationWithBlock(^(id self, id button) {
                // Get current text
                if (g_captured_textfield) {
                    NSString *text = ((id(*)(id,SEL))objc_msgSend)(g_captured_textfield, sel_registerName("text"));
                    NSLog(@"[WizKey] buttonTapped with key: '%@'", text);
                }
                orig_tap(self, sel_registerName("buttonTapped:"), button);

                // Check if IKAFHFDSAJ was triggered
                if (g_ikafhfdsaj_called) {
                    NSLog(@"[WizKey] *** SUCCESS! IKAFHFDSAJ was called after button tap! ***");
                }
            }));
            NSLog(@"[WizKey] buttonTapped: hooked");
        }
    }

    // Delayed: resolve slide + config + start key testing
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

        // Wait for popup to appear, then start testing keys after 10s
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            if (!g_ok_action_block) {
                NSLog(@"[WizKey] No OK block captured yet — enter popup first, then keys will be tested");
                return;
            }

            NSLog(@"[WizKey] === STARTING KEY TESTS ===");

            // Get the block's invoke function
            struct Block_layout *bl = (__bridge struct Block_layout *)g_ok_action_block;
            typedef void (*BlockInvoke)(void *);
            BlockInvoke invokeOK = (BlockInvoke)bl->invoke;

            // Test various key formats
            NSArray *testKeys = @[
                @"0000-0000-0000-0000",
                @"1234-5678-9ABC-DEF0",
                @"AAAA-AAAA-AAAA-AAAA",
                @"WIZARD",
                @"wizard",
                @"admin",
                @"test",
                @"1234567890",
                @"ABCDEFGHIJ",
                @"0000000000000000",
                @"FFFFFFFFFFFFFFFF",
                @"1111111111111111",
            ];

            for (NSString *key in testKeys) {
                g_ikafhfdsaj_called = NO;

                // Set text field value
                if (g_captured_textfield) {
                    ((void(*)(id,SEL,id))objc_msgSend)(g_captured_textfield,
                        sel_registerName("setText:"), key);
                }

                NSLog(@"[WizKey] Testing key: '%@'", key);

                // Call the OK button's action block
                @try {
                    invokeOK((__bridge void *)g_ok_action_block);
                } @catch (NSException *e) {
                    NSLog(@"[WizKey] Exception for key '%@': %@", key, e);
                }

                if (g_ikafhfdsaj_called) {
                    NSLog(@"[WizKey] *** VALID KEY FOUND: '%@' ***", key);
                    break;
                }

                // Small delay between tests
                usleep(100000);
            }

            NSLog(@"[WizKey] === KEY TESTS COMPLETE ===");
        });

        NSLog(@"[WizKey] === READY — popup will appear, wait 10s for auto-testing ===");
    });
}
