================================================================================
WIZARD BYPASS PROJECT - HANDOFF DOCUMENT V2
================================================================================
Last Updated: 2026-03-17 01:50 UTC
Status: Menu visible + no crash! drawInMTKView no-op confirmed working. Need to
        find anti-tamper branch to allow real rendering.
Build: v19 (pending push — 512-byte IMP dump + idle kill)

================================================================================
THE PROBLEM
================================================================================

CURRENT ISSUE:
--------------
Menu shows (hidden→visible) and MTKView unpauses WITHOUT CRASHING!
The drawInMTKView: no-op kills the anti-tamper 0xDEAD trap completely.
However, the menu is BLANK because drawInMTKView: does nothing.

NEXT STEP: Dump 512 bytes of the original drawInMTKView: IMP, find the
anti-tamper branch (MOV X?, #0xDEAD + BR X?), and patch just those bytes
in a future build so the real imgui rendering works.

SECONDARY ISSUE: Wizard has an idle/timeout mechanism that crashes or exits
the game if the auth popup is up too long. v19 neutralizes this with:
  - NSTimer hooks (block all Wizard.framework timers)
  - performSelector:afterDelay: hooks (block ≥5s delays from Wizard)
  - Immediate invalidation of ABVJSMGADJS timer ivars

ROOT CAUSE (CONFIRMED VIA RUNTIME v18):
-----------------------------------------
1. IKAFHFDSAJ successfully creates: UITextFields, MTKView, Wksahfnasj, 4x Pajdsakdfj
2. Wksahfnasj ivars after creation:
     tsjfhasjfsa  (^v)              = 0x280f57400  ← render callback (NOT nil!)
     _pPfuasjrasfh (@"MTKView")     = <MTKView>    ← Metal view
     _paJFSAUJJFSAC (@"AJFADSHFSAJXN") = <AJFADSHFSAJXN> ← renderer
3. initializePlatform runs SUCCESS — Metal pipeline is ready
4. When MTKView is unpaused → drawInMTKView: fires → anti-tamper check inside
   detects swizzled methods → jumps to 0xDEAD → crash
5. @try/@catch CANNOT catch 0xDEAD (it's EXC_BAD_ACCESS, not NSException)

FIX APPLIED (v18, commit 97b6ec8):
   Replace drawInMTKView: with complete NO-OP — never call original.
   This prevents the anti-tamper code from executing entirely.
   Menu survives but renders blank (no imgui frames drawn).

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
  ivar[5]: _qmshnfuas      (type: @"NSTimer")        ← Timer 1 (IDLE KILL?)
  ivar[6]: _nvjsafhsa      (type: @"NSTimer")        ← Timer 2 (IDLE KILL?)

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

Kmsjfaigh — ICON VIEW (UIView subclass, VARIANT)
--------------------------------------------------
IVARS: 2
  _Vmasfisahf (@"UIImageView")  — the icon image
  _type (q / long long)           — icon type identifier
METHODS: 7
  didTapIconView          — tap handler (same as Pajdsakdfj!)
  Vmasfisahf / setVmasfisahf:  — image view property
  type / setType:               — type property
  initWithFrame:          — standard init
  .cxx_destruct

Mjshjgkash — DRAG GESTURE HANDLER (UIView subclass)
-----------------------------------------------------
IVARS: 2
  _startLocation ({CGPoint="x"d"y"d})  — drag start point
  _didMovePoint ({CGPoint="x"d"y"d})   — current drag offset
METHODS: 8
  touchesBegan/Moved/Ended/Cancelled   — standard pan gesture
  startLocation / setStartLocation:     — start point property
  didMovePoint / setDidMovePoint:       — move point property

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
                                            *** CONTAINS ANTI-TAMPER 0xDEAD ***
  mtkView:drawableSizeWillChange:         — MTKViewDelegate resize
  initializePlatform / shutdownPlatform   — Metal pipeline setup/teardown
  handleEvent:view:                       — input event forwarding
  device / setDevice:                     — MTLDevice
  commandQueue / setCommandQueue:         — MTLCommandQueue
  loader / setLoader: / delegate / setDelegate:

Other Classes:
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
v18        97b6ec8    drawInMTKView no-op + diagnostics.
                      ✓ No crash on icon tap!
                      ✓ Menu toggles visible (hidden→shown)
                      ✓ MTKView unpauses without crash
                      ✗ Menu is BLANK (no imgui rendering)
                      NEW: Kmsjfaigh has 2 ivars (UIImageView + type)
                      NEW: Mjshjgkash has 2 ivars (startLocation + didMovePoint)
v19        PENDING    512-byte IMP dump + idle/timeout kill.
                      Changes:
                      - Dump 512 bytes of drawInMTKView IMP to find 0xDEAD
                      - Auto-detect MOV #0xDEAD and BR instructions in dump
                      - Hook NSTimer to block Wizard framework timers
                      - Hook performSelector:afterDelay: for Wizard classes
                      - Invalidate ABVJSMGADJS timer ivars (_qmshnfuas, _nvjsafhsa)

CURRENT STATE:
✓ Icon appears on screen (purple W circle, top-right, 60x60px)
✓ Icon is tappable and draggable
✓ SCLAlertView auth popup is blocked (showInfo:title:... intercepted)
✓ auth-token-type faked to "premium" in NSUserDefaults
✓ ABVJSMGADJS created and its 4 methods called (all succeed, no crash)
✓ didTapIconView runs without crash
✓ Menu toggles visible/hidden on tap (NO CRASH!)
✓ MTKView unpauses without crash (drawInMTKView is no-op)
✗ Menu is blank — drawInMTKView no-op means no imgui frames render
✗ Need to find & patch the anti-tamper branch to allow real rendering

================================================================================
WHAT NEEDS TO HAPPEN NEXT
================================================================================

IMMEDIATE (v19 output analysis):
---------------------------------
1. Build & deploy v19
2. Read the 512-byte hex dump from syslog
3. Find the anti-tamper pattern:
   - Look for MOV X?, #0xDEAD (should show as !!! FOUND 0xDEAD MOV in logs)
   - Look for BR X? nearby (should show as !!! FOUND BR Xn in logs)
   - The conditional branch (B.NE or B.EQ) before the MOV is the check
4. In v20: patch those specific bytes to NOP, call the original drawInMTKView:

FUTURE (v20+):
--------------
Once we can identify the anti-tamper branch offset:
  - Use vm_protect + mach_vm_write to patch the branch to NOP (if kernel allows)
  - OR use a custom drawInMTKView: that calls original but first patches the check
  - OR dump enough to reconstruct drawInMTKView: without the anti-tamper branch

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
  WizardBypass.x         — Main tweak code (~1200 lines)
  WizardBypass.plist      — Load config (targets pool app bundle)
  .github/workflows/build.yml — CI build config
  HANDOFF_V2.md           — This file

================================================================================
SYSLOG MESSAGES TO WATCH FOR
================================================================================

STARTUP:
  "PHASE 7: HOOKING METAL + SETTING UP CONTROLLER"  → Metal hooks installed
  "DUMPING 512 BYTES FOR ANTI-TAMPER ANALYSIS"       → IMP dump started
  "+000: fa 67 bb a9..."                              → Hex dump lines
  "!!! FOUND 0xDEAD MOV at offset ..."               → ANTI-TAMPER FOUND!
  "!!! FOUND BR Xn at offset ..."                    → Branch to 0xDEAD found!
  "HOOKING IDLE/TIMEOUT KILL MECHANISMS"              → Timer hooks installed
  "BLOCKED NSTimer from Wizard..."                    → Timer intercepted
  "Set _qmshnfuas = nil"                              → Controller timer killed
  "Set _nvjsafhsa = nil"                              → Controller timer killed

ON TAP:
  "TAP! Toggling menu via g_wizardController"        → Tap detected
  "Menu isHidden=1, toggling to 0"                   → Menu shown
  "MTKView UNPAUSED (drawInMTKView is no-op)"        → Render loop active (no-op)
  "Menu SHOWN!"                                       → Success

AUTH:
  "FAKING auth-token-type -> premium"                 → NSUserDefaults spoofed
  "BLOCKED SCLAlertView::showInfo"                    → License popup blocked

================================================================================
END OF HANDOFF
================================================================================
