#!/bin/bash
# Build WizardBypass.dylib without CydiaSubstrate dependency

set -e

echo "=========================================="
echo "Building WizardBypass.dylib (NO SUBSTRATE)"
echo "=========================================="

# Use the special Makefile
export THEOS_PACKAGE_SCHEME=rootless
make -f Makefile.wizard clean
make -f Makefile.wizard

echo ""
echo "=========================================="
echo "Checking dependencies..."
echo "=========================================="

DYLIB_PATH=".theos/obj/WizardBypass.dylib"

if [ -f "$DYLIB_PATH" ]; then
    echo "✓ WizardBypass.dylib built successfully"
    echo ""
    echo "Dependencies:"
    otool -L "$DYLIB_PATH"
    echo ""

    # Check for CydiaSubstrate
    if otool -L "$DYLIB_PATH" | grep -i "CydiaSubstrate"; then
        echo "❌ ERROR: CydiaSubstrate dependency found!"
        exit 1
    else
        echo "✓ No CydiaSubstrate dependency - GOOD!"
    fi

    echo ""
    echo "File size: $(ls -lh "$DYLIB_PATH" | awk '{print $5}')"
    echo ""
    echo "=========================================="
    echo "Build complete! Copy to device:"
    echo "  $DYLIB_PATH"
    echo "=========================================="
else
    echo "❌ ERROR: Build failed - dylib not found"
    exit 1
fi
