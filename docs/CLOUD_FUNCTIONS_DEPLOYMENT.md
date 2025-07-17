# 🚀 Cloud Functions Deployment Guide

## Overview

This guide covers deploying Firebase Cloud Functions to production for the Avii.mn marketplace. These functions are critical for order processing, payments, and notifications.

## 📋 Prerequisites

### 1. Firebase CLI Setup
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Select your project
firebase use shoppy-6d81f
```

### 2. Environment Variables
Create a `.env` file in the `functions/` directory:
```env
# Firebase Admin SDK
FIREBASE_PROJECT_ID=shoppy-6d81f

# QPay Configuration
QPAY_USERNAME=AVII_MN
QPAY_PASSWORD=your_qpay_password
QPAY_INVOICE_CODE=AVII_MN_INVOICE
QPAY_BASE_URL=https://merchant.qpay.mn/v2

# Email Configuration (for notifications)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your_email@gmail.com
SMTP_PASSWORD=your_app_password

# SMS Configuration (for notifications)
SMS_API_KEY=your_sms_api_key
SMS_API_SECRET=your_sms_api_secret
```

## 🔧 Functions Overview

### Critical Functions for Production

1. **Order Processing Functions**
   - `processNewOrder` - Handles new order creation
   - `updateOrderStatus` - Manages order status transitions
   - `processOrderCancellation` - Handles order cancellations

2. **Payment Processing Functions**
   - `processQPayPayment` - QPay payment processing
   - `handlePaymentWebhook` - Payment webhook handling
   - `processRefund` - Refund processing

3. **Notification Functions**
   - `sendOrderNotifications` - Customer order notifications
   - `sendStoreNotifications` - Store owner notifications
   - `sendSMSNotifications` - SMS notifications

4. **Analytics Functions**
   - `updateAnalytics` - Real-time analytics updates
   - `generateReports` - Report generation

## 🚀 Deployment Steps

### Step 1: Build Functions
```bash
cd functions
npm install
npm run build
```

### Step 2: Set Environment Variables
```bash
# Set Firebase project
firebase use shoppy-6d81f

# Set environment variables for functions
firebase functions:config:set qpay.username="AVII_MN"
firebase functions:config:set qpay.password="your_password"
firebase functions:config:set qpay.invoice_code="AVII_MN_INVOICE"
firebase functions:config:set qpay.base_url="https://merchant.qpay.mn/v2"
```

### Step 3: Deploy Functions
```bash
# Deploy all functions
firebase deploy --only functions

# Or deploy specific functions
firebase deploy --only functions:processNewOrder
firebase deploy --only functions:processQPayPayment
firebase deploy --only functions:sendOrderNotifications
```

### Step 4: Verify Deployment
```bash
# List deployed functions
firebase functions:list

# Check function logs
firebase functions:log

# Test specific function
firebase functions:shell
```

## 📊 Monitoring & Debugging

### View Function Logs
```bash
# View all function logs
firebase functions:log

# View logs for specific function
firebase functions:log --only processNewOrder

# View logs with timestamps
firebase functions:log --only processNewOrder --start-time="2024-01-01"
```

### Monitor Function Performance
```bash
# Check function execution times
firebase functions:log --only processNewOrder | grep "execution"

# Monitor memory usage
firebase functions:log --only processNewOrder | grep "memory"
```

### Debug Functions Locally
```bash
# Start Firebase emulator
firebase emulators:start --only functions

# Test functions locally
firebase functions:shell
```

## 🔒 Security Configuration

### 1. Function Permissions
Ensure functions have proper IAM permissions:
```bash
# Grant necessary permissions
gcloud projects add-iam-policy-binding shoppy-6d81f \
  --member="serviceAccount:shoppy-6d81f@appspot.gserviceaccount.com" \
  --role="roles/firebase.admin"
```

### 2. Environment Variable Security
```bash
# Set sensitive environment variables
firebase functions:config:set qpay.password="secure_password"
firebase functions:config:set smtp.password="secure_smtp_password"

# Verify configuration
firebase functions:config:get
```

### 3. CORS Configuration
Update `functions/src/index.ts` to include proper CORS headers:
```typescript
import * as cors from 'cors';

const corsHandler = cors({ origin: true });

export const processNewOrder = functions.https.onRequest((req, res) => {
  return corsHandler(req, res, () => {
    // Function logic here
  });
});
```

## 🧪 Testing Functions

### 1. Local Testing
```bash
# Start emulator
firebase emulators:start --only functions

# Test function locally
curl -X POST http://localhost:5001/shoppy-6d81f/us-central1/processNewOrder \
  -H "Content-Type: application/json" \
  -d '{"orderId": "test_order_123"}'
```

### 2. Production Testing
```bash
# Test deployed function
curl -X POST https://us-central1-shoppy-6d81f.cloudfunctions.net/processNewOrder \
  -H "Content-Type: application/json" \
  -d '{"orderId": "test_order_123"}'
```

## 📈 Performance Optimization

### 1. Function Configuration
Update `functions/package.json`:
```json
{
  "engines": {
    "node": "18"
  },
  "main": "lib/index.js",
  "scripts": {
    "build": "tsc",
    "deploy": "firebase deploy --only functions",
    "logs": "firebase functions:log"
  }
}
```

### 2. Memory Allocation
```bash
# Set function memory (if needed)
firebase functions:config:set functions.memory="1GB"
```

### 3. Timeout Configuration
```bash
# Set function timeout
firebase functions:config:set functions.timeout="540s"
```

## 🚨 Troubleshooting

### Common Issues

1. **Authentication Errors**
```bash
# Re-authenticate
firebase logout
firebase login
```

2. **Deployment Failures**
```bash
# Clear cache and retry
firebase functions:delete processNewOrder --force
firebase deploy --only functions
```

3. **Environment Variable Issues**
```bash
# Verify environment variables
firebase functions:config:get
```

4. **Permission Errors**
```bash
# Check project permissions
firebase projects:list
firebase use shoppy-6d81f
```

## 📋 Deployment Checklist

### Pre-Deployment
- [ ] Environment variables configured
- [ ] Functions built successfully
- [ ] Local testing completed
- [ ] Security rules reviewed
- [ ] CORS headers configured

### Deployment
- [ ] Firebase CLI authenticated
- [ ] Project selected correctly
- [ ] Functions deployed successfully
- [ ] Environment variables set
- [ ] Function logs verified

### Post-Deployment
- [ ] Functions responding correctly
- [ ] Error handling tested
- [ ] Performance monitored
- [ ] Security verified
- [ ] Documentation updated

## 🔄 Continuous Deployment

### GitHub Actions Integration
Add to `.github/workflows/ci-cd-pipeline.yml`:
```yaml
deploy-functions:
  name: 🚀 Deploy Cloud Functions
  runs-on: ubuntu-latest
  needs: [test-suite]
  
  steps:
    - uses: actions/checkout@v4
    
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
    
    - name: Install Firebase CLI
      run: npm install -g firebase-tools
    
    - name: Deploy Functions
      run: |
        cd functions
        npm install
        npm run build
        firebase deploy --only functions --token "${{ secrets.FIREBASE_TOKEN }}"
      env:
        FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}
```

## 📞 Support

For deployment issues:
1. Check Firebase Console logs
2. Verify environment variables
3. Test functions locally first
4. Review security configurations
5. Monitor function performance

---

**🎉 Your Cloud Functions are now ready for production deployment!** 