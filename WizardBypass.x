// Wizard Authentication Bypass - Enhanced Version
// Operation ROBUST Implementation
// Uses early constructor, dylib hiding, trap patching, and auth flag hooks

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <mach/vm_map.h>
#import <objc/runtime.h>

// ============================================================================
// STRATEGY 1: EARLY CONSTRUCTOR (Priority 101)
// Runs BEFORE Wizard's constructors to intercept auth early
// ============================================================================

__attribute__((constructor(101)))
static void wizard_bypass_early_init() {
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] EARLY INIT - Priority 101");
    NSLog(@"[WizardBypass] Running BEFORE Wizard constructors");
    NSLog(@"[WizardBypass] ========================================");

    // Log all loaded images to see what's already loaded
    uint32_t count = _dyld_image_count();
    NSLog(@"[WizardBypass] Total dylibs loaded: %u", count);

    for (uint32_t i = 0; i < count; i++) {
        const char* name = _dyld_get_image_name(i);
        if (name && (strstr(name, "Wizard") || strstr(name, "pool"))) {
            NSLog(@"[WizardBypass] Found: %s", name);
        }
    }
}

// ============================================================================
// STRATEGY 2: DYLIB HIDING
// Hide our dylib from Wizard's detection mechanisms
// ============================================================================

%hookf(uint32_t, _dyld_image_count) {
    uint32_t real_count = %orig;

    // Check if WizardBypass is in the list
    BOOL has_bypass = NO;
    for (uint32_t i = 0; i < real_count; i++) {
        const char* name = _dyld_get_image_name(i);
        if (name && strstr(name, "WizardBypass")) {
            has_bypass = YES;
            break;
        }
    }

    if (has_bypass) {
        NSLog(@"[WizardBypass] dyld_image_count: hiding -1 (real: %u)", real_count);
        return real_count - 1;  // Hide our dylib
    }

    return real_count;
}

%hookf(const char*, _dyld_get_image_name, uint32_t index) {
    const char* name = %orig(index);

    if (name && strstr(name, "WizardBypass")) {
        NSLog(@"[WizardBypass] dyld_get_image_name: hiding WizardBypass at index %u", index);
        // Return the next image instead
        return %orig(index + 1);
    }

    return name;
}

%hookf(const struct mach_header*, _dyld_get_image_header, uint32_t index) {
    const char* name = _dyld_get_image_name(index);

    if (name && strstr(name, "WizardBypass")) {
        NSLog(@"[WizardBypass] dyld_get_image_header: hiding WizardBypass");
        // Return the next image's header
        return %orig(index + 1);
    }

    return %orig(index);
}

// ============================================================================
// STRATEGY 3: 0xDEAD TRAP PATCHING
// Patch the anti-tamper trap to prevent crash
// ============================================================================

static void patch_dead_trap() {
    NSLog(@"[WizardBypass] Attempting to patch 0xdead trap...");

    // Find Wizard.framework base address
    uint32_t count = _dyld_image_count();
    const struct mach_header_64* wizard_header = NULL;
    intptr_t wizard_slide = 0;

    for (uint32_t i = 0; i < count; i++) {
        const char* name = _dyld_get_image_name(i);
        if (name && strstr(name, "Wizard.framework/Wizard")) {
            wizard_header = (const struct mach_header_64*)_dyld_get_image_header(i);
            wizard_slide = _dyld_get_image_vmaddr_slide(i);
            NSLog(@"[WizardBypass] Found Wizard at: %p (slide: 0x%lx)", wizard_header, wizard_slide);
            break;
        }
    }

    if (!wizard_header) {
        NSLog(@"[WizardBypass] ERROR: Wizard.framework not found!");
        return;
    }

    // Calculate trap address: base + slide + offset
    // Offset 0x39da9c in __text section (from analysis)
    uintptr_t trap_addr = (uintptr_t)wizard_header + wizard_slide + 0x39da9c;
    NSLog(@"[WizardBypass] Trap address: 0x%lx", trap_addr);

    // Make memory writable
    uintptr_t page_start = trap_addr & ~0xFFF;
    kern_return_t kr = vm_protect(mach_task_self(), page_start, 0x1000, FALSE,
                                   VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);

    if (kr != KERN_SUCCESS) {
        NSLog(@"[WizardBypass] ERROR: vm_protect failed: %d", kr);
        return;
    }

    // Read current instruction
    uint32_t current = *(uint32_t*)trap_addr;
    NSLog(@"[WizardBypass] Current instruction: 0x%08x", current);

    // Patch MOVZ W8, #0xdead to NOP (0x1F2003D5)
    uint32_t nop = 0x1F2003D5;
    *(uint32_t*)trap_addr = nop;

    // Verify patch
    uint32_t patched = *(uint32_t*)trap_addr;
    NSLog(@"[WizardBypass] Patched instruction: 0x%08x", patched);

    // Restore protection
    vm_protect(mach_task_self(), page_start, 0x1000, FALSE,
               VM_PROT_READ | VM_PROT_EXECUTE);

    NSLog(@"[WizardBypass] 0xdead trap patched successfully!");
}

// Call trap patcher in early constructor
__attribute__((constructor(102)))
static void patch_traps() {
    NSLog(@"[WizardBypass] Constructor 102: Patching traps");
    patch_dead_trap();
}

// ============================================================================
// STRATEGY 4: AUTH FLAG HOOKS
// Hook obfuscated classes to force authentication success
// ============================================================================

// SCLAlertView interface
@interface SCLAlertView : UIView
- (void)showCustom:(UIImage *)image color:(UIColor *)color title:(NSString *)title subTitle:(NSString *)subTitle closeButtonTitle:(NSString *)closeButtonTitle duration:(NSTimeInterval)duration;
- (void)showTitle:(NSString *)title subTitle:(NSString *)subTitle style:(NSInteger)style closeButtonTitle:(NSString *)closeButtonTitle duration:(NSTimeInterval)duration;
- (void)addButton:(NSString *)title validationBlock:(BOOL (^)(void))validationBlock actionBlock:(void (^)(void))action;
@end

// Hook all obfuscated classes
%hook ABVJSMGADJS

- (id)init {
    NSLog(@"[WizardBypass] ABVJSMGADJS init");
    id result = %orig;

    // Try to force auth properties
    @try {
        [result setValue:@YES forKey:@"authenticated"];
        [result setValue:@YES forKey:@"isAuthenticated"];
        [result setValue:@YES forKey:@"valid"];
        [result setValue:@YES forKey:@"isValid"];
        NSLog(@"[WizardBypass] Forced auth properties to YES");
    } @catch (NSException *e) {
        NSLog(@"[WizardBypass] Exception setting properties: %@", e);
    }

    return result;
}

- (void)setAuthenticated:(BOOL)authenticated {
    NSLog(@"[WizardBypass] ABVJSMGADJS setAuthenticated: %d -> forcing YES", authenticated);
    %orig(YES);
}

- (BOOL)isAuthenticated {
    NSLog(@"[WizardBypass] ABVJSMGADJS isAuthenticated -> YES");
    return YES;
}

- (BOOL)authenticated {
    NSLog(@"[WizardBypass] ABVJSMGADJS authenticated -> YES");
    return YES;
}

- (void)setValid:(BOOL)valid {
    NSLog(@"[WizardBypass] ABVJSMGADJS setValid: %d -> forcing YES", valid);
    %orig(YES);
}

- (BOOL)isValid {
    NSLog(@"[WizardBypass] ABVJSMGADJS isValid -> YES");
    return YES;
}

- (BOOL)valid {
    NSLog(@"[WizardBypass] ABVJSMGADJS valid -> YES");
    return YES;
}

%end

%hook AJFADSHFSAJXN

- (id)init {
    NSLog(@"[WizardBypass] AJFADSHFSAJXN init");
    id result = %orig;

    @try {
        [result setValue:@YES forKey:@"authenticated"];
        [result setValue:@YES forKey:@"valid"];
    } @catch (NSException *e) {}

    return result;
}

- (void)setAuthenticated:(BOOL)authenticated {
    NSLog(@"[WizardBypass] AJFADSHFSAJXN setAuthenticated -> forcing YES");
    %orig(YES);
}

- (BOOL)isAuthenticated {
    return YES;
}

- (BOOL)isValid {
    return YES;
}

%end

%hook Kmsjfaigh

- (id)init {
    NSLog(@"[WizardBypass] Kmsjfaigh init");
    id result = %orig;

    @try {
        [result setValue:@YES forKey:@"authenticated"];
        [result setValue:@YES forKey:@"valid"];
    } @catch (NSException *e) {}

    return result;
}

- (BOOL)isAuthenticated {
    return YES;
}

- (BOOL)isValid {
    return YES;
}

%end

%hook Mjshjgkash

- (id)init {
    NSLog(@"[WizardBypass] Mjshjgkash init");
    id result = %orig;

    @try {
        [result setValue:@YES forKey:@"authenticated"];
        [result setValue:@YES forKey:@"valid"];
    } @catch (NSException *e) {}

    return result;
}

- (BOOL)isAuthenticated {
    return YES;
}

- (BOOL)isValid {
    return YES;
}

%end

%hook Pajdsakdfj

- (id)init {
    NSLog(@"[WizardBypass] Pajdsakdfj init");
    id result = %orig;

    @try {
        [result setValue:@YES forKey:@"authenticated"];
        [result setValue:@YES forKey:@"valid"];
    } @catch (NSException *e) {}

    return result;
}

- (BOOL)isAuthenticated {
    return YES;
}

- (BOOL)isValid {
    return YES;
}

%end

%hook Wksahfnasj

- (id)init {
    NSLog(@"[WizardBypass] Wksahfnasj init");
    id result = %orig;

    @try {
        [result setValue:@YES forKey:@"authenticated"];
        [result setValue:@YES forKey:@"valid"];
    } @catch (NSException *e) {}

    return result;
}

- (BOOL)isAuthenticated {
    return YES;
}

- (BOOL)isValid {
    return YES;
}

%end

// ============================================================================
// STRATEGY 5: POPUP BLOCKING (Backup)
// Block SCLAlertView popups as last resort
// ============================================================================

%hook SCLAlertView

- (void)showCustom:(UIImage *)image color:(UIColor *)color title:(NSString *)title subTitle:(NSString *)subTitle closeButtonTitle:(NSString *)closeButtonTitle duration:(NSTimeInterval)duration {
    NSLog(@"[WizardBypass] SCLAlertView showCustom blocked: %@ - %@", title, subTitle);
    return;
}

- (void)showTitle:(NSString *)title subTitle:(NSString *)subTitle style:(NSInteger)style closeButtonTitle:(NSString *)closeButtonTitle duration:(NSTimeInterval)duration {
    NSLog(@"[WizardBypass] SCLAlertView showTitle blocked: %@ - %@", title, subTitle);
    return;
}

- (void)addButton:(NSString *)title validationBlock:(BOOL (^)(void))validationBlock actionBlock:(void (^)(void))action {
    NSLog(@"[WizardBypass] SCLAlertView addButton: %@", title);

    // Replace validation with always-true
    BOOL (^bypassBlock)(void) = ^BOOL(void) {
        return YES;
    };

    %orig(title, bypassBlock, action);
}

%end

// ============================================================================
// MONITORING HOOKS
// Log important events for debugging
// ============================================================================

%hook NSBundle

- (BOOL)load {
    NSString *path = [self bundlePath];
    if ([path containsString:@"Wizard"]) {
        NSLog(@"[WizardBypass] NSBundle load: %@", path);
    }
    return %orig;
}

%end

%hookf(void*, dlopen, const char *path, int mode) {
    if (path && strstr(path, "Wizard")) {
        NSLog(@"[WizardBypass] dlopen: %s", path);
    }
    return %orig;
}

%hookf(FILE*, fopen, const char *path, const char *mode) {
    if (path && strstr(path, "wizardcore.dat")) {
        NSLog(@"[WizardBypass] fopen: wizardcore.dat (mode: %s)", mode);
    }
    return %orig;
}

// ============================================================================
// MAIN CONSTRUCTOR
// Final initialization after all hooks are set up
// ============================================================================

%ctor {
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] Main Constructor - All hooks active");
    NSLog(@"[WizardBypass] Operation ROBUST Implementation");
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] Features:");
    NSLog(@"[WizardBypass]   - Early constructor (priority 101)");
    NSLog(@"[WizardBypass]   - Dylib hiding from enumeration");
    NSLog(@"[WizardBypass]   - 0xdead trap patching");
    NSLog(@"[WizardBypass]   - Auth flag hooks (6 classes)");
    NSLog(@"[WizardBypass]   - SCLAlertView popup blocking");
    NSLog(@"[WizardBypass] ========================================");
}
