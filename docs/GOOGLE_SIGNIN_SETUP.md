# Google Sign-In Setup for Release Builds

## 🔍 Problem Description

When running `flutter run --release`, Google Sign-In fails with:
```
PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 10: null,)
```

This happens because Firebase doesn't have the correct SHA-1 fingerprints for your release build.

## 🛠️ Solution Steps

### Step 1: Get SHA-1 Fingerprints

Run the script to get your fingerprints:
```bash
# Windows
scripts\get-sha1-fingerprints.bat

# Or manually:
# Debug fingerprint
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android

# Release fingerprint (you'll need the correct password)
keytool -list -v -keystore "android\avii.keystore" -alias upload
```

### Step 2: Update Firebase Project

1. **Go to Firebase Console**: https://console.firebase.google.com/
2. **Select your project**: `shoppy-6d81f`
3. **Go to Project Settings** (gear icon)
4. **Select your Android app**: `com.avii.marketplace`
5. **Add SHA-1 fingerprints**:
   - Debug SHA-1: `23:4B:8E:8D:A4:C3:4B:FF:E0:B9:81:AB:8D:A4:95:90:90:05:B5:D0:F0:B1:04:01:A4:50:8F:31:8A:9D:6E:AC`
   - Release SHA-1: (get from step 1)
6. **Download updated google-services.json**
7. **Replace the file**: `android/app/google-services.json`

### Step 3: Verify Configuration

Your `google-services.json` should have this structure for your package:

```json
{
  "client_info": {
    "mobilesdk_app_id": "1:110394685689:android:1f1320d2fb6f710242ca28",
    "android_client_info": {
      "package_name": "com.avii.marketplace"
    }
  },
  "oauth_client": [
    {
      "client_id": "110394685689-xxxxx.apps.googleusercontent.com",
      "client_type": 1,
      "android_info": {
        "package_name": "com.avii.marketplace",
        "certificate_hash": "YOUR_SHA1_FINGERPRINT_HERE"
      }
    }
  ]
}
```

### Step 4: Test the Fix

```bash
# Clean and rebuild
flutter clean
flutter pub get

# Test release build
flutter run --release
```

## 🔧 Alternative: Use Debug Build for Testing

If you need to test Google Sign-In immediately:

```bash
# Use debug build (works with debug SHA-1)
flutter run --debug
```

## 🚨 Common Issues

### Issue 1: Wrong Keystore Password
**Error**: `keystore password was incorrect`

**Solution**: 
1. Check your `android/key.properties` file
2. Verify the password matches your keystore
3. If unsure, regenerate the keystore

### Issue 2: Missing SHA-1 in Firebase
**Error**: `ApiException: 10`

**Solution**:
1. Add both debug and release SHA-1 to Firebase
2. Download and replace `google-services.json`
3. Clean and rebuild the project

### Issue 3: Package Name Mismatch
**Error**: `ApiException: 12501`

**Solution**:
1. Verify package name in `android/app/build.gradle`
2. Ensure Firebase project has the correct package name
3. Check `google-services.json` matches your package

## 📱 Production Firebase Project

### What "Create Production Firebase Project" Means

When I mentioned "Create Production Firebase Project", I meant:

1. **Keep your current Firebase project** (`shoppy-6d81f`) - this is fine for production
2. **Your database and data will remain intact**
3. **No need to migrate data**

The current setup is actually good for production. You just need to:
- Add the correct SHA-1 fingerprints
- Configure proper security rules
- Set up production environment variables

### Current Firebase Project Status

✅ **Good for Production**:
- Your current Firebase project `shoppy-6d81f` is production-ready
- All your data (users, products, orders) will remain
- No migration needed

⚠️ **Needs Fixing**:
- Add SHA-1 fingerprints for Google Sign-In
- Update security rules for production
- Configure proper environment variables

## 🔐 Security Best Practices

1. **Never commit keystore files** to version control
2. **Use different Firebase projects** for development and production (optional)
3. **Rotate API keys** regularly
4. **Monitor Firebase usage** and costs
5. **Set up proper security rules**

## 📞 Support

If you continue having issues:

1. **Check Firebase Console** for any error messages
2. **Verify SHA-1 fingerprints** are correct
3. **Ensure google-services.json** is up to date
4. **Test with debug build** first
5. **Check Android Studio logs** for detailed error messages 