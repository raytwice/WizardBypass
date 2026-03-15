#!/usr/bin/env python3
"""
Wizard Bypass - Runtime Hooks Only (No Binary Patching)
Avoids triggering anti-tamper by not modifying the binary
"""

import os
import sys
import shutil
import zipfile
from pathlib import Path

def inject_bypass_only(ipa_path, bypass_dylib, output_ipa):
    """Inject bypass dylib WITHOUT patching the binary"""

    print(f"\n[*] Processing {ipa_path}")
    print("[!] Using runtime hooks only (no binary patching)")

    temp_dir = Path("temp_wizard_bypass")
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

        # Inject bypass dylib (DO NOT TOUCH Wizard.framework binary)
        frameworks_dir = app_bundle / "Frameworks"
        if not frameworks_dir.exists():
            frameworks_dir.mkdir()

        bypass_dest = frameworks_dir / Path(bypass_dylib).name
        print(f"[*] Injecting bypass dylib: {bypass_dest.name}")
        print("[!] Wizard.framework binary left UNTOUCHED (avoids anti-tamper)")
        shutil.copy2(bypass_dylib, bypass_dest)

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

def sign_ipa(ipa_path):
    """Sign IPA using zsign"""
    import subprocess

    print(f"\n[*] Signing IPA with zsign...")

    zsign_path = r"C:\Project\zsign.exe"
    if not os.path.exists(zsign_path):
        print("[!] zsign not found at C:\\Project\\zsign.exe")
        return None

    cert_path = r"C:\Users\ray\Downloads\Telegram Desktop\[ ELI GAMING ] - 00008020-00124DEC2663002E.p12"
    provision_path = r"C:\Users\ray\Downloads\Telegram Desktop\1 - [ ELI GAMING ] - 00008020-00124DEC2663002E.mobileprovision"
    password = "1"

    if not os.path.exists(cert_path) or not os.path.exists(provision_path):
        print("[!] Certificate or provisioning profile not found")
        return None

    signed_ipa = ipa_path.replace(".ipa", "_signed.ipa")
    cmd = [zsign_path, "-k", cert_path, "-m", provision_path, "-p", password, "-z", "9", "-o", signed_ipa, ipa_path]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode == 0:
            print(f"[+] Successfully signed: {signed_ipa}")
            return signed_ipa
        else:
            print(f"[!] Signing failed: {result.stderr}")
            return None
    except Exception as e:
        print(f"[!] Error: {e}")
        return None

def main():
    print("=" * 70)
    print("Wizard Bypass - Runtime Hooks Only (Anti-Tamper Safe)")
    print("=" * 70)
    print()
    print("[!] IMPORTANT: This version does NOT patch the binary")
    print("[!] Wizard detected binary modifications and crashed at 0xdead")
    print("[!] Using runtime hooks only to avoid anti-tamper detection")
    print()

    if len(sys.argv) < 3:
        print("Usage: python bypass_wizard_safe.py <wizard_ipa> <bypass_dylib>")
        sys.exit(1)

    ipa_path = sys.argv[1]
    bypass_dylib = sys.argv[2]
    output_ipa = "pool_wizard_bypassed.ipa"

    if not os.path.exists(ipa_path):
        print(f"[!] Error: IPA not found: {ipa_path}")
        sys.exit(1)

    if not os.path.exists(bypass_dylib):
        print(f"[!] Error: Bypass dylib not found: {bypass_dylib}")
        sys.exit(1)

    success = inject_bypass_only(ipa_path, bypass_dylib, output_ipa)

    if success:
        print("\n" + "=" * 70)
        print("[+] BYPASS INJECTION COMPLETE!")
        print("=" * 70)
        print(f"\n[*] Output: {output_ipa}")
        print("\n[*] What was done:")
        print("    1. Injected WizardBypass.dylib (runtime hooks)")
        print("    2. Left Wizard.framework binary UNTOUCHED")
        print("    3. Avoided triggering anti-tamper protection")

        # Auto-sign
        signed_ipa = sign_ipa(output_ipa)

        if signed_ipa:
            print("\n" + "=" * 70)
            print("[+] SIGNING COMPLETE!")
            print("=" * 70)
            print(f"\n[*] Signed IPA: {signed_ipa}")
            print("\n[*] Ready to install!")
            print("\n[*] Next steps:")
            print("    1. Install with Sideloadly/AltStore")
            print("    2. Launch the app")
            print("    3. Check logs: idevicesyslog | grep WizardBypass")
            print("\n[*] Expected behavior:")
            print("    - App should NOT crash at 0xdead")
            print("    - SCLAlertView popups blocked")
            print("    - Validation methods return YES")
            print("    - Check logs for '[WizardBypass]' messages")
        else:
            print("\n[!] Auto-signing failed. Sign manually with Sideloadly.")
    else:
        print("\n[!] Bypass injection failed!")
        sys.exit(1)

if __name__ == "__main__":
    main()
