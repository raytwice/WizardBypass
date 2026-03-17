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
// GLOBAL: Wizard controller reference accessible from didTapIconView
// Since Pajdsakdfj has 0 ivars, we use a global to bridge the gap
// ============================================================================
static id g_wizardController = nil;
static id g_wizardIcon = nil;

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
    // Now we know: ABVJSMGADJS has 7 object ivars (no BOOLs), 4 void methods
    // Pajdsakdfj has 0 ivars — didTapIconView uses unknown mechanism
    // Solution: use global g_wizardController + fully replace didTapIconView
    // ========================================
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] PHASE 7: SETTING UP ABVJSMGADJS CONTROLLER");
    NSLog(@"[WizardBypass] ========================================");

    Class abvjsmgadjs_class = objc_getClass("ABVJSMGADJS");
    if (!abvjsmgadjs_class) {
        NSLog(@"[WizardBypass] FATAL: ABVJSMGADJS class not found!");
        return;
    }

    // Create the controller and store in global
    g_wizardController = [[abvjsmgadjs_class alloc] init];
    NSLog(@"[WizardBypass] Created ABVJSMGADJS controller: %@ (stored in g_wizardController)", g_wizardController);

    // ========================================
    // PHASE 8: CREATE ICON + FULLY REPLACE didTapIconView
    // ========================================
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] PHASE 8: CREATING ICON + MENU TOGGLE");
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

    // Create Pajdsakdfj icon
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
    g_wizardIcon = iconView;

    // Wire controller -> icon (set first Pajdsakdfj ivar on controller)
    unsigned int ctrlIvarCount;
    Ivar *ctrlIvars = class_copyIvarList(abvjsmgadjs_class, &ctrlIvarCount);
    for (unsigned int i = 0; i < ctrlIvarCount; i++) {
        const char *type = ivar_getTypeEncoding(ctrlIvars[i]);
        const char *name = ivar_getName(ctrlIvars[i]);
        if (type && strstr(type, "Pajdsakdfj")) {
            NSLog(@"[WizardBypass] Setting ABVJSMGADJS::%s = icon", name);
            object_setIvar(g_wizardController, ctrlIvars[i], iconView);
            break; // Set first one only
        }
    }
    free(ctrlIvars);

    // Call PADSGFNDSAHJ to let it do icon setup
    NSLog(@"[WizardBypass] Calling PADSGFNDSAHJ (icon setup)...");
    SEL padsgfn = sel_registerName("PADSGFNDSAHJ");
    ((void (*)(id, SEL))objc_msgSend)(g_wizardController, padsgfn);

    // Check if menu was created by PADSGFNDSAHJ
    Ivar menuIvar = class_getInstanceVariable(abvjsmgadjs_class, "_jdsghadurewmf");
    id menuAfterSetup = menuIvar ? object_getIvar(g_wizardController, menuIvar) : nil;
    NSLog(@"[WizardBypass] Menu (_jdsghadurewmf) after PADSGFNDSAHJ: %@", menuAfterSetup);

    // Call full chain: IKAFHFDSAJ -> ASFGAHJFAHS -> MdhsaJFSAJ
    NSLog(@"[WizardBypass] Calling IKAFHFDSAJ (full setup chain)...");
    SEL ikafhf = sel_registerName("IKAFHFDSAJ");
    ((void (*)(id, SEL))objc_msgSend)(g_wizardController, ikafhf);

    // Check menu again
    menuAfterSetup = menuIvar ? object_getIvar(g_wizardController, menuIvar) : nil;
    NSLog(@"[WizardBypass] Menu after IKAFHFDSAJ: %@", menuAfterSetup);

    // Set up icon appearance
    [iconView setFrame:frame];
    [iconView setHidden:NO];
    [iconView setAlpha:1.0];
    [iconView setUserInteractionEnabled:YES];
    [iconView setBackgroundColor:[UIColor colorWithRed:0.5 green:0.0 blue:0.8 alpha:0.8]];
    ((UIView*)iconView).layer.cornerRadius = 30;
    ((UIView*)iconView).clipsToBounds = YES;

    // Fix icon image
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
            UIImage* img = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            imageView.image = img;
            object_setIvar(iconView, imageViewIvar, imageView);
            [iconView addSubview:imageView];
        }
    }

    // ========================================
    // FULLY REPLACE didTapIconView
    // Original can't find controller (0 ivars). We use g_wizardController.
    // ========================================
    SEL tapSelector = NSSelectorFromString(@"didTapIconView");
    Method tapMethod = class_getInstanceMethod(pajdsakdfj_class, tapSelector);
    if (tapMethod) {
        IMP newTap = imp_implementationWithBlock(^(id self) {
            NSLog(@"[WizardBypass] ========================================");
            NSLog(@"[WizardBypass] TAP! Using g_wizardController to toggle menu");
            NSLog(@"[WizardBypass] ========================================");

            if (!g_wizardController) {
                NSLog(@"[WizardBypass] ERROR: g_wizardController is nil!");
                return;
            }

            // Get menu ivar from controller
            Class ctrlClass = [g_wizardController class];
            Ivar mIvar = class_getInstanceVariable(ctrlClass, "_jdsghadurewmf");
            id menu = mIvar ? object_getIvar(g_wizardController, mIvar) : nil;
            NSLog(@"[WizardBypass] Current menu: %@", menu);

            if (menu) {
                // Menu exists - toggle visibility
                BOOL isHidden = [(UIView*)menu isHidden];
                NSLog(@"[WizardBypass] Menu exists, isHidden=%d, toggling...", isHidden);
                [(UIView*)menu setHidden:!isHidden];
                if (isHidden) {
                    [(UIView*)menu setAlpha:1.0];
                    UIWindow* w = [(UIView*)menu window];
                    if (w) [w bringSubviewToFront:menu];
                }
                return;
            }

            // Menu doesn't exist - try to create it
            NSLog(@"[WizardBypass] Menu is nil, attempting to create Wksahfnasj...");

            Class menuClass = objc_getClass("Wksahfnasj");
            if (!menuClass) {
                NSLog(@"[WizardBypass] Wksahfnasj class not found!");
                return;
            }

            // Get the key window
            UIWindow* kw = nil;
            NSArray* wins = [[UIApplication sharedApplication] windows];
            for (UIWindow* w in wins) {
                if (w.isKeyWindow) { kw = w; break; }
            }
            if (!kw && [wins count] > 0) kw = [wins objectAtIndex:0];

            if (!kw) {
                NSLog(@"[WizardBypass] No window for menu!");
                return;
            }

            // Try initWithFrame: for the menu (full screen)
            CGRect menuFrame = kw.bounds;
            NSLog(@"[WizardBypass] Creating Wksahfnasj with frame: %@", NSStringFromCGRect(menuFrame));

            @try {
                id newMenu = [[menuClass alloc] initWithFrame:menuFrame];
                if (newMenu) {
                    NSLog(@"[WizardBypass] Wksahfnasj created: %@", newMenu);

                    // Wire it: set AJFADSHFSAJXN (Metal renderer) if needed
                    // Set it on the controller
                    if (mIvar) {
                        object_setIvar(g_wizardController, mIvar, newMenu);
                        NSLog(@"[WizardBypass] Set menu on controller");
                    }

                    // Also set the controller ref on menu (paJFSAUJJFSAC ivar)
                    Class ajfClass = objc_getClass("AJFADSHFSAJXN");
                    Ivar menuCtrlIvar = class_getInstanceVariable(menuClass, "_paJFSAUJJFSAC");
                    if (menuCtrlIvar) {
                        NSLog(@"[WizardBypass] Wksahfnasj has _paJFSAUJJFSAC ivar");
                        // It expects AJFADSHFSAJXN, not ABVJSMGADJS
                    }

                    // Dump Wksahfnasj ivars to see what it has
                    unsigned int wkIvarCount;
                    Ivar *wkIvars = class_copyIvarList(menuClass, &wkIvarCount);
                    NSLog(@"[WizardBypass] Wksahfnasj has %d ivars:", wkIvarCount);
                    for (unsigned int i = 0; i < wkIvarCount; i++) {
                        const char *nm = ivar_getName(wkIvars[i]);
                        const char *tp = ivar_getTypeEncoding(wkIvars[i]);
                        id val = nil;
                        if (tp && tp[0] == '@') val = object_getIvar(newMenu, wkIvars[i]);
                        NSLog(@"[WizardBypass]   %s (%s) = %@", nm, tp, val);
                    }
                    free(wkIvars);

                    // Try to set up MTKView if needed
                    Ivar mtkIvar = class_getInstanceVariable(menuClass, "_pPfuasjrasfh");
                    if (mtkIvar) {
                        id mtkView = object_getIvar(newMenu, mtkIvar);
                        NSLog(@"[WizardBypass] _pPfuasjrasfh (MTKView): %@", mtkView);
                    }

                    // Add to window
                    [(UIView*)newMenu setHidden:NO];
                    [(UIView*)newMenu setAlpha:1.0];
                    [kw addSubview:newMenu];
                    [kw bringSubviewToFront:newMenu];
                    NSLog(@"[WizardBypass] Added menu to window!");

                    // Try calling Wksahfnasj setup methods
                    SEL paDJSAFBSANC = sel_registerName("paDJSAFBSANC");
                    if ([newMenu respondsToSelector:paDJSAFBSANC]) {
                        NSLog(@"[WizardBypass] Calling Wksahfnasj::paDJSAFBSANC...");
                        @try {
                            ((void (*)(id, SEL))objc_msgSend)(newMenu, paDJSAFBSANC);
                            NSLog(@"[WizardBypass] paDJSAFBSANC returned!");
                        } @catch (NSException *e) {
                            NSLog(@"[WizardBypass] paDJSAFBSANC exception: %@", e);
                        }
                    }
                } else {
                    NSLog(@"[WizardBypass] Wksahfnasj initWithFrame: returned nil!");
                }
            } @catch (NSException *exception) {
                NSLog(@"[WizardBypass] Exception creating Wksahfnasj: %@", exception);
            }
        });
        method_setImplementation(tapMethod, newTap);
        NSLog(@"[WizardBypass] didTapIconView FULLY REPLACED (uses g_wizardController)");
    }

    // Add icon to window
    [keyWindow addSubview:iconView];
    [keyWindow bringSubviewToFront:iconView];
    NSLog(@"[WizardBypass] Icon added to window at %@", NSStringFromCGRect(frame));

    // Final menu state check
    id finalMenu = menuIvar ? object_getIvar(g_wizardController, menuIvar) : nil;
    NSLog(@"[WizardBypass] === FINAL STATE ===");
    NSLog(@"[WizardBypass] g_wizardController: %@", g_wizardController);
    NSLog(@"[WizardBypass] g_wizardIcon: %@", g_wizardIcon);
    NSLog(@"[WizardBypass] Menu (_jdsghadurewmf): %@", finalMenu);
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
