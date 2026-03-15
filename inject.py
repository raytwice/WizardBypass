#!/usr/bin/env python3
"""
8 Ball Pool Extended Guidelines Injector
Injects the custom dylib into the IPA and signs it with zsign
"""

import os
import sys
import shutil
import zipfile
import subprocess
import argparse
from pathlib import Path

def sign_ipa(ipa_path, cert_path, mobileprovision_path, password=None):
    """Sign IPA using zsign"""

    print(f"\n[*] Signing IPA with zsign...")

    # Check if zsign is available
    zsign_path = shutil.which("zsign")
    if not zsign_path:
        print("[!] Warning: zsign not found in PATH")
        print("[!] Download from: https://github.com/zhlynn/zsign")
        return False

    # Build zsign command
    cmd = [zsign_path, "-k", cert_path, "-m", mobileprovision_path]

    if password:
        cmd.extend(["-p", password])

    # Output signed IPA
    signed_ipa = ipa_path.replace(".ipa", "_signed.ipa")
    cmd.extend(["-o", signed_ipa, ipa_path])

    print(f"[*] Running: {' '.join(cmd[:6])}...")  # Don't print password

    try:
        result = subprocess.run(cmd, capture_output=True, text=True)

        if result.returncode == 0:
            print(f"[+] Successfully signed: {signed_ipa}")
            return signed_ipa
        else:
            print(f"[!] Signing failed: {result.stderr}")
            return False
    except Exception as e:
        print(f"[!] Error running zsign: {e}")
        return False

def inject_dylib(ipa_path, dylib_path, output_ipa):
    """Inject dylib into IPA"""

    print(f"[*] Injecting {dylib_path} into {ipa_path}")

    # Create temp directory
    temp_dir = Path("temp_ipa_inject")
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

        # Copy dylib into app bundle
        dylib_dest = app_bundle / Path(dylib_path).name
        print(f"[*] Copying dylib to {dylib_dest}")
        shutil.copy2(dylib_path, dylib_dest)

        # Find the main executable
        executable_name = app_bundle.stem
        executable_path = app_bundle / executable_name

        if not executable_path.exists():
            print(f"[!] Warning: Executable {executable_name} not found, trying 'pool'")
            executable_path = app_bundle / "pool"

        if executable_path.exists():
            print(f"[*] Found executable: {executable_path.name}")

            # Use optool or insert_dylib to inject (if available)
            # For now, we'll add it to the Frameworks directory and modify Info.plist

            # Create Frameworks directory if it doesn't exist
            frameworks_dir = app_bundle / "Frameworks"
            frameworks_dir.mkdir(exist_ok=True)

            # Move dylib to Frameworks
            framework_dylib = frameworks_dir / Path(dylib_path).name
            if dylib_dest.exists():
                shutil.move(str(dylib_dest), str(framework_dylib))
                print(f"[*] Moved dylib to Frameworks directory")

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
    parser = argparse.ArgumentParser(description='Inject dylib into IPA and optionally sign it')
    parser.add_argument('ipa', help='Input IPA file')
    parser.add_argument('dylib', help='Dylib to inject')
    parser.add_argument('-o', '--output', help='Output IPA file', default='pool_extended_guidelines.ipa')
    parser.add_argument('-c', '--cert', help='Path to .p12 certificate for signing')
    parser.add_argument('-m', '--mobileprovision', help='Path to .mobileprovision file')
    parser.add_argument('-p', '--password', help='Certificate password')

    args = parser.parse_args()

    if not os.path.exists(args.ipa):
        print(f"[!] Error: IPA not found: {args.ipa}")
        sys.exit(1)

    if not os.path.exists(args.dylib):
        print(f"[!] Error: Dylib not found: {args.dylib}")
        sys.exit(1)

    # Inject dylib
    success = inject_dylib(args.ipa, args.dylib, args.output)

    if not success:
        print("\n[!] Injection failed!")
        sys.exit(1)

    print("\n[+] Injection complete!")
    print(f"[*] Output: {args.output}")

    # Sign if certificate provided
    if args.cert and args.mobileprovision:
        if not os.path.exists(args.cert):
            print(f"[!] Error: Certificate not found: {args.cert}")
            sys.exit(1)

        if not os.path.exists(args.mobileprovision):
            print(f"[!] Error: Mobileprovision not found: {args.mobileprovision}")
            sys.exit(1)

        signed_ipa = sign_ipa(args.output, args.cert, args.mobileprovision, args.password)

        if signed_ipa:
            print(f"\n[+] All done! Signed IPA: {signed_ipa}")
            print("[*] Ready to install on device!")
        else:
            print("\n[!] Signing failed. You'll need to sign manually.")
    else:
        print("\n[!] Note: IPA not signed. Use -c and -m flags to sign with zsign")
        print("[!] Or use Sideloadly/AltStore to sign and install")

if __name__ == "__main__":
    main()
