#!/usr/bin/env python3
"""
Complete Wizard Bypass Injector with Signing
Injects WizardBypass.dylib and signs with zsign for direct installation
"""

import os
import sys
import shutil
import zipfile
import subprocess
from pathlib import Path

def inject_and_sign(ipa_path, bypass_dylib, output_name="pool_wizard_bypassed_signed.ipa"):
    """Inject bypass dylib and sign with zsign"""

    print("=" * 70)
    print("Wizard Bypass - Inject and Sign")
    print("=" * 70)
    print()

    # Step 1: Inject dylib
    print("[*] Step 1: Injecting WizardBypass.dylib")
    print("-" * 70)

    temp_dir = Path("temp_inject_sign")
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

        # Inject bypass dylib
        frameworks_dir = app_bundle / "Frameworks"
        if not frameworks_dir.exists():
            frameworks_dir.mkdir()

        bypass_dest = frameworks_dir / Path(bypass_dylib).name
        print(f"[*] Injecting: {bypass_dest.name}")
        shutil.copy2(bypass_dylib, bypass_dest)
        print("[+] Dylib injected successfully")

        # Repackage (unsigned)
        unsigned_ipa = "pool_wizard_bypassed_unsigned.ipa"
        print(f"[*] Repackaging to: {unsigned_ipa}")
        with zipfile.ZipFile(unsigned_ipa, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as zip_out:
            for root, dirs, files in os.walk(temp_dir):
                for file in files:
                    file_path = Path(root) / file
                    arcname = file_path.relative_to(temp_dir)
                    zip_out.write(file_path, arcname)

        size_mb = os.path.getsize(unsigned_ipa) / (1024*1024)
        print(f"[+] Created unsigned IPA: {size_mb:.2f} MB")

        # Step 2: Sign with zsign
        print()
        print("[*] Step 2: Signing with zsign")
        print("-" * 70)

        zsign_path = r"C:\Project\zsign.exe"
        if not os.path.exists(zsign_path):
            print("[!] ERROR: zsign not found at C:\\Project\\zsign.exe")
            print(f"[*] Unsigned IPA available at: {unsigned_ipa}")
            print("[!] You'll need to sign manually with Sideloadly")
            return False

        cert_path = r"C:\Users\ray\Downloads\Telegram Desktop\[ ELI GAMING ] - 00008020-00124DEC2663002E.p12"
        provision_path = r"C:\Users\ray\Downloads\Telegram Desktop\1 - [ ELI GAMING ] - 00008020-00124DEC2663002E.mobileprovision"
        password = "1"

        if not os.path.exists(cert_path):
            print(f"[!] ERROR: Certificate not found at: {cert_path}")
            return False

        if not os.path.exists(provision_path):
            print(f"[!] ERROR: Provisioning profile not found at: {provision_path}")
            return False

        print("[*] Certificate found")
        print("[*] Provisioning profile found")
        print("[*] Signing IPA...")

        cmd = [
            zsign_path,
            "-k", cert_path,
            "-m", provision_path,
            "-p", password,
            "-z", "9",  # Maximum compression
            "-o", output_name,
            unsigned_ipa
        ]

        result = subprocess.run(cmd, capture_output=True, text=True)

        if result.returncode == 0:
            print(f"[+] Successfully signed!")

            # Clean up unsigned IPA
            if os.path.exists(unsigned_ipa):
                os.remove(unsigned_ipa)
                print("[*] Cleaned up temporary files")

            signed_size_mb = os.path.getsize(output_name) / (1024*1024)
            print()
            print("=" * 70)
            print("[+] SUCCESS!")
            print("=" * 70)
            print(f"\n[*] Signed IPA: {output_name}")
            print(f"[*] Size: {signed_size_mb:.2f} MB")
            print()
            print("[*] Installation methods:")
            print("    1. AltStore: Drag and drop the IPA")
            print("    2. Sideloadly: Drag and drop (no dylib injection needed)")
            print("    3. ideviceinstaller: ideviceinstaller -i pool_wizard_bypassed_signed.ipa")
            print("    4. iTunes/Finder: Drag to device")
            print()
            print("[*] After installation:")
            print("    1. Launch the app")
            print("    2. Check logs: idevicesyslog | findstr WizardBypass")
            print()
            print("[*] Expected behavior:")
            print("    - No authentication popup")
            print("    - Logs show '[WizardBypass] EARLY INIT - Priority 101'")
            print("    - Logs show '[WizardBypass] 0xdead trap patched successfully!'")
            print("    - All Wizard features should work")
            print()
            return True
        else:
            print(f"[!] Signing failed!")
            print(f"[!] Error: {result.stderr}")
            print(f"[*] Unsigned IPA available at: {unsigned_ipa}")
            return False

    finally:
        if temp_dir.exists():
            shutil.rmtree(temp_dir)

def main():
    if len(sys.argv) < 3:
        print("Usage: python inject_and_sign.py <wizard_ipa> <bypass_dylib> [output]")
        print("\nExample:")
        print('  python inject_and_sign.py "WizardiOS_8BP.ipa" WizardBypass.dylib')
        sys.exit(1)

    ipa_path = sys.argv[1]
    bypass_dylib = sys.argv[2]
    output_name = sys.argv[3] if len(sys.argv) > 3 else "pool_wizard_bypassed_signed.ipa"

    if not os.path.exists(ipa_path):
        print(f"[!] Error: IPA not found: {ipa_path}")
        sys.exit(1)

    if not os.path.exists(bypass_dylib):
        print(f"[!] Error: Bypass dylib not found: {bypass_dylib}")
        sys.exit(1)

    success = inject_and_sign(ipa_path, bypass_dylib, output_name)

    if not success:
        sys.exit(1)

if __name__ == "__main__":
    main()
