// Wizard Authentication Bypass - NUCLEAR OPTION
// No CydiaSubstrate - Pure C/Objective-C runtime manipulation

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <QuartzCore/QuartzCore.h>
#import <mach/mach.h>
#import <libkern/OSCacheControl.h>

// ============================================================================
// GLOBAL: Wizard controller reference accessible from didTapIconView
// Since Pajdsakdfj has 0 ivars, we use a global to bridge the gap
// ============================================================================
static id g_wizardController = nil;
static id g_wizardIcon = nil;

// v28: Safe no-op drawInMTKView + hex dump. v27 flag-preset crashed (bad ADRP decode).
// Only system-level hooks (UIKit, NSUserDefaults, SCLAlertView, dyld) are used.

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
// PHASE 4: POPUP BLOCKING - Block SCLAlertView
// ============================================================================

static IMP original_showCustom = NULL;
static IMP original_showTitle = NULL;

// Swizzled showCustom method
static void swizzled_showCustom(id self, SEL _cmd, UIImage* image, UIColor* color,
                                 NSString* title, NSString* subTitle,
                                 NSString* closeButtonTitle, NSTimeInterval duration) {
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] SCLAlertView showCustom called!");
    NSLog(@"[WizardBypass] Title: %@", title);
    NSLog(@"[WizardBypass] SubTitle: %@", subTitle);
    NSLog(@"[WizardBypass] CloseButton: %@", closeButtonTitle);
    NSLog(@"[WizardBypass] ========================================");

    // BLOCK ALL POPUPS - we'll refine this later
    NSLog(@"[WizardBypass] ✓ BLOCKED popup!");
    return;
}

// Swizzled showTitle method
static void swizzled_showTitle(id self, SEL _cmd, NSString* title, NSString* subTitle,
                                NSInteger style, NSString* closeButtonTitle, NSTimeInterval duration) {
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] SCLAlertView showTitle called!");
    NSLog(@"[WizardBypass] Title: %@", title);
    NSLog(@"[WizardBypass] SubTitle: %@", subTitle);
    NSLog(@"[WizardBypass] Style: %ld", (long)style);
    NSLog(@"[WizardBypass] CloseButton: %@", closeButtonTitle);
    NSLog(@"[WizardBypass] ========================================");

    // BLOCK ALL POPUPS
    NSLog(@"[WizardBypass] ✓ BLOCKED popup!");
    return;
}

static void hook_scl_alert_view(void) {
    NSLog(@"[WizardBypass] Hooking SCLAlertView...");

    Class cls = objc_getClass("SCLAlertView");
    if (!cls) {
        NSLog(@"[WizardBypass] WARNING: SCLAlertView class not found (may load later)");
        return;
    }

    NSLog(@"[WizardBypass] Found SCLAlertView class, hooking ALL methods...");

    // CRITICAL: Hook the main entry points first
    const char* critical_methods[] = {
        "showAlertView:",
        "showAlertView:onViewController:",
        NULL
    };

    for (int i = 0; critical_methods[i] != NULL; i++) {
        SEL selector = sel_registerName(critical_methods[i]);
        Method method = class_getInstanceMethod(cls, selector);

        if (method) {
            NSLog(@"[WizardBypass] ✓✓✓ Hooking CRITICAL method: %s", critical_methods[i]);

            // Copy method name for block capture
            const char* method_name = critical_methods[i];
            char* name_copy = strdup(method_name);

            IMP new_imp = imp_implementationWithBlock(^(id self) {
                NSLog(@"[WizardBypass] ========================================");
                NSLog(@"[WizardBypass] ✓✓✓ BLOCKED CRITICAL: %s ✓✓✓", name_copy);
                NSLog(@"[WizardBypass] ========================================");
                // Do nothing - popup blocked
            });

            method_setImplementation(method, new_imp);
        } else {
            NSLog(@"[WizardBypass] WARNING: Method not found: %s", critical_methods[i]);
        }
    }

    // Get ALL instance methods
    unsigned int method_count;
    Method* methods = class_copyMethodList(cls, &method_count);

    NSLog(@"[WizardBypass] Found %u methods in SCLAlertView", method_count);

    for (unsigned int i = 0; i < method_count; i++) {
        SEL selector = method_getName(methods[i]);
        const char* name = sel_getName(selector);

        // Hook ANY method that contains "show" (case insensitive)
        if (strcasestr(name, "show")) {
            NSLog(@"[WizardBypass] Hooking method: %s", name);

            // Copy name for block capture
            char* name_copy = strdup(name);

            // Replace with blocking implementation
            IMP new_imp = imp_implementationWithBlock(^(id self) {
                NSLog(@"[WizardBypass] ✓✓✓ BLOCKED SCLAlertView::%s ✓✓✓", name_copy);
                // Do nothing - popup blocked
            });

            method_setImplementation(methods[i], new_imp);
        }
    }

    free(methods);

    // Also hook the specific methods we know about
    SEL sel1 = NSSelectorFromString(@"showCustom:color:title:subTitle:closeButtonTitle:duration:");
    Method method1 = class_getInstanceMethod(cls, sel1);
    if (method1) {
        original_showCustom = method_setImplementation(method1, (IMP)swizzled_showCustom);
        NSLog(@"[WizardBypass] ✓ Hooked showCustom (specific)");
    }

    SEL sel2 = NSSelectorFromString(@"showTitle:subTitle:style:closeButtonTitle:duration:");
    Method method2 = class_getInstanceMethod(cls, sel2);
    if (method2) {
        original_showTitle = method_setImplementation(method2, (IMP)swizzled_showTitle);
        NSLog(@"[WizardBypass] ✓ Hooked showTitle (specific)");
    }

    NSLog(@"[WizardBypass] SCLAlertView comprehensive hooking complete");
}

// ============================================================================
// PHASE 4B: HOOK UIAlertController
// ============================================================================

static void hook_ui_alert_controller(void) {
    NSLog(@"[WizardBypass] Hooking UIAlertController...");

    Class alert_class = objc_getClass("UIAlertController");
    if (!alert_class) {
        NSLog(@"[WizardBypass] WARNING: UIAlertController not found");
        return;
    }

    // Hook alertControllerWithTitle:message:preferredStyle:
    SEL selector = @selector(alertControllerWithTitle:message:preferredStyle:);
    Method method = class_getClassMethod(alert_class, selector);

    if (method) {
        IMP original_imp = method_getImplementation(method);
        IMP new_imp = imp_implementationWithBlock(^UIAlertController*(Class self, NSString* title, NSString* message, UIAlertControllerStyle style) {
            // Check if this is an auth-related alert
            NSString* lowerTitle = [title lowercaseString];
            NSString* lowerMsg = [message lowercaseString];

            if ([lowerTitle containsString:@"auth"] || [lowerTitle containsString:@"license"] ||
                [lowerTitle containsString:@"key"] || [lowerTitle containsString:@"wizard"] ||
                [lowerMsg containsString:@"auth"] || [lowerMsg containsString:@"license"]) {
                NSLog(@"[WizardBypass] ✓ BLOCKED UIAlertController: %@", title);
                return nil;
            }

            // Call original for non-auth alerts
            typedef UIAlertController* (*OrigFunc)(Class, SEL, NSString*, NSString*, UIAlertControllerStyle);
            return ((OrigFunc)original_imp)(self, selector, title, message, style);
        });

        method_setImplementation(method, new_imp);
        NSLog(@"[WizardBypass] UIAlertController hook installed");
    }
}

// ============================================================================
// PHASE 4B2: HOOK SCLAlertViewShowBuilder - The builder pattern
// ============================================================================

static void hook_scl_alert_view_show_builder(void) {
    NSLog(@"[WizardBypass] Hooking SCLAlertViewShowBuilder...");

    Class builder_class = objc_getClass("SCLAlertViewShowBuilder");
    if (!builder_class) {
        NSLog(@"[WizardBypass] WARNING: SCLAlertViewShowBuilder not found");
        return;
    }

    NSLog(@"[WizardBypass] Found SCLAlertViewShowBuilder, hooking all methods...");

    // Get ALL instance methods
    unsigned int method_count;
    Method* methods = class_copyMethodList(builder_class, &method_count);

    NSLog(@"[WizardBypass] Found %u methods in SCLAlertViewShowBuilder", method_count);

    for (unsigned int i = 0; i < method_count; i++) {
        SEL selector = method_getName(methods[i]);
        const char* name = sel_getName(selector);

        NSLog(@"[WizardBypass] Hooking builder method: %s", name);

        // Copy name for block capture
        char* name_copy = strdup(name);

        // Replace ALL methods with blocking implementation
        IMP new_imp = imp_implementationWithBlock(^id(id self) {
            NSLog(@"[WizardBypass] ✓✓✓ BLOCKED SCLAlertViewShowBuilder::%s ✓✓✓", name_copy);
            // Return self for chaining, but don't actually show anything
            return self;
        });

        method_setImplementation(methods[i], new_imp);
    }

    free(methods);
    NSLog(@"[WizardBypass] SCLAlertViewShowBuilder hooking complete");
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

            // Log ALL presentations to see what's being shown
            NSLog(@"[WizardBypass] presentViewController called: %@", className);

            // ONLY block SCLAlertView itself, not other SCL* view controllers
            if ([className isEqualToString:@"SCLAlertView"] ||
                [className containsString:@"UIAlertController"]) {
                NSLog(@"[WizardBypass] ✓✓✓ BLOCKED presentation of: %@ ✓✓✓", className);
                if (completion) completion();
                return;
            }

            // Call original for non-alert VCs
            typedef void (*OrigFunc)(UIViewController*, SEL, UIViewController*, BOOL, void(^)(void));
            ((OrigFunc)original_imp)(self, selector, vc, animated, completion);
        });

        method_setImplementation(method, new_imp);
        NSLog(@"[WizardBypass] UIViewController presentation hook installed");
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

    // Hook addSubview to catch alert views being added
    SEL selector2 = @selector(addSubview:);
    Method method2 = class_getInstanceMethod(window_class, selector2);
    if (method2) {
        IMP original_imp = method_getImplementation(method2);
        IMP new_imp = imp_implementationWithBlock(^(UIWindow* self, UIView* view) {
            NSString* viewClassName = NSStringFromClass([view class]);

            NSLog(@"[WizardBypass] UIWindow addSubview: %@", viewClassName);

            // ONLY block SCLAlertView itself, not other SCL* classes (like SCLTextView, SCLButton)
            // These are legitimate game UI components
            if ([viewClassName isEqualToString:@"SCLAlertView"] ||
                [viewClassName containsString:@"AlertView"] ||
                [viewClassName containsString:@"UIAlertController"]) {
                NSLog(@"[WizardBypass] ✓✓✓ BLOCKED UIWindow addSubview: %@ ✓✓✓", viewClassName);
                return;
            }

            // Call original
            typedef void (*OrigFunc)(UIWindow*, SEL, UIView*);
            ((OrigFunc)original_imp)(self, selector2, view);
        });

        method_setImplementation(method2, new_imp);
        NSLog(@"[WizardBypass] UIWindow addSubview hook installed");
    }
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

    // 4. Hook dispatch_after indirectly by hooking SCLAlertView's hideView method
    //    and hideAnimationType — the popup's internal dismiss triggers Wizard's timeout
    Class sclClass = objc_getClass("SCLAlertView");
    if (sclClass) {
        // Hook hideView to prevent auto-dismiss triggering timeout
        SEL hideViewSel = NSSelectorFromString(@"hideView");
        Method hideViewMethod = class_getInstanceMethod(sclClass, hideViewSel);
        if (hideViewMethod) {
            IMP newHide = imp_implementationWithBlock(^(id self) {
                NSLog(@"[WizardBypass] *** SCLAlertView::hideView called — BLOCKING (prevents timeout dismiss) ***");
                // Don't call original — prevents the dismiss-triggered auth timeout
            });
            method_setImplementation(hideViewMethod, newHide);
            NSLog(@"[WizardBypass] SCLAlertView::hideView hooked (blocked)");
        }

        // Also hook dismissViewControllerAnimated:completion:
        SEL dismissSel = @selector(dismissViewControllerAnimated:completion:);
        Method dismissMethod = class_getInstanceMethod(sclClass, dismissSel);
        if (dismissMethod) {
            IMP newDismiss = imp_implementationWithBlock(^(id self, BOOL animated, void(^completion)(void)) {
                NSLog(@"[WizardBypass] *** SCLAlertView::dismissVC called — BLOCKING ***");
                // Don't dismiss, don't trigger completion
            });
            method_setImplementation(dismissMethod, newDismiss);
            NSLog(@"[WizardBypass] SCLAlertView::dismissVC hooked (blocked)");
        }
    }

    NSLog(@"[WizardBypass] Idle/timeout kill hooks complete");
}

// ============================================================================
// DELAYED HOOK - Re-hook after Wizard loads (NO MEMORY PATCHING)
// ============================================================================

static void delayed_hook(void) {
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] DELAYED HOOK - Wizard should be loaded now");
    NSLog(@"[WizardBypass] ========================================");

    // Re-hook SCLAlertView now that Wizard is fully loaded
    NSLog(@"[WizardBypass] Re-hooking SCLAlertView...");
    hook_scl_alert_view();

    // Hook SCLAlertViewShowBuilder (builder pattern)
    NSLog(@"[WizardBypass] Hooking SCLAlertViewShowBuilder...");
    hook_scl_alert_view_show_builder();

    // Hook UIAlertController
    hook_ui_alert_controller();

    // Hook UIViewController presentation
    hook_view_controller_presentation();

    // Hook UIWindow (nuclear option)
    hook_ui_window();

    // Try to force authentication state
    force_authentication();

    // Re-hook NSUserDefaults in case Wizard checks again
    hook_user_defaults();

    // Kill idle/timeout mechanisms
    hook_idle_timeout_kill();

    NSLog(@"[WizardBypass] Delayed hook complete - all hooks refreshed");

    // ========================================
    // PHASE 7: HOOK METAL RENDERER FOR SAFETY + SETUP CONTROLLER
    // IKAFHFDSAJ creates MTKView + Wksahfnasj but the Metal render loop
    // (drawInMTKView:) can crash if imgui isn't fully ready.
    // Solution: hook drawInMTKView: with @try/@catch before calling IKAFHFDSAJ
    // ========================================
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] PHASE 7: HOOKING METAL + SETTING UP CONTROLLER");
    NSLog(@"[WizardBypass] ========================================");

    // FIRST: Hook drawInMTKView: on AJFADSHFSAJXN
    // The ORIGINAL drawInMTKView: contains anti-tamper checks that jump to 0xDEAD
    // We MUST NOT call the original - replace with complete no-op
    Class ajfClass = objc_getClass("AJFADSHFSAJXN");
    if (ajfClass) {
        SEL drawSel = NSSelectorFromString(@"drawInMTKView:");
        Method drawMethod = class_getInstanceMethod(ajfClass, drawSel);
        if (drawMethod) {
            IMP originalDraw = method_getImplementation(drawMethod);
            NSLog(@"[WizardBypass] === drawInMTKView: IMP @ %p ===", originalDraw);

            // ================================================================
            // v28: SAFE NO-OP + HEX DUMP (reverted from v27 flag-preset crash)
            // ================================================================
            // v27 crashed because ADRP+ADD decode produced a bad address.
            // Strategy: dump 128 bytes of the original IMP for manual analysis,
            // then replace with no-op (proven safe in v18/v24).
            // ================================================================

            // STEP 1: Hex dump 128 bytes of original IMP for offline analysis
            unsigned char *impPtr = (unsigned char *)originalDraw;
            NSLog(@"[WizardBypass] ========================================");
            NSLog(@"[WizardBypass] DUMPING 128 BYTES OF drawInMTKView: IMP");
            NSLog(@"[WizardBypass] IMP address: %p", originalDraw);
            NSLog(@"[WizardBypass] ========================================");
            for (int row = 0; row < 8; row++) {
                int off = row * 16;
                NSLog(@"[WizardBypass] +%03x: %02x %02x %02x %02x  %02x %02x %02x %02x  %02x %02x %02x %02x  %02x %02x %02x %02x",
                      off,
                      impPtr[off+0],  impPtr[off+1],  impPtr[off+2],  impPtr[off+3],
                      impPtr[off+4],  impPtr[off+5],  impPtr[off+6],  impPtr[off+7],
                      impPtr[off+8],  impPtr[off+9],  impPtr[off+10], impPtr[off+11],
                      impPtr[off+12], impPtr[off+13], impPtr[off+14], impPtr[off+15]);
            }
            // Also dump as 32-bit words for ARM64 instruction decode
            uint32_t *instrPtr = (uint32_t *)originalDraw;
            NSLog(@"[WizardBypass] --- ARM64 instructions (32 words) ---");
            for (int i = 0; i < 32; i++) {
                uint32_t instr = instrPtr[i];
                // Basic ARM64 instruction identification
                const char *hint = "";
                if ((instr & 0x9F000000) == 0x90000000) hint = " <-- ADRP";
                else if ((instr & 0x7F800000) == 0x11000000) hint = " <-- ADD imm";
                else if ((instr & 0xFF000000) == 0x35000000) hint = " <-- CBNZ W";
                else if ((instr & 0xFF000000) == 0xB5000000) hint = " <-- CBNZ X";
                else if ((instr & 0xFF000000) == 0x34000000) hint = " <-- CBZ W";
                else if ((instr & 0xFF000000) == 0xB4000000) hint = " <-- CBZ X";
                else if ((instr & 0xFFE00000) == 0xD2800000) hint = " <-- MOVZ";
                else if ((instr & 0xFFE00000) == 0xF2A00000) hint = " <-- MOVK (lsl#16)";
                else if ((instr & 0xFC000000) == 0x14000000) hint = " <-- B";
                else if ((instr & 0xFF000010) == 0x54000000) hint = " <-- B.cond";
                else if ((instr & 0xFFFFFC1F) == 0xD61F0000) hint = " <-- BR";
                else if ((instr & 0xFFFFFC1F) == 0xD63F0000) hint = " <-- BLR";
                else if ((instr & 0xFFE0001F) == 0xD65F0000) hint = " <-- RET";
                else if ((instr & 0x7FC00000) == 0x29000000) hint = " <-- STP";
                else if ((instr & 0x7FC00000) == 0x29400000) hint = " <-- LDP";
                else if ((instr & 0x3B000000) == 0x39000000) hint = " <-- LDR/STR imm";
                NSLog(@"[WizardBypass] [%02d] +0x%03x: 0x%08x%s", i, i*4, instr, hint);
            }
            NSLog(@"[WizardBypass] ========================================");

            // STEP 2: Replace with SAFE NO-OP (never calls original)
            IMP noopDraw = imp_implementationWithBlock(^(id selfDraw, id mtkView) {
                // Complete no-op — anti-tamper code never executes
                // Menu will be blank but game won't crash
            });
            method_setImplementation(drawMethod, noopDraw);
            NSLog(@"[WizardBypass] drawInMTKView: replaced with SAFE NO-OP (v28)");
        }

        // Log initializePlatform (not hooked, runs natively)
        SEL initPlatSel = NSSelectorFromString(@"initializePlatform");
        Method initPlatMethod = class_getInstanceMethod(ajfClass, initPlatSel);
        if (initPlatMethod) {
            NSLog(@"[WizardBypass] initializePlatform IMP @ %p (not hooked)",
                  method_getImplementation(initPlatMethod));
        }
    } else {
        NSLog(@"[WizardBypass] WARNING: AJFADSHFSAJXN class not found for safety hooks");
    }

    // Dump unknown classes for anti-tamper intelligence
    Class kmsjClass = objc_getClass("Kmsjfaigh");
    if (kmsjClass) {
        unsigned int kmMethodCount;
        Method *kmMethods = class_copyMethodList(kmsjClass, &kmMethodCount);
        NSLog(@"[WizardBypass] === Kmsjfaigh class: %d methods ===", kmMethodCount);
        for (unsigned int i = 0; i < kmMethodCount; i++) {
            SEL sel = method_getName(kmMethods[i]);
            char *retType = method_copyReturnType(kmMethods[i]);
            NSLog(@"[WizardBypass]   Kmsjfaigh::%s (ret: %s)", sel_getName(sel), retType);
            free(retType);
        }
        free(kmMethods);
        // Dump ivars too
        unsigned int kmIvarCount;
        Ivar *kmIvars = class_copyIvarList(kmsjClass, &kmIvarCount);
        NSLog(@"[WizardBypass]   Kmsjfaigh ivars: %d", kmIvarCount);
        for (unsigned int i = 0; i < kmIvarCount; i++) {
            NSLog(@"[WizardBypass]     %s (%s)", ivar_getName(kmIvars[i]), ivar_getTypeEncoding(kmIvars[i]));
        }
        free(kmIvars);
    }

    Class mjshClass = objc_getClass("Mjshjgkash");
    if (mjshClass) {
        unsigned int mjMethodCount;
        Method *mjMethods = class_copyMethodList(mjshClass, &mjMethodCount);
        NSLog(@"[WizardBypass] === Mjshjgkash class: %d methods ===", mjMethodCount);
        for (unsigned int i = 0; i < mjMethodCount; i++) {
            SEL sel = method_getName(mjMethods[i]);
            char *retType = method_copyReturnType(mjMethods[i]);
            NSLog(@"[WizardBypass]   Mjshjgkash::%s (ret: %s)", sel_getName(sel), retType);
            free(retType);
        }
        free(mjMethods);
        unsigned int mjIvarCount;
        Ivar *mjIvars = class_copyIvarList(mjshClass, &mjIvarCount);
        NSLog(@"[WizardBypass]   Mjshjgkash ivars: %d", mjIvarCount);
        for (unsigned int i = 0; i < mjIvarCount; i++) {
            NSLog(@"[WizardBypass]     %s (%s)", ivar_getName(mjIvars[i]), ivar_getTypeEncoding(mjIvars[i]));
        }
        free(mjIvars);
    }

    // Create ABVJSMGADJS controller
    Class abvjsmgadjs_class = objc_getClass("ABVJSMGADJS");
    if (!abvjsmgadjs_class) {
        NSLog(@"[WizardBypass] FATAL: ABVJSMGADJS class not found!");
        return;
    }
    g_wizardController = [[abvjsmgadjs_class alloc] init];
    NSLog(@"[WizardBypass] Created ABVJSMGADJS controller: %@", g_wizardController);

    // IMMEDIATELY invalidate controller timers to prevent idle/timeout kills
    Ivar timerIvar1 = class_getInstanceVariable(abvjsmgadjs_class, "_qmshnfuas");
    Ivar timerIvar2 = class_getInstanceVariable(abvjsmgadjs_class, "_nvjsafhsa");
    if (timerIvar1) {
        NSTimer *t1 = object_getIvar(g_wizardController, timerIvar1);
        if (t1) {
            [t1 invalidate];
            NSLog(@"[WizardBypass] Invalidated _qmshnfuas timer: %@", t1);
        }
        object_setIvar(g_wizardController, timerIvar1, nil);
        NSLog(@"[WizardBypass] Set _qmshnfuas = nil");
    }
    if (timerIvar2) {
        NSTimer *t2 = object_getIvar(g_wizardController, timerIvar2);
        if (t2) {
            [t2 invalidate];
            NSLog(@"[WizardBypass] Invalidated _nvjsafhsa timer: %@", t2);
        }
        object_setIvar(g_wizardController, timerIvar2, nil);
        NSLog(@"[WizardBypass] Set _nvjsafhsa = nil");
    }

    // ========================================
    // PHASE 8: CREATE UI + LET IKAFHFDSAJ BUILD MENU + PAUSE METAL
    // ========================================
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] PHASE 8: CREATE UI + MENU SETUP");
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

    // Create our icon
    Class pajdsakdfj_class = objc_getClass("Pajdsakdfj");
    if (!pajdsakdfj_class) { NSLog(@"[WizardBypass] ERROR: Pajdsakdfj not found"); return; }

    CGRect frame = CGRectMake(keyWindow.bounds.size.width - 80, 100, 60, 60);
    SEL initSelector = NSSelectorFromString(@"initWithFrame:type:");
    id iconView = nil;
    if ([pajdsakdfj_class instancesRespondToSelector:initSelector]) {
        id instance = [pajdsakdfj_class alloc];
        typedef id (*InitFunc)(id, SEL, CGRect, NSInteger);
        iconView = ((InitFunc)[pajdsakdfj_class instanceMethodForSelector:initSelector])(instance, initSelector, frame, 0);
    }
    if (!iconView) { NSLog(@"[WizardBypass] Failed to create icon"); return; }
    g_wizardIcon = iconView;

    // Wire our icon into controller's first Pajdsakdfj slot
    unsigned int ctrlIvarCount;
    Ivar *ctrlIvars = class_copyIvarList(abvjsmgadjs_class, &ctrlIvarCount);
    for (unsigned int i = 0; i < ctrlIvarCount; i++) {
        const char *type = ivar_getTypeEncoding(ctrlIvars[i]);
        if (type && strstr(type, "Pajdsakdfj")) {
            NSLog(@"[WizardBypass] Setting ABVJSMGADJS::%s = our icon", ivar_getName(ctrlIvars[i]));
            object_setIvar(g_wizardController, ctrlIvars[i], iconView);
            break;
        }
    }
    free(ctrlIvars);

    // Call PADSGFNDSAHJ (icon setup - creates UIImageViews, safe)
    NSLog(@"[WizardBypass] Calling PADSGFNDSAHJ...");
    ((void (*)(id, SEL))objc_msgSend)(g_wizardController, sel_registerName("PADSGFNDSAHJ"));

    // Call IKAFHFDSAJ (FULL setup - creates MTKView + Wksahfnasj + 4 icons)
    NSLog(@"[WizardBypass] Calling IKAFHFDSAJ (creates menu)...");
    ((void (*)(id, SEL))objc_msgSend)(g_wizardController, sel_registerName("IKAFHFDSAJ"));

    // Get the menu that IKAFHFDSAJ created
    Ivar menuIvar = class_getInstanceVariable(abvjsmgadjs_class, "_jdsghadurewmf");
    id menu = menuIvar ? object_getIvar(g_wizardController, menuIvar) : nil;
    NSLog(@"[WizardBypass] Menu after IKAFHFDSAJ: %@", menu);

    if (menu) {
        // CRITICAL: Hide the menu and pause its MTKView to stop render loop crash
        [(UIView*)menu setHidden:YES];
        NSLog(@"[WizardBypass] Menu hidden (will show on tap)");

        // Pause the MTKView inside the menu to stop Metal render loop
        Class wksClass = objc_getClass("Wksahfnasj");
        if (wksClass) {
            Ivar mtkIvar = class_getInstanceVariable(wksClass, "_pPfuasjrasfh");
            if (mtkIvar) {
                id mtkView = object_getIvar(menu, mtkIvar);
                NSLog(@"[WizardBypass] MTKView inside menu: %@", mtkView);
                if (mtkView) {
                    // Pause the MTKView - stops drawInMTKView: calls
                    SEL pausedSel = NSSelectorFromString(@"setPaused:");
                    if ([mtkView respondsToSelector:pausedSel]) {
                        ((void (*)(id, SEL, BOOL))objc_msgSend)(mtkView, pausedSel, YES);
                        NSLog(@"[WizardBypass] MTKView PAUSED - render loop stopped");
                    }
                    // Also disable frame updates
                    SEL enableSetterSel = NSSelectorFromString(@"setEnableSetNeedsDisplay:");
                    if ([mtkView respondsToSelector:enableSetterSel]) {
                        ((void (*)(id, SEL, BOOL))objc_msgSend)(mtkView, enableSetterSel, NO);
                        NSLog(@"[WizardBypass] MTKView setNeedsDisplay disabled");
                    }
                }
            }

            // Dump Wksahfnasj ivars for diagnostics
            unsigned int wkIvarCount;
            Ivar *wkIvars = class_copyIvarList(wksClass, &wkIvarCount);
            NSLog(@"[WizardBypass] Wksahfnasj has %d ivars:", wkIvarCount);
            for (unsigned int i = 0; i < wkIvarCount; i++) {
                const char *nm = ivar_getName(wkIvars[i]);
                const char *tp = ivar_getTypeEncoding(wkIvars[i]);
                id val = nil;
                if (tp && tp[0] == '@') val = object_getIvar(menu, wkIvars[i]);
                NSLog(@"[WizardBypass]   %s (%s) = %@", nm, tp, val);
            }
            free(wkIvars);

            // CRITICAL FIX: Check tsjfhasjfsa (render callback block)
            // If nil, set a no-op block so drawInMTKView: doesn't crash
            Ivar cbIvar = class_getInstanceVariable(wksClass, "tsjfhasjfsa");
            if (cbIvar) {
                ptrdiff_t offset = ivar_getOffset(cbIvar);
                void *blockPtr = *(void **)((char *)(__bridge void *)menu + offset);
                NSLog(@"[WizardBypass] tsjfhasjfsa (render callback) raw ptr: %p", blockPtr);
                if (!blockPtr) {
                    NSLog(@"[WizardBypass] *** tsjfhasjfsa is NULL - setting no-op block ***");
                    // Set a no-op block so the renderer has something safe to call
                    void (^noopBlock)(void) = ^{
                        // No-op: prevents EXC_BAD_ACCESS when Metal tries to render
                    };
                    // Copy the block to the heap so it persists
                    void *heapBlock = (__bridge void *)[noopBlock copy];
                    *(void **)((char *)(__bridge void *)menu + offset) = heapBlock;
                    NSLog(@"[WizardBypass] Set no-op render callback at offset %td", offset);
                    
                    // Verify
                    void *verifyPtr = *(void **)((char *)(__bridge void *)menu + offset);
                    NSLog(@"[WizardBypass] Verified tsjfhasjfsa ptr: %p", verifyPtr);
                } else {
                    NSLog(@"[WizardBypass] tsjfhasjfsa is already set (not nil)");
                }
            }
        }
    }

    // Hide ALL framework-created Pajdsakdfj icons (IKAFHFDSAJ created extras)
    for (UIView *subview in [keyWindow subviews]) {
        if ([subview isKindOfClass:pajdsakdfj_class] && subview != (UIView*)iconView) {
            NSLog(@"[WizardBypass] Hiding framework Pajdsakdfj: %@", subview);
            subview.hidden = YES;
        }
    }

    // Set up OUR icon appearance
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

    // ========================================
    // FULLY REPLACE didTapIconView - toggle menu + unpause MTKView
    // ========================================
    SEL tapSelector = NSSelectorFromString(@"didTapIconView");
    Method tapMethod = class_getInstanceMethod(pajdsakdfj_class, tapSelector);
    if (tapMethod) {
        IMP newTap = imp_implementationWithBlock(^(id self) {
            NSLog(@"[WizardBypass] ========================================");
            NSLog(@"[WizardBypass] TAP! Toggling menu via g_wizardController");
            NSLog(@"[WizardBypass] ========================================");

            if (!g_wizardController) {
                NSLog(@"[WizardBypass] ERROR: g_wizardController is nil!");
                return;
            }

            Class ctrlClass = [g_wizardController class];
            Ivar mIvar = class_getInstanceVariable(ctrlClass, "_jdsghadurewmf");
            id menuRef = mIvar ? object_getIvar(g_wizardController, mIvar) : nil;
            NSLog(@"[WizardBypass] Menu: %@", menuRef);

            if (!menuRef) {
                NSLog(@"[WizardBypass] Menu is nil, cannot toggle!");
                return;
            }

            BOOL isHidden = [(UIView*)menuRef isHidden];
            NSLog(@"[WizardBypass] Menu isHidden=%d, toggling to %d", isHidden, !isHidden);

            if (isHidden) {
                // SHOW menu — DO NOT unpause MTKView (anti-tamper runs in render loop)
                [(UIView*)menuRef setHidden:NO];
                [(UIView*)menuRef setUserInteractionEnabled:YES];
                [(UIView*)menuRef setAlpha:1.0];

                // Bring to front
                UIWindow* kw = [(UIView*)menuRef window];
                if (!kw) {
                    NSArray* wins = [[UIApplication sharedApplication] windows];
                    for (UIWindow* w in wins) {
                        if (w.isKeyWindow) { kw = w; break; }
                    }
                    if (!kw && [wins count] > 0) kw = [wins objectAtIndex:0];
                    if (kw) {
                        [kw addSubview:menuRef];
                        NSLog(@"[WizardBypass] Added menu to window");
                    }
                }
                if (kw) [kw bringSubviewToFront:menuRef];

                // NOTE: MTKView stays paused — drawInMTKView: is a no-op anyway
                // Unpausing would trigger the render loop which we don't need
                // since drawInMTKView: is replaced with no-op
                // BUT let's try unpausing now that the anti-tamper code is bypassed:
                Class wksClass = objc_getClass("Wksahfnasj");
                Ivar mtkIvar = wksClass ? class_getInstanceVariable(wksClass, "_pPfuasjrasfh") : NULL;
                if (mtkIvar) {
                    id mtkView = object_getIvar(menuRef, mtkIvar);
                    if (mtkView) {
                        SEL pausedSel = NSSelectorFromString(@"setPaused:");
                        if ([mtkView respondsToSelector:pausedSel]) {
                            ((void (*)(id, SEL, BOOL))objc_msgSend)(mtkView, pausedSel, NO);
                            NSLog(@"[WizardBypass] MTKView UNPAUSED (drawInMTKView is no-op)");
                        }
                    }
                }

                NSLog(@"[WizardBypass] Menu SHOWN!");
            } else {
                // HIDE menu
                [(UIView*)menuRef setHidden:YES];
                NSLog(@"[WizardBypass] Menu HIDDEN!");
            }

            // Keep our icon on top
            if (g_wizardIcon) {
                UIWindow* kw = [(UIView*)g_wizardIcon window];
                if (kw) [kw bringSubviewToFront:g_wizardIcon];
            }
        });
        method_setImplementation(tapMethod, newTap);
        NSLog(@"[WizardBypass] didTapIconView FULLY REPLACED (toggle + MTKView pause/unpause)");
    }

    // Add our icon to window (on top)
    [keyWindow addSubview:iconView];
    [keyWindow bringSubviewToFront:iconView];
    NSLog(@"[WizardBypass] Icon added at %@", NSStringFromCGRect(frame));

    // Final state
    NSLog(@"[WizardBypass] === FINAL STATE ===");
    NSLog(@"[WizardBypass] g_wizardController: %@", g_wizardController);
    NSLog(@"[WizardBypass] Menu: %@ (hidden=%d)", menu, menu ? [(UIView*)menu isHidden] : -1);
    NSLog(@"[WizardBypass] PHASE 8 COMPLETE - TAP ICON TO SHOW MENU");
}

// ============================================================================
// PHASE 5: CONSTRUCTOR - Run everything EARLY
// ============================================================================

__attribute__((constructor(101)))
static void wizard_bypass_init(void) {
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] METHOD SWIZZLING ONLY - EARLY INIT (Priority 101)");
    NSLog(@"[WizardBypass] ========================================");

    // Phase 1: Force authentication
    NSLog(@"[WizardBypass] Phase 1: Forcing authentication...");
    force_authentication();

    // Phase 1b: Hook NSUserDefaults to fake license key
    NSLog(@"[WizardBypass] Phase 1b: Hooking NSUserDefaults...");
    hook_user_defaults();

    // Phase 2: Hook popup display (SCLAlertView)
    NSLog(@"[WizardBypass] Phase 2: Hooking SCLAlertView...");
    hook_scl_alert_view();

    // Phase 2b: Hook SCLAlertViewShowBuilder
    NSLog(@"[WizardBypass] Phase 2b: Hooking SCLAlertViewShowBuilder...");
    hook_scl_alert_view_show_builder();

    // Phase 3: Hook UIAlertController
    NSLog(@"[WizardBypass] Phase 3: Hooking UIAlertController...");
    hook_ui_alert_controller();

    // Phase 4: Hook UIViewController presentation
    NSLog(@"[WizardBypass] Phase 4: Hooking UIViewController presentation...");
    hook_view_controller_presentation();

    // Phase 5: Hook UIWindow (nuclear option)
    NSLog(@"[WizardBypass] Phase 5: Hooking UIWindow...");
    hook_ui_window();

    // Phase 6: Schedule delayed hook after 2 seconds (when Wizard is fully loaded)
    NSLog(@"[WizardBypass] Phase 6: Scheduling delayed hook in 2 seconds...");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        delayed_hook();
    });

    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] Initialization complete - NO MEMORY PATCHING!");
    NSLog(@"[WizardBypass] ========================================");
}
