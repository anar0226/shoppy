@echo off
echo 🔧 Generating mock classes...

REM Clean previous generated files
flutter packages pub run build_runner clean

REM Generate new mock files
flutter packages pub run build_runner build --delete-conflicting-outputs

echo ✅ Mock classes generated successfully!
echo 📁 Generated files are in: lib/generated/
pause 