@echo off
:: 🚀 Shoppy CI/CD Setup Script (Windows)
:: This script helps set up the GitHub Actions CI/CD pipeline

echo 🚀 Setting up Shoppy CI/CD Pipeline
echo ==================================

:: Check if GitHub CLI is installed
where gh >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ GitHub CLI is not installed.
    echo Please install it from: https://cli.github.com/
    pause
    exit /b 1
)

:: Check if user is logged in to GitHub CLI
gh auth status >nul 2>&1
if %errorlevel% neq 0 (
    echo ⚠️ You're not logged in to GitHub CLI.
    echo Please run: gh auth login
    pause
    exit /b 1
)

echo.
echo 🔐 Setting up GitHub Secrets
echo =============================

echo.
echo Setting up required secrets...
echo.

:: Required secrets array (simulated with goto labels)
call :setup_secret "FIREBASE_TOKEN" "Firebase CI token (run: firebase login:ci)"
call :setup_secret "ANDROID_KEYSTORE" "Base64 encoded Android keystore file"
call :setup_secret "ANDROID_KEYSTORE_PASSWORD" "Android keystore password"
call :setup_secret "ANDROID_KEY_PASSWORD" "Android key password"
call :setup_secret "ANDROID_KEY_ALIAS" "Android key alias"
call :setup_secret "GOOGLE_PLAY_SERVICE_ACCOUNT" "Google Play Console service account JSON"
call :setup_secret "SLACK_WEBHOOK_URL" "Slack webhook URL for notifications"

echo.
echo 📱 iOS Secrets (Optional)
echo =========================
echo The following secrets are only needed if you plan to build and deploy iOS apps:
echo.

set /p setup_ios="Do you want to set up iOS deployment secrets? (y/N): "
if /i "%setup_ios%"=="y" (
    call :setup_secret "APPLE_CERTIFICATE" "Base64 encoded Apple certificate (.p12)"
    call :setup_secret "APPLE_CERTIFICATE_PASSWORD" "Apple certificate password"
    call :setup_secret "APPLE_PROVISIONING_PROFILE" "Base64 encoded provisioning profile"
    call :setup_secret "APP_STORE_CONNECT_API_KEY" "App Store Connect API key"
    call :setup_secret "APP_STORE_CONNECT_ISSUER_ID" "App Store Connect issuer ID"
    call :setup_secret "APP_STORE_CONNECT_KEY_ID" "App Store Connect key ID"
)

echo.
echo 🚀 Workflow Files
echo =================

:: Check if workflow files exist
set workflows=.github\workflows\ci-cd.yml .github\workflows\pr-validation.yml .github\workflows\security-scan.yml .github\workflows\release.yml

for %%w in (%workflows%) do (
    if exist "%%w" (
        echo ✅ Workflow file exists: %%w
    ) else (
        echo ❌ Workflow file missing: %%w
    )
)

echo.
echo 📋 Next Steps
echo =============
echo.
echo 1. 🔑 Firebase Setup:
echo    - Run: firebase login:ci
echo    - Copy the token and set it as FIREBASE_TOKEN secret
echo.
echo 2. 🤖 Android Setup:
echo    - Generate a release keystore
echo    - Encode it as base64 and set as ANDROID_KEYSTORE secret
echo    - Set up Google Play Console service account
echo.
echo 3. 🍎 iOS Setup (if needed):
echo    - Generate Apple certificates and provisioning profiles
echo    - Set up App Store Connect API keys
echo.
echo 4. 🔔 Notifications:
echo    - Set up Slack webhook for team notifications
echo    - Configure SMTP for email alerts
echo.
echo 5. 🧪 Test the Pipeline:
echo    - Create a pull request to test PR validation
echo    - Push to main branch to test full CI/CD
echo    - Create a tag (v1.0.0) to test release workflow
echo.

echo ✅ CI/CD setup complete! 🎉
echo Check the GitHub Actions tab to see your workflows in action.
echo.

echo Useful Commands:
echo - View workflow runs: gh run list
echo - View specific run: gh run view ^<run-id^>
echo - View secrets: gh secret list
echo - Trigger workflow: gh workflow run ci-cd.yml
echo.

echo Happy deploying! 🚀
pause
exit /b 0

:: Function to setup a secret
:setup_secret
set secret_name=%~1
set secret_description=%~2

echo.
echo Setting up: %secret_name%
echo Description: %secret_description%

:: Check if secret already exists
gh secret list | findstr /C:"%secret_name%" >nul 2>&1
if %errorlevel% equ 0 (
    echo ⚠️ Secret %secret_name% already exists.
    set /p update_secret="Do you want to update it? (y/N): "
    if not /i "!update_secret!"=="y" goto :eof
)

set /p secret_value="Enter value for %secret_name% (or press Enter to skip): "
if "%secret_value%"=="" (
    echo Skipping %secret_name%
    goto :eof
)

gh secret set "%secret_name%" --body "%secret_value%"
if %errorlevel% equ 0 (
    echo ✅ Secret %secret_name% set successfully
) else (
    echo ❌ Failed to set secret %secret_name%
)
goto :eof 