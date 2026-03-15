#!/usr/bin/env python3
"""
8 Ball Pool Extended Guidelines Injector
Injects the custom dylib into the IPA
"""

import os
import sys
import shutil
import zipfile
import subprocess
from pathlib import Path

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
    if len(sys.argv) < 3:
        print("Usage: python inject.py <input.ipa> <tweak.dylib> [output.ipa]")
        print("\nExample:")
        print("  python inject.py pool.ipa ExtendedGuidelines.dylib pool_modded.ipa")
        sys.exit(1)

    ipa_path = sys.argv[1]
    dylib_path = sys.argv[2]
    output_ipa = sys.argv[3] if len(sys.argv) > 3 else "pool_extended_guidelines.ipa"

    if not os.path.exists(ipa_path):
        print(f"[!] Error: IPA not found: {ipa_path}")
        sys.exit(1)

    if not os.path.exists(dylib_path):
        print(f"[!] Error: Dylib not found: {dylib_path}")
        sys.exit(1)

    success = inject_dylib(ipa_path, dylib_path, output_ipa)

    if success:
        print("\n[+] Injection complete!")
        print(f"[*] Output: {output_ipa}")
        print("\n[!] Note: You'll need to re-sign the IPA before installing on device")
        print("[!] Use a tool like iOS App Signer or Sideloadly")
    else:
        print("\n[!] Injection failed!")
        sys.exit(1)

if __name__ == "__main__":
    main()
