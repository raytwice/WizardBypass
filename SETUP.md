# GitHub Setup Guide

## Step 1: Create GitHub Repository

1. Go to https://github.com/new
2. Repository name: `8bp-extended-guidelines` (or any name you prefer)
3. Description: "Extended guideline prediction for 8 Ball Pool"
4. Make it **Private** (recommended for game cheats)
5. **Don't** initialize with README (we already have one)
6. Click "Create repository"

## Step 2: Push Code to GitHub

Run these commands in your terminal:

```bash
cd c:\Project\8bp_extended_guidelines

# Add your GitHub repository as remote (replace YOUR_USERNAME)
git remote add origin https://github.com/YOUR_USERNAME/8bp-extended-guidelines.git

# Push to GitHub
git branch -M main
git push -u origin main
```

## Step 3: GitHub Actions Will Auto-Build

Once pushed, GitHub Actions will automatically:
1. Detect the push
2. Spin up a macOS runner
3. Install Theos and iOS SDK
4. Compile the tweak
5. Upload the dylib as an artifact

## Step 4: Download the Built Dylib

1. Go to your repository on GitHub
2. Click "Actions" tab
3. Click on the latest workflow run
4. Scroll down to "Artifacts"
5. Download `ExtendedGuidelines-dylib`
6. Extract the `.dylib` file

## Step 5: Inject into IPA

Once you have the dylib:

```bash
cd c:\Project\8bp_extended_guidelines

# Inject into your IPA
python inject.py "C:\Users\ray\Desktop\8 Ball Pool_56.5.0_1752510191.ipa" ExtendedGuidelines.dylib pool_modded.ipa
```

## Step 6: Sign and Install

Use one of these tools to sign and install:
- **Sideloadly** (easiest for Windows)
- **AltStore**
- **iOS App Signer** (Mac)

## Troubleshooting

### Build fails on GitHub Actions
- Check the Actions log for errors
- The workflow might need SDK adjustments

### Injection fails
- Make sure the dylib is for arm64 architecture
- Check that the IPA is decrypted

### App crashes on launch
- The dylib might need code signing
- Table dimensions might need adjustment for your game version

## Alternative: Quick Test Without Building

If you want to test the concept first, you can:
1. Use Wizard's existing dylib as a base
2. Modify the table dimensions in `Tweak.x` to match your game version
3. Then build and inject

---

**Ready to push to GitHub?** Just replace `YOUR_USERNAME` in the git commands above with your actual GitHub username!
