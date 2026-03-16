================================================================================
WIZARD ICON VISIBILITY FIX - CHANGES MADE
================================================================================

PROBLEM:
--------
The Pajdsakdfj icon was being created with correct frame (60x60 at position 816,100)
but wasn't visible on screen. Analysis revealed the icon has a UIImageView ivar
called "_Vmasfisahf" that wasn't being populated without valid authentication.

SOLUTION:
---------
Modified WizardBypass.x to manually populate the icon's visual content after creation.

CHANGES:
--------

1. Added QuartzCore import (line 9):
   #import <QuartzCore/QuartzCore.h>

2. Enhanced icon creation code (lines 678-760):
   - After creating Pajdsakdfj instance, we now:
     a) Get the _Vmasfisahf ivar using class_getInstanceVariable()
     b) Check if it's already populated
     c) If not, create a UIImageView with a custom purple circle icon
     d) Draw a white "W" in the center using Core Graphics
     e) Set the ivar using object_setIvar()
     f) Add the imageView as a subview
     g) Set background color to purple (0.5, 0.0, 0.8, 0.8)
     h) Make it round with cornerRadius = 30
     i) Log all subviews for debugging

KEY CODE ADDITIONS:
-------------------

// Get the _Vmasfisahf ivar (UIImageView)
Ivar imageViewIvar = class_getInstanceVariable(pajdsakdfj_class, "_Vmasfisahf");
if (imageViewIvar) {
    UIImageView* existingImageView = object_getIvar(iconView, imageViewIvar);

    if (!existingImageView) {
        // Create UIImageView with purple circle + white "W"
        UIImageView* imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 60, 60)];

        // Draw icon using Core Graphics
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(60, 60), NO, 0.0);
        CGContextRef ctx = UIGraphicsGetCurrentContext();

        // Purple circle
        CGContextSetFillColorWithColor(ctx, [UIColor colorWithRed:0.5 green:0.0 blue:0.8 alpha:1.0].CGColor);
        CGContextFillEllipseInRect(ctx, CGRectMake(5, 5, 50, 50));

        // White "W"
        NSDictionary* attrs = @{
            NSFontAttributeName: [UIFont boldSystemFontOfSize:30],
            NSForegroundColorAttributeName: [UIColor whiteColor]
        };
        [@"W" drawInRect:CGRectMake(15, 10, 30, 40) withAttributes:attrs];

        UIImage* iconImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        imageView.image = iconImage;
        object_setIvar(iconView, imageViewIvar, imageView);
        [iconView addSubview:imageView];
    }
}

// Set background color and make round
[iconView setBackgroundColor:[UIColor colorWithRed:0.5 green:0.0 blue:0.8 alpha:0.8]];
((UIView*)iconView).layer.cornerRadius = 30;

EXPECTED RESULT:
----------------
The icon should now be visible as a purple circle with a white "W" in the top-right
corner of the screen. Even if the _Vmasfisahf ivar doesn't exist, the background
color will make it visible.

TO BUILD:
---------
On macOS with Xcode:
  bash compile_manual.sh

Or use the existing build script:
  bash build_wizard.sh

TO TEST:
--------
1. Compile on macOS
2. Inject WizardBypass.dylib into the IPA
3. Install and run
4. Check syslog for:
   - "[WizardBypass] Found _Vmasfisahf ivar"
   - "[WizardBypass] ✓ Created and set _Vmasfisahf UIImageView"
   - "[WizardBypass] Subviews: ..." (should show the UIImageView)
5. Look for purple circle icon in top-right corner

DEBUGGING:
----------
If still not visible, check the logs for:
- Whether _Vmasfisahf ivar was found
- Whether imageView was created and added
- The subviews array (should contain at least one UIImageView)
- Whether the icon is being blocked by our UIWindow addSubview hook
  (we only block "SCLAlertView" exactly, not "Pajdsakdfj")

================================================================================
