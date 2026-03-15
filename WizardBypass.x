// Wizard Authentication Bypass
// Comprehensive bypass for Wizard's authentication system

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>

// SCLAlertView interface
@interface SCLAlertView : UIView
- (void)showCustom:(UIImage *)image color:(UIColor *)color title:(NSString *)title subTitle:(NSString *)subTitle closeButtonTitle:(NSString *)closeButtonTitle duration:(NSTimeInterval)duration;
- (void)showTitle:(NSString *)title subTitle:(NSString *)subTitle style:(NSInteger)style closeButtonTitle:(NSString *)closeButtonTitle duration:(NSTimeInterval)duration;
- (void)addButton:(NSString *)title validationBlock:(BOOL (^)(void))validationBlock actionBlock:(void (^)(void))action;
@end

static BOOL wizardInitialized = NO;

// Hook all SCLAlertView show methods
%hook SCLAlertView

- (void)showCustom:(UIImage *)image color:(UIColor *)color title:(NSString *)title subTitle:(NSString *)subTitle closeButtonTitle:(NSString *)closeButtonTitle duration:(NSTimeInterval)duration {
    NSLog(@"[WizardBypass] SCLAlertView showCustom: %@ - %@", title, subTitle);

    // Block ALL popups from SCLAlertView to prevent any authentication UI
    NSLog(@"[WizardBypass] Blocking popup!");
    return;
}

- (void)showTitle:(NSString *)title subTitle:(NSString *)subTitle style:(NSInteger)style closeButtonTitle:(NSString *)closeButtonTitle duration:(NSTimeInterval)duration {
    NSLog(@"[WizardBypass] SCLAlertView showTitle: %@ - %@", title, subTitle);

    // Block ALL popups
    NSLog(@"[WizardBypass] Blocking popup!");
    return;
}

- (void)addButton:(NSString *)title validationBlock:(BOOL (^)(void))validationBlock actionBlock:(void (^)(void))action {
    NSLog(@"[WizardBypass] addButton: %@", title);

    // Replace validation with always-true block
    BOOL (^bypassBlock)(void) = ^BOOL(void) {
        return YES;
    };

    %orig(title, bypassBlock, action);
}

%end

// Hook NSBundle to intercept Wizard.framework loading
%hook NSBundle

- (BOOL)load {
    NSString *bundlePath = [self bundlePath];

    if ([bundlePath containsString:@"Wizard.framework"]) {
        NSLog(@"[WizardBypass] Wizard.framework loading detected!");
        wizardInitialized = YES;
    }

    return %orig;
}

- (BOOL)loadAndReturnError:(NSError **)error {
    NSString *bundlePath = [self bundlePath];

    if ([bundlePath containsString:@"Wizard.framework"]) {
        NSLog(@"[WizardBypass] Wizard.framework loading detected!");
        wizardInitialized = YES;
    }

    return %orig;
}

%end

// Hook file operations to intercept wizardcore.dat access
%hookf(FILE *, fopen, const char *path, const char *mode) {
    if (path && strstr(path, "wizardcore.dat")) {
        NSLog(@"[WizardBypass] Intercepted fopen for wizardcore.dat");
        // Let it open normally - we're not blocking the data file
    }

    return %orig;
}

// Hook dlopen to catch dynamic library loading
%hookf(void *, dlopen, const char *path, int mode) {
    if (path) {
        NSString *pathStr = [NSString stringWithUTF8String:path];
        if ([pathStr containsString:@"Wizard"]) {
            NSLog(@"[WizardBypass] dlopen called for: %@", pathStr);
        }
    }

    return %orig;
}

// Hook the obfuscated classes - these might be doing validation
%hook ABVJSMGADJS

- (id)init {
    NSLog(@"[WizardBypass] ABVJSMGADJS init");
    id result = %orig;

    // Try to set any "isValid" or "isAuthenticated" properties to YES
    @try {
        if ([result respondsToSelector:@selector(setIsValid:)]) {
            [result performSelector:@selector(setIsValid:) withObject:@YES];
            NSLog(@"[WizardBypass] Set isValid to YES");
        }
        if ([result respondsToSelector:@selector(setIsAuthenticated:)]) {
            [result performSelector:@selector(setIsAuthenticated:) withObject:@YES];
            NSLog(@"[WizardBypass] Set isAuthenticated to YES");
        }
    } @catch (NSException *e) {
        NSLog(@"[WizardBypass] Exception: %@", e);
    }

    return result;
}

// Hook any method that might return validation status
- (BOOL)isValid {
    NSLog(@"[WizardBypass] ABVJSMGADJS isValid called - returning YES");
    return YES;
}

- (BOOL)isAuthenticated {
    NSLog(@"[WizardBypass] ABVJSMGADJS isAuthenticated called - returning YES");
    return YES;
}

%end

%hook AJFADSHFSAJXN

- (id)init {
    NSLog(@"[WizardBypass] AJFADSHFSAJXN init");
    return %orig;
}

- (BOOL)isValid {
    NSLog(@"[WizardBypass] AJFADSHFSAJXN isValid - returning YES");
    return YES;
}

- (BOOL)isAuthenticated {
    NSLog(@"[WizardBypass] AJFADSHFSAJXN isAuthenticated - returning YES");
    return YES;
}

%end

%hook Kmsjfaigh

- (id)init {
    NSLog(@"[WizardBypass] Kmsjfaigh init");
    return %orig;
}

- (BOOL)isValid {
    NSLog(@"[WizardBypass] Kmsjfaigh isValid - returning YES");
    return YES;
}

%end

%hook Mjshjgkash

- (id)init {
    NSLog(@"[WizardBypass] Mjshjgkash init");
    return %orig;
}

- (BOOL)isValid {
    NSLog(@"[WizardBypass] Mjshjgkash isValid - returning YES");
    return YES;
}

%end

%hook Pajdsakdfj

- (id)init {
    NSLog(@"[WizardBypass] Pajdsakdfj init");
    return %orig;
}

- (BOOL)isValid {
    NSLog(@"[WizardBypass] Pajdsakdfj isValid - returning YES");
    return YES;
}

%end

%hook Wksahfnasj

- (id)init {
    NSLog(@"[WizardBypass] Wksahfnasj init");
    return %orig;
}

- (BOOL)isValid {
    NSLog(@"[WizardBypass] Wksahfnasj isValid - returning YES");
    return YES;
}

%end

%ctor {
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] Wizard Authentication Bypass Loaded");
    NSLog(@"[WizardBypass] Version: 1.0");
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] All SCLAlertView popups will be blocked");
    NSLog(@"[WizardBypass] All validation checks will return YES");
    NSLog(@"[WizardBypass] Monitoring Wizard.framework initialization");
}
