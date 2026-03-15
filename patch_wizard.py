#!/usr/bin/env python3
"""
Binary Patcher for Wizard.framework
Patches validation functions to always return true
"""

import sys
import struct
from pathlib import Path

def patch_wizard_binary(binary_path, output_path):
    """Patch Wizard binary to bypass authentication"""

    print(f"[*] Reading {binary_path}")

    with open(binary_path, 'rb') as f:
        data = bytearray(f.read())

    original_size = len(data)
    patches_applied = 0

    print(f"[*] Binary size: {original_size} bytes")
    print(f"[*] Searching for validation patterns...")

    # Pattern 1: Functions that return 0 (false) - patch to return 1 (true)
    # ARM64: MOV W0, #0; RET -> MOV W0, #1; RET
    # Before: 00 00 80 52 C0 03 5F D6
    # After:  20 00 80 52 C0 03 5F D6
    pattern1 = bytes([0x00, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6])
    replacement1 = bytes([0x20, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6])

    offset = 0
    while True:
        offset = data.find(pattern1, offset)
        if offset == -1:
            break

        # Patch it
        data[offset:offset+len(replacement1)] = replacement1
        patches_applied += 1
        print(f"  [+] Patched validation at offset 0x{offset:x}")
        offset += len(pattern1)

    # Pattern 2: CMP + B.EQ (branch if equal) -> B (unconditional branch)
    # This bypasses conditional checks
    # Look for: CMP followed by B.EQ/B.NE
    # We'll convert B.EQ to B (always branch)

    # Pattern 3: CBZ/CBNZ (compare and branch if zero/non-zero)
    # Convert CBZ to B (always branch)
    # CBZ pattern: xx xx xx 34 (where xx varies)
    # B pattern: xx xx xx 14

    print(f"\n[*] Patching conditional branches...")

    # Search for CBZ instructions and convert to unconditional branches
    for i in range(0, len(data) - 4, 4):
        instr = struct.unpack('<I', data[i:i+4])[0]

        # Check if it's CBZ (opcode 0x34xxxxxx)
        if (instr & 0xFF000000) == 0x34000000:
            # Convert to B (unconditional branch)
            # Keep the offset, change opcode from 0x34 to 0x14
            new_instr = (instr & 0x00FFFFFF) | 0x14000000
            data[i:i+4] = struct.pack('<I', new_instr)
            patches_applied += 1

            if patches_applied % 100 == 0:
                print(f"  [+] Patched {patches_applied} conditional branches...")

    print(f"\n[+] Total patches applied: {patches_applied}")

    # Write patched binary
    print(f"[*] Writing patched binary to {output_path}")
    with open(output_path, 'wb') as f:
        f.write(data)

    print(f"[+] Done! Patched binary saved.")
    print(f"[*] Original size: {original_size} bytes")
    print(f"[*] Patched size: {len(data)} bytes")

    return patches_applied > 0

def main():
    if len(sys.argv) < 2:
        print("Usage: python patch_wizard.py <path_to_Wizard_binary> [output_path]")
        print("\nExample:")
        print("  python patch_wizard.py Payload/pool.app/Frameworks/Wizard.framework/Wizard")
        sys.exit(1)

    binary_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else binary_path + ".patched"

    if not Path(binary_path).exists():
        print(f"[!] Error: Binary not found: {binary_path}")
        sys.exit(1)

    print("[*] Wizard Binary Patcher")
    print("[*] This will patch validation functions to always return true")
    print()

    success = patch_wizard_binary(binary_path, output_path)

    if success:
        print("\n[+] Patching complete!")
        print(f"[*] Patched binary: {output_path}")
        print("\n[!] IMPORTANT:")
        print("    1. Replace the original Wizard binary with the patched one")
        print("    2. Re-sign the IPA with your certificate")
        print("    3. Install and test")
    else:
        print("\n[!] No patches applied - binary might already be patched or has different structure")

if __name__ == "__main__":
    main()
