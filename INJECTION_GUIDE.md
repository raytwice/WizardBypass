# Injection and Signing Guide

## Prerequisites

1. **Download the dylib** from GitHub Actions artifacts
2. **Install zsign** (optional, for automatic signing)
   - Download: https://github.com/zhlynn/zsign/releases
   - Extract `zsign.exe` to a folder in your PATH

## Quick Method (Automated)

Just run the batch script:

```bash
cd c:\Project\8bp_extended_guidelines
inject_and_sign.bat
```

This will:
1. Inject the dylib into the IPA
2. Sign it with your certificate (if zsign is installed)
3. Output `pool_extended_signed.ipa`

## Manual Method

### Option 1: With Signing (requires zsign)

```bash
python inject.py "C:\Users\ray\Desktop\8 Ball Pool_56.5.0_1752510191.ipa" ExtendedGuidelines.dylib -o pool_extended.ipa -c "C:\Users\ray\Downloads\Telegram Desktop\[ ELI GAMING ] - 00008020-00124DEC2663002E.p12" -m "C:\Users\ray\Downloads\Telegram Desktop\1 - [ ELI GAMING ] - 00008020-00124DEC2663002E.mobileprovision" -p "YOUR_PASSWORD"
```

### Option 2: Without Signing (use Sideloadly after)

```bash
python inject.py "C:\Users\ray\Desktop\8 Ball Pool_56.5.0_1752510191.ipa" ExtendedGuidelines.dylib -o pool_extended.ipa
```

Then sign with Sideloadly or AltStore.

## Command Line Options

```
python inject.py <ipa> <dylib> [options]

Required:
  ipa                   Input IPA file
  dylib                 Dylib to inject

Optional:
  -o, --output         Output IPA filename (default: pool_extended_guidelines.ipa)
  -c, --cert           Path to .p12 certificate
  -m, --mobileprovision Path to .mobileprovision file
  -p, --password       Certificate password
```

## Installing zsign

### Windows:
1. Download from https://github.com/zhlynn/zsign/releases
2. Extract `zsign.exe`
3. Add to PATH or place in project folder

### macOS/Linux:
```bash
git clone https://github.com/zhlynn/zsign.git
cd zsign
chmod +x build.sh
./build.sh
sudo cp zsign /usr/local/bin/
```

## Troubleshooting

**"zsign not found"**
- Install zsign or use Sideloadly to sign manually

**"Certificate not found"**
- Check the paths in `inject_and_sign.bat`
- Make sure the certificate files exist

**"Signing failed"**
- Verify certificate password is correct
- Check that mobileprovision matches the certificate

**App crashes on launch**
- The dylib might need adjustments for your game version
- Check device logs for crash details
