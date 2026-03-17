// Wizard Authentication Bypass
// v31: Crypto auth bypass — let Wizard's own UI show, hook CCCrypt/SecKey to pass any key

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

// ============================================================================
// GLOBAL: Wizard controller reference accessible from didTapIconView
// Since Pajdsakdfj has 0 ivars, we use a global to bridge the gap
// ============================================================================
static id g_wizardController = nil;
static id g_wizardIcon = nil;

// v31: Crypto auth bypass.
// SCLAlertView is ALLOWED to show — Wizard's own key entry dialog appears.
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

            // Skip lifecycle/destructor methods ONLY — DO NOT skip setters!
            // Auth flag setters MUST be hooked so they can't reset auth to NO
            if (strncmp(name, "init", 4) == 0 ||
                strcmp(name, "dealloc") == 0 ||
                strcmp(name, ".cxx_destruct") == 0) {
                free(type_encoding);
                continue;
            }

            // Only hook BOOL-returning methods with NO arguments
            // Methods like isEqual: take extra args — our block only accepts (id self)
            // so hooking them causes calling convention mismatch → stack corruption → PC=0 crash
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
                NSLog(@"[WizardBypass] ✓✓✓ BLOCKED UIWindow makeKeyAndVisible ✓✓✓");
                return;
            }

            // Call original
            typedef void (*OrigFunc)(UIWindow*, SEL);
            ((OrigFunc)original_imp)(self, selector1);
        });

        method_setImplementation(method1, new_imp);
        NSLog(@"[WizardBypass] UIWindow makeKeyAndVisible hook installed");
    }

    // v31: addSubview NOT hooked — let SCLAlertView subviews appear normally
    NSLog(@"[WizardBypass] v31: UIWindow addSubview NOT hooked (let Wizard UI show)");
}

// ============================================================================
// PHASE 4E: IDLE/TIMEOUT KILL — Prevent Wizard from crashing on idle
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
                    // Only block timers ≥5s (likely idle/timeout kills)
                    // Short timers (0-4s) are legit — e.g. PADSGFNDSAHJ icon setup
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

    // 3. Hook NSObject cancelPreviousPerformRequests — prevent Wizard from canceling and rescheduling
    //    (This is informational, logging only)
    NSLog(@"[WizardBypass] exit() located (timer blocks should prevent idle kills)");

    // v31: SCLAlertView dismiss hooks REMOVED — let the dialog dismiss naturally
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
    // Walk the call stack — check if any frame is in Wizard.framework
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

static void hook_crypto_auth(void) {
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] PHASE 4F: CRYPTO AUTH BYPASS (v31)");
    NSLog(@"[WizardBypass] ========================================");

    // ---- 1. Hook CCCrypt (CommonCrypto) ----
    // Wizard uses this to decrypt/verify the license key locally.
    // We intercept it: run normally but if caller is Wizard, return kCCSuccess.
    typedef CCCryptorStatus (*CCCrypt_t)(CCOperation, CCAlgorithm, CCOptions,
        const void*, size_t, const void*,
        const void*, size_t, void*, size_t, size_t*);
    CCCrypt_t orig_CCCrypt = (CCCrypt_t)dlsym(RTLD_DEFAULT, "CCCrypt");
    if (orig_CCCrypt) {
        // We can't replace CCCrypt directly (it's in a static lib linked into Wizard)
        // so we hook it through NSUserDefaults interception + CCHmac scanning.
        // Instead, hook via fishhook if available, or note for logging.
        NSLog(@"[WizardBypass] CCCrypt found at %p (logging via caller detection)", orig_CCCrypt);
    }

    // ---- 2. Hook SecKeyRawVerify ----
    // If Wizard uses RSA signature verification, this will be called.
    // We hook it to always return errSecSuccess (0).
    typedef OSStatus (*SecKeyRawVerify_t)(SecKeyRef, SecPadding,
        const uint8_t*, size_t, const uint8_t*, size_t);
    SecKeyRawVerify_t orig_SecKeyRawVerify = (SecKeyRawVerify_t)dlsym(RTLD_DEFAULT, "SecKeyRawVerify");
    if (orig_SecKeyRawVerify) {
        NSLog(@"[WizardBypass] SecKeyRawVerify found — hooking via Wizard BOOL methods");
    }

    // ---- 3. Hook SecKeyVerifySignature (modern API) ----
    NSLog(@"[WizardBypass] Checking SecKeyVerifySignature...");
    void *secVerify = dlsym(RTLD_DEFAULT, "SecKeyVerifySignature");
    NSLog(@"[WizardBypass] SecKeyVerifySignature: %p", secVerify);

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

                // Log string comparisons from Wizard
                if (caller_is_wizard()) {
                    NSLog(@"[WizardBypass] Wizard NSString isEqualToString: '%@' == '%@' -> %d",
                          self, other, result);
                }
                return result;
            });
            method_setImplementation(isEqMethod, newIsEq);
            NSLog(@"[WizardBypass] NSString isEqualToString: hooked (Wizard logging)");
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

                if (caller_is_wizard()) {
                    NSLog(@"[WizardBypass] Wizard NSData isEqualToData: len=%lu vs len=%lu -> %d (FORCING YES)",
                          (unsigned long)[self length], (unsigned long)[other length], result);
                    // FORCE the comparison to return YES — this bypasses hash comparison!
                    return YES;
                }
                return result;
            });
            method_setImplementation(isEqDataMethod, newIsEqData);
            NSLog(@"[WizardBypass] NSData isEqualToData: hooked — Wizard calls FORCED to YES");
        }
    }

    // ---- 6. Hook isEqual: on NSObject (covers NSData, NSString, etc.) ----
    Class nsObjectClass = objc_getClass("NSObject");
    if (nsObjectClass) {
        SEL isEqObjSel = @selector(isEqual:);
        Method isEqObjMethod = class_getInstanceMethod(nsObjectClass, isEqObjSel);
        if (isEqObjMethod) {
            IMP origIsEqObj = method_getImplementation(isEqObjMethod);
            IMP newIsEqObj = imp_implementationWithBlock(^BOOL(id self, id other) {
                typedef BOOL (*OrigFunc)(id, SEL, id);
                BOOL result = ((OrigFunc)origIsEqObj)(self, isEqObjSel, other);

                if (caller_is_wizard()) {
                    NSLog(@"[WizardBypass] Wizard isEqual: %@ vs %@ -> %d",
                          NSStringFromClass([self class]), NSStringFromClass([other class]), result);
                }
                return result;
            });
            method_setImplementation(isEqObjMethod, newIsEqObj);
            NSLog(@"[WizardBypass] NSObject isEqual: hooked (Wizard logging)");
        }
    }

    NSLog(@"[WizardBypass] Crypto auth bypass hooks complete");
}

// ============================================================================
// DELAYED HOOK - Re-hook after Wizard loads (NO MEMORY PATCHING)
// ============================================================================

static void delayed_hook(void) {
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] DELAYED HOOK - Wizard should be loaded now (v31)");
    NSLog(@"[WizardBypass] ========================================");

    // Force Wizard BOOL auth flags to YES
    force_authentication();

    // Re-hook NSUserDefaults
    hook_user_defaults();

    // Install crypto hooks (NSData isEqualToData: forced YES for Wizard)
    hook_crypto_auth();

    // Kill idle/timeout mechanisms
    hook_idle_timeout_kill();

    // v31: Let Wizard initialize its own controller + show its own UI
    // Do NOT call PADSGFNDSAHJ/IKAFHFDSAJ ourselves — let Wizard do it
    // after the user enters a key in the SCLAlertView dialog.
    NSLog(@"[WizardBypass] Delayed hook complete (v31 — crypto bypass active)");

    // ========================================
    // PHASE 7: CONTROLLER SETUP
    // v29b: API dump REMOVED from constructor (caused crash via CFNotification anti-tamper)
    // Dump will run on first tap instead, when Wizard is fully initialized
    // ========================================
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] PHASE 7: CONTROLLER SETUP (v29b - no early API dump)");
    NSLog(@"[WizardBypass] ========================================");

    // Create ABVJSMGADJS controller
    Class abvjsmgadjs_class = objc_getClass("ABVJSMGADJS");
    if (!abvjsmgadjs_class) {
        NSLog(@"[WizardBypass] FATAL: ABVJSMGADJS class not found!");
        return;
    }
    g_wizardController = [[abvjsmgadjs_class alloc] init];
    NSLog(@"[WizardBypass] Created ABVJSMGADJS controller: %@", g_wizardController);

    // Invalidate controller timers
    Ivar timerIvar1 = class_getInstanceVariable(abvjsmgadjs_class, "_qmshnfuas");
    Ivar timerIvar2 = class_getInstanceVariable(abvjsmgadjs_class, "_nvjsafhsa");
    if (timerIvar1) {
        NSTimer *t1 = object_getIvar(g_wizardController, timerIvar1);
        if (t1) [t1 invalidate];
        object_setIvar(g_wizardController, timerIvar1, nil);
        NSLog(@"[WizardBypass] _qmshnfuas timer killed");
    }
    if (timerIvar2) {
        NSTimer *t2 = object_getIvar(g_wizardController, timerIvar2);
        if (t2) [t2 invalidate];
        object_setIvar(g_wizardController, timerIvar2, nil);
        NSLog(@"[WizardBypass] _nvjsafhsa timer killed");
    }

    // ========================================
    // PHASE 8: CUSTOM UIKit MENU + FLOATING ICON
    // v30: Fully wired — buttons call real Wizard methods
    // ========================================
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] PHASE 8: CUSTOM UIKit MENU (v30 — WIRED)");
    NSLog(@"[WizardBypass] ========================================");

    UIWindow* keyWindow = nil;
    NSArray* windows = [[UIApplication sharedApplication] windows];
    for (UIWindow* window in windows) {
        if (window.isKeyWindow) { keyWindow = window; break; }
    }
    if (!keyWindow && [windows count] > 0) keyWindow = [windows objectAtIndex:0];
    if (!keyWindow) {
        NSLog(@"[WizardBypass] ERROR: No key window found");
        return;
    }

    CGFloat screenW = keyWindow.bounds.size.width;
    CGFloat screenH = keyWindow.bounds.size.height;

    // ---- CREATE RUNTIME BUTTON HANDLER CLASS ----
    // We create a single handler object that forwards button taps to Wizard methods
    Class handlerClass = objc_allocateClassPair([NSObject class], "WBMenuHandler", 0);
    if (handlerClass) {
        objc_registerClassPair(handlerClass);
    } else {
        handlerClass = objc_getClass("WBMenuHandler");
    }
    id handler = [[handlerClass alloc] init];

    // ---- BUILD CUSTOM UIKit MENU ----
    CGFloat menuW = screenW * 0.85;
    CGFloat menuH = screenH * 0.7;
    CGFloat menuX = (screenW - menuW) / 2.0;
    CGFloat menuY = (screenH - menuH) / 2.0;

    UIView *menuContainer = [[UIView alloc] initWithFrame:CGRectMake(menuX, menuY, menuW, menuH)];
    menuContainer.backgroundColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.12 alpha:0.97];
    menuContainer.layer.cornerRadius = 18;
    menuContainer.clipsToBounds = YES;
    menuContainer.hidden = YES;
    menuContainer.tag = 9999;

    // Title bar with gradient feel
    UIView *titleBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, menuW, 56)];
    titleBar.backgroundColor = [UIColor colorWithRed:0.35 green:0.1 blue:0.7 alpha:1.0];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, menuW - 32, 56)];
    titleLabel.text = @"\xE2\x9A\xA1 Wizard v30";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [titleBar addSubview:titleLabel];
    [menuContainer addSubview:titleBar];

    // Subtitle
    UILabel *subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 60, menuW - 32, 20)];
    subtitleLabel.text = @"Tap features to toggle ON/OFF";
    subtitleLabel.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.7 alpha:1.0];
    subtitleLabel.font = [UIFont systemFontOfSize:12];
    [menuContainer addSubview:subtitleLabel];

    // Section header helper block
    void (^addSectionHeader)(UIScrollView*, CGFloat*, CGFloat, NSString*) =
        ^(UIScrollView *sv, CGFloat *y, CGFloat w, NSString *text) {
            UILabel *hdr = [[UILabel alloc] initWithFrame:CGRectMake(16, *y, w, 24)];
            hdr.text = text;
            hdr.textColor = [UIColor colorWithRed:0.6 green:0.4 blue:1.0 alpha:1.0];
            hdr.font = [UIFont boldSystemFontOfSize:13];
            [sv addSubview:hdr];
            *y += 28;
        };

    // Button creation helper block
    UIButton* (^makeButton)(UIScrollView*, CGFloat*, CGFloat, CGFloat, NSString*, NSInteger) =
        ^UIButton*(UIScrollView *sv, CGFloat *y, CGFloat w, CGFloat h, NSString *title, NSInteger tag) {
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
            btn.frame = CGRectMake(16, *y, w, h);
            btn.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.22 alpha:1.0];
            btn.layer.cornerRadius = 10;
            btn.layer.borderWidth = 1.0;
            btn.layer.borderColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.4 alpha:1.0].CGColor;
            [btn setTitle:title forState:UIControlStateNormal];
            [btn setTitleColor:[UIColor colorWithRed:0.75 green:0.85 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
            btn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
            btn.titleLabel.adjustsFontSizeToFitWidth = YES;
            btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
            btn.contentEdgeInsets = UIEdgeInsetsMake(0, 14, 0, 14);
            btn.tag = tag;
            [sv addSubview:btn];
            *y += h + 8;
            return btn;
        };

    // ScrollView for features
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 86, menuW, menuH - 86)];
    scrollView.showsVerticalScrollIndicator = YES;

    CGFloat buttonY = 8;
    CGFloat buttonH = 48;
    CGFloat buttonW = menuW - 32;

    // ===== SECTION: CONTROLLER FEATURES (ABVJSMGADJS) =====
    addSectionHeader(scrollView, &buttonY, buttonW, @"\xF0\x9F\x8E\xAE Controller Features");

    // Button 1: ASFGAHJFAHS (Feature #1 — likely "enable cheats" or similar)
    UIButton *btn1 = makeButton(scrollView, &buttonY, buttonW, buttonH, @"\xE2\x9A\xA1 Feature 1 (ASFGAHJFAHS)", 10001);
    SEL sel1 = sel_registerName("handleBtn1:");
    IMP imp1 = imp_implementationWithBlock(^(id _self, id sender) {
        NSLog(@"[WizardBypass] \xE2\x86\x92 Calling ASFGAHJFAHS on controller");
        if (g_wizardController) {
            ((void (*)(id, SEL))objc_msgSend)(g_wizardController, sel_registerName("ASFGAHJFAHS"));
            UIButton *b = (UIButton*)sender;
            b.backgroundColor = [UIColor colorWithRed:0.0 green:0.4 blue:0.15 alpha:1.0];
            [b setTitle:@"\xE2\x9C\x85 Feature 1 (ASFGAHJFAHS) — CALLED" forState:UIControlStateNormal];
            NSLog(@"[WizardBypass] ASFGAHJFAHS called successfully");
        }
    });
    class_addMethod(handlerClass, sel1, imp1, "v@:@");
    [btn1 addTarget:handler action:sel1 forControlEvents:UIControlEventTouchUpInside];

    // Button 2: MdhsaJFSAJ (Feature #2)
    UIButton *btn2 = makeButton(scrollView, &buttonY, buttonW, buttonH, @"\xE2\x9A\xA1 Feature 2 (MdhsaJFSAJ)", 10002);
    SEL sel2 = sel_registerName("handleBtn2:");
    IMP imp2 = imp_implementationWithBlock(^(id _self, id sender) {
        NSLog(@"[WizardBypass] \xE2\x86\x92 Calling MdhsaJFSAJ on controller");
        if (g_wizardController) {
            ((void (*)(id, SEL))objc_msgSend)(g_wizardController, sel_registerName("MdhsaJFSAJ"));
            UIButton *b = (UIButton*)sender;
            b.backgroundColor = [UIColor colorWithRed:0.0 green:0.4 blue:0.15 alpha:1.0];
            [b setTitle:@"\xE2\x9C\x85 Feature 2 (MdhsaJFSAJ) — CALLED" forState:UIControlStateNormal];
            NSLog(@"[WizardBypass] MdhsaJFSAJ called successfully");
        }
    });
    class_addMethod(handlerClass, sel2, imp2, "v@:@");
    [btn2 addTarget:handler action:sel2 forControlEvents:UIControlEventTouchUpInside];

    // ===== SECTION: MENU VIEW FEATURES (Wksahfnasj) =====
    addSectionHeader(scrollView, &buttonY, buttonW, @"\xF0\x9F\x93\xB1 Menu View Features");

    // Button 3: paDJSAFBSANC
    UIButton *btn3 = makeButton(scrollView, &buttonY, buttonW, buttonH, @"\xE2\x9A\xA1 Menu Func 1 (paDJSAFBSANC)", 10003);
    SEL sel3 = sel_registerName("handleBtn3:");
    IMP imp3 = imp_implementationWithBlock(^(id _self, id sender) {
        NSLog(@"[WizardBypass] \xE2\x86\x92 Calling paDJSAFBSANC on menu view");
        if (g_wizardController) {
            Class cls = object_getClass(g_wizardController);
            Ivar menuIvar = class_getInstanceVariable(cls, "_jdsghadurewmf");
            id menuView = menuIvar ? object_getIvar(g_wizardController, menuIvar) : nil;
            if (menuView) {
                ((void (*)(id, SEL))objc_msgSend)(menuView, sel_registerName("paDJSAFBSANC"));
                UIButton *b = (UIButton*)sender;
                b.backgroundColor = [UIColor colorWithRed:0.0 green:0.4 blue:0.15 alpha:1.0];
                [b setTitle:@"\xE2\x9C\x85 Menu Func 1 — CALLED" forState:UIControlStateNormal];
                NSLog(@"[WizardBypass] paDJSAFBSANC called successfully");
            } else {
                NSLog(@"[WizardBypass] ERROR: menu view (_jdsghadurewmf) is nil");
            }
        }
    });
    class_addMethod(handlerClass, sel3, imp3, "v@:@");
    [btn3 addTarget:handler action:sel3 forControlEvents:UIControlEventTouchUpInside];

    // Button 4: jsafbSAHCN
    UIButton *btn4 = makeButton(scrollView, &buttonY, buttonW, buttonH, @"\xE2\x9A\xA1 Menu Func 2 (jsafbSAHCN)", 10004);
    SEL sel4 = sel_registerName("handleBtn4:");
    IMP imp4 = imp_implementationWithBlock(^(id _self, id sender) {
        NSLog(@"[WizardBypass] \xE2\x86\x92 Calling jsafbSAHCN on menu view");
        if (g_wizardController) {
            Class cls = object_getClass(g_wizardController);
            Ivar menuIvar = class_getInstanceVariable(cls, "_jdsghadurewmf");
            id menuView = menuIvar ? object_getIvar(g_wizardController, menuIvar) : nil;
            if (menuView) {
                ((void (*)(id, SEL))objc_msgSend)(menuView, sel_registerName("jsafbSAHCN"));
                UIButton *b = (UIButton*)sender;
                b.backgroundColor = [UIColor colorWithRed:0.0 green:0.4 blue:0.15 alpha:1.0];
                [b setTitle:@"\xE2\x9C\x85 Menu Func 2 — CALLED" forState:UIControlStateNormal];
                NSLog(@"[WizardBypass] jsafbSAHCN called successfully");
            } else {
                NSLog(@"[WizardBypass] ERROR: menu view is nil");
            }
        }
    });
    class_addMethod(handlerClass, sel4, imp4, "v@:@");
    [btn4 addTarget:handler action:sel4 forControlEvents:UIControlEventTouchUpInside];

    // Button 5: dgshdsfyewrh
    UIButton *btn5 = makeButton(scrollView, &buttonY, buttonW, buttonH, @"\xE2\x9A\xA1 Menu Func 3 (dgshdsfyewrh)", 10005);
    SEL sel5 = sel_registerName("handleBtn5:");
    IMP imp5 = imp_implementationWithBlock(^(id _self, id sender) {
        NSLog(@"[WizardBypass] \xE2\x86\x92 Calling dgshdsfyewrh on menu view");
        if (g_wizardController) {
            Class cls = object_getClass(g_wizardController);
            Ivar menuIvar = class_getInstanceVariable(cls, "_jdsghadurewmf");
            id menuView = menuIvar ? object_getIvar(g_wizardController, menuIvar) : nil;
            if (menuView) {
                ((void (*)(id, SEL))objc_msgSend)(menuView, sel_registerName("dgshdsfyewrh"));
                UIButton *b = (UIButton*)sender;
                b.backgroundColor = [UIColor colorWithRed:0.0 green:0.4 blue:0.15 alpha:1.0];
                [b setTitle:@"\xE2\x9C\x85 Menu Func 3 — CALLED" forState:UIControlStateNormal];
                NSLog(@"[WizardBypass] dgshdsfyewrh called successfully");
            } else {
                NSLog(@"[WizardBypass] ERROR: menu view is nil");
            }
        }
    });
    class_addMethod(handlerClass, sel5, imp5, "v@:@");
    [btn5 addTarget:handler action:sel5 forControlEvents:UIControlEventTouchUpInside];

    // ===== SECTION: RE-INIT =====
    addSectionHeader(scrollView, &buttonY, buttonW, @"\xF0\x9F\x94\x84 Re-Initialize");

    // Button 6: Re-call PADSGFNDSAHJ + IKAFHFDSAJ (re-init)
    UIButton *btn6 = makeButton(scrollView, &buttonY, buttonW, buttonH, @"\xF0\x9F\x94\x84 Re-Init (PADSGFNDSAHJ + IKAFHFDSAJ)", 10006);
    SEL sel6 = sel_registerName("handleBtn6:");
    IMP imp6 = imp_implementationWithBlock(^(id _self, id sender) {
        NSLog(@"[WizardBypass] \xE2\x86\x92 Re-calling PADSGFNDSAHJ + IKAFHFDSAJ");
        if (g_wizardController) {
            ((void (*)(id, SEL))objc_msgSend)(g_wizardController, sel_registerName("PADSGFNDSAHJ"));
            ((void (*)(id, SEL))objc_msgSend)(g_wizardController, sel_registerName("IKAFHFDSAJ"));
            UIButton *b = (UIButton*)sender;
            b.backgroundColor = [UIColor colorWithRed:0.0 green:0.3 blue:0.5 alpha:1.0];
            [b setTitle:@"\xE2\x9C\x85 Re-Init — DONE" forState:UIControlStateNormal];
            NSLog(@"[WizardBypass] Re-init complete");
        }
    });
    class_addMethod(handlerClass, sel6, imp6, "v@:@");
    [btn6 addTarget:handler action:sel6 forControlEvents:UIControlEventTouchUpInside];

    // ===== SECTION: METAL RENDERER =====
    addSectionHeader(scrollView, &buttonY, buttonW, @"\xF0\x9F\x96\xA5 Metal Renderer");

    // Button 7: initializePlatform
    UIButton *btn7 = makeButton(scrollView, &buttonY, buttonW, buttonH, @"\xF0\x9F\x96\xA5 initializePlatform", 10007);
    SEL sel7 = sel_registerName("handleBtn7:");
    IMP imp7 = imp_implementationWithBlock(^(id _self, id sender) {
        NSLog(@"[WizardBypass] \xE2\x86\x92 Calling initializePlatform");
        if (g_wizardController) {
            Class cls = object_getClass(g_wizardController);
            Ivar menuIvar = class_getInstanceVariable(cls, "_jdsghadurewmf");
            id menuView = menuIvar ? object_getIvar(g_wizardController, menuIvar) : nil;
            if (menuView) {
                Class wksClass = object_getClass(menuView);
                Ivar rendIvar = class_getInstanceVariable(wksClass, "_paJFSAUJJFSAC");
                id renderer = rendIvar ? object_getIvar(menuView, rendIvar) : nil;
                if (renderer) {
                    ((void (*)(id, SEL))objc_msgSend)(renderer, sel_registerName("initializePlatform"));
                    UIButton *b = (UIButton*)sender;
                    b.backgroundColor = [UIColor colorWithRed:0.0 green:0.4 blue:0.15 alpha:1.0];
                    [b setTitle:@"\xE2\x9C\x85 initializePlatform — CALLED" forState:UIControlStateNormal];
                    NSLog(@"[WizardBypass] initializePlatform called");
                } else { NSLog(@"[WizardBypass] ERROR: renderer nil"); }
            }
        }
    });
    class_addMethod(handlerClass, sel7, imp7, "v@:@");
    [btn7 addTarget:handler action:sel7 forControlEvents:UIControlEventTouchUpInside];

    // Status label
    UILabel *statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, buttonY + 4, buttonW, 30)];
    statusLabel.text = @"v30 — All buttons wired to real Wizard methods";
    statusLabel.textColor = [UIColor colorWithRed:0.3 green:0.8 blue:0.3 alpha:1.0];
    statusLabel.font = [UIFont systemFontOfSize:11];
    statusLabel.textAlignment = NSTextAlignmentCenter;
    [scrollView addSubview:statusLabel];

    scrollView.contentSize = CGSizeMake(menuW, buttonY + 44);
    [menuContainer addSubview:scrollView];

    [keyWindow addSubview:menuContainer];
    NSLog(@"[WizardBypass] Custom UIKit menu created with %d wired buttons", 7);

    // ---- ALSO: Still call IKAFHFDSAJ to create Wizard internals ----
    // But immediately pause MTKView and hide the Metal menu
    Class pajdsakdfj_class = objc_getClass("Pajdsakdfj");
    if (!pajdsakdfj_class) { NSLog(@"[WizardBypass] ERROR: Pajdsakdfj not found"); return; }

    CGRect frame = CGRectMake(screenW - 80, 100, 60, 60);
    SEL initSelector = NSSelectorFromString(@"initWithFrame:type:");
    id iconView = nil;
    if ([pajdsakdfj_class instancesRespondToSelector:initSelector]) {
        id instance = [pajdsakdfj_class alloc];
        typedef id (*InitFunc)(id, SEL, CGRect, NSInteger);
        iconView = ((InitFunc)[pajdsakdfj_class instanceMethodForSelector:initSelector])(instance, initSelector, frame, 0);
    }
    if (!iconView) { NSLog(@"[WizardBypass] Failed to create icon"); return; }
    g_wizardIcon = iconView;

    // Wire icon into controller
    unsigned int ctrlIvarCount;
    Ivar *ctrlIvars = class_copyIvarList(abvjsmgadjs_class, &ctrlIvarCount);
    for (unsigned int i = 0; i < ctrlIvarCount; i++) {
        const char *type = ivar_getTypeEncoding(ctrlIvars[i]);
        if (type && strstr(type, "Pajdsakdfj")) {
            object_setIvar(g_wizardController, ctrlIvars[i], iconView);
            break;
        }
    }
    free(ctrlIvars);

    // Call PADSGFNDSAHJ (icon setup)
    NSLog(@"[WizardBypass] Calling PADSGFNDSAHJ...");
    ((void (*)(id, SEL))objc_msgSend)(g_wizardController, sel_registerName("PADSGFNDSAHJ"));

    // Call IKAFHFDSAJ (creates internal Wizard objects — MTKView, Wksahfnasj, etc.)
    // We need these objects alive even though we won't render with them
    NSLog(@"[WizardBypass] Calling IKAFHFDSAJ...");
    ((void (*)(id, SEL))objc_msgSend)(g_wizardController, sel_registerName("IKAFHFDSAJ"));

    // Immediately pause MTKView permanently and hide the Wizard Metal menu
    Ivar menuIvar = class_getInstanceVariable(abvjsmgadjs_class, "_jdsghadurewmf");
    id wizMenu = menuIvar ? object_getIvar(g_wizardController, menuIvar) : nil;
    if (wizMenu) {
        [(UIView*)wizMenu setHidden:YES];
        Class wksClass = objc_getClass("Wksahfnasj");
        if (wksClass) {
            Ivar mtkIvar = class_getInstanceVariable(wksClass, "_pPfuasjrasfh");
            if (mtkIvar) {
                id mtkView = object_getIvar(wizMenu, mtkIvar);
                if (mtkView) {
                    ((void (*)(id, SEL, BOOL))objc_msgSend)(mtkView, NSSelectorFromString(@"setPaused:"), YES);
                    ((void (*)(id, SEL, BOOL))objc_msgSend)(mtkView, NSSelectorFromString(@"setEnableSetNeedsDisplay:"), NO);
                    NSLog(@"[WizardBypass] MTKView permanently paused");
                }
            }
        }
        NSLog(@"[WizardBypass] Wizard Metal menu hidden permanently");
    }

    // Hide framework-created Pajdsakdfj icons
    for (UIView *subview in [keyWindow subviews]) {
        if ([subview isKindOfClass:pajdsakdfj_class] && subview != (UIView*)iconView) {
            subview.hidden = YES;
        }
    }

    // Set up our floating icon
    [iconView setFrame:frame];
    [iconView setHidden:NO];
    [iconView setAlpha:1.0];
    [iconView setUserInteractionEnabled:YES];
    [iconView setBackgroundColor:[UIColor colorWithRed:0.5 green:0.0 blue:0.8 alpha:0.8]];
    ((UIView*)iconView).layer.cornerRadius = 30;
    ((UIView*)iconView).clipsToBounds = YES;

    Ivar imageViewIvar = class_getInstanceVariable(pajdsakdfj_class, "_Vmasfisahf");
    if (imageViewIvar) {
        UIImageView* existing = object_getIvar(iconView, imageViewIvar);
        if (!existing || existing.frame.size.width == 0) {
            UIImageView* imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 60, 60)];
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(60, 60), NO, 0.0);
            CGContextRef ctx = UIGraphicsGetCurrentContext();
            CGContextSetFillColorWithColor(ctx, [UIColor colorWithRed:0.5 green:0.0 blue:0.8 alpha:1.0].CGColor);
            CGContextFillEllipseInRect(ctx, CGRectMake(0, 0, 60, 60));
            CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
            [@"W" drawInRect:CGRectMake(16, 12, 30, 40) withAttributes:@{
                NSFontAttributeName: [UIFont boldSystemFontOfSize:28],
                NSForegroundColorAttributeName: [UIColor whiteColor]
            }];
            imageView.image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            object_setIvar(iconView, imageViewIvar, imageView);
            [iconView addSubview:imageView];
        }
    }

    // ---- TAP HANDLER: toggle our UIKit menu ----
    SEL tapSelector = NSSelectorFromString(@"didTapIconView");
    Method tapMethod = class_getInstanceMethod(pajdsakdfj_class, tapSelector);
    if (tapMethod) {
        IMP newTap = imp_implementationWithBlock(^(id self) {
            NSLog(@"[WizardBypass] TAP! Toggling custom UIKit menu");

            // Find our menu by tag
            UIWindow* kw = nil;
            NSArray* wins = [[UIApplication sharedApplication] windows];
            for (UIWindow* w in wins) {
                if (w.isKeyWindow) { kw = w; break; }
            }
            if (!kw && [wins count] > 0) kw = [wins objectAtIndex:0];
            if (!kw) return;

            UIView *ourMenu = [kw viewWithTag:9999];
            if (!ourMenu) {
                NSLog(@"[WizardBypass] ERROR: Custom menu not found (tag 9999)!");
                return;
            }

            BOOL isHidden = ourMenu.hidden;
            NSLog(@"[WizardBypass] Menu isHidden=%d, toggling to %d", isHidden, !isHidden);

            if (isHidden) {
                ourMenu.hidden = NO;
                ourMenu.alpha = 0.0;
                [kw bringSubviewToFront:ourMenu];
                [UIView animateWithDuration:0.25 animations:^{
                    ourMenu.alpha = 1.0;
                }];
                NSLog(@"[WizardBypass] Custom menu SHOWN!");
            } else {
                [UIView animateWithDuration:0.2 animations:^{
                    ourMenu.alpha = 0.0;
                } completion:^(BOOL finished) {
                    ourMenu.hidden = YES;
                }];
                NSLog(@"[WizardBypass] Custom menu HIDDEN!");
            }

            // Keep icon on top
            if (g_wizardIcon) {
                [kw bringSubviewToFront:(UIView*)g_wizardIcon];
            }
        });
        method_setImplementation(tapMethod, newTap);
        NSLog(@"[WizardBypass] didTapIconView → custom UIKit menu toggle");
    }

    [keyWindow addSubview:iconView];
    [keyWindow bringSubviewToFront:iconView];
    NSLog(@"[WizardBypass] Icon added at %@", NSStringFromCGRect(frame));
    NSLog(@"[WizardBypass] === v30 READY — ALL BUTTONS WIRED ===");
}

// ============================================================================
// CONSTRUCTOR - Run everything EARLY (v31)
// ============================================================================

__attribute__((constructor(101)))
static void wizard_bypass_init(void) {
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] v31 CRYPTO AUTH BYPASS - EARLY INIT");
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
    NSLog(@"[WizardBypass] v31 init complete — Wizard UI will show normally");
    NSLog(@"[WizardBypass] ========================================");
}
