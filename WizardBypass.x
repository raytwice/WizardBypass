// Wizard Authentication Bypass
// v35: diagnostic hooks to find real key validation path

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <QuartzCore/QuartzCore.h>
#import <mach/mach.h>
#import <libkern/OSCacheControl.h>
#import <CommonCrypto/CommonCrypto.h>
#import <Security/Security.h>
#import <execinfo.h>
#include "fishhook.h"

// ============================================================================
// GLOBAL: Wizard controller reference accessible from didTapIconView
// Since Pajdsakdfj has 0 ivars, we use a global to bridge the gap
// ============================================================================
static id g_wizardController = nil;
static id g_wizardIcon = nil;

// v31: Crypto auth bypass.
// SCLAlertView is ALLOWED to show â€” Wizard's own key entry dialog appears.
// CommonCrypto/Security hooks make any entered key pass validation.

// ============================================================================
// PHASE 1: DYLD HIDING - Hide our dylib from detection
// ============================================================================

static uint32_t (*original_dyld_image_count)(void) = NULL;
static const char* (*original_dyld_get_image_name_ptr)(uint32_t) = NULL;

// Hook dyld_image_count to hide our dylib
uint32_t hooked_dyld_image_count(void) {
    if (!original_dyld_image_count) {
        return _dyld_image_count();
    }
    uint32_t count = original_dyld_image_count();
    NSLog(@"[WizardBypass] dyld_image_count called, real count: %u", count);

    // Check if WizardBypass.dylib is in the list
    for (uint32_t i = 0; i < count; i++) {
        const char* name = _dyld_get_image_name(i);
        if (name && strstr(name, "WizardBypass")) {
            NSLog(@"[WizardBypass] Hiding WizardBypass.dylib from count");
            return count - 1;  // Hide our dylib
        }
    }
    return count;
}

// Hook dyld_get_image_name to skip our dylib
const char* hooked_dyld_get_image_name(uint32_t index) {
    if (!original_dyld_get_image_name_ptr) {
        return _dyld_get_image_name(index);
    }

    const char* name = original_dyld_get_image_name_ptr(index);
    if (name && strstr(name, "WizardBypass")) {
        NSLog(@"[WizardBypass] Hiding WizardBypass.dylib from name query");
        // Return next image instead
        return original_dyld_get_image_name_ptr(index + 1);
    }
    return name;
}

// ============================================================================
// PHASE 2: REMOVED - Memory patching causes KERN_PROTECTION_FAILURE
// ============================================================================
// The patch_dead_trap() function has been removed because:
// - vm_protect() fails on iOS due to code signing
// - Attempting to write to read-only memory causes SIGBUS crash
// - Method swizzling is the correct approach for iOS

// ============================================================================
// PHASE 3: AUTH FLAG MANIPULATION - Force authentication to succeed
// ============================================================================

static void force_authentication(void) {
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] FORCING AUTHENTICATION - SMART APPROACH");
    NSLog(@"[WizardBypass] ========================================");

    // Strategy: Hook ALL classes in Wizard.framework that might check auth
    // Look for methods that return BOOL and might be validation checks

    unsigned int class_count;
    Class *classes = objc_copyClassList(&class_count);

    int hooked_classes = 0;
    int hooked_methods = 0;

    for (unsigned int i = 0; i < class_count; i++) {
        const char* class_name = class_getName(classes[i]);

        // Only hook classes from Wizard.framework (not system classes)
        // Check if class is defined in Wizard by checking its image
        const char* image_name = class_getImageName(classes[i]);
        if (!image_name || !strstr(image_name, "Wizard.framework")) {
            continue;
        }

        // Skip SCL classes (UI components)
        if (strncmp(class_name, "SCL", 3) == 0) {
            continue;
        }

        NSLog(@"[WizardBypass] Scanning Wizard class: %s", class_name);
        hooked_classes++;

        // LOG key obfuscated classes but DON'T hook them blindly
        // (blind varargs hooking breaks methods with non-object params)
        if (strcmp(class_name, "Pajdsakdfj") == 0 || strcmp(class_name, "Wksahfnasj") == 0 ||
            strcmp(class_name, "AJFADSHFSAJXN") == 0 || strcmp(class_name, "ABVJSMGADJS") == 0) {
            NSLog(@"[WizardBypass] *** FOUND KEY CLASS: %s ***", class_name);

            unsigned int all_method_count;
            Method* all_methods = class_copyMethodList(classes[i], &all_method_count);
            for (unsigned int k = 0; k < all_method_count; k++) {
                SEL sel = method_getName(all_methods[k]);
                const char* method_name = sel_getName(sel);
                NSLog(@"[WizardBypass]   Method: %s::%s", class_name, method_name);
            }
            free(all_methods);
        }

        unsigned int method_count;
        Method* methods = class_copyMethodList(classes[i], &method_count);

        for (unsigned int j = 0; j < method_count; j++) {
            SEL selector = method_getName(methods[j]);
            const char* name = sel_getName(selector);
            char* type_encoding = method_copyReturnType(methods[j]);

            // Skip lifecycle/destructor methods ONLY â€” DO NOT skip setters!
            // Auth flag setters MUST be hooked so they can't reset auth to NO
            if (strncmp(name, "init", 4) == 0 ||
                strcmp(name, "dealloc") == 0 ||
                strcmp(name, ".cxx_destruct") == 0) {
                free(type_encoding);
                continue;
            }

            // Only hook BOOL-returning methods with NO arguments
            // Methods like isEqual: take extra args â€” our block only accepts (id self)
            // so hooking them causes calling convention mismatch â†’ stack corruption â†’ PC=0 crash
            // Also, isEqual: returning YES breaks Metal pipeline state caching
            if (type_encoding[0] == 'c' || type_encoding[0] == 'B') {
                // Skip methods that take arguments (contain ':')
                // Our block is ^BOOL(id self) which only works for 0-arg methods
                if (strchr(name, ':') != NULL) {
                    NSLog(@"[WizardBypass]   SKIPPING BOOL with args: %s::%s (block signature mismatch)", class_name, name);
                    free(type_encoding);
                    continue;
                }

                NSLog(@"[WizardBypass]   Hooking BOOL (no args): %s::%s -> YES", class_name, name);


                IMP new_imp = imp_implementationWithBlock(^BOOL(id self) {
                    return YES;
                });

                method_setImplementation(methods[j], new_imp);
                hooked_methods++;
            }

            free(type_encoding);
        }

        free(methods);
    }

    free(classes);

    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] Scanned %d Wizard classes", hooked_classes);
    NSLog(@"[WizardBypass] Hooked %d BOOL methods", hooked_methods);
    NSLog(@"[WizardBypass] ========================================");
}

// ============================================================================
// PHASE 3B: HOOK NSUserDefaults - Fake license key storage
// ============================================================================

static void hook_user_defaults(void) {
    NSLog(@"[WizardBypass] Hooking NSUserDefaults to monitor license keys...");

    Class defaults_class = objc_getClass("NSUserDefaults");
    if (!defaults_class) {
        NSLog(@"[WizardBypass] WARNING: NSUserDefaults not found");
        return;
    }

    // Hook objectForKey: - Fake auth-token-type specifically
    SEL selector1 = @selector(objectForKey:);
    Method method1 = class_getInstanceMethod(defaults_class, selector1);
    if (method1) {
        IMP original_imp = method_getImplementation(method1);
        IMP new_imp = imp_implementationWithBlock(^id(NSUserDefaults* self, NSString* key) {
            typedef id (*OrigFunc)(NSUserDefaults*, SEL, NSString*);
            id result = ((OrigFunc)original_imp)(self, selector1, key);

            // Log ALL keys to see what Wizard is checking
            if ([key containsString:@"wizard"] || [key containsString:@"Wizard"] ||
                [key containsString:@"license"] || [key containsString:@"key"] ||
                [key containsString:@"auth"] || [key containsString:@"valid"] ||
                [key containsString:@"token"] || [key containsString:@"premium"]) {
                NSLog(@"[WizardBypass] objectForKey: '%@' -> %@ (type: %@)",
                      key, result, [result class]);

                // FAKE auth-token-type specifically
                if ([key isEqualToString:@"auth-token-type"] && !result) {
                    NSLog(@"[WizardBypass] *** FAKING auth-token-type -> 'premium'");
                    return @"premium";
                }
            }

            return result;
        });
        method_setImplementation(method1, new_imp);
        NSLog(@"[WizardBypass] NSUserDefaults objectForKey: hook installed");
    }

    // Hook boolForKey: - ONLY LOG
    SEL selector2 = @selector(boolForKey:);
    Method method2 = class_getInstanceMethod(defaults_class, selector2);
    if (method2) {
        IMP original_imp = method_getImplementation(method2);
        IMP new_imp = imp_implementationWithBlock(^BOOL(NSUserDefaults* self, NSString* key) {
            typedef BOOL (*OrigFunc)(NSUserDefaults*, SEL, NSString*);
            BOOL result = ((OrigFunc)original_imp)(self, selector2, key);

            if ([key containsString:@"wizard"] || [key containsString:@"Wizard"] ||
                [key containsString:@"license"] || [key containsString:@"valid"] ||
                [key containsString:@"auth"] || [key containsString:@"enable"] ||
                [key containsString:@"premium"] || [key containsString:@"active"]) {
                NSLog(@"[WizardBypass] boolForKey: '%@' -> %d", key, result);
            }

            return result;
        });
        method_setImplementation(method2, new_imp);
        NSLog(@"[WizardBypass] NSUserDefaults boolForKey: monitor installed");
    }

    // Hook stringForKey: - ONLY LOG
    SEL selector3 = @selector(stringForKey:);
    Method method3 = class_getInstanceMethod(defaults_class, selector3);
    if (method3) {
        IMP original_imp = method_getImplementation(method3);
        IMP new_imp = imp_implementationWithBlock(^NSString*(NSUserDefaults* self, NSString* key) {
            typedef NSString* (*OrigFunc)(NSUserDefaults*, SEL, NSString*);
            NSString* result = ((OrigFunc)original_imp)(self, selector3, key);

            if ([key containsString:@"wizard"] || [key containsString:@"Wizard"] ||
                [key containsString:@"license"] || [key containsString:@"key"] ||
                [key containsString:@"auth"] || [key containsString:@"token"]) {
                NSLog(@"[WizardBypass] stringForKey: '%@' -> '%@'", key, result);
            }

            return result;
        });
        method_setImplementation(method3, new_imp);
        NSLog(@"[WizardBypass] NSUserDefaults stringForKey: monitor installed");
    }

    // Hook dictionaryForKey: - might be storing license as dictionary
    SEL selector4 = @selector(dictionaryForKey:);
    Method method4 = class_getInstanceMethod(defaults_class, selector4);
    if (method4) {
        IMP original_imp = method_getImplementation(method4);
        IMP new_imp = imp_implementationWithBlock(^NSDictionary*(NSUserDefaults* self, NSString* key) {
            typedef NSDictionary* (*OrigFunc)(NSUserDefaults*, SEL, NSString*);
            NSDictionary* result = ((OrigFunc)original_imp)(self, selector4, key);

            if ([key containsString:@"wizard"] || [key containsString:@"Wizard"] ||
                [key containsString:@"license"] || [key containsString:@"auth"]) {
                NSLog(@"[WizardBypass] dictionaryForKey: '%@' -> %@", key, result);
            }

            return result;
        });
        method_setImplementation(method4, new_imp);
        NSLog(@"[WizardBypass] NSUserDefaults dictionaryForKey: monitor installed");
    }
}



// ============================================================================
// PHASE 4C: HOOK UIViewController presentation
// ============================================================================

static void hook_view_controller_presentation(void) {
    NSLog(@"[WizardBypass] Hooking UIViewController presentation...");

    Class vc_class = objc_getClass("UIViewController");
    if (!vc_class) {
        NSLog(@"[WizardBypass] WARNING: UIViewController not found");
        return;
    }

    // Hook presentViewController:animated:completion:
    SEL selector = @selector(presentViewController:animated:completion:);
    Method method = class_getInstanceMethod(vc_class, selector);

    if (method) {
        IMP original_imp = method_getImplementation(method);
        IMP new_imp = imp_implementationWithBlock(^(UIViewController* self, UIViewController* vc, BOOL animated, void(^completion)(void)) {
            NSString* className = NSStringFromClass([vc class]);
            // v31: Log all presentations but DON'T block anything
            // Let Wizard's SCLAlertView key entry show to the user
            NSLog(@"[WizardBypass] presentViewController: %@ (ALLOWED - v31)", className);
            typedef void (*OrigFunc)(UIViewController*, SEL, UIViewController*, BOOL, void(^)(void));
            ((OrigFunc)original_imp)(self, selector, vc, animated, completion);
        });
        method_setImplementation(method, new_imp);
        NSLog(@"[WizardBypass] UIViewController presentation hook installed (passthrough)");
    }
}

// ============================================================================
// PHASE 4D: HOOK UIWindow - Nuclear option to catch everything
// ============================================================================

static void hook_ui_window(void) {
    NSLog(@"[WizardBypass] Hooking UIWindow methods...");

    Class window_class = objc_getClass("UIWindow");
    if (!window_class) {
        NSLog(@"[WizardBypass] WARNING: UIWindow not found");
        return;
    }

    // Hook makeKeyAndVisible
    SEL selector1 = @selector(makeKeyAndVisible);
    Method method1 = class_getInstanceMethod(window_class, selector1);
    if (method1) {
        IMP original_imp = method_getImplementation(method1);
        IMP new_imp = imp_implementationWithBlock(^(UIWindow* self) {
            // Check if this window contains an alert
            NSString* className = NSStringFromClass([self class]);
            UIViewController* rootVC = self.rootViewController;
            NSString* vcClassName = rootVC ? NSStringFromClass([rootVC class]) : @"nil";

            NSLog(@"[WizardBypass] UIWindow makeKeyAndVisible: %@, rootVC: %@", className, vcClassName);

            // ONLY block actual alert windows, not all SCL* classes
            if ([className containsString:@"Alert"] ||
                [vcClassName isEqualToString:@"SCLAlertView"] ||
                [vcClassName containsString:@"UIAlertController"]) {
                NSLog(@"[WizardBypass] âœ“âœ“âœ“ BLOCKED UIWindow makeKeyAndVisible âœ“âœ“âœ“");
                return;
            }

            // Call original
            typedef void (*OrigFunc)(UIWindow*, SEL);
            ((OrigFunc)original_imp)(self, selector1);
        });

        method_setImplementation(method1, new_imp);
        NSLog(@"[WizardBypass] UIWindow makeKeyAndVisible hook installed");
    }

    // v31: addSubview NOT hooked â€” let SCLAlertView subviews appear normally
    NSLog(@"[WizardBypass] v31: UIWindow addSubview NOT hooked (let Wizard UI show)");
}

// ============================================================================
// PHASE 4E: IDLE/TIMEOUT KILL â€” Prevent Wizard from crashing on idle
// ============================================================================

static void hook_idle_timeout_kill(void) {
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] HOOKING IDLE/TIMEOUT KILL MECHANISMS");
    NSLog(@"[WizardBypass] ========================================");

    // 1. Hook NSTimer scheduledTimerWithTimeInterval:target:selector:userInfo:repeats:
    //    Block timers targeting Wizard framework classes
    Class timerClass = objc_getClass("NSTimer");
    if (timerClass) {
        SEL timerSel = @selector(scheduledTimerWithTimeInterval:target:selector:userInfo:repeats:);
        Method timerMethod = class_getClassMethod(timerClass, timerSel);
        if (timerMethod) {
            IMP origTimer = method_getImplementation(timerMethod);
            IMP newTimer = imp_implementationWithBlock(^NSTimer*(Class self, NSTimeInterval interval, id target, SEL selector, id userInfo, BOOL repeats) {
                const char* targetClass = object_getClassName(target);
                const char* selName = sel_getName(selector);
                const char* targetImage = class_getImageName([target class]);
                BOOL isWizard = (targetImage && strstr(targetImage, "Wizard.framework"));

                if (isWizard) {
                    NSLog(@"[WizardBypass] Wizard NSTimer: %.1fs target=%s sel=%s repeats=%d",
                          interval, targetClass, selName, repeats);
                    // Only block timers â‰¥5s (likely idle/timeout kills)
                    // Short timers (0-4s) are legit â€” e.g. PADSGFNDSAHJ icon setup
                    if (interval >= 5.0) {
                        NSLog(@"[WizardBypass] *** BLOCKED (>=5s idle kill) ***");
                        NSTimer *dummy = [NSTimer timerWithTimeInterval:999999 target:[NSNull null] selector:@selector(description) userInfo:nil repeats:NO];
                        return dummy;
                    }
                    NSLog(@"[WizardBypass] ALLOWED (short interval, likely legit)");
                }

                // Log other interesting timers
                if (interval >= 10.0) {
                    NSLog(@"[WizardBypass] NSTimer: %.1fs target=%s sel=%s (allowed)", interval, targetClass, selName);
                }

                typedef NSTimer* (*OrigFunc)(Class, SEL, NSTimeInterval, id, SEL, id, BOOL);
                return ((OrigFunc)origTimer)(self, timerSel, interval, target, selector, userInfo, repeats);
            });
            method_setImplementation(timerMethod, newTimer);
            NSLog(@"[WizardBypass] NSTimer scheduledTimer hook installed");
        }

        // Also hook timerWithTimeInterval:target:selector:userInfo:repeats: (non-scheduled)
        SEL timerSel2 = @selector(timerWithTimeInterval:target:selector:userInfo:repeats:);
        Method timerMethod2 = class_getClassMethod(timerClass, timerSel2);
        if (timerMethod2) {
            IMP origTimer2 = method_getImplementation(timerMethod2);
            IMP newTimer2 = imp_implementationWithBlock(^NSTimer*(Class self, NSTimeInterval interval, id target, SEL selector, id userInfo, BOOL repeats) {
                const char* targetImage = class_getImageName([target class]);
                BOOL isWizard = (targetImage && strstr(targetImage, "Wizard.framework"));

                if (isWizard) {
                    NSLog(@"[WizardBypass] Wizard timerWith: %.1fs sel=%s",
                          interval, sel_getName(selector));
                    if (interval >= 5.0) {
                        NSLog(@"[WizardBypass] *** BLOCKED (>=5s idle kill) ***");
                        NSTimer *dummy = [NSTimer timerWithTimeInterval:999999 target:[NSNull null] selector:@selector(description) userInfo:nil repeats:NO];
                        return dummy;
                    }
                    NSLog(@"[WizardBypass] ALLOWED (short interval)");
                }

                typedef NSTimer* (*OrigFunc)(Class, SEL, NSTimeInterval, id, SEL, id, BOOL);
                return ((OrigFunc)origTimer2)(self, timerSel2, interval, target, selector, userInfo, repeats);
            });
            method_setImplementation(timerMethod2, newTimer2);
            NSLog(@"[WizardBypass] NSTimer timerWithInterval hook installed");
        }
    }

    // 2. Hook performSelector:withObject:afterDelay: on NSObject
    //    Wizard may use delayed selectors as timeouts
    Class nsobjectClass = objc_getClass("NSObject");
    if (nsobjectClass) {
        SEL perfSel = @selector(performSelector:withObject:afterDelay:);
        Method perfMethod = class_getInstanceMethod(nsobjectClass, perfSel);
        if (perfMethod) {
            IMP origPerf = method_getImplementation(perfMethod);
            IMP newPerf = imp_implementationWithBlock(^(id self, SEL aSelector, id anObject, NSTimeInterval delay) {
                const char* targetImage = class_getImageName([self class]);
                BOOL isWizard = (targetImage && strstr(targetImage, "Wizard.framework"));

                if (isWizard) {
                    NSLog(@"[WizardBypass] Wizard performSelector:%s afterDelay:%.1fs",
                          sel_getName(aSelector), delay);
                    if (delay >= 3.0) {
                        NSLog(@"[WizardBypass] *** BLOCKED (>=3s, likely timeout kill) ***");
                        return;
                    }
                }

                typedef void (*OrigFunc)(id, SEL, SEL, id, NSTimeInterval);
                ((OrigFunc)origPerf)(self, perfSel, aSelector, anObject, delay);
            });
            method_setImplementation(perfMethod, newPerf);
            NSLog(@"[WizardBypass] performSelector:afterDelay: hook installed");
        }
    }

    // 3. Hook NSObject cancelPreviousPerformRequests â€” prevent Wizard from canceling and rescheduling
    //    (This is informational, logging only)
    NSLog(@"[WizardBypass] exit() located (timer blocks should prevent idle kills)");

    // v31: SCLAlertView dismiss hooks REMOVED â€” let the dialog dismiss naturally
    // after user enters a key. The crypto hooks will make validation pass.
    NSLog(@"[WizardBypass] Idle/timeout kill hooks complete");
}

// ============================================================================
// PHASE 4F: CRYPTO AUTH BYPASS (v31)
// Hook CommonCrypto + Security framework to make Wizard's local key validation
// always succeed, regardless of what key the user enters.
// ============================================================================

// Helper: is the caller from Wizard.framework?
static BOOL caller_is_wizard(void) {
    // Walk the call stack â€” check if any frame is in Wizard.framework
    void *frames[16];
    int count = backtrace(frames, 16);
    for (int i = 0; i < count; i++) {
        Dl_info info;
        if (dladdr(frames[i], &info) && info.dli_fname) {
            if (strstr(info.dli_fname, "Wizard.framework") ||
                strstr(info.dli_fname, "Wizard.dylib")) {
                return YES;
            }
        }
    }
    return NO;
}

// ---- FISHHOOK: Original function pointers ----
static CCCryptorStatus (*orig_CCCrypt)(CCOperation op, CCAlgorithm alg, CCOptions options,
    const void *key, size_t keyLength, const void *iv,
    const void *dataIn, size_t dataInLength,
    void *dataOut, size_t dataOutAvailable, size_t *dataOutMoved);
static int (*orig_memcmp)(const void *s1, const void *s2, size_t n);
static unsigned char *(*orig_CC_SHA256)(const void *data, uint32_t len, unsigned char *md);
static unsigned char *(*orig_CC_MD5)(const void *data, uint32_t len, unsigned char *md);
static _Atomic int g_in_hash_hook = 0; // re-entrancy guard

// ---- FISHHOOK: Replacement CCCrypt ----
// v35: LOG ONLY, do NOT force success (was corrupting 6MB game assets!)
static CCCryptorStatus replaced_CCCrypt(CCOperation op, CCAlgorithm alg, CCOptions options,
    const void *key, size_t keyLength, const void *iv,
    const void *dataIn, size_t dataInLength,
    void *dataOut, size_t dataOutAvailable, size_t *dataOutMoved) {
    CCCryptorStatus result = orig_CCCrypt(op, alg, options, key, keyLength, iv,
                                          dataIn, dataInLength, dataOut, dataOutAvailable, dataOutMoved);
    NSLog(@"[WizardBypass] CCCrypt: op=%d alg=%d keyLen=%zu dataLen=%zu -> status=%d",
          op, alg, keyLength, dataInLength, result);
    return result; // v35: pass through original result
}

// ---- FISHHOOK: Replacement memcmp ----
static int replaced_memcmp(const void *s1, const void *s2, size_t n) {
    if (n >= 16 && n <= 64 && caller_is_wizard()) {
        int real_result = orig_memcmp(s1, s2, n);
        if (real_result != 0) {
            NSLog(@"[WizardBypass] *** Wizard memcmp(%zu bytes) MISMATCH -> FORCING EQUAL ***", n);
            return 0;
        }
    }
    return orig_memcmp(s1, s2, n);
}

// ---- FISHHOOK: Replacement strcmp ----
// NOTE: strcmp hook REMOVED — causes infinite recursion (backtrace() calls strcmp internally)

// ---- FISHHOOK: Replacement CC_SHA256 ----
static unsigned char *replaced_CC_SHA256(const void *data, uint32_t len, unsigned char *md) {
    unsigned char *result = orig_CC_SHA256(data, len, md);
    if (!g_in_hash_hook) {
        g_in_hash_hook = 1;
        NSLog(@"[WizardBypass] CC_SHA256 called: dataLen=%u", len);
        g_in_hash_hook = 0;
    }
    return result;
}

// ---- FISHHOOK: Replacement CC_MD5 ----
static unsigned char *replaced_CC_MD5(const void *data, uint32_t len, unsigned char *md) {
    unsigned char *result = orig_CC_MD5(data, len, md);
    if (!g_in_hash_hook) {
        g_in_hash_hook = 1;
        NSLog(@"[WizardBypass] CC_MD5 called: dataLen=%u", len);
        g_in_hash_hook = 0;
    }
    return result;
}

static void hook_crypto_auth(void) {
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] PHASE 4F: CRYPTO HOOKS (v35 DIAGNOSTIC)");
    NSLog(@"[WizardBypass] ========================================");

    struct rebinding rebindings[] = {
        {"CCCrypt", (void *)replaced_CCCrypt, (void **)&orig_CCCrypt},
        {"memcmp", (void *)replaced_memcmp, (void **)&orig_memcmp},
        {"CC_SHA256", (void *)replaced_CC_SHA256, (void **)&orig_CC_SHA256},
        {"CC_MD5", (void *)replaced_CC_MD5, (void **)&orig_CC_MD5},
    };
    int result = rebind_symbols(rebindings, 4);
    NSLog(@"[WizardBypass] fishhook rebind_symbols result: %d (0=success)", result);
    if (result == 0) {
        NSLog(@"[WizardBypass] Hooked: CCCrypt(log) memcmp CC_SHA256 CC_MD5");
    } else {
        NSLog(@"[WizardBypass] WARNING: fishhook rebind failed!");
    }

    // ---- 4. Key insight: Wizard stores auth result locally. ----
    // The BOOL-returning methods we already hook (returning YES for all Wizard BOOLs)
    // covers the auth state check. But the KEY ENTRY validation happens via:
    //   a) Some hash/HMAC of the entered key
    //   b) Compare against a stored hash
    // Hook NSString comparison methods that Wizard might use:
    Class nsStringClass = objc_getClass("NSString");
    if (nsStringClass) {
        SEL isEqSel = @selector(isEqualToString:);
        Method isEqMethod = class_getInstanceMethod(nsStringClass, isEqSel);
        if (isEqMethod) {
            IMP origIsEq = method_getImplementation(isEqMethod);
            IMP newIsEq = imp_implementationWithBlock(^BOOL(NSString* self, NSString* other) {
                typedef BOOL (*OrigFunc)(NSString*, SEL, NSString*);
                BOOL result = ((OrigFunc)origIsEq)(self, isEqSel, other);

                // v32: INTERCEPT validation result
                // When Wizard checks if result == "Key is invalid" and it IS true,
                // force NO so Wizard thinks validation passed
                if (result) {
                    if (([other length] > 5 && [other containsString:@"invalid"]) ||
                        ([self length] > 5 && [self containsString:@"invalid"])) {
                        NSLog(@"[WizardBypass] *** INTERCEPTED 'invalid' check: '%@' == '%@' -> FORCING NO ***", self, other);
                        return NO;
                    }
                }

                // Log string comparisons from Wizard (only short strings)
                if (caller_is_wizard() && [self length] < 100 && [other length] < 100) {
                    NSLog(@"[WizardBypass] Wizard isEqualToString: '%@' == '%@' -> %d",
                          self, other, result);
                }
                return result;
            });
            method_setImplementation(isEqMethod, newIsEq);
            NSLog(@"[WizardBypass] NSString isEqualToString: hooked (v32 intercepts 'invalid')");
        }
    }

    // ---- 5. Hook NSData isEqualToData: ----
    // Wizard likely compares hash(enteredKey) == storedHash as NSData
    Class nsDataClass = objc_getClass("NSData");
    if (nsDataClass) {
        SEL isEqDataSel = @selector(isEqualToData:);
        Method isEqDataMethod = class_getInstanceMethod(nsDataClass, isEqDataSel);
        if (isEqDataMethod) {
            IMP origIsEqData = method_getImplementation(isEqDataMethod);
            IMP newIsEqData = imp_implementationWithBlock(^BOOL(NSData* self, NSData* other) {
                typedef BOOL (*OrigFunc)(NSData*, SEL, NSData*);
                BOOL result = ((OrigFunc)origIsEqData)(self, isEqDataSel, other);

                // v32: Force YES for crypto-sized data (no backtrace check)
                NSUInteger len1 = [self length];
                NSUInteger len2 = [other length];
                if (len1 == len2 && len1 >= 16 && len1 <= 64 && !result) {
                    NSLog(@"[WizardBypass] *** NSData isEqualToData: len=%lu FORCING YES ***",
                          (unsigned long)len1);
                    return YES;
                }
                return result;
            });
            method_setImplementation(isEqDataMethod, newIsEqData);
            NSLog(@"[WizardBypass] NSData isEqualToData: hooked (v32 size-filter force YES)");
        }
    }

    // NOTE: NSObject isEqual: hook REMOVED â€” too noisy (thousands of UIGestureRecognizer comparisons)
    // NSData isEqualToData: and NSString isEqualToString: are the targeted hooks above

    NSLog(@"[WizardBypass] Crypto auth bypass hooks complete");
}

// ============================================================================
// DELAYED HOOK - Re-hook after Wizard loads (NO MEMORY PATCHING)
// ============================================================================

static void delayed_hook(void) {
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] DELAYED HOOK - v35 diagnostic");
    NSLog(@"[WizardBypass] ========================================");

    // Force Wizard BOOL auth flags to YES
    force_authentication();

    // Re-hook NSUserDefaults
    hook_user_defaults();

    // Install crypto hooks (NSData isEqualToData: forced YES for Wizard)
    hook_crypto_auth();

    // Kill idle/timeout mechanisms
    hook_idle_timeout_kill();

    // v35c: Hook Wizard methods with VOID blocks (safe for any return type)
    // Use method_getTypeEncoding to log return type for debugging
    Class wksClass = objc_getClass("Wksahfnasj");
    if (wksClass) {
        NSString *methodNames[] = {@"paDJSAFBSANC", @"jsafbSAHCN", @"dgshdsfyewrh"};
        for (int i = 0; i < 3; i++) {
            SEL sel = sel_registerName([methodNames[i] UTF8String]);
            Method m = class_getInstanceMethod(wksClass, sel);
            if (m) {
                const char *types = method_getTypeEncoding(m);
                NSLog(@"[WizardBypass] Wksahfnasj::%@ type='%s'", methodNames[i], types ? types : "?");
                __block IMP origImp = method_getImplementation(m);
                __block SEL origSel = sel;
                __block NSString *name = methodNames[i];
                IMP newImp = imp_implementationWithBlock(^void(id self) {
                    NSLog(@"[WizardBypass] *** Wksahfnasj::%@ CALLED ***", name);
                    typedef void (*VoidFunc)(id, SEL);
                    ((VoidFunc)origImp)(self, origSel);
                });
                method_setImplementation(m, newImp);
            }
        }
    }

    Class abvClass = objc_getClass("ABVJSMGADJS");
    if (abvClass) {
        NSString *methodNames[] = {@"PADSGFNDSAHJ", @"IKAFHFDSAJ", @"ASFGAHJFAHS", @"MdhsaJFSAJ"};
        for (int i = 0; i < 4; i++) {
            SEL sel = sel_registerName([methodNames[i] UTF8String]);
            Method m = class_getInstanceMethod(abvClass, sel);
            if (m) {
                const char *types = method_getTypeEncoding(m);
                NSLog(@"[WizardBypass] ABVJSMGADJS::%@ type='%s'", methodNames[i], types ? types : "?");
                __block IMP origImp = method_getImplementation(m);
                __block SEL origSel = sel;
                __block NSString *name = methodNames[i];
                IMP newImp = imp_implementationWithBlock(^void(id self) {
                    NSLog(@"[WizardBypass] *** ABVJSMGADJS::%@ CALLED ***", name);
                    typedef void (*VoidFunc)(id, SEL);
                    ((VoidFunc)origImp)(self, origSel);
                });
                method_setImplementation(m, newImp);
            }
        }
    }

    NSLog(@"[WizardBypass] Delayed hook complete (v35c - void-safe method hooks)");
}

// ============================================================================
// CONSTRUCTOR - Run everything EARLY (v31)
// ============================================================================

__attribute__((constructor(101)))
static void wizard_bypass_init(void) {
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] v35 DIAGNOSTIC - EARLY INIT");
    NSLog(@"[WizardBypass] ========================================");

    // Phase 1: Force all Wizard BOOL auth flags to YES
    NSLog(@"[WizardBypass] Phase 1: Forcing authentication...");
    force_authentication();

    // Phase 1b: Hook NSUserDefaults
    NSLog(@"[WizardBypass] Phase 1b: Hooking NSUserDefaults...");
    hook_user_defaults();

    // Phase 1c: Crypto hooks (NSData comparison bypass)
    NSLog(@"[WizardBypass] Phase 1c: Installing crypto bypass hooks...");
    hook_crypto_auth();

    // Phase 2: Hook UIViewController presentation (passthrough logging)
    NSLog(@"[WizardBypass] Phase 2: Hooking UIViewController presentation...");
    hook_view_controller_presentation();

    // Phase 3: Hook UIWindow makeKeyAndVisible (passthrough)
    NSLog(@"[WizardBypass] Phase 3: Hooking UIWindow...");
    hook_ui_window();

    // Phase 4: Schedule delayed re-hook after 2 seconds
    NSLog(@"[WizardBypass] Phase 4: Scheduling delayed hook in 2 seconds...");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        delayed_hook();
    });

    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] v31 init complete â€” Wizard UI will show normally");
    NSLog(@"[WizardBypass] ========================================");
}
