#!/usr/bin/env python3
"""
Wizard IPA Bypass Injector
Removes Wizard.framework authentication and injects bypass dylib
"""

import os
import sys
import shutil
import zipfile
from pathlib import Path

def remove_wizard_and_inject_bypass(ipa_path, bypass_dylib, output_ipa):
    """Remove Wizard.framework and inject bypass dylib"""

    print(f"[*] Processing {ipa_path}")
    print(f"[*] Removing Wizard.framework authentication")
    print(f"[*] Injecting bypass: {bypass_dylib}")

    # Create temp directory
    temp_dir = Path("temp_wizard_bypass")
    if temp_dir.exists():
        shutil.rmtree(temp_dir)
    temp_dir.mkdir()

    try:
        # Extract IPA
        print("[*] Extracting IPA...")
        with zipfile.ZipFile(ipa_path, 'r') as zip_ref:
            zip_ref.extractall(temp_dir)

        # Find the app bundle
        payload_dir = temp_dir / "Payload"
        app_dirs = list(payload_dir.glob("*.app"))

        if not app_dirs:
            print("[!] Error: No .app bundle found in IPA")
            return False

        app_bundle = app_dirs[0]
        print(f"[*] Found app bundle: {app_bundle.name}")

        # Remove Wizard.framework (keep the dylib but remove authentication)
        frameworks_dir = app_bundle / "Frameworks"
        wizard_framework = frameworks_dir / "Wizard.framework"

        if wizard_framework.exists():
            print(f"[*] Found Wizard.framework at {wizard_framework}")

            # Keep the framework but we'll inject our bypass
            print("[*] Keeping Wizard.framework (will bypass authentication)")
        else:
            print("[!] Warning: Wizard.framework not found")

        # Copy bypass dylib into Frameworks
        if not frameworks_dir.exists():
            frameworks_dir.mkdir()

        bypass_dest = frameworks_dir / Path(bypass_dylib).name
        print(f"[*] Copying bypass dylib to {bypass_dest}")
        shutil.copy2(bypass_dylib, bypass_dest)

        # Repackage IPA
        print("[*] Repackaging IPA...")
        with zipfile.ZipFile(output_ipa, 'w', zipfile.ZIP_DEFLATED) as zip_out:
            for root, dirs, files in os.walk(temp_dir):
                for file in files:
                    file_path = Path(root) / file
                    arcname = file_path.relative_to(temp_dir)
                    zip_out.write(file_path, arcname)

        print(f"[+] Successfully created: {output_ipa}")
        print(f"[*] Size: {os.path.getsize(output_ipa) / (1024*1024):.2f} MB")
        return True

    finally:
        # Cleanup
        if temp_dir.exists():
            shutil.rmtree(temp_dir)

def main():
    if len(sys.argv) < 3:
        print("Usage: python inject_bypass.py <wizard_ipa> <bypass_dylib> [output_ipa]")
        sys.exit(1)

    ipa_path = sys.argv[1]
    bypass_dylib = sys.argv[2]
    output_ipa = sys.argv[3] if len(sys.argv) > 3 else "pool_wizard_bypassed.ipa"

    if not os.path.exists(ipa_path):
        print(f"[!] Error: IPA not found: {ipa_path}")
        sys.exit(1)

    if not os.path.exists(bypass_dylib):
        print(f"[!] Error: Bypass dylib not found: {bypass_dylib}")
        sys.exit(1)

    success = remove_wizard_and_inject_bypass(ipa_path, bypass_dylib, output_ipa)

    if success:
        print("\n[+] Bypass injection complete!")
        print(f"[*] Output: {output_ipa}")
        print("[*] Sign with Sideloadly/AltStore and install")
        print("[*] The authentication popup should be blocked")
    else:
        print("\n[!] Bypass injection failed!")
        sys.exit(1)

if __name__ == "__main__":
    main()
