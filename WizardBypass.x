// WizardBypass v60 — Hook buttonTapped: to clear validation
// Instead of hooking validationBlock getter (class hierarchy issues),
// hook buttonTapped: and call setValidationBlock:nil BEFORE original runs.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <mach-o/dyld.h>
#import <signal.h>

// ── Anti-tamper signal handler ──
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

// ── Hook: SCLAlertView buttonTapped: ──
static void (*orig_buttonTapped)(id, SEL, id) = NULL;
static void hooked_buttonTapped(id self, SEL _cmd, id button) {
    // Clear validation block on the button — doesn't matter what class it is
    NSLog(@"[WizKey] buttonTapped: fired! Button class: %@", NSStringFromClass([button class]));
    @try {
        ((void(*)(id, SEL, id))objc_msgSend)(button, sel_registerName("setValidationBlock:"), nil);
        NSLog(@"[WizKey] *** setValidationBlock:nil — validation bypassed! ***");
    } @catch (NSException *e) {
        NSLog(@"[WizKey] setValidationBlock failed: %@", e);
    }
    // Call original — with validationBlock=nil, it will skip validation and call actionBlock
    orig_buttonTapped(self, _cmd, button);
}

// ── Hook: UIImage imageWithData: (keygen data capture) ──
static id (*orig_imageWithData)(id, SEL, id) = NULL;
static id hooked_imageWithData(id self, SEL _cmd, id data) {
    id result = orig_imageWithData(self, _cmd, data);
    if (data) {
        NSUInteger len = [(NSData *)data length];
        if (len > 100 && len < 100000) {
            const uint8_t *b = [(NSData *)data bytes];
            NSMutableString *hex = [NSMutableString string];
            for (NSUInteger i = 0; i < MIN(64, len); i++)
                [hex appendFormat:@"%02X", b[i]];
            NSLog(@"[WizKey] imageWithData len=%lu first64=%@ result=%@",
                  (unsigned long)len, hex, result ? @"VALID" : @"nil");
        }
    }
    return result;
}

// ── Constructor ──
__attribute__((constructor))
static void wizard_bypass_init(void) {
    NSLog(@"[WizKey] === v60 START ===");

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

    // ═══════════════════════════════════════════════════════
    // HOOK buttonTapped: on SCLAlertView
    // Clear validationBlock on the button BEFORE original runs
    // ═══════════════════════════════════════════════════════
    Class sclAlert = objc_getClass("SCLAlertView");
    if (sclAlert) {
        Method m = class_getInstanceMethod(sclAlert, sel_registerName("buttonTapped:"));
        if (m) {
            orig_buttonTapped = (void (*)(id, SEL, id))method_getImplementation(m);
            method_setImplementation(m, (IMP)hooked_buttonTapped);
            NSLog(@"[WizKey] SCLAlertView.buttonTapped: hooked ✓");
        }
    }

    // Hook UIImage imageWithData:
    Method imgM = class_getClassMethod([UIImage class], @selector(imageWithData:));
    if (imgM) {
        orig_imageWithData = (id (*)(id, SEL, id))method_getImplementation(imgM);
        method_setImplementation(imgM, (IMP)hooked_imageWithData);
        NSLog(@"[WizKey] UIImage imageWithData: hooked ✓");
    }

    // Delayed config
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

        uint64_t base = (uint64_t)wizard_slide;
        uint8_t *cfg = (uint8_t *)(base + 0x1B0B470);
        uint8_t *auth = (uint8_t *)(base + 0x1B0B4A9);

        cfg[0]=1; cfg[1]=1; cfg[2]=1; cfg[3]=1;
        cfg[4]=1; cfg[5]=1; cfg[6]=0; cfg[7]=1;
        memcpy(cfg+8,  (void*)(base+0xFD6820), 16);
        memcpy(cfg+24, (void*)(base+0xFD6830), 16);
        memcpy((void*)(base+0x1B0B498), (void*)(base+0xFD6840), 16);
        memcpy((void*)(base+0x1B0B4B0), (void*)(base+0xFD6850), 16);
        memcpy((void*)(base+0x1B0B4C0), (void*)(base+0xFD6860), 16);

        *auth = 1;
        NSLog(@"[WizKey] Config + auth set");

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            while (1) { usleep(50000); if (*auth != 1) *auth = 1; }
        });
        NSLog(@"[WizKey] === READY ===");
    });
}
