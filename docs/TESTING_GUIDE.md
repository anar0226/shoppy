# Shoppy/Avii Testing Guide

This guide covers how to test all the systems we've implemented for the marketplace app.

## 🧪 **Testing Overview**

Our app includes several enterprise-level systems that need thorough testing:

1. **Inventory Management System**
2. **Order Fulfillment Automation**
3. **User Agreement & Legal System**
4. **Enhanced Cart & Checkout**
5. **Analytics & Reporting**
6. **Super Admin System**

## 📦 **1. Inventory Management System Testing**

### **Setup Test Data:**
```bash
# Create test products with variants
1. Go to Admin Panel → Products → Add Product
2. Create product with multiple variants (e.g., T-shirt with sizes S, M, L)
3. Set initial stock levels for each variant
4. Create products with simple inventory (no variants)
```

### **Test Scenarios:**

#### **A. Stock Reservation & Release**
```bash
# Test automatic inventory management
1. Place order with variant products
2. Verify stock is reduced in real-time
3. Cancel the order
4. Verify stock is restored
5. Check audit trail shows the transactions
```

#### **B. Manual Stock Adjustments**
```bash
# Test manual inventory management
1. Go to Inventory Management → Adjustments
2. Add manual adjustment (+5 units)
3. Verify stock level updates
4. Check audit trail entry
5. Test bulk adjustments with CSV upload
```

#### **C. Stock Alerts**
```bash
# Test automated alerts
1. Set low stock threshold (e.g., 5 units)
2. Reduce stock below threshold
3. Verify alert appears in dashboard
4. Check email notifications (if configured)
```

#### **D. Inventory Analytics**
```bash
# Test analytics features
1. View inventory overview dashboard
2. Check stock movement charts
3. Export inventory reports
4. Verify analytics data accuracy
```

## 🚚 **2. Order Fulfillment Automation Testing**

### **Setup Test Orders:**
```bash
# Create test orders for automation testing
1. Place orders through customer app
2. Use test payment methods
3. Create orders with different product types
```

### **Test Order Lifecycle:**

#### **A. Automatic Status Transitions**
```bash
# Test automated workflow
1. Place order → Status: pending
2. Complete payment → Status: paid (auto)
3. Wait 2 minutes → Status: processing (auto)
4. Wait 30 minutes → Status: readyForPickup (auto)
5. Wait 5 minutes → Status: deliveryRequested (auto)
6. Wait 5 minutes → Status: inTransit (auto)
7. Wait 45 minutes → Status: delivered (auto)
8. Wait 24 hours → Status: completed (auto)
```

#### **B. Manual Overrides**
```bash
# Test admin controls
1. Go to Store Owner Dashboard → Orders
2. Select active order
3. Manually change status
4. Add status update reason
5. Verify customer notification
```

#### **C. Escalation System**
```bash
# Test stuck order detection
1. Create order that gets stuck in processing
2. Wait for escalation (6+ hours)
3. Check support notifications
4. Verify escalation record in database
```

#### **D. Customer Notifications**
```bash
# Test notification system
1. Monitor customer app during order lifecycle
2. Verify push notifications at each status change
3. Check email notifications (if configured)
4. Test order tracking page updates
```

## 📋 **3. User Agreement & Legal System Testing**

### **Test Signup Flow:**
```bash
# Test terms agreement requirement
1. Start new user registration
2. Try to proceed without checking terms box
3. Verify validation prevents signup
4. Check terms box and verify signup completes
5. Test terms page navigation from settings
```

### **Test Terms Page:**
```bash
# Test terms and conditions display
1. Navigate to Settings → Terms & Conditions
2. Verify Mongolian text displays correctly
3. Test scrolling through content
4. Verify navigation back to settings
5. Test on different screen sizes
```

## 🛒 **4. Enhanced Cart & Checkout Testing**

### **Test Cart Functionality:**
```bash
# Test cart features
1. Add products to cart
2. Test quantity changes
3. Verify real-time stock validation
4. Remove items from cart
5. Test cart persistence (close/reopen app)
```

### **Test Checkout Process:**
```bash
# Test complete checkout flow
1. Proceed to checkout
2. Test address selection/entry
3. Verify shipping calculations
4. Test payment flow (with test data)
5. Verify order confirmation
```

## 📊 **5. Analytics & Reporting Testing**

### **Test Analytics Dashboard:**
```bash
# Test analytics features
1. Navigate to Analytics page
2. Verify real-time data loading
3. Test period selection (day, week, month)
4. Check chart interactions
5. Test data export functionality
```

### **Test Order Analytics:**
```bash
# Test order-specific analytics
1. View order fulfillment metrics
2. Check processing time calculations
3. Verify delivery time analytics
4. Test status breakdown charts
```

## 👑 **6. Super Admin System Testing**

### **Test Admin Authentication:**
```bash
# Test super admin login
1. Access super admin login page
2. Test with valid admin credentials
3. Verify role-based access control
4. Test session management
```

### **Test Admin Dashboard:**
```bash
# Test admin features
1. View platform-wide analytics
2. Test store management
3. Check user management
4. Verify commission tracking
5. Test backup management
```

## 🔧 **Automated Testing**

### **Run Existing Tests:**
```bash
# Run all tests
flutter test

# Run specific test files
flutter test test/backup_integration_test.dart
flutter test test/backup_system_test.dart
flutter test test/widget_test.dart
```

### **Create New Tests:**
```bash
# Test inventory service
flutter test test/inventory_service_test.dart

# Test order fulfillment
flutter test test/order_fulfillment_test.dart

# Test user agreements
flutter test test/user_agreements_test.dart
```

## 🐛 **Common Issues & Debugging**

### **Inventory Issues:**
```bash
# Check Firestore transactions
1. Verify atomic operations are working
2. Check for transaction conflicts
3. Verify stock field updates

# Debug stock calculations
1. Check variant stock fields
2. Verify inventory service calls
3. Check audit trail entries
```

### **Order Fulfillment Issues:**
```bash
# Check automation triggers
1. Verify Cloud Functions are deployed
2. Check order status transitions
3. Verify notification sending

# Debug stuck orders
1. Check order_transitions collection
2. Verify escalation triggers
3. Check support notifications
```

### **Performance Issues:**
```bash
# Monitor app performance
1. Check Firestore query performance
2. Verify real-time listeners
3. Monitor memory usage
4. Check network requests
```

## 📱 **Device Testing**

### **Test on Different Devices:**
```bash
# Android testing
flutter run -d android

# iOS testing
flutter run -d ios

# Web testing
flutter run -d chrome

# Desktop testing
flutter run -d windows
flutter run -d macos
flutter run -d linux
```

### **Test Different Screen Sizes:**
```bash
# Use Flutter Inspector to test responsive design
1. Open Flutter Inspector
2. Test different device sizes
3. Verify UI adapts correctly
4. Check navigation on small screens
```

## 🔒 **Security Testing**

### **Test Authentication:**
```bash
# Test user authentication
1. Verify email verification requirement
2. Test password strength validation
3. Check session management
4. Test logout functionality

# Test admin authentication
1. Verify super admin access control
2. Test role-based permissions
3. Check audit trail for admin actions
```

### **Test Data Security:**
```bash
# Verify Firestore rules
1. Test read/write permissions
2. Verify user data isolation
3. Check store ownership validation
4. Test admin data access
```

## 📈 **Performance Testing**

### **Load Testing:**
```bash
# Test with multiple users
1. Simulate concurrent orders
2. Test inventory reservation under load
3. Verify order processing performance
4. Check notification delivery

# Test database performance
1. Monitor Firestore usage
2. Check query performance
3. Verify indexing effectiveness
4. Monitor Cloud Functions execution
```

## 🚀 **Production Readiness Testing**

### **Pre-Launch Checklist:**
- [ ] All core features tested
- [ ] Performance benchmarks met
- [ ] Security vulnerabilities addressed
- [ ] Error handling verified
- [ ] Analytics tracking confirmed
- [ ] Backup systems tested
- [ ] Monitoring alerts configured
- [ ] Documentation complete

### **Go-Live Testing:**
```bash
# Final verification
1. Test with real payment methods
2. Verify production environment
3. Test customer support flow
4. Monitor system performance
5. Verify backup procedures
```

## 📞 **Support & Troubleshooting**

### **Common Error Messages:**
- **"Stock not available"** - Check inventory levels and variant selection
- **"Order stuck in processing"** - Check automation triggers and manual override
- **"Payment failed"** - Verify payment configuration and test credentials
- **"Terms agreement required"** - Ensure terms checkbox is selected during signup

### **Debug Tools:**
- Flutter Inspector for UI debugging
- Firebase Console for database monitoring
- Cloud Functions logs for automation debugging
- Analytics dashboard for performance monitoring

This testing guide ensures all systems are thoroughly validated before production deployment. 