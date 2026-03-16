// Wizard Authentication Bypass - NUCLEAR OPTION
// No CydiaSubstrate - Pure C/Objective-C runtime manipulation

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>

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
    NSLog(@"[WizardBypass] Forcing authentication flags...");

    // Try to find and patch authentication-related classes
    const char* auth_classes[] = {
        "ABVJSMGADJS",
        "AJFADSHFSAJXN",
        "Kmsjfaigh",
        "Mjshjgkash",
        "Pajdsakdfj",
        "Wksahfnasj",
        NULL
    };

    for (int i = 0; auth_classes[i] != NULL; i++) {
        Class cls = objc_getClass(auth_classes[i]);
        if (cls) {
            NSLog(@"[WizardBypass] Found auth class: %s", auth_classes[i]);

            // Hook all methods that might set authentication state
            unsigned int method_count;
            Method* methods = class_copyMethodList(cls, &method_count);

            for (unsigned int j = 0; j < method_count; j++) {
                SEL selector = method_getName(methods[j]);
                const char* name = sel_getName(selector);

                // Look for setters that might control auth
                if (strstr(name, "set") || strstr(name, "auth") || strstr(name, "valid")) {
                    NSLog(@"[WizardBypass]   Found potential auth method: %s", name);
                }
            }

            free(methods);
        }
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

            IMP new_imp = imp_implementationWithBlock(^(id self) {
                NSLog(@"[WizardBypass] ========================================");
                NSLog(@"[WizardBypass] ✓✓✓ BLOCKED CRITICAL: %s ✓✓✓", critical_methods[i]);
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

            // Replace with blocking implementation
            IMP new_imp = imp_implementationWithBlock(^(id self) {
                NSLog(@"[WizardBypass] ✓✓✓ BLOCKED SCLAlertView::%s ✓✓✓", name);
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

        // Replace ALL methods with blocking implementation
        IMP new_imp = imp_implementationWithBlock(^id(id self) {
            NSLog(@"[WizardBypass] ✓✓✓ BLOCKED SCLAlertViewShowBuilder::%s ✓✓✓", name);
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

            // Block alert-related view controllers
            if ([className containsString:@"Alert"] || [className containsString:@"SCL"]) {
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

            // Block if it's an alert window
            if ([className containsString:@"Alert"] || [vcClassName containsString:@"Alert"] ||
                [vcClassName containsString:@"SCL"]) {
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

            // Block if it's an alert view
            if ([viewClassName containsString:@"Alert"] || [viewClassName containsString:@"SCL"]) {
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

    NSLog(@"[WizardBypass] Delayed hook complete - all hooks refreshed");
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
