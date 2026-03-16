# WizardBypass v4 - Binary Analysis Edition

## Summary

After analyzing the Wizard.framework binary, we discovered the ACTUAL methods being used and updated the hooks accordingly.

## What Changed

### Before (v1-v3): Blind Guessing ❌
- Hooked only 2 specific methods
- Popup still appeared
- No idea why it wasn't working

### After (v4): Binary Analysis ✅
- Analyzed 32MB Wizard.framework binary
- Found the REAL entry points
- Hooked the actual methods Wizard uses

## Key Discoveries from Binary Analysis

### 1. The Missing Entry Points
```objc
// WE WERE MISSING THESE!
- (void)showAlertView:
- (void)showAlertView:onViewController:
```

These are the MAIN methods Wizard calls to show the popup. All our previous hooks were on internal methods that were never reached.

### 2. The Builder Pattern
```objc
SCLAlertViewShowBuilder  // Builder class for constructing alerts
```

Wizard uses a builder pattern to construct and show alerts. We now hook ALL methods in this class.

### 3. Complete Method List
Found 20+ show methods in SCLAlertView:
- showAlertView: ← **CRITICAL**
- showAlertView:onViewController: ← **CRITICAL**
- showCustom:color:title:subTitle:closeButtonTitle:duration:
- showTitle:subTitle:style:closeButtonTitle:duration:
- showSuccess:subTitle:closeButtonTitle:duration:
- showError:subTitle:closeButtonTitle:duration:
- showInfo:subTitle:closeButtonTitle:duration:
- showNotice:subTitle:closeButtonTitle:duration:
- showQuestion:subTitle:closeButtonTitle:duration:
- showEdit:subTitle:closeButtonTitle:duration:
- And more...

## Updated Hook Strategy

### Priority 1: Critical Entry Points
```objc
hook_scl_alert_view() {
    // Hook showAlertView: FIRST
    // Hook showAlertView:onViewController: FIRST
    // Then hook all other show* methods as backup
}
```

### Priority 2: Builder Pattern
```objc
hook_scl_alert_view_show_builder() {
    // Hook ALL methods in SCLAlertViewShowBuilder
    // Return self for chaining but don't show anything
}
```

### Priority 3: Backup Hooks
- UIAlertController
- UIViewController presentation
- UIWindow makeKeyAndVisible/addSubview

## Technical Fixes

### Block Capture Issue
Fixed compilation error by using `strdup()` to copy method names before capturing in blocks:

```objc
// WRONG (causes undefined behavior)
IMP new_imp = imp_implementationWithBlock(^(id self) {
    NSLog(@"Blocked: %s", name);  // 'name' is loop variable!
});

// CORRECT
char* name_copy = strdup(name);
IMP new_imp = imp_implementationWithBlock(^(id self) {
    NSLog(@"Blocked: %s", name_copy);  // Safe copy
});
```

## Expected Results

### Confidence: 90%+

The popup should now be blocked because:
1. ✅ We hook the ACTUAL entry points Wizard uses
2. ✅ We hook the builder pattern class
3. ✅ We hook all backup methods
4. ✅ We hook at multiple levels (SCLAlertView, UIViewController, UIWindow)

### What to Look For in Logs

**Success indicators:**
```
[WizardBypass] ✓✓✓ BLOCKED CRITICAL: showAlertView: ✓✓✓
[WizardBypass] ✓✓✓ BLOCKED SCLAlertViewShowBuilder::... ✓✓✓
```

**If popup still appears:**
- Check logs for any method calls we missed
- Capture full syslog to see the actual call stack

## Build Status

Latest build: https://github.com/raytwice/WizardBypass/actions

Once build completes:
1. Download WizardBypass.dylib artifact
2. Inject with Sideloadly
3. Install on device
4. Capture logs: `idevicesyslog | findstr WizardBypass`
5. Launch app and check for "BLOCKED CRITICAL" messages

## Lessons Learned

### 1. Always Analyze the Binary First
- 5 minutes of binary analysis > hours of guessing
- Strings extraction reveals actual method names
- Pattern matching finds Objective-C signatures

### 2. Hook Entry Points, Not Internal Methods
- Wizard calls `showAlertView:` → which calls internal methods
- We were hooking the internal methods (too late!)
- Hook at the entry point to catch everything

### 3. Use Multiple Analysis Tools
- Python for string extraction
- Pattern matching for method signatures
- Manual inspection for understanding flow

## Next Steps

1. **Test the new dylib** - Should block popup now
2. **If popup is blocked** - Investigate how to enable Wizard features
3. **If popup still appears** - Capture full syslog and analyze what we missed

## Files

- `/c/Project/8bp_extended_guidelines/WizardBypass.x` - Updated source
- `/c/Users/ray/Desktop/wizard_analysis/BINARY_ANALYSIS_FINDINGS.md` - Detailed findings
- `/c/Users/ray/Desktop/wizard_analysis/analyze_wizard.py` - Analysis script

---

**You were right** - we should have analyzed the binary from the start instead of guessing! 🎯
