// WizardBypass v65 — NETWORK DETECTOR + KEY FORMAT TESTER
// Hooks NSURLSession to detect if key validation is server-side
// Tests the real key format (32 alphanumeric chars)

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
static BOOL g_network_called = NO;
static id g_captured_textfield = nil;
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
    NSLog(@"[WizKey] === v65 NETWORK DETECTOR START ===");

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

    // ═══════════════════════════════════════
    // HOOK ALL NETWORK METHODS
    // ═══════════════════════════════════════

    // Hook NSURLSession dataTaskWithRequest:completionHandler:
    Class sessionClass = [NSURLSession class];
    SEL dtSel = sel_registerName("dataTaskWithRequest:completionHandler:");
    Method dtM = class_getInstanceMethod(sessionClass, dtSel);
    if (dtM) {
        void (*orig_dt)(id, SEL, id, id) = (void (*)(id, SEL, id, id))method_getImplementation(dtM);
        method_setImplementation(dtM, imp_implementationWithBlock(
            ^(id self, NSURLRequest *request, id completion) {
                g_network_called = YES;
                NSLog(@"[WizKey] *** NETWORK: dataTaskWithRequest ***");
                NSLog(@"[WizKey]   URL: %@", request.URL);
                NSLog(@"[WizKey]   Method: %@", request.HTTPMethod);
                if (request.HTTPBody) {
                    NSString *body = [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding];
                    NSLog(@"[WizKey]   Body: %@", body);
                }
                NSDictionary *headers = request.allHTTPHeaderFields;
                if (headers) {
                    NSLog(@"[WizKey]   Headers: %@", headers);
                }
                orig_dt(self, dtSel, request, completion);
            }
        ));
        NSLog(@"[WizKey] NSURLSession dataTask hooked");
    }

    // Hook NSURLSession dataTaskWithURL:completionHandler:
    SEL dtUrlSel = sel_registerName("dataTaskWithURL:completionHandler:");
    Method dtUrlM = class_getInstanceMethod(sessionClass, dtUrlSel);
    if (dtUrlM) {
        void (*orig_dtu)(id, SEL, id, id) = (void (*)(id, SEL, id, id))method_getImplementation(dtUrlM);
        method_setImplementation(dtUrlM, imp_implementationWithBlock(
            ^(id self, NSURL *url, id completion) {
                g_network_called = YES;
                NSLog(@"[WizKey] *** NETWORK: dataTaskWithURL ***");
                NSLog(@"[WizKey]   URL: %@", url);
                orig_dtu(self, dtUrlSel, url, completion);
            }
        ));
    }

    // Hook NSURLConnection sendSynchronousRequest (legacy)
    Class connClass = objc_getClass("NSURLConnection");
    if (connClass) {
        SEL syncSel = sel_registerName("sendSynchronousRequest:returningResponse:error:");
        Method syncM = class_getClassMethod(connClass, syncSel);
        if (syncM) {
            void (*orig_sync)(id, SEL, id, id, id) = (void (*)(id, SEL, id, id, id))method_getImplementation(syncM);
            method_setImplementation(syncM, imp_implementationWithBlock(
                ^(id self, NSURLRequest *req, id resp, id err) {
                    g_network_called = YES;
                    NSLog(@"[WizKey] *** NETWORK: sendSynchronousRequest ***");
                    NSLog(@"[WizKey]   URL: %@", req.URL);
                    orig_sync(self, syncSel, req, resp, err);
                }
            ));
        }
    }
    NSLog(@"[WizKey] Network hooks installed");

    // Hook IKAFHFDSAJ
    Class abvClass = objc_getClass("ABVJSMGADJS");
    if (abvClass) {
        Method m = class_getInstanceMethod(abvClass, sel_registerName("IKAFHFDSAJ"));
        if (m) {
            void (*orig_ik)(id, SEL) = (void (*)(id, SEL))method_getImplementation(m);
            method_setImplementation(m, imp_implementationWithBlock(^(id self) {
                NSLog(@"[WizKey] *** IKAFHFDSAJ CALLED! ***");
                g_ikafhfdsaj_called = YES;
                orig_ik(self, sel_registerName("IKAFHFDSAJ"));
            }));
        }
    }

    // Hook SCLAlertView
    Class sclAlert = objc_getClass("SCLAlertView");
    if (sclAlert) {
        SEL addBtnActSel = sel_registerName("addButton:actionBlock:");
        Method m2 = class_getInstanceMethod(sclAlert, addBtnActSel);
        if (m2) {
            void (*orig)(id, SEL, id, id) = (void (*)(id, SEL, id, id))method_getImplementation(m2);
            method_setImplementation(m2, imp_implementationWithBlock(
                ^(id self, id title, id actBlock) {
                    NSLog(@"[WizKey] addButton: '%@'", title);
                    if ([title isEqualToString:@"OK"] || [title isEqualToString:@"Submit"]) {
                        g_ok_action_block = [actBlock copy];
                        // Find text field
                        @try {
                            id view = ((id(*)(id,SEL))objc_msgSend)(self, sel_registerName("view"));
                            if (view) {
                                NSArray *subs = ((id(*)(id,SEL))objc_msgSend)(view, sel_registerName("subviews"));
                                for (id sv in subs) {
                                    NSArray *inner = ((id(*)(id,SEL))objc_msgSend)(sv, sel_registerName("subviews"));
                                    for (id isv in inner) {
                                        if ([isv isKindOfClass:[UITextField class]]) {
                                            g_captured_textfield = isv;
                                            NSLog(@"[WizKey] Text field captured");
                                        }
                                    }
                                }
                            }
                        } @catch (NSException *e) {}
                    }
                    orig(self, addBtnActSel, title, actBlock);
                }
            ));
        }

        // Hook buttonTapped:
        Method m3 = class_getInstanceMethod(sclAlert, sel_registerName("buttonTapped:"));
        if (m3) {
            void (*orig_tap)(id, SEL, id) = (void (*)(id, SEL, id))method_getImplementation(m3);
            method_setImplementation(m3, imp_implementationWithBlock(^(id self, id button) {
                g_network_called = NO;
                g_ikafhfdsaj_called = NO;

                NSString *text = nil;
                if (g_captured_textfield) {
                    text = ((id(*)(id,SEL))objc_msgSend)(g_captured_textfield, sel_registerName("text"));
                    NSLog(@"[WizKey] buttonTapped key: '%@' (len=%lu)", text, (unsigned long)text.length);
                }

                orig_tap(self, sel_registerName("buttonTapped:"), button);

                // Check results after 2 seconds (for async network)
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                    dispatch_get_main_queue(), ^{
                    NSLog(@"[WizKey] === POST-TAP RESULTS ===");
                    NSLog(@"[WizKey]   Network called: %@", g_network_called ? @"YES ← SERVER VALIDATION!" : @"NO (local)");
                    NSLog(@"[WizKey]   IKAFHFDSAJ called: %@", g_ikafhfdsaj_called ? @"YES ← VALID KEY!" : @"NO");
                });
            }));
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

        NSLog(@"[WizKey] === READY — Type the key, tap OK, check POST-TAP RESULTS ===");
    });
}
