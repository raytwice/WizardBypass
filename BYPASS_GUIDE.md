# Wizard Authentication Bypass - Complete Solution

This is a comprehensive bypass that cracks Wizard's authentication system using two methods:
1. **Binary Patching**: Patches validation functions in Wizard.framework to always return true
2. **Runtime Hooking**: Hooks SCLAlertView and validation methods at runtime

## How It Works

### Binary Patching
- Finds functions that return `false` (0) and patches them to return `true` (1)
- Converts conditional branches (CBZ) to unconditional branches (B)
- Patches are applied directly to the Wizard binary before installation

### Runtime Hooking
- Blocks ALL SCLAlertView popups (prevents authentication UI)
- Hooks all obfuscated classes (ABVJSMGADJS, AJFADSHFSAJXN, etc.)
- Forces `isValid()` and `isAuthenticated()` methods to return YES
- Monitors Wizard.framework loading and file access

## Building the Bypass

### Option 1: GitHub Actions (Recommended)

1. Push to GitHub
2. Download `WizardBypass.dylib` from Actions artifacts

### Option 2: Local Build (macOS only)

```bash
cd c:\Project\8bp_extended_guidelines
export THEOS=~/theos
make -f Makefile.bypass clean
make -f Makefile.bypass package
```

The dylib will be in `.theos/obj/debug/WizardBypass.dylib`

## Cracking Wizard IPA

### Complete Solution (Recommended)

```bash
python crack_wizard.py "C:\Users\ray\Desktop\WizardiOS_8BP_56.18.0_18022026.ipa" WizardBypass.dylib
```

This will:
1. Extract the IPA
2. Patch Wizard.framework binary (validation functions)
3. Inject WizardBypass.dylib (runtime hooks)
4. Backup original Wizard binary
5. Repackage as `pool_wizard_cracked.ipa`

### Manual Binary Patching Only

```bash
# Extract IPA first
python patch_wizard.py "Payload/pool.app/Frameworks/Wizard.framework/Wizard"
```

This patches the binary in-place. Then repackage the IPA manually.

### Dylib Injection Only

```bash
python inject_bypass.py "WizardiOS_8BP.ipa" WizardBypass.dylib
```

This only injects the runtime hooks without binary patching.

## Installing

1. Sign with Sideloadly or AltStore
2. Install on device
3. Launch the app

## Verification

Check device logs to confirm the bypass is working:

```bash
idevicesyslog | grep WizardBypass
```

You should see:
```
[WizardBypass] ========================================
[WizardBypass] Wizard Authentication Bypass Loaded
[WizardBypass] All SCLAlertView popups will be blocked
[WizardBypass] Monitoring Wizard.framework initialization
```

## What Gets Bypassed

### Binary Level
- Validation functions that return false → patched to return true
- Conditional branches that check authentication → converted to unconditional

### Runtime Level
- SCLAlertView authentication popups → blocked
- License validation blocks → always return YES
- isValid() / isAuthenticated() methods → always return YES
- All obfuscated class validation → bypassed

## Troubleshooting

**Popup still shows:**
- The binary patching might not have caught all validation functions
- Check logs: `idevicesyslog | grep WizardBypass`
- Try the complete solution (crack_wizard.py) which does both patching + hooking

**App crashes on launch:**
- Wizard has integrity checks that detected the patches
- The binary patching might have corrupted the binary
- Try using only the dylib injection without binary patching

**Features don't work:**
- Some features might be server-side locked
- The authentication might be more complex than expected
- Check logs to see which methods are being called

**No logs appear:**
- The bypass dylib wasn't loaded
- Check that it's in the Frameworks directory
- Verify the IPA was signed correctly

## Advanced: Manual Analysis

If the bypass doesn't work, you can analyze what's happening:

```bash
# Monitor all method calls
idevicesyslog | grep -E "WizardBypass|Wizard|SCL"

# Check if Wizard.framework loaded
idevicesyslog | grep "Wizard.framework"

# See what popups are being blocked
idevicesyslog | grep "Blocking popup"
```

## Files

- `WizardBypass.x` - Main bypass tweak source
- `crack_wizard.py` - Complete cracking solution (patching + injection)
- `patch_wizard.py` - Binary patcher only
- `inject_bypass.py` - Dylib injector only
- `Makefile.bypass` - Build configuration
