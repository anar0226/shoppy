@echo off
echo 🔍 Getting SHA-1 Fingerprints for Google Sign-In
echo ================================================

echo.
echo 📱 Debug Keystore SHA-1:
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android | findstr "SHA1"

echo.
echo 🔑 Release Keystore SHA-1:
echo Please enter the correct password for your release keystore:
keytool -list -v -keystore "android\avii.keystore" -alias upload

echo.
echo 📋 Instructions:
echo 1. Copy the SHA-1 fingerprints above
echo 2. Go to Firebase Console ^> Project Settings ^> Your Apps ^> Android
echo 3. Add the SHA-1 fingerprints to your Firebase project
echo 4. Download the updated google-services.json
echo 5. Replace the existing google-services.json file

pause 