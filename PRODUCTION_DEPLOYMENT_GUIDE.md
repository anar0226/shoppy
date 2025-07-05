# 🚀 Production Deployment Guide

## ✅ Pre-Deployment Checklist

### 1. **Environment Variables Setup**

Before deploying to production, set these environment variables:

#### **Required Environment Variables:**
```bash
# Production flag
PRODUCTION=true
DEBUG=false

# Payment Configuration
QPAY_USERNAME=your_actual_qpay_username
QPAY_PASSWORD=your_actual_qpay_password

# Delivery Configuration  
UBCAB_API_KEY=your_actual_ubcab_api_key
UBCAB_MERCHANT_ID=your_actual_merchant_id
UBCAB_PRODUCTION=true

# App Information
APP_VERSION=1.0.0
BUILD_NUMBER=1

# Feature Flags
ENABLE_ANALYTICS=true
ENABLE_CRASH_REPORTING=true
ENABLE_PERFORMANCE_MONITORING=true

# API Endpoints
API_BASE_URL=https://api.shoppy.mn
CDN_BASE_URL=https://cdn.shoppy.mn
```

#### **How to Set Environment Variables:**

**For Flutter Build:**
```bash
flutter build apk --release --dart-define=PRODUCTION=true --dart-define=QPAY_USERNAME=your_username --dart-define=QPAY_PASSWORD=your_password
```

**For CI/CD (GitHub Actions):**
Add these as GitHub Secrets and reference them in your workflow.

### 2. **Security Checklist**

- [x] ✅ Removed all debug print statements
- [x] ✅ Removed setup_super_admin.html file
- [x] ✅ Moved sensitive data to environment variables
- [x] ✅ Implemented comprehensive input validation
- [x] ✅ Updated Firestore security rules
- [ ] 🔄 Enable Firebase App Check
- [ ] 🔄 Set up monitoring and alerting
- [ ] 🔄 Configure CDN for static assets

### 3. **Performance Optimizations**

- [ ] 🔄 Optimize images and assets
- [ ] 🔄 Implement proper caching strategies
- [ ] 🔄 Add database query optimization
- [ ] 🔄 Set up performance monitoring

### 4. **Testing Requirements**

- [ ] 🔄 Run all unit tests
- [ ] 🔄 Perform integration testing
- [ ] 🔄 Test payment flows
- [ ] 🔄 Verify backup system
- [ ] 🔄 Test offline functionality

## 🔧 Build Commands

### **Android Production Build:**
```bash
flutter build apk --release \
  --dart-define=PRODUCTION=true \
  --dart-define=QPAY_USERNAME=$QPAY_USERNAME \
  --dart-define=QPAY_PASSWORD=$QPAY_PASSWORD \
  --dart-define=UBCAB_API_KEY=$UBCAB_API_KEY \
  --dart-define=UBCAB_MERCHANT_ID=$UBCAB_MERCHANT_ID \
  --dart-define=UBCAB_PRODUCTION=true
```

### **iOS Production Build:**
```bash
flutter build ios --release \
  --dart-define=PRODUCTION=true \
  --dart-define=QPAY_USERNAME=$QPAY_USERNAME \
  --dart-define=QPAY_PASSWORD=$QPAY_PASSWORD \
  --dart-define=UBCAB_API_KEY=$UBCAB_API_KEY \
  --dart-define=UBCAB_MERCHANT_ID=$UBCAB_MERCHANT_ID \
  --dart-define=UBCAB_PRODUCTION=true
```

## 🔒 Security Best Practices

### **1. Environment Variables Security:**
- Never commit sensitive environment variables to version control
- Use different credentials for staging and production
- Rotate credentials regularly
- Use secure secret management systems

### **2. Firebase Security:**
- Enable Firebase App Check for production
- Review and test Firestore security rules
- Enable audit logging
- Set up monitoring for suspicious activities

### **3. API Security:**
- Implement rate limiting
- Use HTTPS for all API calls
- Validate all input on both client and server
- Implement proper authentication and authorization

## 📊 Monitoring Setup

### **1. Firebase Performance Monitoring:**
Already integrated - will automatically start collecting data in production.

### **2. Crash Reporting:**
Consider adding Firebase Crashlytics:
```bash
flutter pub add firebase_crashlytics
```

### **3. Analytics:**
Firebase Analytics is already configured and will track user behavior.

## 🚨 Emergency Procedures

### **1. Rollback Plan:**
- Keep previous APK/IPA versions for quick rollback
- Have database backup restoration procedures ready
- Document rollback steps clearly

### **2. Incident Response:**
- Set up alerting for critical errors
- Have escalation procedures defined
- Keep emergency contact information updated

## 📱 App Store Deployment

### **Android (Google Play):**
1. Generate signed APK using production environment variables
2. Upload to Google Play Console
3. Complete store listing information
4. Submit for review

### **iOS (App Store):**
1. Build using Xcode with production configuration
2. Upload to App Store Connect
3. Complete app information and screenshots
4. Submit for review

## 🔍 Post-Deployment Verification

### **Immediately After Deployment:**
- [ ] Verify app launches correctly
- [ ] Test user registration and login
- [ ] Test payment flows with small amounts
- [ ] Verify backup system is working
- [ ] Check analytics data is being collected

### **Within 24 Hours:**
- [ ] Monitor error rates and crashes
- [ ] Check performance metrics
- [ ] Verify all critical user flows
- [ ] Monitor server resource usage

### **Within 1 Week:**
- [ ] Analyze user feedback and reviews
- [ ] Monitor business metrics
- [ ] Check for any security issues
- [ ] Plan next iteration based on user behavior

## 📞 Support Contacts

- **Technical Issues:** [Your technical team contact]
- **Payment Issues:** [Payment provider support]
- **Infrastructure:** [Cloud provider support]
- **Security Incidents:** [Security team contact]

---

## ⚠️ Important Notes

1. **Never deploy without testing** - Always test in a staging environment first
2. **Monitor closely** - Watch metrics closely for the first 48 hours after deployment
3. **Have rollback ready** - Be prepared to rollback quickly if issues arise
4. **Communicate** - Keep stakeholders informed of deployment status

---

**Last Updated:** [Current Date]
**Version:** 1.0.0 