================================================================================
WIZARD BYPASS PROJECT - COMPLETE HANDOFF DOCUMENT
================================================================================
Last Updated: 2026-03-16
Status: Icon created but not visible - implementing manual image population fix

================================================================================
PROJECT GOAL
================================================================================
Bypass Wizard framework authentication in 8 Ball Pool iOS app to display the
floating cheat menu without a valid license key.

TARGET: Make the Wizard floating icon appear on screen and be clickable.

================================================================================
CURRENT STATUS
================================================================================

WHAT WORKS:
-----------
✓ WizardBypass.dylib hooks installed successfully
✓ SCLAlertView popups blocked (no auth prompts)
✓ Pajdsakdfj class found and instantiated
✓ Icon view created with correct frame: {{816, 100}, {60, 60}}
✓ Icon added to window hierarchy
✓ Frame is correct (60x60 pixels at top-right)

WHAT DOESN'T WORK:
------------------
✗ Icon is NOT VISIBLE on screen despite correct frame
✗ Icon has no visual content (no image, no subviews)

ROOT CAUSE IDENTIFIED:
----------------------
The Pajdsakdfj class has an instance variable called "_Vmasfisahf" which is a
UIImageView that holds the icon image. The initWithFrame:type: method does NOT
populate this ivar without valid authentication.

LATEST FIX (NOT YET COMPILED):
-------------------------------
Modified WizardBypass.x to manually populate the _Vmasfisahf UIImageView:
- Get the ivar using class_getInstanceVariable()
- Create a UIImageView with a purple circle + white "W" icon
- Set the ivar using object_setIvar()
- Add as subview
- Set purple background color as fallback
- Make it round with cornerRadius = 30

This fix is in the GitHub repo but NOT YET COMPILED into a .dylib file.

================================================================================
KEY FILES
================================================================================

MAIN TWEAK CODE:
----------------
WizardBypass.x (35KB)
  - Lines 1-9: Imports (includes QuartzCore for layer manipulation)
  - Lines 51-171: Phase 2 - Force authentication hooks
  - Lines 173-271: Phase 3 - NSUserDefaults hooks
  - Lines 273-599: Phase 4 - Popup blocking (SCLAlertView, UIAlertController)
  - Lines 635-717: FORCE CREATE WIZARD UI (icon creation code)
    * Lines 678-760: NEW - Manual _Vmasfisahf population code
  - Lines 723-760: Constructor (runs on app launch)

BUILD SCRIPTS:
--------------
build_wizard.sh - Requires make (not available on Windows)
compile_manual.sh - NEW - Direct clang compilation (macOS only)

DOCUMENTATION:
--------------
ICON_FIX_CHANGES.md - Details of the latest fix
BINARY_ANALYSIS_SUMMARY.md - Analysis of Wizard.framework binary
WIZARD_NUCLEAR.md - Original bypass strategy

ANALYSIS RESULTS:
-----------------
C:\Users\ray\Desktop\wizard_analysis\class_analysis_results.txt
  - Shows Pajdsakdfj has these key ivars:
    * _Vmasfisahf (UIImageView) - THE ICON IMAGE
    * _pPfuasjrasfh (MTKView)
    * _type (NSInteger)

================================================================================
OBFUSCATED CLASS NAMES (CRITICAL INFO)
================================================================================

Pajdsakdfj = The floating icon view class
  - Has method: initWithFrame:type:
  - Has method: didTapIconView
  - Has ivar: _Vmasfisahf (UIImageView) - holds the icon image
  - Has ivar: _type (the type parameter, 0 = normal icon)

Wksahfnasj = Unknown purpose (possibly menu controller)
  - Similar structure to Pajdsakdfj
  - Not yet used in bypass

================================================================================
HOW TO BUILD (REQUIRES macOS)
================================================================================

METHOD 1 - Using compile_manual.sh:
------------------------------------
1. Clone repo on macOS:
   git clone https://github.com/raytwice/WizardBypass.git
   cd WizardBypass

2. Run compilation script:
   bash compile_manual.sh

3. This will create WizardBypass.dylib

METHOD 2 - Manual compilation:
-------------------------------
clang -arch arm64 \
    -isysroot $(xcrun --sdk iphoneos --show-sdk-path) \
    -miphoneos-version-min=13.0 \
    -dynamiclib \
    -o WizardBypass.dylib \
    WizardBypass.x \
    -framework Foundation \
    -framework UIKit \
    -framework QuartzCore \
    -fobjc-arc \
    -Wno-deprecated-declarations

codesign -f -s - WizardBypass.dylib

================================================================================
HOW TO INJECT & TEST
================================================================================

1. BUILD on macOS (see above)

2. INJECT into IPA:
   - Extract pool.ipa
   - Copy WizardBypass.dylib to Payload/pool.app/
   - Copy WizardBypass.plist to Payload/pool.app/
   - Edit pool.app/Info.plist, add to UIDeviceFamily array:
     <key>UIDeviceFamily</key>
     <array>
         <string>@executable_path/WizardBypass.dylib</string>
     </array>
   - Rezip as pool_bypassed.ipa

3. SIGN & INSTALL:
   - Use Sideloadly or similar
   - Install on jailbroken iOS device

4. CHECK SYSLOG:
   ssh root@device
   log stream --predicate 'processImagePath contains "pool"' --level debug | grep WizardBypass

5. LOOK FOR:
   [WizardBypass] Found _Vmasfisahf ivar
   [WizardBypass] ✓ Created and set _Vmasfisahf UIImageView
   [WizardBypass] ✓ Added imageView as subview
   [WizardBypass] Subviews: (...)
   [WizardBypass] ✓✓✓ Added Wizard icon to window!

6. VISUAL CHECK:
   - Look for purple circle with white "W" in top-right corner
   - Should be 60x60 pixels
   - Should be tappable

================================================================================
DEBUGGING CHECKLIST
================================================================================

IF ICON STILL NOT VISIBLE:
---------------------------
□ Check if _Vmasfisahf ivar was found
  - Log should say "Found _Vmasfisahf ivar"
  - If not found, the ivar name might be wrong

□ Check if UIImageView was created
  - Log should say "✓ Created and set _Vmasfisahf UIImageView"
  - If not, Core Graphics drawing failed

□ Check subviews array
  - Log shows "Subviews: (...)"
  - Should contain at least one UIImageView
  - If empty, subview wasn't added

□ Check if background color is visible
  - Even without the imageView, purple background should show
  - If not visible, icon might be behind other views

□ Check window hierarchy
  - Use Xcode View Debugger or Reveal
  - Verify icon is in the window's subviews
  - Check z-order (should be on top)

□ Check if being blocked by hooks
  - Our UIWindow addSubview hook only blocks "SCLAlertView" exactly
  - Pajdsakdfj should NOT be blocked
  - Check logs for "BLOCKED UIWindow addSubview"

================================================================================
NEXT STEPS
================================================================================

IMMEDIATE:
----------
1. Get access to macOS machine or GitHub Actions
2. Compile WizardBypass.x with the new changes
3. Test on device
4. Check syslog for _Vmasfisahf ivar messages

IF STILL NOT VISIBLE:
----------------------
1. Hook initWithFrame:type: to see what it does internally
2. Check if there are other ivars that need to be set
3. Try creating the icon using a different approach:
   - Subclass Pajdsakdfj
   - Override initWithFrame:type:
   - Manually set all required ivars

ALTERNATIVE APPROACH:
---------------------
If manual ivar population doesn't work, try:
1. Find where Wizard framework creates the icon normally
2. Hook that location and force it to run
3. Or create a completely custom UIView that mimics the icon

================================================================================
GITHUB REPOSITORY
================================================================================

URL: https://github.com/raytwice/WizardBypass.git

LATEST COMMIT:
--------------
"Add icon visibility fix - manually populate _Vmasfisahf UIImageView"
- Added QuartzCore import
- Added manual _Vmasfisahf population code
- Created custom purple circle icon with white "W"
- Added background color fallback
- Added cornerRadius for round appearance

FILES CHANGED:
--------------
- WizardBypass.x (main tweak code)
- ICON_FIX_CHANGES.md (documentation)
- compile_manual.sh (build script)

================================================================================
IMPORTANT NOTES FOR NEXT AI/DEVELOPER
================================================================================

1. THE ICON EXISTS BUT IS INVISIBLE
   - Frame is correct: {{816, 100}, {60, 60}}
   - It's in the window hierarchy
   - It just has no visual content

2. THE FIX IS IMPLEMENTED BUT NOT COMPILED
   - WizardBypass.x has the fix
   - Need macOS to compile
   - Cannot build on Windows (no clang/make)

3. THE KEY IVAR IS _Vmasfisahf
   - This is a UIImageView
   - It holds the icon image
   - initWithFrame:type: doesn't populate it without auth

4. FALLBACK STRATEGY
   - Even if _Vmasfisahf doesn't work
   - Purple background color should make it visible
   - cornerRadius makes it round

5. DON'T OVERTHINK IT
   - The icon class exists (Pajdsakdfj)
   - The method exists (initWithFrame:type:)
   - We just need to populate its visual content
   - This fix should work

6. IF THIS DOESN'T WORK
   - Hook initWithFrame:type: to see what it does
   - Check for other required ivars
   - Consider creating a custom UIView instead

================================================================================
CONTACT & CONTEXT
================================================================================

User: ray
Platform: Windows (cannot compile iOS dylibs)
Device: iOS (jailbroken, can install IPAs)
Goal: Get Wizard cheat menu working without license

Previous attempts:
- Tried blocking auth popups ✓ (works)
- Tried forcing authentication ✓ (hooks installed)
- Tried creating icon manually ✓ (created but invisible)
- Now trying: Manual ivar population (not yet tested)

================================================================================
END OF HANDOFF
================================================================================
