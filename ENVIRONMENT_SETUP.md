# Environment Setup Guide

This guide explains how to set up environment variables for both development and production environments.

## 🏗️ Development Setup

### 1. Create Development Environment File

Copy the template and fill in your development values:

```bash
cp assets/env/dev.env.template assets/env/dev.env
```

Then edit `assets/env/dev.env` with your actual development Firebase and QPay credentials.

### 2. Required Development Variables

```bash
# Firebase Configuration (Development Project)
F_API_KEY=your-dev-firebase-api-key
F_APP_ID=your-dev-firebase-app-id  
F_PROJECT_ID=your-dev-firebase-project-id
F_SENDER_ID=your-dev-firebase-sender-id

# QPay Configuration (Sandbox/Development)
QPAY_USERNAME=your-dev-qpay-username
QPAY_PASSWORD=your-dev-qpay-password
QPAY_INVOICE_CODE=your-dev-qpay-invoice-code
QPAY_BASE_URL=https://merchant.qpay.mn/v2
```

## 🚀 Production Setup

### 1. GitHub Repository Secrets

Production builds automatically use GitHub repository secrets. Add these secrets to your repository:

**Go to:** `https://github.com/anar0226/shoppy/settings/secrets/actions`

**Add these secrets:**

| Secret Name | Description |
|-------------|-------------|
| `FIREBASE_API_KEY` | Production Firebase API key |
| `FIREBASE_APP_ID` | Production Firebase App ID |
| `FIREBASE_PROJECT_ID` | Production Firebase Project ID |
| `FIREBASE_SENDER_ID` | Production Firebase Sender ID |
| `QPAY_USERNAME` | Production QPay username |
| `QPAY_PASSWORD` | Production QPay password |
| `QPAY_INVOICE_CODE` | Production QPay invoice code |
| `QPAY_BASE_URL` | Production QPay base URL |

### 2. CI/CD Pipeline

The GitHub Actions workflow automatically:
- Injects secrets into `assets/env/prod.env` during production builds
- Uses development environment for debug builds
- Keeps sensitive data secure and never commits it to the repository

## 🔒 Security Best Practices

### ✅ What's Protected
- Production secrets are stored in GitHub repository secrets
- Environment files are ignored by Git
- No sensitive data is committed to the repository
- Different environments use different configurations

### ⚠️ Important Notes
- Never commit actual environment files with real credentials
- Use separate Firebase projects for development and production
- Use QPay sandbox for development, production credentials for release
- Regularly rotate API keys and passwords

## 🛠️ Local Development

### Running the App
```bash
# Development build (uses dev.env)
flutter run

# Release build (uses prod.env, requires secrets)
flutter run --release
```

### Testing Environment Loading
```bash
# Check which environment file is being loaded
flutter logs | grep "environment"
```

## 🚨 Troubleshooting

### "Environment file not found"
- Ensure `assets/env/dev.env` exists for development
- Check that the file is listed in `pubspec.yaml` under assets

### "Firebase initialization failed"
- Verify all Firebase configuration values are correct
- Ensure the Firebase project exists and is active
- Check that API keys have proper permissions

### "QPay integration failed"
- Verify QPay credentials are correct
- Ensure you're using the right base URL (sandbox vs production)
- Check that your QPay account has proper permissions

## 📱 Production Readiness Checklist

- [ ] GitHub repository secrets are configured
- [ ] CI/CD pipeline runs successfully
- [ ] Production Firebase project is set up
- [ ] Production QPay account is configured
- [ ] App signing certificates are configured
- [ ] Firestore security rules are deployed
- [ ] Storage security rules are deployed
- [ ] All environment variables are properly injected during build 