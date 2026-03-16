// Wizard Authentication Bypass - Safe Test Version
// Hooks with crash prevention

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// SCLAlertView interface
@interface SCLAlertView : UIView
- (void)showCustom:(UIImage *)image color:(UIColor *)color title:(NSString *)title subTitle:(NSString *)subTitle closeButtonTitle:(NSString *)closeButtonTitle duration:(NSTimeInterval)duration;
- (void)showTitle:(NSString *)title subTitle:(NSString *)subTitle style:(NSInteger)style closeButtonTitle:(NSString *)closeButtonTitle duration:(NSTimeInterval)duration;
@end

// Hook SCLAlertView but call original to prevent crash
%hook SCLAlertView

- (void)showCustom:(UIImage *)image color:(UIColor *)color title:(NSString *)title subTitle:(NSString *)subTitle closeButtonTitle:(NSString *)closeButtonTitle duration:(NSTimeInterval)duration {
    NSLog(@"[WizardBypass] SCLAlertView showCustom: %@ - %@", title, subTitle);

    // Check if this is the auth popup
    if ([title containsString:@"Wizard"] || [subTitle containsString:@"key"] || [subTitle containsString:@"auth"]) {
        NSLog(@"[WizardBypass] Detected auth popup - BLOCKING");
        return; // Block auth popup
    }

    // Allow other popups
    NSLog(@"[WizardBypass] Allowing non-auth popup");
    %orig;
}

- (void)showTitle:(NSString *)title subTitle:(NSString *)subTitle style:(NSInteger)style closeButtonTitle:(NSString *)closeButtonTitle duration:(NSTimeInterval)duration {
    NSLog(@"[WizardBypass] SCLAlertView showTitle: %@ - %@", title, subTitle);

    // Check if this is the auth popup
    if ([title containsString:@"Wizard"] || [subTitle containsString:@"key"] || [subTitle containsString:@"auth"]) {
        NSLog(@"[WizardBypass] Detected auth popup - BLOCKING");
        return; // Block auth popup
    }

    // Allow other popups
    NSLog(@"[WizardBypass] Allowing non-auth popup");
    %orig;
}

%end

// Constructor
%ctor {
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] Safe Test Version Loaded");
    NSLog(@"[WizardBypass] Will only block auth popups");
    NSLog(@"[WizardBypass] ========================================");
}
