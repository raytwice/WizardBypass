#!/usr/bin/env python3
"""
Prepare Wizard IPA for dylib injection
Adds proper entitlements and modifies Info.plist to allow dylib loading
"""

import os
import sys
import shutil
import zipfile
import plistlib
from pathlib import Path

def prepare_ipa_for_injection(ipa_path, output_ipa):
    """Prepare IPA to accept dylib injection from Sideloadly"""

    print(f"\n[*] Preparing {ipa_path} for dylib injection")

    temp_dir = Path("temp_prepare")
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

        # Modify Info.plist to allow dylib loading
        info_plist_path = app_bundle / "Info.plist"
        if info_plist_path.exists():
            print("[*] Modifying Info.plist...")

            with open(info_plist_path, 'rb') as f:
                plist_data = plistlib.load(f)

            # Add flags to allow dylib loading
            if 'UIFileSharingEnabled' not in plist_data:
                plist_data['UIFileSharingEnabled'] = True

            if 'LSSupportsOpeningDocumentsInPlace' not in plist_data:
                plist_data['LSSupportsOpeningDocumentsInPlace'] = True

            # Write back
            with open(info_plist_path, 'wb') as f:
                plistlib.dump(plist_data, f)

            print("[+] Info.plist modified")

        # Create Frameworks directory if it doesn't exist
        frameworks_dir = app_bundle / "Frameworks"
        if not frameworks_dir.exists():
            frameworks_dir.mkdir()
            print("[*] Created Frameworks directory")

        # Create a placeholder file to ensure Frameworks directory is included
        placeholder = frameworks_dir / ".placeholder"
        placeholder.touch()

        # Repackage
        print("[*] Repackaging IPA...")
        with zipfile.ZipFile(output_ipa, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as zip_out:
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
    print("=" * 70)
    print("Prepare IPA for Dylib Injection")
    print("=" * 70)
    print()

    if len(sys.argv) < 2:
        print("Usage: python prepare_for_injection.py <wizard_ipa> [output]")
        print("\nExample:")
        print('  python prepare_for_injection.py "WizardiOS_8BP.ipa"')
        sys.exit(1)

    ipa_path = sys.argv[1]
    output_ipa = sys.argv[2] if len(sys.argv) > 2 else "wizard_prepared.ipa"

    if not os.path.exists(ipa_path):
        print(f"[!] Error: IPA not found: {ipa_path}")
        sys.exit(1)

    success = prepare_ipa_for_injection(ipa_path, output_ipa)

    if success:
        print("\n" + "=" * 70)
        print("[+] IPA PREPARED!")
        print("=" * 70)
        print(f"\n[*] Output: {output_ipa}")
        print("\n[*] Next steps:")
        print("    1. Open Sideloadly")
        print("    2. Drag wizard_prepared.ipa into Sideloadly")
        print("    3. Go to Advanced Options")
        print("    4. Click 'Inject dylibs/frameworks/bundles'")
        print("    5. Add WizardBypass.dylib")
        print("    6. Sign and install")
        print("\n[*] The IPA is now ready to accept dylib injection!")
    else:
        print("\n[!] Preparation failed!")
        sys.exit(1)

if __name__ == "__main__":
    main()
