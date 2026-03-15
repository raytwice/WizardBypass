# 8 Ball Pool Extended Guidelines

Advanced guideline prediction system with multi-bounce trajectory visualization.

## Features

- **Extended Guidelines**: Shows full ball path beyond the default guideline
- **Multi-Bounce Prediction**: Calculates and displays up to 5 cushion bounces
- **Color-Coded Trajectories**: Different colors for each bounce segment
- **Physics-Based**: Accurate trajectory calculation with energy loss simulation

## Files

- `Tweak.x` - Main tweak source code (Objective-C with Logos)
- `Makefile` - Theos build configuration
- `control` - Package metadata
- `build.sh` - Build script (requires macOS/Linux with iOS toolchain)
- `inject.py` - Python script to inject dylib into IPA

## Building

### Option 1: Build on macOS (Recommended)

1. Install Theos:
   ```bash
   bash -c "$(curl -fsSL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos)"
   ```

2. Build the tweak:
   ```bash
   make package
   ```

3. The dylib will be in `.theos/obj/ExtendedGuidelines.dylib`

### Option 2: Manual Compilation

```bash
chmod +x build.sh
./build.sh
```

### Option 3: Use Pre-compiled Dylib

Since you're on Windows, you'll need to either:
- Build on a Mac/Linux machine with iOS toolchain
- Use a CI/CD service (GitHub Actions) to build
- Modify existing Wizard dylib

## Injection

### Using the Python Script

```bash
python inject.py input.ipa ExtendedGuidelines.dylib output.ipa
```

### Manual Injection

1. Unzip the IPA
2. Copy `ExtendedGuidelines.dylib` to `Payload/pool.app/Frameworks/`
3. Use `insert_dylib` or `optool` to add load command to the binary
4. Re-sign and repackage

## How It Works

The tweak hooks into the `TableLineView` class methods:
- `addLine:destination:color:width:gradientRatio:drawTips:`
- `addLine:destination:color:width:gradientRatio:drawTips:blend:`

When the game draws the guideline, our hook:
1. Calls the original method (preserves default guideline)
2. Calculates extended trajectory using physics
3. Detects wall collisions and calculates bounce angles
4. Draws additional colored line segments for each bounce

## Physics Model

- Table boundaries with ball radius offset
- Reflection physics for cushion bounces
- Energy damping (5% loss per bounce)
- Maximum 5 bounces to prevent infinite loops

## Color Scheme

- Yellow: First bounce
- Orange: Second bounce
- Red: Third bounce
- Purple: Fourth bounce
- Blue: Fifth bounce

## Next Steps for Windows Users

Since you can't compile on Windows, here are your options:

1. **Use GitHub Actions**: I can create a workflow to auto-build
2. **Modify Wizard's dylib**: Patch the existing dylib with our logic
3. **Use WSL2**: Install Ubuntu on WSL2 and set up iOS toolchain
4. **Cloud Build**: Use a Mac VM or cloud service

Which approach would you prefer?
