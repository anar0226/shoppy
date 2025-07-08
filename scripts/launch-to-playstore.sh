#!/bin/bash

# Shoppy Google Play Store Launch Script
# Run this script to prepare your app for Google Play Store

echo "🚀 Shoppy Google Play Store Launch Script"
echo "=========================================="

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed. Please install Flutter first."
    exit 1
fi

# Check Flutter doctor
echo "📋 Checking Flutter installation..."
flutter doctor

# Clean project
echo "🧹 Cleaning project..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Check for any issues
echo "🔍 Analyzing code..."
flutter analyze

# Build for testing
echo "🔨 Building debug version for testing..."
flutter build apk --debug

# Check if keystore exists
if [ ! -f "android/shoppy.keystore" ]; then
    echo "🔑 Keystore not found. Creating new keystore..."
    echo "Please run the following command manually:"
    echo "keytool -genkey -v -keystore android/shoppy.keystore -alias shoppy -keyalg RSA -keysize 2048 -validity 10000"
    echo ""
    echo "Then create android/key.properties with:"
    echo "storePassword=your_keystore_password"
    echo "keyPassword=your_key_password"
    echo "keyAlias=shoppy"
    echo "storeFile=shoppy.keystore"
    exit 1
fi

# Check if key.properties exists
if [ ! -f "android/key.properties" ]; then
    echo "❌ key.properties not found. Please create it with your keystore details."
    exit 1
fi

# Build release APK
echo "🔨 Building release APK..."
flutter build apk --release

# Build App Bundle (recommended for Play Store)
echo "📦 Building App Bundle..."
flutter build appbundle --release

# Check if builds were successful
if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    echo "✅ APK built successfully: build/app/outputs/flutter-apk/app-release.apk"
    echo "📱 APK size: $(du -h build/app/outputs/flutter-apk/app-release.apk | cut -f1)"
else
    echo "❌ APK build failed"
    exit 1
fi

if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
    echo "✅ App Bundle built successfully: build/app/outputs/bundle/release/app-release.aab"
    echo "📦 AAB size: $(du -h build/app/outputs/bundle/release/app-release.aab | cut -f1)"
else
    echo "❌ App Bundle build failed"
    exit 1
fi

echo ""
echo "🎉 Build completed successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Upload app-release.aab to Google Play Console"
echo "2. Complete store listing information"
echo "3. Submit for review"
echo ""
echo "📁 Build files:"
echo "- APK: build/app/outputs/flutter-apk/app-release.apk"
echo "- AAB: build/app/outputs/bundle/release/app-release.aab"
echo ""
echo "🔗 Google Play Console: https://play.google.com/console" 