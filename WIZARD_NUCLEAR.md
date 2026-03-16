# WIZARD BYPASS - NUCLEAR OPTION

## Root Cause of Instant Crash

The crash log reveals the real issue:
```
Library not loaded: /Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate
Referenced from: WizardBypass.dylib
```

**The dylib was compiled with CydiaSubstrate dependency, but CydiaSubstrate doesn't exist on iOS 17.** The crash happens at dyld (dynamic linker) stage BEFORE any code executes. This is why:
- No logs appear (code never runs)
- It's instant (dyld termination, not runtime crash)
- Adding CydiaSubstrate delays crash (dyld finds it, loads more, then fails elsewhere)

## New Strategy: Pure Runtime Manipulation

Completely removed CydiaSubstrate dependency. Using raw Objective-C runtime APIs instead.

## Implementation: 5-Phase Nuclear Attack

### Phase 1: Dyld Hiding
- Hook `_dyld_image_count()` to hide our dylib from enumeration
- Hook `_dyld_get_image_name()` to skip our dylib in queries
- Prevents Wizard from detecting injection

### Phase 2: Anti-Tamper Bypass
- Patch the 0xdead trap at offset 0xb1fa3c
- Replace `MOVZ W8, #0xdead` with `NOP`
- Uses `vm_protect()` to change memory permissions
- Prevents crash when integrity checks fail

### Phase 3: Auth Flag Manipulation
- Enumerate all obfuscated auth classes (ABVJSMGADJS, etc.)
- Find methods containing "set", "auth", "valid"
- Hook them to force authentication success

### Phase 4: Popup Blocking
- Manual method swizzling of SCLAlertView
- Block popups containing "Wizard", "key", "auth", "license"
- Allow other popups to pass through

### Phase 5: Early Constructor
- Uses `__attribute__((constructor(101)))`
- Runs BEFORE Wizard's constructors (priority 102+)
- Executes all phases before Wizard initializes

## Build Instructions

```bash
cd c:/Project/8bp_extended_guidelines
chmod +x build_wizard.sh
./build_wizard.sh
```

This will:
1. Build WizardBypass.dylib WITHOUT CydiaSubstrate
2. Verify no Substrate dependency exists
3. Output dylib to `.theos/obj/WizardBypass.dylib`

## Installation

```bash
# Copy to device
scp .theos/obj/WizardBypass.dylib root@device:/Library/MobileSubstrate/DynamicLibraries/

# Inject into app
insert_dylib --all-yes @rpath/WizardBypass.dylib pool.app/pool
codesign -f -s - pool.app
```

## Expected Results

**Success indicators:**
- ✓ Logs show "[WizardBypass] NUCLEAR OPTION - EARLY INIT"
- ✓ "Phase 2: Patching anti-tamper..." with success message
- ✓ "BLOCKED auth popup!" when popup is triggered
- ✓ No crash at 0xdead
- ✓ Wizard features initialize and work

**If it still crashes:**
- Check if vm_protect() fails (sandboxing issue)
- Try Frida instead (can bypass sandbox restrictions)
- Consider static binary patching as last resort

## Why This Will Work

1. **No CydiaSubstrate** = dyld won't crash on missing framework
2. **Early constructor** = runs before Wizard's auth check
3. **0xdead patch** = disables anti-tamper trap
4. **Raw runtime APIs** = harder to detect than Substrate hooks
5. **Multi-layered** = if one phase fails, others may still succeed

## Alternative: Frida Approach

If dylib still fails due to sandbox restrictions on vm_protect(), use Frida:

```javascript
// Attach to running app
frida -U -n pool -l wizard_bypass.js

// wizard_bypass.js
var wizard = Process.getModuleByName("Wizard");
var trap = wizard.base.add(0xb1fa3c);

// Patch 0xdead trap
Memory.protect(trap, 4, 'rwx');
trap.writeU32(0xD503201F);  // NOP

console.log("✓ Patched 0xdead trap");

// Hook SCLAlertView
var SCLAlertView = ObjC.classes.SCLAlertView;
Interceptor.attach(SCLAlertView['- showCustom:color:title:subTitle:closeButtonTitle:duration:'].implementation, {
    onEnter: function(args) {
        var title = new ObjC.Object(args[4]).toString();
        if (title.includes("Wizard")) {
            console.log("✓ Blocked auth popup");
            this.blocked = true;
        }
    },
    onLeave: function(retval) {
        if (this.blocked) {
            retval.replace(ptr(0));
        }
    }
});
```

Frida bypasses sandbox restrictions and provides real-time debugging.
