// Wizard Authentication Bypass - NUCLEAR OPTION
// No CydiaSubstrate - Pure C/Objective-C runtime manipulation

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
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

        // SPECIAL: Hook init methods for key obfuscated classes
        if (strcmp(class_name, "Pajdsakdfj") == 0 || strcmp(class_name, "Wksahfnasj") == 0) {
            NSLog(@"[WizardBypass] *** FOUND KEY CLASS: %s - Hooking ALL methods ***", class_name);

            unsigned int all_method_count;
            Method* all_methods = class_copyMethodList(classes[i], &all_method_count);

            for (unsigned int k = 0; k < all_method_count; k++) {
                SEL sel = method_getName(all_methods[k]);
                const char* method_name = sel_getName(sel);

                NSLog(@"[WizardBypass]   Method: %s::%s", class_name, method_name);

                // Hook ALL methods to log when they're called
                IMP original = method_getImplementation(all_methods[k]);
                IMP new_imp = imp_implementationWithBlock(^id(id self, ...) {
                    NSLog(@"[WizardBypass] *** CALLED: %s::%s ***", class_name, method_name);

                    // Call original
                    typedef id (*OrigFunc)(id, SEL, ...);
                    return ((OrigFunc)original)(self, sel);
                });
                method_setImplementation(all_methods[k], new_imp);
            }

            free(all_methods);
        }

        unsigned int method_count;
        Method* methods = class_copyMethodList(classes[i], &method_count);

        for (unsigned int j = 0; j < method_count; j++) {
            SEL selector = method_getName(methods[j]);
            const char* name = sel_getName(selector);
            char* type_encoding = method_copyReturnType(methods[j]);

            // Skip lifecycle methods
            if (strncmp(name, "init", 4) == 0 ||
                strncmp(name, "set", 3) == 0 ||
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

    // FORCE CREATE WIZARD UI - Manually instantiate the floating icon
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] FORCE CREATING WIZARD UI");
    NSLog(@"[WizardBypass] ========================================");

    Class pajdsakdfj_class = objc_getClass("Pajdsakdfj");
    if (pajdsakdfj_class) {
        NSLog(@"[WizardBypass] Found Pajdsakdfj class, creating instance...");

        // HOOK didTapIconView to force menu display
        SEL tapSelector = NSSelectorFromString(@"didTapIconView");
        Method tapMethod = class_getInstanceMethod(pajdsakdfj_class, tapSelector);
        if (tapMethod) {
            NSLog(@"[WizardBypass] Hooking didTapIconView to force menu display");
            IMP originalTap = method_getImplementation(tapMethod);
            IMP newTap = imp_implementationWithBlock(^(id self) {
                NSLog(@"[WizardBypass] 🔵 didTapIconView CALLED - forcing menu display");

                // Call original first to see what happens
                typedef void (*OrigFunc)(id, SEL);
                ((OrigFunc)originalTap)(self, tapSelector);
                NSLog(@"[WizardBypass] Original didTapIconView completed");

                // Now try to manually show the menu
                NSLog(@"[WizardBypass] Attempting to show menu manually...");

                // Look for Wksahfnasj class (likely the menu controller)
                Class menuClass = objc_getClass("Wksahfnasj");
                if (menuClass) {
                    NSLog(@"[WizardBypass] Found Wksahfnasj (menu class)");

                    // Try to create and show menu
                    id menuInstance = [[menuClass alloc] init];
                    if (menuInstance) {
                        NSLog(@"[WizardBypass] Created menu instance: %@", menuInstance);

                        // Try common show methods
                        SEL showSel = NSSelectorFromString(@"show");
                        if ([menuInstance respondsToSelector:showSel]) {
                            NSLog(@"[WizardBypass] Calling show method");
                            ((void (*)(id, SEL))objc_msgSend)(menuInstance, showSel);
                        }

                        SEL presentSel = NSSelectorFromString(@"present");
                        if ([menuInstance respondsToSelector:presentSel]) {
                            NSLog(@"[WizardBypass] Calling present method");
                            ((void (*)(id, SEL))objc_msgSend)(menuInstance, presentSel);
                        }
                    }
                } else {
                    NSLog(@"[WizardBypass] Wksahfnasj class not found, searching for menu classes...");

                    // Search for any class that might be the menu
                    unsigned int classCount;
                    Class *allClasses = objc_copyClassList(&classCount);
                    for (unsigned int i = 0; i < classCount; i++) {
                        const char* className = class_getName(allClasses[i]);
                        const char* imageName = class_getImageName(allClasses[i]);

                        if (imageName && strstr(imageName, "Wizard.framework")) {
                            // Look for classes with "menu", "view", "controller" in methods
                            unsigned int methodCount;
                            Method *methods = class_copyMethodList(allClasses[i], &methodCount);
                            for (unsigned int j = 0; j < methodCount; j++) {
                                const char* methodName = sel_getName(method_getName(methods[j]));
                                if (strcasestr(methodName, "menu") || strcasestr(methodName, "show") || strcasestr(methodName, "present")) {
                                    NSLog(@"[WizardBypass] Found potential menu class: %s with method: %s", className, methodName);
                                }
                            }
                            free(methods);
                        }
                    }
                    free(allClasses);
                }
            });
            method_setImplementation(tapMethod, newTap);
            NSLog(@"[WizardBypass] ✓ didTapIconView hook installed");
        } else {
            NSLog(@"[WizardBypass] WARNING: didTapIconView method not found");
        }

        // Get the main window (iOS 13+ compatible)
        UIWindow* keyWindow = nil;
        NSArray* windows = [[UIApplication sharedApplication] windows];
        for (UIWindow* window in windows) {
            if (window.isKeyWindow) {
                keyWindow = window;
                break;
            }
        }

        // Fallback to first window
        if (!keyWindow && [windows count] > 0) {
            keyWindow = [windows objectAtIndex:0];
        }

        if (keyWindow) {
            NSLog(@"[WizardBypass] Got key window: %@", keyWindow);

            // Create frame for floating icon (top-right corner)
            CGRect frame = CGRectMake(keyWindow.bounds.size.width - 80, 100, 60, 60);

            // Try to call initWithFrame:type:
            SEL initSelector = NSSelectorFromString(@"initWithFrame:type:");
            if ([pajdsakdfj_class instancesRespondToSelector:initSelector]) {
                NSLog(@"[WizardBypass] Calling initWithFrame:type:");

                // Allocate instance
                id instance = [[pajdsakdfj_class alloc] init];

                // Call initWithFrame:type: with type = 0
                typedef id (*InitFunc)(id, SEL, CGRect, NSInteger);
                InitFunc initFunc = (InitFunc)[pajdsakdfj_class instanceMethodForSelector:initSelector];
                id iconView = initFunc(instance, initSelector, frame, 0);

                if (iconView) {
                    NSLog(@"[WizardBypass] ✓✓✓ Created Wizard icon view: %@", iconView);

                    // Force set the frame (it was set to 0,0,0,0 by init)
                    [iconView setFrame:frame];
                    [iconView setHidden:NO];
                    [iconView setAlpha:1.0];
                    [iconView setUserInteractionEnabled:YES];

                    NSLog(@"[WizardBypass] Set frame to: %@", NSStringFromCGRect(frame));

                    // CRITICAL: Manually populate the _Vmasfisahf UIImageView ivar
                    // This is what initWithFrame:type: doesn't do without valid auth
                    NSLog(@"[WizardBypass] Forcing icon image population...");

                    // Get the _Vmasfisahf ivar (UIImageView)
                    Ivar imageViewIvar = class_getInstanceVariable(pajdsakdfj_class, "_Vmasfisahf");
                    if (imageViewIvar) {
                        NSLog(@"[WizardBypass] Found _Vmasfisahf ivar");

                        // Get current value
                        UIImageView* existingImageView = object_getIvar(iconView, imageViewIvar);
                        NSLog(@"[WizardBypass] Current _Vmasfisahf: %@", existingImageView);

                        if (!existingImageView) {
                            // Create a UIImageView with a colored circle as placeholder
                            UIImageView* imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 60, 60)];

                            // Create a simple colored circle image
                            UIGraphicsBeginImageContextWithOptions(CGSizeMake(60, 60), NO, 0.0);
                            CGContextRef ctx = UIGraphicsGetCurrentContext();

                            // Draw a purple circle (Wizard's color)
                            CGContextSetFillColorWithColor(ctx, [UIColor colorWithRed:0.5 green:0.0 blue:0.8 alpha:1.0].CGColor);
                            CGContextFillEllipseInRect(ctx, CGRectMake(5, 5, 50, 50));

                            // Draw a white "W" in the center
                            CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
                            NSDictionary* attrs = @{
                                NSFontAttributeName: [UIFont boldSystemFontOfSize:30],
                                NSForegroundColorAttributeName: [UIColor whiteColor]
                            };
                            [@"W" drawInRect:CGRectMake(15, 10, 30, 40) withAttributes:attrs];

                            UIImage* iconImage = UIGraphicsGetImageFromCurrentImageContext();
                            UIGraphicsEndImageContext();

                            imageView.image = iconImage;
                            imageView.contentMode = UIViewContentModeScaleAspectFit;

                            // Set the ivar
                            object_setIvar(iconView, imageViewIvar, imageView);
                            NSLog(@"[WizardBypass] ✓ Created and set _Vmasfisahf UIImageView");

                            // Add as subview
                            [iconView addSubview:imageView];
                            NSLog(@"[WizardBypass] ✓ Added imageView as subview");
                        } else {
                            NSLog(@"[WizardBypass] _Vmasfisahf already exists, ensuring it's visible");
                            existingImageView.hidden = NO;
                            existingImageView.alpha = 1.0;
                        }
                    } else {
                        NSLog(@"[WizardBypass] WARNING: _Vmasfisahf ivar not found");
                    }

                    // Set background color to make it visible even without image
                    [iconView setBackgroundColor:[UIColor colorWithRed:0.5 green:0.0 blue:0.8 alpha:0.8]];
                    [(UIView*)iconView setClipsToBounds:NO];

                    // Make it round
                    ((UIView*)iconView).layer.cornerRadius = 30;

                    // Add to window
                    [keyWindow addSubview:iconView];
                    [keyWindow bringSubviewToFront:iconView];

                    NSLog(@"[WizardBypass] ✓✓✓ Added Wizard icon to window!");
                    NSLog(@"[WizardBypass] Final frame: %@", NSStringFromCGRect([iconView frame]));
                    NSLog(@"[WizardBypass] Subviews: %@", [(UIView*)iconView subviews]);
                } else {
                    NSLog(@"[WizardBypass] Failed to create icon view");
                }
            } else {
                NSLog(@"[WizardBypass] initWithFrame:type: not found, trying initWithFrame:");

                SEL initFrameSelector = NSSelectorFromString(@"initWithFrame:");
                if ([pajdsakdfj_class instancesRespondToSelector:initFrameSelector]) {
                    id iconView = [[pajdsakdfj_class alloc] initWithFrame:frame];
                    if (iconView) {
                        NSLog(@"[WizardBypass] ✓✓✓ Created Wizard icon view: %@", iconView);
                        [keyWindow addSubview:iconView];
                        NSLog(@"[WizardBypass] ✓✓✓ Added Wizard icon to window!");
                    }
                }
            }
        } else {
            NSLog(@"[WizardBypass] ERROR: No key window found");
        }
    } else {
        NSLog(@"[WizardBypass] ERROR: Pajdsakdfj class not found");
    }
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
