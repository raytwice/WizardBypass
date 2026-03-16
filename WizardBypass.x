// Wizard Authentication Bypass - Minimal Test Version
// Simple hooks only to test if dylib injection works

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// SCLAlertView interface
@interface SCLAlertView : UIView
- (void)showCustom:(UIImage *)image color:(UIColor *)color title:(NSString *)title subTitle:(NSString *)subTitle closeButtonTitle:(NSString *)closeButtonTitle duration:(NSTimeInterval)duration;
- (void)showTitle:(NSString *)title subTitle:(NSString *)subTitle style:(NSInteger)style closeButtonTitle:(NSString *)closeButtonTitle duration:(NSTimeInterval)duration;
@end

// Simple popup blocking
%hook SCLAlertView

- (void)showCustom:(UIImage *)image color:(UIColor *)color title:(NSString *)title subTitle:(NSString *)subTitle closeButtonTitle:(NSString *)closeButtonTitle duration:(NSTimeInterval)duration {
    NSLog(@"[WizardBypass] Blocked SCLAlertView showCustom: %@", title);
    return;
}

- (void)showTitle:(NSString *)title subTitle:(NSString *)subTitle style:(NSInteger)style closeButtonTitle:(NSString *)closeButtonTitle duration:(NSTimeInterval)duration {
    NSLog(@"[WizardBypass] Blocked SCLAlertView showTitle: %@", title);
    return;
}

%end

// Constructor
%ctor {
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] Minimal Test Version Loaded");
    NSLog(@"[WizardBypass] ========================================");
}
