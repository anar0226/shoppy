# Firebase Hosting Guide for Flutter Web App

This guide will help you deploy your Flutter web app to Firebase Hosting.

## Prerequisites

1. **Node.js and npm** - Required for Firebase CLI
2. **Firebase account** - Sign up at https://firebase.google.com
3. **Flutter project** - Your existing Flutter web app

## Step 1: Install Firebase CLI

```bash
npm install -g firebase-tools
```

## Step 2: Login to Firebase

```bash
firebase login
```

This will open a browser window for authentication.

## Step 3: Initialize Firebase in Your Project

```bash
firebase init hosting
```

**During initialization, answer the questions:**

- **Which Firebase project?** - Select your project or create a new one
- **What do you want to use as your public directory?** - `build/web`
- **Configure as a single-page app?** - `Yes`
- **Set up automatic builds and deploys with GitHub?** - `No` (we'll use our custom script)
- **File build/web/index.html already exists. Overwrite?** - `No`

## Step 4: Build Your Flutter App

```bash
flutter build web --target lib/admin_panel/admin_main.dart --release
```

## Step 5: Deploy to Firebase

### Option A: Using the Deployment Script

```powershell
.\scripts\deploy_firebase.ps1
```

### Option B: Manual Deployment

```bash
firebase deploy --only hosting
```

## Step 6: Add Custom Domain

1. **Go to Firebase Console**
2. **Navigate to Hosting**
3. **Click "Add custom domain"**
4. **Enter your domain name**
5. **Follow the DNS configuration instructions**

## Configuration Files

### firebase.json
This file is already configured for your project with:
- Public directory: `build/web`
- URL rewriting for Flutter routing
- Security headers
- Caching headers for performance

### Deployment Script
The `scripts/deploy_firebase.ps1` script handles:
- Building your Flutter app
- Deploying to Firebase
- Error checking and validation

## Deployment Commands

### Build and Deploy (Recommended)
```powershell
.\scripts\deploy_firebase.ps1
```

### Build Only
```powershell
.\scripts\deploy_firebase.ps1 -BuildOnly
```

### Deploy Only (if build already exists)
```powershell
.\scripts\deploy_firebase.ps1 -DeployOnly
```

### Deploy Main App Instead of Admin
```powershell
.\scripts\deploy_firebase.ps1 -Target lib/main.dart
```

## Firebase CLI Commands

### List Projects
```bash
firebase projects:list
```

### Switch Projects
```bash
firebase use <project-id>
```

### Deploy to Preview Channel
```bash
firebase hosting:channel:deploy preview
```

### Open Your Site
```bash
firebase hosting:open
```

### View Deployment History
```bash
firebase hosting:releases:list
```

## Custom Domain Setup

### Step 1: Add Domain in Firebase Console
1. Go to Firebase Console > Hosting
2. Click "Add custom domain"
3. Enter your domain (e.g., `yourdomain.com`)
4. Click "Continue"

### Step 2: Configure DNS Records
Firebase will provide you with DNS records to add:

**For A Records:**
```
Type: A
Name: @
Value: [Firebase IP addresses]
```

**For CNAME Records:**
```
Type: CNAME
Name: www
Value: [your-project-id].web.app
```

### Step 3: Verify Domain
1. Add the DNS records at your domain registrar
2. Wait for DNS propagation (can take up to 48 hours)
3. Firebase will automatically verify your domain

## Performance Optimization

The Firebase configuration includes:

### Caching Headers
- JavaScript and CSS files: 1 year cache
- Images: 1 year cache
- HTML files: No cache (for updates)

### Security Headers
- X-Frame-Options: DENY
- X-XSS-Protection: 1; mode=block
- X-Content-Type-Options: nosniff
- Referrer-Policy: strict-origin-when-cross-origin

### URL Rewriting
- All routes redirect to `index.html` for Flutter routing

## Troubleshooting

### Build Errors
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build web --target lib/admin_panel/admin_main.dart --release
```

### Deployment Errors
```bash
# Check Firebase CLI version
firebase --version

# Re-login to Firebase
firebase logout
firebase login

# Check project configuration
firebase projects:list
firebase use <your-project-id>
```

### Domain Issues
1. **DNS not propagated** - Wait up to 48 hours
2. **Wrong DNS records** - Double-check the records from Firebase
3. **SSL certificate issues** - Firebase handles SSL automatically

## Monitoring and Analytics

### Firebase Analytics
1. Enable Analytics in Firebase Console
2. Add Firebase Analytics to your Flutter app
3. View analytics in Firebase Console

### Performance Monitoring
1. Enable Performance Monitoring in Firebase Console
2. Monitor your app's performance metrics

## Cost and Limits

### Firebase Hosting Free Tier
- **Storage**: 10 GB
- **Data transfer**: 10 GB/month
- **Custom domains**: Unlimited
- **SSL certificates**: Free

### Pricing (if you exceed free tier)
- **Storage**: $0.026/GB/month
- **Data transfer**: $0.15/GB

## Best Practices

1. **Use preview channels** for testing before production
2. **Monitor your usage** in Firebase Console
3. **Set up automatic deployments** from Git (optional)
4. **Use Firebase Analytics** to track user behavior
5. **Enable Performance Monitoring** for optimization

## Next Steps

After successful deployment:

1. **Test your website** thoroughly
2. **Add your custom domain**
3. **Set up Firebase Analytics**
4. **Configure monitoring and alerts**
5. **Set up CI/CD pipeline** (optional)

---

**Your Flutter web app is now ready for Firebase Hosting!** 🚀 