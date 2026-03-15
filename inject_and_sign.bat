@echo off
REM Quick injection and signing script for 8BP Extended Guidelines

set CERT="C:\Users\ray\Downloads\Telegram Desktop\[ ELI GAMING ] - 00008020-00124DEC2663002E.p12"
set PROVISION="C:\Users\ray\Downloads\Telegram Desktop\1 - [ ELI GAMING ] - 00008020-00124DEC2663002E.mobileprovision"
set IPA="C:\Users\ray\Desktop\8 Ball Pool_56.5.0_1752510191.ipa"
set DYLIB="ExtendedGuidelines.dylib"

echo ========================================
echo 8BP Extended Guidelines - Inject and Sign
echo ========================================
echo.

REM Check if dylib exists
if not exist %DYLIB% (
    echo [!] Error: %DYLIB% not found!
    echo [!] Download it from GitHub Actions artifacts first.
    pause
    exit /b 1
)

REM Check if zsign exists
where zsign >nul 2>&1
if errorlevel 1 (
    echo [!] Warning: zsign not found in PATH
    echo [!] Download from: https://github.com/zhlynn/zsign
    echo.
    echo [*] Continuing without signing...
    python inject.py %IPA% %DYLIB% -o pool_extended.ipa
) else (
    echo [*] Found zsign, will sign after injection
    echo.

    REM Prompt for password
    set /p PASSWORD="Enter certificate password: "

    python inject.py %IPA% %DYLIB% -o pool_extended.ipa -c %CERT% -m %PROVISION% -p "%PASSWORD%"
)

echo.
echo ========================================
echo Done!
echo ========================================
pause
