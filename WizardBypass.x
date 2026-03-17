// Wizard Authentication Bypass - NUCLEAR OPTION
// No CydiaSubstrate - Pure C/Objective-C runtime manipulation

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <QuartzCore/QuartzCore.h>

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

            // Only hook BOOL-returning methods (likely validation checks)
            if (type_encoding[0] == 'c' || type_encoding[0] == 'B') {
                NSLog(@"[WizardBypass]   Hooking BOOL: %s::%s -> YES", class_name, name);

                IMP new_imp = imp_implementationWithBlock(^BOOL(id self) {
                    NSLog(@"[WizardBypass]   *** CALLED: %s::%s -> returning YES", class_name, name);
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

    NSLog(@"[WizardBypass] Delayed hook complete - all hooks refreshed");

    // ========================================
    // PHASE 7: HOOK ABVJSMGADJS - THE REAL CONTROLLER
    // ABVJSMGADJS owns: 4 Pajdsakdfj icons + 1 Wksahfnasj menu + 2 NSTimers
    // Its 4 obfuscated methods (PADSGFNDSAHJ, IKAFHFDSAJ, ASFGAHJFAHS, MdhsaJFSAJ) likely control auth
    // ========================================
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] PHASE 7: HOOKING ABVJSMGADJS (REAL CONTROLLER)");
    NSLog(@"[WizardBypass] ========================================");

    Class abvjsmgadjs_class = objc_getClass("ABVJSMGADJS");
    if (abvjsmgadjs_class) {
        NSLog(@"[WizardBypass] Found ABVJSMGADJS class!");

        // Dump ALL ivars to understand the structure
        unsigned int ivarCount;
        Ivar *ivars = class_copyIvarList(abvjsmgadjs_class, &ivarCount);
        NSLog(@"[WizardBypass] ABVJSMGADJS has %d ivars:", ivarCount);
        for (unsigned int i = 0; i < ivarCount; i++) {
            const char *name = ivar_getName(ivars[i]);
            const char *type = ivar_getTypeEncoding(ivars[i]);
            NSLog(@"[WizardBypass]   ivar[%d]: %s (type: %s)", i, name, type);
        }
        free(ivars);

        // Hook the 4 obfuscated methods to LOG what they do
        const char* methodNames[] = {"PADSGFNDSAHJ", "IKAFHFDSAJ", "ASFGAHJFAHS", "MdhsaJFSAJ", NULL};
        for (int m = 0; methodNames[m] != NULL; m++) {
            SEL methodSel = sel_registerName(methodNames[m]);
            Method method = class_getInstanceMethod(abvjsmgadjs_class, methodSel);
            if (method) {
                char *retType = method_copyReturnType(method);
                unsigned int argCount = method_getNumberOfArguments(method);
                NSLog(@"[WizardBypass] ABVJSMGADJS::%s -> retType=%s, argCount=%d", methodNames[m], retType, argCount);

                // Get full type encoding
                const char *typeEncoding = method_getTypeEncoding(method);
                NSLog(@"[WizardBypass]   Full encoding: %s", typeEncoding);

                IMP originalIMP = method_getImplementation(method);
                const char *capturedName = methodNames[m];

                // Hook based on return type
                if (retType[0] == 'v') {
                    // void return - hook to log and call original
                    IMP newIMP = imp_implementationWithBlock(^(id self) {
                        NSLog(@"[WizardBypass] *** CALLED: ABVJSMGADJS::%s (void) ***", capturedName);
                        typedef void (*OrigFunc)(id, SEL);
                        ((OrigFunc)originalIMP)(self, methodSel);
                        NSLog(@"[WizardBypass] *** RETURNED: ABVJSMGADJS::%s ***", capturedName);
                    });
                    method_setImplementation(method, newIMP);
                } else if (retType[0] == '@') {
                    // id return - hook to log and call original
                    IMP newIMP = imp_implementationWithBlock(^id(id self) {
                        NSLog(@"[WizardBypass] *** CALLED: ABVJSMGADJS::%s (id) ***", capturedName);
                        typedef id (*OrigFunc)(id, SEL);
                        id result = ((OrigFunc)originalIMP)(self, methodSel);
                        NSLog(@"[WizardBypass] *** RETURNED: ABVJSMGADJS::%s -> %@ ***", capturedName, result);
                        return result;
                    });
                    method_setImplementation(method, newIMP);
                } else if (retType[0] == 'c' || retType[0] == 'B') {
                    // BOOL return - force YES
                    IMP newIMP = imp_implementationWithBlock(^BOOL(id self) {
                        NSLog(@"[WizardBypass] *** CALLED: ABVJSMGADJS::%s (BOOL) -> forcing YES ***", capturedName);
                        return YES;
                    });
                    method_setImplementation(method, newIMP);
                } else {
                    NSLog(@"[WizardBypass] Unknown return type '%s' for %s, skipping hook", retType, capturedName);
                }

                free(retType);
            } else {
                NSLog(@"[WizardBypass] ABVJSMGADJS::%s NOT FOUND as instance method", methodNames[m]);
            }
        }
    } else {
        NSLog(@"[WizardBypass] ABVJSMGADJS class NOT FOUND!");
    }

    // ========================================
    // PHASE 8: CREATE ABVJSMGADJS + PAJDSAKDFJ WITH PROPER WIRING
    // ========================================
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] PHASE 8: CREATING WIZARD UI VIA ABVJSMGADJS");
    NSLog(@"[WizardBypass] ========================================");

    // Get the main window
    UIWindow* keyWindow = nil;
    NSArray* windows = [[UIApplication sharedApplication] windows];
    for (UIWindow* window in windows) {
        if (window.isKeyWindow) {
            keyWindow = window;
            break;
        }
    }
    if (!keyWindow && [windows count] > 0) {
        keyWindow = [windows objectAtIndex:0];
    }

    if (!keyWindow) {
        NSLog(@"[WizardBypass] ERROR: No key window found");
        return;
    }

    NSLog(@"[WizardBypass] Got key window: %@", keyWindow);

    // Step 1: Create ABVJSMGADJS controller
    id wizardController = nil;
    if (abvjsmgadjs_class) {
        wizardController = [[abvjsmgadjs_class alloc] init];
        NSLog(@"[WizardBypass] Created ABVJSMGADJS controller: %@", wizardController);
    }

    // Step 2: Create Pajdsakdfj icon
    Class pajdsakdfj_class = objc_getClass("Pajdsakdfj");
    if (!pajdsakdfj_class) {
        NSLog(@"[WizardBypass] ERROR: Pajdsakdfj class not found");
        return;
    }

    CGRect frame = CGRectMake(keyWindow.bounds.size.width - 80, 100, 60, 60);

    SEL initSelector = NSSelectorFromString(@"initWithFrame:type:");
    id iconView = nil;

    if ([pajdsakdfj_class instancesRespondToSelector:initSelector]) {
        id instance = [pajdsakdfj_class alloc];
        typedef id (*InitFunc)(id, SEL, CGRect, NSInteger);
        InitFunc initFunc = (InitFunc)[pajdsakdfj_class instanceMethodForSelector:initSelector];
        iconView = initFunc(instance, initSelector, frame, 0);
    }

    if (!iconView) {
        NSLog(@"[WizardBypass] Failed to create Pajdsakdfj icon");
        return;
    }

    NSLog(@"[WizardBypass] Created Pajdsakdfj icon: %@", iconView);

    // Step 3: Wire icon -> controller by finding ABVJSMGADJS ivar on Pajdsakdfj
    // Pajdsakdfj's ivars were listed in class_analysis. We need to find which one references ABVJSMGADJS
    // From properties: Pajdsakdfj has the same ivars as Wksahfnasj including object references
    NSLog(@"[WizardBypass] Dumping Pajdsakdfj ivars to find controller ref:");
    unsigned int pajIvarCount;
    Ivar *pajIvars = class_copyIvarList(pajdsakdfj_class, &pajIvarCount);
    NSLog(@"[WizardBypass] Pajdsakdfj has %d ivars", pajIvarCount);
    for (unsigned int i = 0; i < pajIvarCount; i++) {
        const char *name = ivar_getName(pajIvars[i]);
        const char *type = ivar_getTypeEncoding(pajIvars[i]);
        NSLog(@"[WizardBypass]   ivar[%d]: %s (type: %s)", i, name, type);

        // If this ivar is of type ABVJSMGADJS, set our controller on it
        if (wizardController && type && strstr(type, "ABVJSMGADJS")) {
            NSLog(@"[WizardBypass] *** FOUND ABVJSMGADJS ivar: %s - setting controller! ***", name);
            object_setIvar(iconView, pajIvars[i], wizardController);
        }
    }
    free(pajIvars);

    // Step 4: Wire controller -> icon by setting the icon reference on ABVJSMGADJS
    if (wizardController) {
        unsigned int ctrlIvarCount;
        Ivar *ctrlIvars = class_copyIvarList(abvjsmgadjs_class, &ctrlIvarCount);
        BOOL setOne = NO;
        for (unsigned int i = 0; i < ctrlIvarCount; i++) {
            const char *name = ivar_getName(ctrlIvars[i]);
            const char *type = ivar_getTypeEncoding(ctrlIvars[i]);
            // Set the first Pajdsakdfj ivar to our icon
            if (type && strstr(type, "Pajdsakdfj") && !setOne) {
                NSLog(@"[WizardBypass] *** Setting ABVJSMGADJS::%s = our Pajdsakdfj icon ***", name);
                object_setIvar(wizardController, ctrlIvars[i], iconView);
                setOne = YES;
            }
        }
        free(ctrlIvars);
    }

    // Step 5: Force frame, visibility, and appearance
    [iconView setFrame:frame];
    [iconView setHidden:NO];
    [iconView setAlpha:1.0];
    [iconView setUserInteractionEnabled:YES];

    // Fix the _Vmasfisahf UIImageView (icon image)
    Ivar imageViewIvar = class_getInstanceVariable(pajdsakdfj_class, "_Vmasfisahf");
    if (imageViewIvar) {
        UIImageView* existingImageView = object_getIvar(iconView, imageViewIvar);
        if (!existingImageView || [(UIView*)existingImageView frame].size.width == 0) {
            UIImageView* imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 60, 60)];

            UIGraphicsBeginImageContextWithOptions(CGSizeMake(60, 60), NO, 0.0);
            CGContextRef ctx = UIGraphicsGetCurrentContext();
            CGContextSetFillColorWithColor(ctx, [UIColor colorWithRed:0.5 green:0.0 blue:0.8 alpha:1.0].CGColor);
            CGContextFillEllipseInRect(ctx, CGRectMake(0, 0, 60, 60));
            CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
            NSDictionary* attrs = @{
                NSFontAttributeName: [UIFont boldSystemFontOfSize:28],
                NSForegroundColorAttributeName: [UIColor whiteColor]
            };
            [@"W" drawInRect:CGRectMake(16, 12, 30, 40) withAttributes:attrs];
            UIImage* iconImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();

            imageView.image = iconImage;
            imageView.contentMode = UIViewContentModeScaleAspectFit;
            object_setIvar(iconView, imageViewIvar, imageView);
            [iconView addSubview:imageView];
            NSLog(@"[WizardBypass] Created and set icon image");
        } else {
            existingImageView.hidden = NO;
            existingImageView.alpha = 1.0;
            if (existingImageView.frame.size.width == 0) {
                existingImageView.frame = CGRectMake(0, 0, 60, 60);
            }
        }
    }

    [iconView setBackgroundColor:[UIColor colorWithRed:0.5 green:0.0 blue:0.8 alpha:0.8]];
    ((UIView*)iconView).layer.cornerRadius = 30;
    ((UIView*)iconView).clipsToBounds = YES;

    // Step 6: Hook didTapIconView to call ABVJSMGADJS methods before original
    SEL tapSelector = NSSelectorFromString(@"didTapIconView");
    Method tapMethod = class_getInstanceMethod(pajdsakdfj_class, tapSelector);
    if (tapMethod) {
        IMP originalTap = method_getImplementation(tapMethod);
        IMP newTap = imp_implementationWithBlock(^(id self) {
            NSLog(@"[WizardBypass] ========================================");
            NSLog(@"[WizardBypass] didTapIconView CALLED");
            NSLog(@"[WizardBypass] ========================================");

            // Dump ALL ivars on self (Pajdsakdfj) to see current state
            unsigned int ivCount;
            Ivar *ivs = class_copyIvarList([self class], &ivCount);
            for (unsigned int i = 0; i < ivCount; i++) {
                const char *nm = ivar_getName(ivs[i]);
                const char *tp = ivar_getTypeEncoding(ivs[i]);
                if (tp && tp[0] == '@') {
                    id val = object_getIvar(self, ivs[i]);
                    NSLog(@"[WizardBypass] PAJD ivar %s (%s) = %@", nm, tp, val);
                } else if (tp && (tp[0] == 'c' || tp[0] == 'B')) {
                    ptrdiff_t offset = ivar_getOffset(ivs[i]);
                    BOOL val = *(BOOL *)((char *)(__bridge void *)self + offset);
                    NSLog(@"[WizardBypass] PAJD ivar %s (%s) = %d", nm, tp, val);
                } else if (tp && (tp[0] == 'i' || tp[0] == 'q' || tp[0] == 'l' || tp[0] == 'I' || tp[0] == 'Q')) {
                    ptrdiff_t offset = ivar_getOffset(ivs[i]);
                    long val = *(long *)((char *)(__bridge void *)self + offset);
                    NSLog(@"[WizardBypass] PAJD ivar %s (%s) = %ld", nm, tp, val);
                }
            }
            free(ivs);

            // Try calling ABVJSMGADJS methods if we have a controller ref
            // Search for any ivar of type ABVJSMGADJS on self
            unsigned int ivCount2;
            Ivar *ivs2 = class_copyIvarList([self class], &ivCount2);
            for (unsigned int i = 0; i < ivCount2; i++) {
                const char *tp = ivar_getTypeEncoding(ivs2[i]);
                if (tp && strstr(tp, "ABVJSMGADJS")) {
                    id ctrl = object_getIvar(self, ivs2[i]);
                    if (ctrl) {
                        NSLog(@"[WizardBypass] Found ABVJSMGADJS controller: %@", ctrl);
                        // Try calling its setup methods
                        SEL padsgfn = sel_registerName("PADSGFNDSAHJ");
                        if ([ctrl respondsToSelector:padsgfn]) {
                            NSLog(@"[WizardBypass] Calling ABVJSMGADJS::PADSGFNDSAHJ...");
                            ((void (*)(id, SEL))objc_msgSend)(ctrl, padsgfn);
                        }
                    }
                }
            }
            free(ivs2);

            // Call original didTapIconView
            NSLog(@"[WizardBypass] Calling ORIGINAL didTapIconView...");
            typedef void (*OrigFunc)(id, SEL);
            ((OrigFunc)originalTap)(self, tapSelector);
            NSLog(@"[WizardBypass] Original didTapIconView RETURNED");

            // Check if menu was created
            Ivar menuIvar = class_getInstanceVariable([self class], "_jdsghadurewmf");
            if (menuIvar) {
                id menuRef = object_getIvar(self, menuIvar);
                NSLog(@"[WizardBypass] _jdsghadurewmf (menu) after tap: %@", menuRef);
            }
        });
        method_setImplementation(tapMethod, newTap);
        NSLog(@"[WizardBypass] didTapIconView hook installed");
    }

    // Step 7: Add to window
    [keyWindow addSubview:iconView];
    [keyWindow bringSubviewToFront:iconView];
    NSLog(@"[WizardBypass] Added Wizard icon to window at frame: %@", NSStringFromCGRect(frame));

    // Step 8: Also try calling ABVJSMGADJS setup methods
    if (wizardController) {
        NSLog(@"[WizardBypass] Trying ABVJSMGADJS setup methods...");
        SEL padsgfn = sel_registerName("PADSGFNDSAHJ");
        SEL ikafhf = sel_registerName("IKAFHFDSAJ");
        SEL asfga = sel_registerName("ASFGAHJFAHS");
        SEL mdhsa = sel_registerName("MdhsaJFSAJ");

        if ([wizardController respondsToSelector:padsgfn]) {
            NSLog(@"[WizardBypass] Calling PADSGFNDSAHJ...");
            ((void (*)(id, SEL))objc_msgSend)(wizardController, padsgfn);
        }
        if ([wizardController respondsToSelector:ikafhf]) {
            NSLog(@"[WizardBypass] Calling IKAFHFDSAJ...");
            ((void (*)(id, SEL))objc_msgSend)(wizardController, ikafhf);
        }
        if ([wizardController respondsToSelector:asfga]) {
            NSLog(@"[WizardBypass] Calling ASFGAHJFAHS...");
            ((void (*)(id, SEL))objc_msgSend)(wizardController, asfga);
        }
        if ([wizardController respondsToSelector:mdhsa]) {
            NSLog(@"[WizardBypass] Calling MdhsaJFSAJ...");
            ((void (*)(id, SEL))objc_msgSend)(wizardController, mdhsa);
        }
    }

    NSLog(@"[WizardBypass] PHASE 8 COMPLETE");
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
