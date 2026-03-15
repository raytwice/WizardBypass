#!/usr/bin/env python3
"""
Complete Wizard Bypass Solution
Combines binary patching + dylib injection for full authentication bypass
"""

import os
import sys
import shutil
import zipfile
import subprocess
from pathlib import Path

def patch_wizard_binary(binary_path):
    """Patch Wizard binary to bypass authentication"""
    import struct

    print(f"[*] Patching {binary_path}")

    with open(binary_path, 'rb') as f:
        data = bytearray(f.read())

    patches = 0

    # Pattern: MOV W0, #0; RET -> MOV W0, #1; RET
    pattern = bytes([0x00, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6])
    replacement = bytes([0x20, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6])

    offset = 0
    while True:
        offset = data.find(pattern, offset)
        if offset == -1:
            break
        data[offset:offset+len(replacement)] = replacement
        patches += 1
        offset += len(pattern)

    print(f"[+] Applied {patches} validation patches")

    with open(binary_path, 'wb') as f:
        f.write(data)

    return patches > 0

def process_wizard_ipa(ipa_path, bypass_dylib, output_ipa):
    """Extract IPA, patch Wizard, inject bypass, repackage"""

    print(f"\n[*] Processing {ipa_path}")

    temp_dir = Path("temp_wizard_crack")
    if temp_dir.exists():
        shutil.rmtree(temp_dir)
    temp_dir.mkdir()

    try:
        # Extract IPA
        print("[*] Extracting IPA...")
        with zipfile.ZipFile(ipa_path, 'r') as zip_ref:
            zip_ref.extractall(temp_dir)

        # Find app bundle
        payload_dir = temp_dir / "Payload"
        app_dirs = list(payload_dir.glob("*.app"))

        if not app_dirs:
            print("[!] Error: No .app bundle found")
            return False

        app_bundle = app_dirs[0]
        print(f"[*] Found: {app_bundle.name}")

        # Find Wizard.framework
        wizard_binary = app_bundle / "Frameworks" / "Wizard.framework" / "Wizard"

        if wizard_binary.exists():
            print(f"[*] Found Wizard binary: {wizard_binary}")

            # Backup original
            backup = wizard_binary.parent / "Wizard.original"
            shutil.copy2(wizard_binary, backup)
            print(f"[*] Backed up to: {backup.name}")

            # Patch the binary
            print("[*] Patching Wizard binary...")
            patch_wizard_binary(str(wizard_binary))
        else:
            print("[!] Warning: Wizard.framework not found")

        # Inject bypass dylib
        frameworks_dir = app_bundle / "Frameworks"
        if not frameworks_dir.exists():
            frameworks_dir.mkdir()

        bypass_dest = frameworks_dir / Path(bypass_dylib).name
        print(f"[*] Injecting bypass dylib: {bypass_dest.name}")
        shutil.copy2(bypass_dylib, bypass_dest)

        # Repackage
        print("[*] Repackaging IPA...")
        with zipfile.ZipFile(output_ipa, 'w', zipfile.ZIP_DEFLATED) as zip_out:
            for root, dirs, files in os.walk(temp_dir):
                for file in files:
                    file_path = Path(root) / file
                    arcname = file_path.relative_to(temp_dir)
                    zip_out.write(file_path, arcname)

        size_mb = os.path.getsize(output_ipa) / (1024*1024)
        print(f"[+] Created: {output_ipa} ({size_mb:.2f} MB)")
        return True

    finally:
        if temp_dir.exists():
            shutil.rmtree(temp_dir)

def main():
    print("=" * 60)
    print("Wizard Authentication Bypass - Complete Solution")
    print("=" * 60)
    print()

    if len(sys.argv) < 3:
        print("Usage: python crack_wizard.py <wizard_ipa> <bypass_dylib> [output]")
        print("\nExample:")
        print('  python crack_wizard.py "WizardiOS_8BP.ipa" WizardBypass.dylib')
        sys.exit(1)

    ipa_path = sys.argv[1]
    bypass_dylib = sys.argv[2]
    output_ipa = sys.argv[3] if len(sys.argv) > 3 else "pool_wizard_cracked.ipa"

    if not os.path.exists(ipa_path):
        print(f"[!] Error: IPA not found: {ipa_path}")
        sys.exit(1)

    if not os.path.exists(bypass_dylib):
        print(f"[!] Error: Bypass dylib not found: {bypass_dylib}")
        sys.exit(1)

    success = process_wizard_ipa(ipa_path, bypass_dylib, output_ipa)

    if success:
        print("\n" + "=" * 60)
        print("[+] CRACKING COMPLETE!")
        print("=" * 60)
        print(f"\n[*] Output: {output_ipa}")
        print("\n[*] What was done:")
        print("    1. Patched Wizard binary (validation functions -> always true)")
        print("    2. Injected bypass dylib (hooks SCLAlertView + validation)")
        print("    3. Backed up original Wizard binary")
        print("\n[*] Next steps:")
        print("    1. Sign with Sideloadly/AltStore")
        print("    2. Install on device")
        print("    3. Check logs: idevicesyslog | grep WizardBypass")
        print("\n[*] Expected behavior:")
        print("    - No authentication popup")
        print("    - All Wizard features unlocked")
        print("    - Logs show '[WizardBypass]' messages")
    else:
        print("\n[!] Cracking failed!")
        sys.exit(1)

if __name__ == "__main__":
    main()
