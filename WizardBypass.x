// WizardBypass v62 — KEY TRACER: Monitor 0x1E73CE8 to find who writes the key
// Also hooks sub_AE49F4 to log every read + polls for value changes

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <mach-o/dyld.h>
#import <signal.h>

static uint64_t g_wizard_base = 0;
static uint64_t g_last_key_value = 0;
static uint64_t g_last_meta_value = 0;

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
    NSLog(@"[WizKey] === v62 KEY TRACER START ===");

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

    // Hook buttonTapped: to log text field content + key value
    Class sclAlert = objc_getClass("SCLAlertView");
    if (sclAlert) {
        Method m = class_getInstanceMethod(sclAlert, sel_registerName("buttonTapped:"));
        if (m) {
            void (*orig)(id, SEL, id) = (void (*)(id, SEL, id))method_getImplementation(m);
            method_setImplementation(m, imp_implementationWithBlock(^(id self, id button) {
                // Read text field content
                @try {
                    // Get all subviews to find SCLTextView
                    id contentView = ((id(*)(id,SEL))objc_msgSend)(self, sel_registerName("view"));
                    if (contentView) {
                        NSArray *subviews = ((id(*)(id,SEL))objc_msgSend)(contentView, sel_registerName("subviews"));
                        for (id sv in subviews) {
                            NSArray *inner = ((id(*)(id,SEL))objc_msgSend)(sv, sel_registerName("subviews"));
                            for (id isv in inner) {
                                if ([isv isKindOfClass:[UITextField class]]) {
                                    NSString *text = ((id(*)(id,SEL))objc_msgSend)(isv, sel_registerName("text"));
                                    NSLog(@"[WizKey] TEXT FIELD VALUE: '%@'", text);
                                    
                                    // Get bytes of text
                                    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
                                    NSLog(@"[WizKey] TEXT BYTES: %@", data);
                                    NSLog(@"[WizKey] TEXT LENGTH: %lu", (unsigned long)data.length);
                                }
                            }
                        }
                    }
                } @catch (NSException *e) {
                    NSLog(@"[WizKey] text read error: %@", e);
                }

                // Log key QWORD BEFORE validation
                if (g_wizard_base) {
                    uint64_t *keyPtr = (uint64_t *)(g_wizard_base + 0x1E73CE8);
                    uint64_t *metaPtr = (uint64_t *)(g_wizard_base + 0x1E73CF0);
                    NSLog(@"[WizKey] KEY QWORD BEFORE buttonTapped: 0x%016llX", *keyPtr);
                    NSLog(@"[WizKey] META QWORD BEFORE buttonTapped: 0x%016llX", *metaPtr);
                }

                // Clear validation
                ((void(*)(id,SEL,id))objc_msgSend)(button, sel_registerName("setValidationBlock:"), nil);
                NSLog(@"[WizKey] validationBlock cleared");

                // Call original
                orig(self, sel_registerName("buttonTapped:"), button);

                // Log key QWORD AFTER
                if (g_wizard_base) {
                    uint64_t *keyPtr = (uint64_t *)(g_wizard_base + 0x1E73CE8);
                    uint64_t *metaPtr = (uint64_t *)(g_wizard_base + 0x1E73CF0);
                    NSLog(@"[WizKey] KEY QWORD AFTER buttonTapped: 0x%016llX", *keyPtr);
                    NSLog(@"[WizKey] META QWORD AFTER buttonTapped: 0x%016llX", *metaPtr);
                }
            }));
            NSLog(@"[WizKey] buttonTapped: hooked with key tracing");
        }
    }

    // Hook SCLTextView (UITextField) textDidChange to catch key writes in real-time
    Class sclText = objc_getClass("SCLTextView");
    if (sclText) {
        NSLog(@"[WizKey] SCLTextView class found");
    } else {
        NSLog(@"[WizKey] SCLTextView NOT found, will monitor via polling");
    }

    // Delayed: find Wizard base + start polling
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
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

        g_wizard_base = (uint64_t)wizard_slide;
        NSLog(@"[WizKey] Wizard slide: 0x%lx", (long)wizard_slide);

        uint64_t *keyPtr = (uint64_t *)(g_wizard_base + 0x1E73CE8);
        uint64_t *metaPtr = (uint64_t *)(g_wizard_base + 0x1E73CF0);

        NSLog(@"[WizKey] INITIAL KEY QWORD: 0x%016llX", *keyPtr);
        NSLog(@"[WizKey] INITIAL META QWORD: 0x%016llX", *metaPtr);

        g_last_key_value = *keyPtr;
        g_last_meta_value = *metaPtr;

        // Set config + auth
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

        // POLL: monitor 0x1E73CE8 for changes every 100ms
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            while (1) {
                usleep(100000); // 100ms
                uint64_t curKey = *keyPtr;
                uint64_t curMeta = *metaPtr;
                if (curKey != g_last_key_value) {
                    NSLog(@"[WizKey] *** KEY CHANGED! 0x%016llX → 0x%016llX ***", g_last_key_value, curKey);
                    // Dump as bytes
                    uint8_t *kb = (uint8_t *)keyPtr;
                    NSLog(@"[WizKey] KEY BYTES: %02x %02x %02x %02x %02x %02x %02x %02x",
                          kb[0], kb[1], kb[2], kb[3], kb[4], kb[5], kb[6], kb[7]);
                    // Dump as ASCII
                    char ascii[9] = {0};
                    for (int i=0; i<8; i++) ascii[i] = (kb[i] >= 0x20 && kb[i] < 0x7F) ? kb[i] : '.';
                    NSLog(@"[WizKey] KEY ASCII: '%s'", ascii);
                    g_last_key_value = curKey;
                }
                if (curMeta != g_last_meta_value) {
                    NSLog(@"[WizKey] *** META CHANGED! 0x%016llX → 0x%016llX ***", g_last_meta_value, curMeta);
                    g_last_meta_value = curMeta;
                }
            }
        });

        NSLog(@"[WizKey] === READY — Type a key, tap submit! Watch for KEY CHANGED logs ===");
    });
}
