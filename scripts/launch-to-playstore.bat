@echo off
REM Avii.mn Google Play Store Launch Script for Windows
REM Run this script to prepare your app for Google Play Store

echo 🚀 Avii.mn Google Play Store Launch Script
echo ==========================================

REM Check if Flutter is installed
where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ Flutter is not installed. Please install Flutter first.
    pause
    exit /b 1
)

REM Check Flutter doctor
echo 📋 Checking Flutter installation...
flutter doctor

REM Clean project
echo 🧹 Cleaning project...
flutter clean

REM Get dependencies
echo 📦 Getting dependencies...
flutter pub get

REM Check for any issues
echo 🔍 Analyzing code...
flutter analyze

REM Build for testing
echo 🔨 Building debug version for testing...
flutter build apk --debug

REM Check if keystore exists
if not exist "android\avii.keystore" (
    echo 🔑 Keystore not found. Creating new keystore...
    echo Please run the following command manually:
    echo keytool -genkey -v -keystore android\avii.keystore -alias avii -keyalg RSA -keysize 2048 -validity 10000
    echo.
    echo Then create android\key.properties with:
    echo storePassword=your_keystore_password
    echo keyPassword=your_key_password
    echo keyAlias=avii
    echo storeFile=avii.keystore
    pause
    exit /b 1
)

REM Check if key.properties exists
if not exist "android\key.properties" (
    echo ❌ key.properties not found. Please create it with your keystore details.
    pause
    exit /b 1
)

REM Build release APK
echo 🔨 Building release APK...
flutter build apk --release

REM Build App Bundle (recommended for Play Store)
echo 📦 Building App Bundle...
flutter build appbundle --release

REM Check if builds were successful
if exist "build\app\outputs\flutter-apk\app-release.apk" (
    echo ✅ APK built successfully: build\app\outputs\flutter-apk\app-release.apk
    for %%A in ("build\app\outputs\flutter-apk\app-release.apk") do echo 📱 APK size: %%~zA bytes
) else (
    echo ❌ APK build failed
    pause
    exit /b 1
)

if exist "build\app\outputs\bundle\release\app-release.aab" (
    echo ✅ App Bundle built successfully: build\app\outputs\bundle\release\app-release.aab
    for %%A in ("build\app\outputs\bundle\release\app-release.aab") do echo 📦 AAB size: %%~zA bytes
) else (
    echo ❌ App Bundle build failed
    pause
    exit /b 1
)

echo.
echo 🎉 Build completed successfully!
echo.
echo 📋 Next steps:
echo 1. Upload app-release.aab to Google Play Console
echo 2. Complete store listing information
echo 3. Submit for review
echo.
echo 📁 Build files:
echo - APK: build\app\outputs\flutter-apk\app-release.apk
echo - AAB: build\app\outputs\bundle\release\app-release.aab
echo.
echo 🔗 Google Play Console: https://play.google.com/console
pause 