@echo off
echo ========================================
echo 8BP Extended Guidelines - GitHub Setup
echo ========================================
echo.

REM Check git config
git config --global user.name >nul 2>&1
if errorlevel 1 (
    echo [!] Git not configured. Let's set it up:
    echo.
    set /p username="Enter your GitHub username: "
    set /p email="Enter your GitHub email: "

    git config --global user.name "%username%"
    git config --global user.email "%email%"

    echo [+] Git configured!
    echo.
)

echo Current git config:
for /f "tokens=*" %%a in ('git config --global user.name') do echo   Name: %%a
for /f "tokens=*" %%a in ('git config --global user.email') do echo   Email: %%a
echo.

set /p gh_user="Enter your GitHub username: "
set /p repo_name="Enter repository name [8bp-extended-guidelines]: "
if "%repo_name%"=="" set repo_name=8bp-extended-guidelines

echo.
echo ========================================
echo Next Steps
echo ========================================
echo.
echo 1. Create a new repository on GitHub:
echo    https://github.com/new
echo.
echo    - Name: %repo_name%
echo    - Private: Yes (recommended)
echo    - Don't initialize with README
echo.
echo 2. After creating the repo, run these commands:
echo.
echo    cd c:\Project\8bp_extended_guidelines
echo    git remote add origin https://github.com/%gh_user%/%repo_name%.git
echo    git branch -M main
echo    git push -u origin main
echo.
echo 3. GitHub Actions will automatically build the dylib
echo.
echo 4. Download the artifact from the Actions tab
echo.
echo 5. Use inject.py to inject into your IPA
echo.

pause
