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

// v29: Custom UIKit menu + full Wizard API dump. No drawInMTKView hook.
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
    // v29: Build our own menu — no more broken Metal/imgui
    // ========================================
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] PHASE 8: CUSTOM UIKit MENU (v29)");
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

    // ---- BUILD CUSTOM UIKit MENU ----
    // Main container: semi-transparent dark overlay
    CGFloat menuW = screenW * 0.85;
    CGFloat menuH = screenH * 0.6;
    CGFloat menuX = (screenW - menuW) / 2.0;
    CGFloat menuY = (screenH - menuH) / 2.0;

    UIView *menuContainer = [[UIView alloc] initWithFrame:CGRectMake(menuX, menuY, menuW, menuH)];
    menuContainer.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.15 alpha:0.95];
    menuContainer.layer.cornerRadius = 16;
    menuContainer.clipsToBounds = YES;
    menuContainer.hidden = YES;
    menuContainer.tag = 9999; // Tag for finding it later

    // Title bar
    UIView *titleBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, menuW, 50)];
    titleBar.backgroundColor = [UIColor colorWithRed:0.3 green:0.1 blue:0.6 alpha:1.0];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, menuW - 32, 50)];
    titleLabel.text = @"Wizard Menu — v29";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [titleBar addSubview:titleLabel];
    [menuContainer addSubview:titleBar];

    // Subtitle
    UILabel *subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 54, menuW - 32, 20)];
    subtitleLabel.text = @"Feature discovery build — check syslog for API dump";
    subtitleLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
    subtitleLabel.font = [UIFont systemFontOfSize:12];
    [menuContainer addSubview:subtitleLabel];

    // ScrollView for feature list
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 80, menuW, menuH - 80)];
    scrollView.showsVerticalScrollIndicator = YES;

    // Create placeholder feature buttons — we'll populate with real features in v30
    // For now, list the known Wizard methods as tappable items
    NSArray *featureNames = @[
        @"PADSGFNDSAHJ — Icon Setup",
        @"IKAFHFDSAJ — Full Menu Init",
        @"ASFGAHJFAHS — Chain Setup",
        @"MdhsaJFSAJ — Base Setup",
        @"paDJSAFBSANC — Menu Method 1",
        @"jsafbSAHCN — Menu Method 2",
        @"dgshdsfyewrh — Menu Method 3",
        @"initializePlatform — Metal Init",
        @"shutdownPlatform — Metal Shutdown",
        @"handleEvent:view: — Input Forward"
    ];

    CGFloat buttonY = 8;
    CGFloat buttonH = 44;
    CGFloat buttonW = menuW - 32;

    for (NSUInteger fi = 0; fi < featureNames.count; fi++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(16, buttonY, buttonW, buttonH);
        btn.backgroundColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.25 alpha:1.0];
        btn.layer.cornerRadius = 8;
        [btn setTitle:featureNames[fi] forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor colorWithRed:0.7 green:0.8 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:14];
        btn.titleLabel.adjustsFontSizeToFitWidth = YES;
        btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        btn.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 12);
        btn.tag = 10000 + fi;

        // All buttons just log for now — v30 will wire real features
        [btn addTarget:nil action:@selector(description) forControlEvents:UIControlEventTouchUpInside];

        [scrollView addSubview:btn];
        buttonY += buttonH + 8;
    }

    // Info label at bottom
    UILabel *infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, buttonY + 4, buttonW, 40)];
    infoLabel.text = @"Check syslog for full Wizard API dump.\nFeatures will be wired in v30.";
    infoLabel.textColor = [UIColor colorWithWhite:0.4 alpha:1.0];
    infoLabel.font = [UIFont systemFontOfSize:11];
    infoLabel.numberOfLines = 2;
    [scrollView addSubview:infoLabel];

    scrollView.contentSize = CGSizeMake(menuW, buttonY + 52);
    [menuContainer addSubview:scrollView];

    [keyWindow addSubview:menuContainer];
    NSLog(@"[WizardBypass] Custom UIKit menu created (hidden, tag=9999)");

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

            // ONE-SHOT: Dump all Wizard classes on first tap (safe — Wizard fully init'd)
            static BOOL didDumpAPI = NO;
            if (!didDumpAPI) {
                didDumpAPI = YES;
                NSLog(@"[WizardBypass] === WIZARD API DUMP (on first tap) ===");
                unsigned int allClassCount;
                Class *allClasses = objc_copyClassList(&allClassCount);
                int wizardClassCount = 0;
                for (unsigned int ci = 0; ci < allClassCount; ci++) {
                    const char *img = class_getImageName(allClasses[ci]);
                    if (!img || !strstr(img, "Wizard.framework")) continue;
                    wizardClassCount++;
                    const char *cn = class_getName(allClasses[ci]);
                    Class superCls = class_getSuperclass(allClasses[ci]);
                    const char *superName = superCls ? class_getName(superCls) : "nil";
                    NSLog(@"[WizardBypass] === CLASS: %s (super: %s) ===", cn, superName);
                    // Ivars
                    unsigned int ivarCount;
                    Ivar *ivars = class_copyIvarList(allClasses[ci], &ivarCount);
                    for (unsigned int iv = 0; iv < ivarCount; iv++) {
                        NSLog(@"[WizardBypass]   ivar[%d] %s (%s) off=%td", iv,
                              ivar_getName(ivars[iv]), ivar_getTypeEncoding(ivars[iv]),
                              ivar_getOffset(ivars[iv]));
                    }
                    if (ivars) free(ivars);
                    // Methods
                    unsigned int methodCount;
                    Method *methods = class_copyMethodList(allClasses[ci], &methodCount);
                    for (unsigned int mi = 0; mi < methodCount; mi++) {
                        SEL sel = method_getName(methods[mi]);
                        char *retType = method_copyReturnType(methods[mi]);
                        unsigned int nargs = method_getNumberOfArguments(methods[mi]);
                        NSLog(@"[WizardBypass]   method[%d] %s ret:%s args:%u", mi,
                              sel_getName(sel), retType, nargs);
                        free(retType);
                    }
                    if (methods) free(methods);
                }
                free(allClasses);
                NSLog(@"[WizardBypass] Total Wizard classes: %d", wizardClassCount);
                NSLog(@"[WizardBypass] === END API DUMP ===");
            }

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
    NSLog(@"[WizardBypass] === v29 READY — TAP ICON FOR UIKit MENU ===");
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
