# Production App Signing Setup

## Overview

This guide covers setting up proper production app signing for Android releases. The app is now configured to use release signing instead of debug signing for production builds.

## ⚠️ Important Security Notes

- **Never commit keystore files or key.properties to version control**
- **Store keystore files securely with multiple backups**
- **Use strong passwords for keystore and key**
- **Keep keystore information confidential**

## Step 1: Generate Production Keystore

### Using Android Studio
1. Open Android Studio
2. Go to `Build` → `Generate Signed Bundle / APK`
3. Select `Android App Bundle` or `APK`
4. Click `Create new...` under Key store path
5. Fill in the keystore information:
   - **Key store path**: `android/upload-keystore.jks`
   - **Password**: Use a strong password
   - **Key alias**: `upload`
   - **Key password**: Use a strong password
   - **Validity**: 25 years minimum
   - **Certificate info**: Fill with your company details

### Using Command Line
```bash
# Navigate to android directory
cd android

# Generate keystore
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# Follow prompts to set passwords and certificate details
```

## Step 2: Update key.properties

Update the `android/key.properties` file with your actual values:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```

## Step 3: Verify Configuration

### Check Files
Ensure these files exist:
- `android/key.properties` (with your passwords)
- `android/upload-keystore.jks` (your keystore file)
- `android/app/proguard-rules.pro` (ProGuard rules)

### Verify .gitignore
The following should be in `android/.gitignore`:
```
key.properties
**/*.keystore
**/*.jks
```

## Step 4: Build Production Release

### Build App Bundle (Recommended)
```bash
# From project root
flutter build appbundle --release
```

### Build APK
```bash
# From project root
flutter build apk --release
```

## Step 5: Google Play Console Setup

### Upload Key Certificate
1. Go to Google Play Console
2. Navigate to your app → Setup → App integrity
3. Upload the certificate from your keystore:
   ```bash
   keytool -export -rfc -keystore upload-keystore.jks -alias upload -file upload_certificate.pem
   ```

### Enable App Signing
- Google Play will re-sign your app with the app signing key
- Your upload key is used to verify uploads
- This provides additional security

## Security Best Practices

### Keystore Management
- **Backup**: Store multiple encrypted backups in different locations
- **Access**: Limit access to keystore files and passwords
- **Rotation**: Consider key rotation policies for high-security apps

### Environment Variables (CI/CD)
For automated builds, use environment variables:
```bash
# In your CI/CD system
export STORE_PASSWORD=your_store_password
export KEY_PASSWORD=your_key_password
export KEY_ALIAS=upload
export STORE_FILE=upload-keystore.jks
```

Update `android/key.properties` for CI/CD:
```properties
storePassword=${STORE_PASSWORD}
keyPassword=${KEY_PASSWORD}
keyAlias=${KEY_ALIAS}
storeFile=${STORE_FILE}
```

## Troubleshooting

### Common Issues

**Build fails with "keystore not found"**
- Verify `android/upload-keystore.jks` exists
- Check the path in `key.properties`

**Build fails with "wrong password"**
- Verify passwords in `key.properties` match keystore
- Check for special characters in passwords

**ProGuard/R8 issues**
- Review `android/app/proguard-rules.pro`
- Add specific rules for your plugins if needed

### Verification Commands
```bash
# Check keystore details
keytool -list -v -keystore android/upload-keystore.jks

# Verify signed APK
jarsigner -verify -verbose -certs app-release.apk
```

## Production Checklist

- [ ] Production keystore generated
- [ ] `key.properties` updated with real values
- [ ] Keystore files backed up securely
- [ ] `.gitignore` prevents committing signing files
- [ ] Release build tested successfully
- [ ] Google Play Console configured
- [ ] CI/CD updated with environment variables

## Next Steps

After completing app signing setup:
1. Test release build thoroughly
2. Upload to Google Play Console for internal testing
3. Configure CI/CD for automated signing
4. Set up release management process

## Support

For issues with app signing:
- Check Flutter documentation: https://flutter.dev/docs/deployment/android
- Review Android signing documentation: https://developer.android.com/studio/publish/app-signing
- Consult Google Play Console help for app signing key management 