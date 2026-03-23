// WizardBypass v58 — KEY DUMPER
// Hooks NSData dataWithBytes:length: to capture what the validation loops produce
// Also hooks UIImage imageWithData: to know if the key is valid
// Read output with: idevicesyslog.exe | findstr "WizardDump"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <mach-o/dyld.h>
#import <signal.h>

// ── Anti-tamper signal handler ──────────────────────────────
static void anti_tamper_handler(int sig, siginfo_t *info, void *context) {
    ucontext_t *uc = (ucontext_t *)context;
    _STRUCT_MCONTEXT64 *mc = uc->uc_mcontext;
    mc->__ss.__pc = (uint64_t)uc + 8; // skip 0xDEAD
}

// jsafbSAHCN hooked via imp_implementationWithBlock in constructor

// ── Hook: NSData dataWithBytes:length: ──────────────────────
static id (*orig_dataWithBytes)(id, SEL, const void*, NSUInteger) = NULL;
static id hooked_dataWithBytes(id self, SEL _cmd, const void *bytes, NSUInteger len) {
    // Only log outputs from Wizard framework (> 100 bytes = likely image data)
    if (len > 100 && len < 100000) {
        NSLog(@"[WizardDump] dataWithBytes:length: called, len=%lu", (unsigned long)len);
        
        // Log first 32 bytes as hex
        const uint8_t *b = (const uint8_t *)bytes;
        NSMutableString *hex = [NSMutableString string];
        for (NSUInteger i = 0; i < MIN(32, len); i++) {
            [hex appendFormat:@"%02X ", b[i]];
        }
        NSLog(@"[WizardDump] First 32 bytes: %@", hex);
        
        // Check if it's a valid PNG (starts with PNG header)
        if (len > 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
            NSLog(@"[WizardDump] *** VALID PNG DETECTED! len=%lu ***", (unsigned long)len);
            // Dump ALL bytes as hex for full keygen
            NSMutableString *fullHex = [NSMutableString string];
            for (NSUInteger i = 0; i < len; i++) {
                [fullHex appendFormat:@"%02X", b[i]];
            }
            NSLog(@"[WizardDump] FULL PNG HEX: %@", fullHex);
        }
    }
    return orig_dataWithBytes(self, _cmd, bytes, len);
}

// ── Hook: UIImage imageWithData: ────────────────────────────
static id (*orig_imageWithData)(id, SEL, id) = NULL;
static id hooked_imageWithData(id self, SEL _cmd, id data) {
    id result = orig_imageWithData(self, _cmd, data);
    if (result) {
        NSLog(@"[WizardDump] *** UIImage created! KEY IS VALID! ***");
    } else {
        NSLog(@"[WizardDump] UIImage nil — key invalid or data not ready");
    }
    return result;
}

// ── Constructor ─────────────────────────────────────────────
__attribute__((constructor))
static void wizard_dumper_init(void) {
    NSLog(@"[WizardDump] === v58 KEY DUMPER START ===");
    
    // Signal handler
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = anti_tamper_handler;
    sa.sa_flags = SA_SIGINFO;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGBUS, &sa, NULL);
    sigaction(SIGSEGV, &sa, NULL);
    
    // Hook jsafbSAHCN (anti-tamper NOP)
    Class wksClass = objc_getClass("Wksahfnasj");
    if (wksClass) {
        Method m = class_getInstanceMethod(wksClass, sel_registerName("jsafbSAHCN"));
        if (m) {
            method_setImplementation(m, imp_implementationWithBlock(^(id self) {}));
            NSLog(@"[WizardDump] jsafbSAHCN NOP'd");
        }
    }
    
    // Hook NSData dataWithBytes:length: (class method)
    Class NSDataClass = objc_getMetaClass("NSData");
    if (NSDataClass) {
        Method m = class_getClassMethod(objc_getClass("NSData"), @selector(dataWithBytes:length:));
        if (m) {
            orig_dataWithBytes = (id (*)(id, SEL, const void*, NSUInteger))method_getImplementation(m);
            method_setImplementation(m, (IMP)hooked_dataWithBytes);
            NSLog(@"[WizardDump] NSData dataWithBytes:length: hooked");
        }
    }
    
    // Hook UIImage imageWithData: (class method)  
    Method imgM = class_getClassMethod(objc_getClass("UIImage"), @selector(imageWithData:));
    if (imgM) {
        orig_imageWithData = (id (*)(id, SEL, id))method_getImplementation(imgM);
        method_setImplementation(imgM, (IMP)hooked_imageWithData);
        NSLog(@"[WizardDump] UIImage imageWithData: hooked");
    }
    
    // Also hook SCLButton.validationBlock → nil
    Class sclBtnClass = objc_getClass("SCLButton");
    if (sclBtnClass) {
        Method m = class_getInstanceMethod(sclBtnClass, sel_registerName("validationBlock"));
        if (m) {
            method_setImplementation(m, imp_implementationWithBlock(^id(id self) { return nil; }));
            NSLog(@"[WizardDump] SCLButton.validationBlock → nil");
        }
    }
    
    NSLog(@"[WizardDump] === READY — Enter any key and tap submit ===");
}
