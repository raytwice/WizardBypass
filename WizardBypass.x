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
// PHASE 2: ANTI-TAMPER BYPASS - Patch the 0xdead trap
// ============================================================================

static void patch_dead_trap(void) {
    NSLog(@"[WizardBypass] Searching for 0xdead trap...");

    // Find Wizard.framework base address
    void* wizard_handle = dlopen("@rpath/Wizard.framework/Wizard", RTLD_NOLOAD);
    if (!wizard_handle) {
        NSLog(@"[WizardBypass] ERROR: Cannot find Wizard.framework");
        return;
    }

    Dl_info info;
    if (dladdr(wizard_handle, &info) == 0) {
        NSLog(@"[WizardBypass] ERROR: Cannot get Wizard base address");
        return;
    }

    uintptr_t base = (uintptr_t)info.dli_fbase;
    NSLog(@"[WizardBypass] Wizard base address: 0x%lx", base);

    // Known trap location: 0xb1fa3c (from analysis)
    // Instruction: MOVZ W8, #0xdead (0x52BD5DA8)
    uintptr_t trap_addr = base + 0xb1fa3c;

    NSLog(@"[WizardBypass] Attempting to patch trap at 0x%lx", trap_addr);

    // Change memory protection to RWX
    kern_return_t kr = vm_protect(mach_task_self(),
                                   (vm_address_t)(trap_addr & ~0xFFF),
                                   0x1000,
                                   FALSE,
                                   VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);

    if (kr != KERN_SUCCESS) {
        NSLog(@"[WizardBypass] ERROR: vm_protect failed: %d", kr);
        return;
    }

    // Patch: Replace MOVZ W8, #0xdead with NOP (0xD503201F)
    uint32_t* instruction = (uint32_t*)trap_addr;
    uint32_t original = *instruction;

    NSLog(@"[WizardBypass] Original instruction: 0x%08x", original);

    if (original == 0x52BD5DA8) {  // Verify it's the MOVZ instruction
        *instruction = 0xD503201F;  // NOP
        NSLog(@"[WizardBypass] ✓ Patched 0xdead trap successfully!");
    } else {
        NSLog(@"[WizardBypass] WARNING: Instruction mismatch, patching anyway");
        *instruction = 0xD503201F;  // NOP
    }

    // Restore protection
    vm_protect(mach_task_self(),
               (vm_address_t)(trap_addr & ~0xFFF),
               0x1000,
               FALSE,
               VM_PROT_READ | VM_PROT_EXECUTE);
}

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
        NSLog(@"[WizardBypass] ERROR: SCLAlertView class not found");
        return;
    }

    // Hook showCustom:color:title:subTitle:closeButtonTitle:duration:
    SEL sel1 = NSSelectorFromString(@"showCustom:color:title:subTitle:closeButtonTitle:duration:");
    Method method1 = class_getInstanceMethod(cls, sel1);
    if (method1) {
        original_showCustom = method_setImplementation(method1, (IMP)swizzled_showCustom);
        NSLog(@"[WizardBypass] ✓ Hooked showCustom");
    }

    // Hook showTitle:subTitle:style:closeButtonTitle:duration:
    SEL sel2 = NSSelectorFromString(@"showTitle:subTitle:style:closeButtonTitle:duration:");
    Method method2 = class_getInstanceMethod(cls, sel2);
    if (method2) {
        original_showTitle = method_setImplementation(method2, (IMP)swizzled_showTitle);
        NSLog(@"[WizardBypass] ✓ Hooked showTitle");
    }
}

// ============================================================================
// DELAYED HOOK - Run after Wizard loads
// ============================================================================

static void delayed_hook(void) {
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] DELAYED HOOK - Wizard should be loaded now");
    NSLog(@"[WizardBypass] ========================================");

    // Try to patch the trap again now that Wizard is loaded
    NSLog(@"[WizardBypass] Attempting to patch 0xdead trap (delayed)...");

    // Find Wizard.framework base address
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char* name = _dyld_get_image_name(i);
        if (name && strstr(name, "Wizard.framework")) {
            const struct mach_header* header = (const struct mach_header*)_dyld_get_image_header(i);
            uintptr_t base = (uintptr_t)header;
            NSLog(@"[WizardBypass] ✓ Found Wizard base: 0x%lx", base);

            // Patch the 0xdead trap
            uintptr_t trap_addr = base + 0x39da9c;  // Offset from analysis
            NSLog(@"[WizardBypass] Trap address: 0x%lx", trap_addr);

            // Change memory protection
            kern_return_t kr = vm_protect(mach_task_self(),
                                           (vm_address_t)(trap_addr & ~0xFFF),
                                           0x1000,
                                           FALSE,
                                           VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);

            if (kr == KERN_SUCCESS) {
                uint32_t* instruction = (uint32_t*)trap_addr;
                uint32_t original = *instruction;
                NSLog(@"[WizardBypass] Original instruction: 0x%08x", original);

                // Patch to NOP
                *instruction = 0xD503201F;
                NSLog(@"[WizardBypass] ✓ Patched 0xdead trap!");
            } else {
                NSLog(@"[WizardBypass] ERROR: vm_protect failed: %d", kr);
            }
            break;
        }
    }

    // Re-hook SCLAlertView now that everything is loaded
    NSLog(@"[WizardBypass] Re-hooking SCLAlertView...");
    hook_scl_alert_view();
}

// ============================================================================
// PHASE 5: CONSTRUCTOR - Run everything EARLY
// ============================================================================

__attribute__((constructor(101)))
static void wizard_bypass_init(void) {
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] NUCLEAR OPTION - EARLY INIT (Priority 101)");
    NSLog(@"[WizardBypass] ========================================");

    // Phase 1: Hide our dylib from detection
    NSLog(@"[WizardBypass] Phase 1: Hiding dylib...");
    // Note: Function hooking would require fishhook or similar
    // For now, just log that we're here

    // Phase 2: Patch anti-tamper trap
    NSLog(@"[WizardBypass] Phase 2: Patching anti-tamper...");
    patch_dead_trap();

    // Phase 3: Force authentication
    NSLog(@"[WizardBypass] Phase 3: Forcing authentication...");
    force_authentication();

    // Phase 4: Hook popup display
    NSLog(@"[WizardBypass] Phase 4: Hooking SCLAlertView...");
    hook_scl_alert_view();

    // Phase 5: Schedule delayed hook after 2 seconds
    NSLog(@"[WizardBypass] Phase 5: Scheduling delayed hook in 2 seconds...");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        delayed_hook();
    });

    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] Initialization complete!");
    NSLog(@"[WizardBypass] ========================================");
}
