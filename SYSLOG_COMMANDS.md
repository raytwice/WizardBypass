================================================================================
SYSLOG COMMANDS FOR TESTING WIZARD BYPASS
================================================================================

BASIC SYSLOG (All WizardBypass messages):
-----------------------------------------
ssh root@<device-ip>
log stream --predicate 'processImagePath contains "pool"' --level debug | grep WizardBypass


ALTERNATIVE (if above doesn't work):
------------------------------------
ssh root@<device-ip>
log stream --predicate 'eventMessage contains "WizardBypass"' --level debug


SAVE TO FILE:
-------------
ssh root@<device-ip>
log stream --predicate 'processImagePath contains "pool"' --level debug | grep WizardBypass > ~/wizard_log.txt


FILTER FOR SPECIFIC EVENTS:
----------------------------

# Icon creation only:
log stream --predicate 'processImagePath contains "pool"' --level debug | grep -E "WizardBypass.*(FORCE CREATE|Created Wizard|Vmasfisahf|Added Wizard icon)"

# Authentication hooks:
log stream --predicate 'processImagePath contains "pool"' --level debug | grep -E "WizardBypass.*(auth|license|valid)"

# Popup blocking:
log stream --predicate 'processImagePath contains "pool"' --level debug | grep -E "WizardBypass.*(BLOCKED|SCLAlertView)"


WHAT TO LOOK FOR:
-----------------
✓ [WizardBypass] FORCE CREATING WIZARD UI
✓ [WizardBypass] Found Pajdsakdfj class, creating instance...
✓ [WizardBypass] Calling initWithFrame:type:
✓ [WizardBypass] ✓✓✓ Created Wizard icon view: <Pajdsakdfj: 0x...>
✓ [WizardBypass] Found _Vmasfisahf ivar
✓ [WizardBypass] ✓ Created and set _Vmasfisahf UIImageView
✓ [WizardBypass] ✓ Added imageView as subview
✓ [WizardBypass] ✓✓✓ Added Wizard icon to window!
✓ [WizardBypass] Subviews: (...)


IF NOTHING SHOWS UP:
--------------------
# Check if dylib is loaded:
ssh root@<device-ip>
ps aux | grep pool
# Get the PID, then:
vmmap <PID> | grep Wizard

# Or check loaded libraries:
DYLD_PRINT_LIBRARIES=1 /var/containers/Bundle/Application/.../pool.app/pool


REAL-TIME MONITORING:
---------------------
# Open two terminals:

# Terminal 1 - Watch logs:
ssh root@<device-ip>
log stream --predicate 'processImagePath contains "pool"' --level debug | grep --line-buffered WizardBypass

# Terminal 2 - Launch app:
ssh root@<device-ip>
killall pool
open /var/containers/Bundle/Application/.../pool.app


EXPORT FULL LOG:
----------------
ssh root@<device-ip>
log show --predicate 'processImagePath contains "pool"' --last 5m | grep WizardBypass > wizard_full_log.txt
scp root@<device-ip>:~/wizard_full_log.txt .


QUICK TEST:
-----------
ssh root@<device-ip> "log stream --predicate 'processImagePath contains \"pool\"' --level debug | grep WizardBypass"

================================================================================
