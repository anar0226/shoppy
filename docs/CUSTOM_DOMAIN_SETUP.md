# Custom Domain Authentication Setup

This guide explains how to configure your Flutter web app to use custom authentication action URLs like `avii.mn/_/auth/action`.

## Overview

The implementation allows you to use your own domain (`avii.mn`) for Firebase Auth action URLs instead of the default Firebase domain. This provides a more professional and branded experience for your users.

## Files Created/Modified

### 1. Configuration Files
- `lib/core/config/auth_action_config.dart` - Configuration for custom action URLs
- `lib/core/services/custom_auth_service.dart` - Custom authentication service
- `web/auth-action.html` - Web page to handle auth actions

### 2. Cloud Functions
- `functions/src/custom-auth-actions.ts` - Firebase Cloud Functions for custom auth actions

### 3. Updated Auth Providers
- `lib/features/auth/providers/auth_provider.dart` - Updated to use custom action URLs

## Domain Configuration

### 1. DNS Setup
You need to configure your domain `avii.mn` to point to your web hosting service. The `/_/auth/action` path should be handled by your web server.

### 2. Web Server Configuration
Configure your web server to serve the `auth-action.html` file when users visit `avii.mn/_/auth/action`.

#### Apache Configuration
```apache
# Add to your .htaccess file or Apache config
RewriteEngine On
RewriteRule ^_/auth/action$ /auth-action.html [L]
```

#### Nginx Configuration
```nginx
# Add to your nginx server block
location /_/auth/action {
    try_files /auth-action.html =404;
}
```

### 3. Firebase Console Configuration
1. Go to Firebase Console > Authentication > Settings
2. In the "Authorized domains" section, add `avii.mn`
3. This allows Firebase Auth to work with your custom domain

## How It Works

### 1. Email Verification Flow
1. User requests email verification
2. App calls `sendEmailVerification()` with custom action URL
3. Firebase generates action link with `avii.mn/_/auth/action` as the URL
4. User clicks link in email
5. `auth-action.html` page handles the verification
6. User is redirected to your app

### 2. Password Reset Flow
1. User requests password reset
2. App calls `sendPasswordResetEmail()` with custom action URL
3. Firebase generates reset link with `avii.mn/_/auth/action` as the URL
4. User clicks link in email
5. `auth-action.html` page validates the reset code
6. User can enter new password

## Implementation Details

### Custom Action URL Format
```
https://avii.mn/_/auth/action?mode=verifyEmail&oobCode=ABC123&continueUrl=https://avii.mn/dashboard
```

### Parameters
- `mode`: Action type (`verifyEmail`, `resetPassword`, `recoverEmail`)
- `oobCode`: Firebase action code
- `continueUrl`: URL to redirect after action completion
- `lang`: Language preference (optional)

## Testing

### 1. Local Testing
1. Build your Flutter web app: `flutter build web`
2. Serve the web build directory
3. Test email verification and password reset flows

### 2. Production Testing
1. Deploy the updated code
2. Deploy the Cloud Functions
3. Test with real email addresses
4. Verify custom action URLs work correctly

## Security Considerations

1. **HTTPS Required**: Ensure your domain uses HTTPS for security
2. **Domain Validation**: Firebase validates the domain in the action URL
3. **Action Code Expiry**: Action codes expire after a set time
4. **Rate Limiting**: Implement rate limiting for auth actions

## Troubleshooting

### Common Issues

1. **Domain Not Authorized**
   - Add `avii.mn` to Firebase Console authorized domains

2. **Action URL Not Working**
   - Check web server configuration
   - Verify `auth-action.html` is accessible
   - Check browser console for errors

3. **Email Not Received**
   - Check spam folder
   - Verify email address is correct
   - Check Firebase Auth logs

### Debug Steps

1. Check Firebase Console > Authentication > Users for action status
2. Monitor Cloud Function logs for errors
3. Test action URLs manually in browser
4. Verify DNS and web server configuration

## Deployment Checklist

- [ ] Deploy updated Flutter web app
- [ ] Deploy Cloud Functions
- [ ] Configure web server for `/_/auth/action` path
- [ ] Add `avii.mn` to Firebase authorized domains
- [ ] Test email verification flow
- [ ] Test password reset flow
- [ ] Verify custom action URLs work
- [ ] Monitor for errors in production

## Support

If you encounter issues:
1. Check Firebase Console logs
2. Review Cloud Function logs
3. Test with different email providers
4. Verify domain configuration 