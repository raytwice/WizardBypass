================================================================================
WIZARD BYPASS PROJECT - HANDOFF DOCUMENT V2
================================================================================
Last Updated: 2026-03-17 01:27 UTC
Status: Icon visible + tappable, menu created but 0xDEAD anti-tamper crash on render
Build: commit 97b6ec8 (anti-tamper no-op + diagnostics)

================================================================================
THE PROBLEM
================================================================================

CURRENT ISSUE:
--------------
Menu is successfully created by IKAFHFDSAJ. Tapping the icon unhides Wksahfnasj
and unpauses its MTKView. However, the original drawInMTKView: on AJFADSHFSAJXN
contains ANTI-TAMPER checks that detect our method swizzling and deliberately
crash with PC=0xDEAD. This is NOT a nil-pointer crash.

ROOT CAUSE (CONFIRMED VIA RUNTIME v18):
-----------------------------------------
1. IKAFHFDSAJ successfully creates: UITextFields, MTKView, Wksahfnasj, 4x Pajdsakdfj
2. Wksahfnasj ivars after creation:
     tsjfhasjfsa  (^v)              = 0x283b9ab00  ← render callback (NOT nil!)
     _pPfuasjrasfh (@"MTKView")     = <MTKView>    ← Metal view
     _paJFSAUJJFSAC (@"AJFADSHFSAJXN") = <AJFADSHFSAJXN> ← renderer
3. initializePlatform runs SUCCESS — Metal pipeline is ready
4. When MTKView is unpaused → drawInMTKView: fires → anti-tamper check inside
   detects swizzled methods → jumps to 0xDEAD → crash
5. @try/@catch CANNOT catch 0xDEAD (it's EXC_BAD_ACCESS, not NSException)

FIX (commit 97b6ec8):
   Replace drawInMTKView: with complete NO-OP — never call original.
   This prevents the anti-tamper code from executing entirely.
   Menu won't render imgui content, but app survives.

PRIOR ISSUES (SOLVED):
-----------------------
✓ Pajdsakdfj has 0 ivars → solved via g_wizardController global
✓ Menu not created → solved by calling IKAFHFDSAJ on ABVJSMGADJS
✓ Startup crash → solved by pausing MTKView after menu creation

================================================================================
RUNTIME-VERIFIED CLASS STRUCTURE
================================================================================

ABVJSMGADJS — THE REAL CONTROLLER (NSObject subclass)
------------------------------------------------------
This is the central manager that owns everything.

IVARS (7 total, ALL objects, ZERO booleans):
  ivar[0]: _jdsghadurewmf  (type: @"Wksahfnasj")    ← THE MENU
  ivar[1]: _pJMSAFHSJSFV   (type: @"Pajdsakdfj")    ← Icon position 1
  ivar[2]: _naJFSAKFNSMN   (type: @"Pajdsakdfj")    ← Icon position 2
  ivar[3]: _AYtPSMFSKdfj   (type: @"Pajdsakdfj")    ← Icon position 3
  ivar[4]: _AYmpXkdajwND   (type: @"Pajdsakdfj")    ← Icon position 4
  ivar[5]: _qmshnfuas      (type: @"NSTimer")        ← Timer 1
  ivar[6]: _nvjsafhsa      (type: @"NSTimer")        ← Timer 2

METHODS (all instance, encoding v16@0:8 = void, no args):
  PADSGFNDSAHJ  — Creates 3 UIImageViews (icon setup). This is the INIT method.
  IKAFHFDSAJ    — Chains to ASFGAHJFAHS → MdhsaJFSAJ (nested setup)
  ASFGAHJFAHS   — Chains to MdhsaJFSAJ
  MdhsaJFSAJ    — Leaf method (base setup)

PROPERTY ACCESSORS:
  jdsghadurewmf / setJdsghadurewmf:     (Wksahfnasj menu)
  pJMSAFHSJSFV / setPJMSAFHSJSFV:      (Pajdsakdfj icon 1)
  naJFSAKFNSMN / setNaJFSAKFNSMN:      (Pajdsakdfj icon 2)
  AYtPSMFSKdfj / setAYtPSMFSKdfj:      (Pajdsakdfj icon 3)
  AYmpXkdajwND / setAYmpXkdajwND:      (Pajdsakdfj icon 4)
  qmshnfuas / setQmshnfuas:            (NSTimer)
  nvjsafhsa / setNvjsafhsa:            (NSTimer)
  init / .cxx_destruct

Pajdsakdfj — FLOATING ICON VIEW (UIView subclass)
--------------------------------------------------
IVARS: **0** (zero) — inherits only from UIView
METHODS: 2 only
  didTapIconView          — tap handler (accesses controller via UNKNOWN mechanism)
  initWithFrame:type:     — creates view with frame + type parameter

CRITICAL: Since Pajdsakdfj has 0 custom ivars, `didTapIconView` MUST access
the ABVJSMGADJS controller through one of:
  a) A C/C++ global variable (most likely — Wizard uses C++)
  b) objc_getAssociatedObject (ObjC runtime)
  c) A class-level static variable
  d) The responder chain or UIView superview hierarchy
  e) A singleton method on ABVJSMGADJS (but no +shared or +instance method found)

Wksahfnasj — METAL-BACKED MENU (UIView subclass)
--------------------------------------------------
This is NOT a standard UIView. It uses a dear imgui-style Metal renderer.
DO NOT try to manually alloc/init this class — it will crash.

METHODS:
  paDJSAFBSANC / jsafbSAHCN / dgshdsfyewrh  — obfuscated setup methods
  pPfuasjrasfh / setPPfuasjrasfh:            — MTKView property
  paJFSAUJJFSAC / setPaJFSAUJJFSAC:         — AJFADSHFSAJXN (Metal renderer)
  touchesBegan/Moved/Ended/Cancelled         — touch forwarding to imgui
  initWithFrame: / .cxx_destruct

AJFADSHFSAJXN — METAL RENDERER (NOT auth controller)
------------------------------------------------------
This is the imgui Metal rendering backend, NOT authentication.

METHODS:
  initWithView:                           — takes MTKView
  drawInMTKView:                          — MTKViewDelegate render callback
  mtkView:drawableSizeWillChange:         — MTKViewDelegate resize
  initializePlatform / shutdownPlatform   — Metal pipeline setup/teardown
  handleEvent:view:                       — input event forwarding
  device / setDevice:                     — MTLDevice
  commandQueue / setCommandQueue:         — MTLCommandQueue
  loader / setLoader: / delegate / setDelegate:

Other Classes:
  Kmsjfaigh     — Unknown purpose, no key methods found
  Mjshjgkash    — Unknown purpose, no key methods found
  MetalContext  — Metal rendering context
  MetalBuffer   — Metal buffer wrapper
  FramebufferDescriptor — Framebuffer config (only BOOL method: isEqual:)

================================================================================
WHAT WE'VE DONE (TIMELINE)
================================================================================

VERSION    COMMIT     RESULT
--------   -------    ------
v1-v11     various    Crashes due to wrong init of Wksahfnasj (Metal class)
v12        various    Discovered Wksahfnasj is Metal-backed, can't alloc/init
v13-v14    various    Tried manual Metal pipeline setup — crashes
v15        24ba375    Option A: let original didTapIconView run.
                      Result: No crash! But nothing happens (silent fail)
v16        9853c6d    Force auth ivars + let original run.
                      Result: No crash, but still no menu. Only 1 BOOL
                      method hooked total (FramebufferDescriptor::isEqual:)
v17        2128ec5    Diagnostic build: dump ABVJSMGADJS/Pajdsakdfj ivars.
                      CRITICAL FINDINGS:
                      - Pajdsakdfj has 0 ivars
                      - ABVJSMGADJS has 7 object ivars (no BOOLs)
                      - All 4 ABVJSMGADJS methods are void
                      - PADSGFNDSAHJ creates UIImageViews
                      - didTapIconView accesses controller via unknown mechanism

CURRENT STATE:
✓ Icon appears on screen (purple W circle, top-right, 60x60px)
✓ Icon is tappable and draggable
✓ SCLAlertView auth popup is blocked (showInfo:title:... intercepted)
✓ auth-token-type faked to "premium" in NSUserDefaults
✓ ABVJSMGADJS created and its 4 methods called (all succeed, no crash)
✓ didTapIconView runs without crash
✗ Menu does not appear — Pajdsakdfj can't find ABVJSMGADJS controller
✗ ABVJSMGADJS controller → Pajdsakdfj wiring is one-way (controller knows
  icon, but icon can't find controller due to 0 ivars)

================================================================================
WHAT NEEDS TO HAPPEN NEXT
================================================================================

THE CORE PROBLEM TO SOLVE:
---------------------------
Find HOW `didTapIconView` accesses ABVJSMGADJS. Since Pajdsakdfj has 0 ivars,
it must use one of these mechanisms:

INVESTIGATION PATH 1: Associated Objects
  - Hook objc_getAssociatedObject to see if didTapIconView uses it
  - If so, use objc_setAssociatedObject to set our ABVJSMGADJS on the icon

INVESTIGATION PATH 2: C++ Global Variable
  - The Wizard binary likely has a global ABVJSMGADJS* pointer
  - Use `nm` or `otool` to find global symbols in the Wizard binary
  - Or hook didTapIconView at the assembly level to see what it accesses

INVESTIGATION PATH 3: Replace didTapIconView Entirely
  - Instead of calling the original, write our own implementation
  - In our implementation, directly call ABVJSMGADJS::PADSGFNDSAHJ on our
    known controller instance to set up icons, then toggle menu visibility

INVESTIGATION PATH 4: Disassemble didTapIconView
  - Get the IMP of didTapIconView
  - Log the first N bytes of machine code
  - Look for adrp/ldr patterns that load a global variable
  - This tells us exactly what memory address the controller is stored at

RECOMMENDED APPROACH:
  Path 3 is fastest: completely replace didTapIconView. We already have a
  valid ABVJSMGADJS instance. When tapped, we should:
  1. Create Wksahfnasj via the controller (not direct alloc/init)
  2. Or toggle visibility of an existing menu
  3. The challenge: Wksahfnasj needs Metal pipeline setup

  Path 1 is safest: check associated objects first, it's a common pattern.

================================================================================
AUTH FLOW OBSERVED IN SYSLOG
================================================================================

At ~3 seconds after launch:
  1. Wizard checks NSUserDefaults for 'auth-token-type' → null
  2. We fake it to 'premium'
  3. Wizard builds SCLAlertView popup (UITextView, UILabel, SCLButton x2)
  4. SCLAlertView::showInfo:title:subTitle:closeButtonTitle:duration: fires
  5. We BLOCK it (popup never shown to user)
  6. Wizard considers auth failed but popup was suppressed

This means the auth popup is a LICENSE KEY ENTRY dialog with:
  - An info icon (UIImageView)
  - A title + subtitle (UILabel + UITextView)
  - Two buttons (SCLButton x2): likely "Enter Key" + "Close"
  - A text input (SCLTextView)

The real auth flow needs a valid license key entered in this dialog.
Without it, Wizard marks itself as unauthenticated internally.

================================================================================
TOOLS & LOCATIONS
================================================================================

LIBIMOBILEDEVICE TOOLS:
-----------------------
Location: C:\Users\ray\Downloads\libimobiledevice.1.2.1-r1122-win-x64\

Commands:
  idevicesyslog.exe | findstr "WizardBypass"     — Live filtered logs
  idevicecrashreport.exe --extract .              — Download crash logs
  idevice_id.exe -l                               — List connected devices

BUILD & DEPLOY:
---------------
1. Edit WizardBypass.x
2. git add WizardBypass.x && git commit -m "msg" && git push
3. GitHub Actions builds at: https://github.com/raytwice/WizardBypass/actions
4. Download WizardBypass-dylib artifact
5. Inject into IPA, install via Sideloadly

KEY FILES:
----------
  WizardBypass.x         — Main tweak code (~950 lines)
  WizardBypass.plist      — Load config (targets pool app bundle)
  .github/workflows/build.yml — CI build config
  HANDOFF_V2.md           — This file

================================================================================
SYSLOG MESSAGES TO WATCH FOR
================================================================================

STARTUP:
  "PHASE 7: HOOKING ABVJSMGADJS"     → Controller class found
  "ABVJSMGADJS has 7 ivars"          → Structure dumped
  "PADSGFNDSAHJ -> retType=v"        → Methods analyzed
  "PHASE 8: CREATING WIZARD UI"      → UI creation started
  "Created ABVJSMGADJS controller"   → Controller instantiated
  "Pajdsakdfj has 0 ivars"           → CRITICAL: no controller ref
  "CALLED: ABVJSMGADJS::PADSGFNDSAHJ" → Setup methods called

ON TAP:
  "didTapIconView CALLED"            → Tap detected
  "Original didTapIconView RETURNED"  → Original ran (no crash)
  (NO ivar dump because 0 ivars)

AUTH (3s after launch):
  "FAKING auth-token-type -> premium" → NSUserDefaults spoofed
  "BLOCKED SCLAlertView::showInfo"    → License popup blocked

================================================================================
END OF HANDOFF
================================================================================
