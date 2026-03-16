#!/bin/bash
# Manual compilation of WizardBypass.x
# Run this on macOS with Xcode installed

set -e

echo "Compiling WizardBypass.x manually..."

clang -arch arm64 \
    -isysroot $(xcrun --sdk iphoneos --show-sdk-path) \
    -miphoneos-version-min=13.0 \
    -dynamiclib \
    -o WizardBypass.dylib \
    WizardBypass.x \
    -framework Foundation \
    -framework UIKit \
    -framework QuartzCore \
    -fobjc-arc \
    -Wno-deprecated-declarations

echo "✓ Compiled WizardBypass.dylib"
echo ""
echo "Checking dependencies..."
otool -L WizardBypass.dylib

echo ""
echo "Signing with ad-hoc signature..."
codesign -f -s - WizardBypass.dylib

echo ""
echo "✓ Build complete!"
ls -lh WizardBypass.dylib
