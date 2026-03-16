================================================================================
LIBIMOBILEDEVICE SYSLOG COMMANDS
================================================================================

INSTALL LIBIMOBILEDEVICE (if not installed):
--------------------------------------------
# macOS:
brew install libimobiledevice

# Windows (via Scoop):
scoop install libimobiledevice

# Linux:
sudo apt-get install libimobiledevice-utils


BASIC SYSLOG (Real-time):
--------------------------
idevicesyslog | grep WizardBypass


FILTER FOR SPECIFIC EVENTS:
----------------------------
# Icon creation:
idevicesyslog | grep -E "WizardBypass.*(FORCE CREATE|Created Wizard|Vmasfisahf|Added Wizard icon)"

# Tap events:
idevicesyslog | grep -E "WizardBypass.*(didTap|tap|touch|gesture)"

# Menu events:
idevicesyslog | grep -E "WizardBypass.*(menu|show|present)"

# All important events:
idevicesyslog | grep -E "WizardBypass.*(didTap|menu|Created|BLOCKED|auth)"


SAVE TO FILE:
-------------
idevicesyslog > wizard_log.txt
# Then in another terminal, tail it:
tail -f wizard_log.txt | grep WizardBypass


COLORED OUTPUT (easier to read):
---------------------------------
idevicesyslog | grep --color=always WizardBypass


SPECIFIC DEVICE (if multiple connected):
-----------------------------------------
# List devices:
idevice_id -l

# Use specific device:
idevicesyslog -u <UDID> | grep WizardBypass


WINDOWS POWERSHELL:
-------------------
idevicesyslog | Select-String "WizardBypass"


WHAT TO LOOK FOR AFTER TAP:
----------------------------
✓ [WizardBypass] 🔵 didTapIconView CALLED
✓ [WizardBypass] Calling original didTapIconView
✓ [WizardBypass] Original returned: ...
✓ [WizardBypass] Attempting to show menu manually
✓ [WizardBypass] Menu class found: ...
✓ [WizardBypass] Menu created: ...
✓ [WizardBypass] Menu presented


TROUBLESHOOTING:
----------------
# If idevicesyslog shows nothing:
1. Check device is connected: idevice_id -l
2. Trust the computer on device
3. Check if device is in developer mode (iOS 16+)

# If no WizardBypass messages:
1. Check dylib is loaded: idevicesyslog | grep "dylib"
2. Check app is running: idevicesyslog | grep "pool"

================================================================================
