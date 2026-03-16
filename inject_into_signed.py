#!/usr/bin/env python3
"""
Inject WizardBypass.dylib into already-signed IPA
No re-signing needed - preserves existing signature
"""

import os
import sys
import shutil
import zipfile
from pathlib import Path

def inject_into_signed_ipa(signed_ipa, bypass_dylib, output_ipa):
    """Inject dylib into already-signed IPA without re-signing"""

    print("=" * 70)
    print("Inject Dylib into Signed IPA")
    print("=" * 70)
    print()
    print("[*] This will inject the dylib WITHOUT re-signing")
    print("[*] The existing signature will be preserved")
    print()

    temp_dir = Path("temp_inject_signed")
    if temp_dir.exists():
        shutil.rmtree(temp_dir)
    temp_dir.mkdir()

    try:
        # Extract signed IPA
        print(f"[*] Extracting: {signed_ipa}")
        with zipfile.ZipFile(signed_ipa, 'r') as zip_ref:
            zip_ref.extractall(temp_dir)

        # Find app bundle
        payload_dir = temp_dir / "Payload"
        app_dirs = list(payload_dir.glob("*.app"))

        if not app_dirs:
            print("[!] Error: No .app bundle found")
            return False

        app_bundle = app_dirs[0]
        print(f"[*] Found: {app_bundle.name}")

        # Inject bypass dylib
        frameworks_dir = app_bundle / "Frameworks"
        if not frameworks_dir.exists():
            frameworks_dir.mkdir()
            print("[*] Created Frameworks directory")

        bypass_dest = frameworks_dir / Path(bypass_dylib).name
        print(f"[*] Injecting: {bypass_dest.name}")
        shutil.copy2(bypass_dylib, bypass_dest)
        print("[+] Dylib injected successfully")

        # Repackage with maximum compression
        print(f"[*] Repackaging to: {output_ipa}")
        with zipfile.ZipFile(output_ipa, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as zip_out:
            for root, dirs, files in os.walk(temp_dir):
                for file in files:
                    file_path = Path(root) / file
                    arcname = file_path.relative_to(temp_dir)
                    zip_out.write(file_path, arcname)

        size_mb = os.path.getsize(output_ipa) / (1024*1024)
        print(f"[+] Created: {output_ipa} ({size_mb:.2f} MB)")

        print()
        print("=" * 70)
        print("[+] SUCCESS!")
        print("=" * 70)
        print()
        print("[*] Installation methods:")
        print("    1. Sideloadly: Drag and drop (no dylib injection needed)")
        print("    2. AltStore: Drag and drop")
        print("    3. ideviceinstaller: ideviceinstaller -i", output_ipa)
        print()
        print("[*] After installation:")
        print("    1. Launch the app")
        print("    2. Check logs: idevicesyslog | findstr WizardBypass")
        print()
        print("[*] Expected logs:")
        print("    [WizardBypass] EARLY INIT - Priority 101")
        print("    [WizardBypass] 0xdead trap patched successfully!")
        print("    [WizardBypass] SCLAlertView showCustom blocked")
        print()
        return True

    finally:
        if temp_dir.exists():
            shutil.rmtree(temp_dir)

def main():
    if len(sys.argv) < 3:
        print("Usage: python inject_into_signed.py <signed_ipa> <bypass_dylib> [output]")
        print("\nExample:")
        print('  python inject_into_signed.py WizardiOS_8BP_signed.ipa WizardBypass.dylib')
        print()
        print("Note: This uses the already-signed IPA, no re-signing needed!")
        sys.exit(1)

    signed_ipa = sys.argv[1]
    bypass_dylib = sys.argv[2]
    output_ipa = sys.argv[3] if len(sys.argv) > 3 else "pool_wizard_bypassed_ready.ipa"

    if not os.path.exists(signed_ipa):
        print(f"[!] Error: Signed IPA not found: {signed_ipa}")
        sys.exit(1)

    if not os.path.exists(bypass_dylib):
        print(f"[!] Error: Bypass dylib not found: {bypass_dylib}")
        sys.exit(1)

    success = inject_into_signed_ipa(signed_ipa, bypass_dylib, output_ipa)

    if not success:
        sys.exit(1)

if __name__ == "__main__":
    main()
