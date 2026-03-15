#!/bin/bash

# Build script for Extended Guidelines tweak
# This compiles the tweak into a dylib for injection into 8 Ball Pool

echo "[*] Building Extended Guidelines tweak..."

# Check if we're on macOS/Linux with proper toolchain
if ! command -v clang &> /dev/null; then
    echo "[!] Error: clang not found. This needs to be built on macOS or Linux with iOS toolchain."
    echo "[!] Alternative: Use a pre-built dylib or build on a Mac."
    exit 1
fi

# Compile the tweak
clang -arch arm64 \
    -isysroot $(xcrun --sdk iphoneos --show-sdk-path) \
    -miphoneos-version-min=14.0 \
    -framework Foundation \
    -framework UIKit \
    -framework CoreGraphics \
    -framework QuartzCore \
    -dynamiclib \
    -o ExtendedGuidelines.dylib \
    Tweak.x \
    -fobjc-arc

if [ $? -eq 0 ]; then
    echo "[+] Build successful! Output: ExtendedGuidelines.dylib"
    echo "[*] Size: $(du -h ExtendedGuidelines.dylib | cut -f1)"
else
    echo "[!] Build failed!"
    exit 1
fi

# Sign the dylib
echo "[*] Signing dylib..."
codesign -f -s - ExtendedGuidelines.dylib

echo "[+] Done! Ready to inject into IPA."
