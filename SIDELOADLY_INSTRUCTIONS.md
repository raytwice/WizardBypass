# Installing Wizard Bypass with Sideloadly

## Method 1: Let Sideloadly Inject the Dylib (RECOMMENDED)

1. **Download WizardBypass.dylib** from GitHub Actions:
   - Go to: https://github.com/raytwice/WizardBypass/actions
   - Click the latest successful run
   - Download "WizardBypass-dylib" artifact
   - Extract the .zip to get WizardBypass.dylib

2. **Open Sideloadly**

3. **Drag the ORIGINAL Wizard IPA** (not the one processed by Python script)
   - Use the clean Wizard IPA from your Desktop

4. **In Sideloadly, go to Advanced Options**:
   - Click "Inject dylibs/frameworks/bundles"
   - Add WizardBypass.dylib
   - Make sure "Remove UISupportedDevices" is checked
   - Make sure "Remove PlugIns" is unchecked

5. **Sign and Install**:
   - Enter your Apple ID
   - Click Start
   - Wait for installation to complete

## Method 2: Use Pre-Injected IPA (If Method 1 Fails)

If Sideloadly gives errors with dylib injection, try this:

1. **Run the Python script to inject the dylib**:
   ```cmd
   python bypass_wizard_safe.py "path\to\wizard.ipa" WizardBypass.dylib
   ```

2. **Use the UNSIGNED output** (pool_wizard_bypassed.ipa, NOT the _signed.ipa)

3. **Open Sideloadly and drag pool_wizard_bypassed.ipa**

4. **Sign and install normally** (don't inject any additional dylibs)

## Troubleshooting

### "Guru Meditation" Error
This usually means:
- The IPA structure is corrupted
- Try Method 1 (let Sideloadly do the injection)
- Make sure you're using the original Wizard IPA, not a modified one

### "Provision.cpp:173" Error
- Your provisioning profile doesn't match
- Try a different Apple ID
- Enable "Remove UISupportedDevices" in Advanced Options

### App Crashes on Launch
- Check device logs: `idevicesyslog | findstr WizardBypass`
- Look for "[WizardBypass]" messages
- If you see "Early Init - Priority 101", the dylib loaded successfully

## Expected Behavior

When successful, you should see in logs:
```
[WizardBypass] ========================================
[WizardBypass] EARLY INIT - Priority 101
[WizardBypass] Running BEFORE Wizard constructors
[WizardBypass] ========================================
[WizardBypass] Total dylibs loaded: XX
[WizardBypass] Constructor 102: Patching traps
[WizardBypass] Attempting to patch 0xdead trap...
[WizardBypass] Found Wizard at: 0xXXXXXXXX
[WizardBypass] 0xdead trap patched successfully!
```

And NO authentication popup should appear.
