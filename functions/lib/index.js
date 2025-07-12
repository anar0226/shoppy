"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __exportStar = (this && this.__exportStar) || function(m, exports) {
    for (var p in m) if (p !== "default" && !Object.prototype.hasOwnProperty.call(exports, p)) __createBinding(exports, m, p);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.processSMSQueue = exports.processQPayPayout = exports.processScheduledPayouts = exports.sendPriceDropNotification = exports.sendOrderNotification = exports.processNotificationQueue = exports.getCommissionStats = exports.initializeCommissionRules = exports.createOrder = exports.checkQPayPaymentStatus = exports.handleQPayWebhook = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const rate_limiter_1 = require("./rate_limiter");
// Initialize Firebase Admin
admin.initializeApp();
// Export Super Admin functions (after Firebase initialization)
__exportStar(require("./super-admin-setup"), exports);
__exportStar(require("./simple-admin-setup"), exports);
// Export Backup & Recovery functions
__exportStar(require("./firestore-backup"), exports);
// Export Store aggregate update triggers
__exportStar(require("./store-aggregates"), exports);
// Export Inventory management functions
__exportStar(require("./inventory-management"), exports);
// Export Rate Limiting functions
__exportStar(require("./rate-limiting"), exports);
// Export Data Consistency functions
__exportStar(require("./data-consistency"), exports);
// Export Order Cleanup functions
__exportStar(require("./order-cleanup"), exports);
// Export QPay Webhook functions
__exportStar(require("./qpay-webhook"), exports);
// QPay Webhook Handler
exports.handleQPayWebhook = functions.https.onRequest(async (req, res) => {
    try {
        console.log('QPay webhook received:', req.body);
        const { payment_id, payment_status, invoice_id, object_id } = req.body;
        if (!payment_id || !payment_status) {
            console.error('Invalid webhook data:', req.body);
            res.status(400).send('Invalid webhook data');
            return;
        }
        // Handle payment status updates
        switch (payment_status) {
            case 'PAID':
                await handleSuccessfulPayment(payment_id, invoice_id, object_id);
                break;
            case 'FAILED':
            case 'CANCELED':
                await handleFailedPayment(payment_id, invoice_id, object_id);
                break;
            default:
                console.log(`Unhandled payment status: ${payment_status}`);
        }
        res.json({ success: true, received: true });
    }
    catch (error) {
        console.error('Error processing QPay webhook:', error);
        res.status(500).send('Internal server error');
    }
});
// Handle successful QPay payment
async function handleSuccessfulPayment(paymentId, invoiceId, objectId) {
    var _a;
    try {
        // Find pending payment in Firestore
        const pendingPaymentsSnapshot = await admin.firestore()
            .collection('pending_payments')
            .where('invoiceId', '==', invoiceId)
            .where('status', '==', 'pending')
            .limit(1)
            .get();
        if (pendingPaymentsSnapshot.empty) {
            console.log(`No pending payment found for invoice ${invoiceId}`);
            return;
        }
        const pendingPaymentDoc = pendingPaymentsSnapshot.docs[0];
        const paymentData = pendingPaymentDoc.data();
        const orderId = pendingPaymentDoc.id;
        // Extract order information
        const item = paymentData.item;
        const storeId = item === null || item === void 0 ? void 0 : item.storeId;
        if (!storeId) {
            console.error('Store ID not found in payment data');
            return;
        }
        // Get store owner ID
        const storeDoc = await admin.firestore().collection('stores').doc(storeId).get();
        if (!storeDoc.exists) {
            console.error(`Store ${storeId} not found`);
            return;
        }
        const vendorId = (_a = storeDoc.data()) === null || _a === void 0 ? void 0 : _a.ownerId;
        // Create order
        const orderData = {
            userId: paymentData.userId,
            userEmail: paymentData.email,
            items: [item],
            total: paymentData.amount,
            subtotal: paymentData.subtotal,
            tax: paymentData.tax,
            shipping: paymentData.shippingCost,
            shippingAddress: paymentData.shippingAddress,
            paymentId: paymentId,
            paymentMethod: 'qpay',
            storeId: storeId,
            vendorId: vendorId,
            category: (item === null || item === void 0 ? void 0 : item.category) || 'General',
            status: 'paid',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            // Analytics fields
            month: new Date().getMonth() + 1,
            week: Math.ceil(new Date().getDate() / 7),
            day: new Date().getDate(),
        };
        await admin.firestore().collection('orders').doc(orderId).set(orderData);
        // Update payment status
        await pendingPaymentDoc.ref.update({
            status: 'completed',
            paymentId: paymentId,
            completedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        // Create commission transaction
        try {
            await createCommissionTransaction(orderId, storeId, vendorId, paymentData.amount, (item === null || item === void 0 ? void 0 : item.category) || 'General');
        }
        catch (commissionError) {
            console.error('Error creating commission transaction:', commissionError);
        }
        console.log(`Payment ${paymentId} processed successfully for order ${orderId}`);
    }
    catch (error) {
        console.error('Error handling successful payment:', error);
    }
}
// Handle failed QPay payment
async function handleFailedPayment(paymentId, invoiceId, objectId) {
    try {
        // Find pending payment in Firestore
        const pendingPaymentsSnapshot = await admin.firestore()
            .collection('pending_payments')
            .where('invoiceId', '==', invoiceId)
            .limit(1)
            .get();
        if (!pendingPaymentsSnapshot.empty) {
            const pendingPaymentDoc = pendingPaymentsSnapshot.docs[0];
            await pendingPaymentDoc.ref.update({
                status: 'failed',
                paymentId: paymentId,
                failedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            console.log(`Payment ${paymentId} marked as failed`);
        }
    }
    catch (error) {
        console.error('Error handling failed payment:', error);
    }
}
// QPay Payment Status Check (for polling)
exports.checkQPayPaymentStatus = functions.https.onCall(async (data, context) => {
    var _a;
    await (0, rate_limiter_1.enforceRateLimit)((((_a = context.auth) === null || _a === void 0 ? void 0 : _a.uid) || context.rawRequest.ip));
    try {
        if (!context.auth) {
            throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
        }
        const { orderId } = data;
        if (!orderId) {
            throw new functions.https.HttpsError('invalid-argument', 'Order ID is required');
        }
        // Check if order exists and is completed
        const orderDoc = await admin.firestore().collection('orders').doc(orderId).get();
        if (orderDoc.exists) {
            const orderData = orderDoc.data();
            return {
                success: true,
                status: (orderData === null || orderData === void 0 ? void 0 : orderData.status) || 'unknown',
                paymentId: (orderData === null || orderData === void 0 ? void 0 : orderData.paymentId) || null,
            };
        }
        // Check pending payment status
        const pendingPaymentDoc = await admin.firestore()
            .collection('pending_payments')
            .doc(orderId)
            .get();
        if (pendingPaymentDoc.exists) {
            const paymentData = pendingPaymentDoc.data();
            return {
                success: false,
                status: (paymentData === null || paymentData === void 0 ? void 0 : paymentData.status) || 'pending',
                invoiceId: (paymentData === null || paymentData === void 0 ? void 0 : paymentData.invoiceId) || null,
            };
        }
        return {
            success: false,
            status: 'not_found',
        };
    }
    catch (error) {
        console.error('Error checking payment status:', error);
        throw new functions.https.HttpsError('internal', 'Unable to check payment status');
    }
});
// Function to create order after successful payment
exports.createOrder = functions.https.onCall(async (data, context) => {
    var _a, _b, _c, _d, _e;
    await (0, rate_limiter_1.enforceRateLimit)((((_a = context.auth) === null || _a === void 0 ? void 0 : _a.uid) || context.rawRequest.ip), 20, 60);
    try {
        // Verify user is authenticated
        if (!context.auth) {
            throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
        }
        const { items, total, subtotal, tax, shipping, shippingAddress, email, paymentIntentId } = data;
        // Extract store information from first item (assuming single-store orders)
        const firstItem = items[0];
        const storeId = firstItem === null || firstItem === void 0 ? void 0 : firstItem.storeId;
        const category = (firstItem === null || firstItem === void 0 ? void 0 : firstItem.category) || 'General';
        if (!storeId) {
            throw new functions.https.HttpsError('invalid-argument', 'Store ID is required');
        }
        // Get store owner ID
        const storeDoc = await admin.firestore().collection('stores').doc(storeId).get();
        if (!storeDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'Store not found');
        }
        const vendorId = (_b = storeDoc.data()) === null || _b === void 0 ? void 0 : _b.ownerId;
        // Get customer name from user profile
        let customerName = 'Үйлчлүүлэгч';
        try {
            const userDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
            if (userDoc.exists) {
                const userData = userDoc.data();
                customerName = (userData === null || userData === void 0 ? void 0 : userData.displayName) ||
                    (userData === null || userData === void 0 ? void 0 : userData.firstName) ||
                    (userData === null || userData === void 0 ? void 0 : userData.name) ||
                    context.auth.token.name ||
                    ((_c = context.auth.token.email) === null || _c === void 0 ? void 0 : _c.split('@')[0]) ||
                    'Үйлчлүүлэгч';
            }
            else {
                customerName = context.auth.token.name ||
                    ((_d = context.auth.token.email) === null || _d === void 0 ? void 0 : _d.split('@')[0]) ||
                    'Үйлчлүүлэгч';
            }
        }
        catch (e) {
            // Fallback if user data fetch fails
            customerName = context.auth.token.name ||
                ((_e = context.auth.token.email) === null || _e === void 0 ? void 0 : _e.split('@')[0]) ||
                'Үйлчлүүлэгч';
        }
        // Create order document
        const orderData = {
            userId: context.auth.uid,
            userEmail: email || context.auth.token.email,
            customerName: customerName,
            items: items,
            total: total,
            subtotal: subtotal,
            tax: tax,
            shipping: shipping,
            shippingAddress: shippingAddress,
            paymentIntentId: paymentIntentId,
            storeId: storeId,
            vendorId: vendorId,
            category: category,
            status: 'placed',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            // Analytics fields
            month: new Date().getMonth() + 1,
            week: Math.ceil(new Date().getDate() / 7),
            day: new Date().getDate(),
        };
        // Add order to Firestore
        const orderRef = await admin.firestore().collection('orders').add(orderData);
        // Create commission transaction
        try {
            await createCommissionTransaction(orderRef.id, storeId, vendorId, total, category);
            console.log(`Commission transaction created for order ${orderRef.id}`);
        }
        catch (commissionError) {
            console.error('Error creating commission transaction:', commissionError);
            // Don't fail the order creation if commission calculation fails
        }
        return {
            orderId: orderRef.id,
            success: true,
        };
    }
    catch (error) {
        console.error('Error creating order:', error);
        throw new functions.https.HttpsError('internal', 'Unable to create order');
    }
});
// Helper function to create commission transaction
async function createCommissionTransaction(orderId, storeId, vendorId, orderTotal, category) {
    try {
        // Get applicable commission rule
        const rule = await getApplicableCommissionRule(storeId, category, orderTotal);
        if (!rule) {
            console.log(`No commission rule found for order ${orderId}`);
            return;
        }
        // Calculate commission
        const commissionAmount = calculateCommission(rule, orderTotal);
        const vendorAmount = orderTotal - commissionAmount;
        // Create commission transaction
        const transactionData = {
            orderId: orderId,
            storeId: storeId,
            vendorId: vendorId,
            ruleId: rule.id,
            orderTotal: orderTotal,
            commissionAmount: commissionAmount,
            vendorAmount: vendorAmount,
            status: 'calculated',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            metadata: {
                commissionRule: {
                    type: rule.type,
                    value: rule.value,
                    category: rule.category,
                },
            },
        };
        await admin.firestore().collection('commission_transactions').add(transactionData);
        console.log(`Commission calculated: $${commissionAmount.toFixed(2)} for order ${orderId}`);
    }
    catch (error) {
        console.error('Error in createCommissionTransaction:', error);
        throw error;
    }
}
// Helper function to get applicable commission rule
async function getApplicableCommissionRule(storeId, category, orderValue) {
    try {
        // Priority order: Store-specific > Category-specific > Global
        // 1. Check for store-specific rule
        const storeRules = await admin.firestore()
            .collection('commission_rules')
            .where('isActive', '==', true)
            .where('storeId', '==', storeId)
            .where('minOrderValue', '<=', orderValue)
            .orderBy('minOrderValue', 'desc')
            .limit(1)
            .get();
        if (!storeRules.empty) {
            return Object.assign({ id: storeRules.docs[0].id }, storeRules.docs[0].data());
        }
        // 2. Check for category-specific rule
        const categoryRules = await admin.firestore()
            .collection('commission_rules')
            .where('isActive', '==', true)
            .where('category', '==', category)
            .where('storeId', '==', null)
            .where('minOrderValue', '<=', orderValue)
            .orderBy('minOrderValue', 'desc')
            .limit(1)
            .get();
        if (!categoryRules.empty) {
            return Object.assign({ id: categoryRules.docs[0].id }, categoryRules.docs[0].data());
        }
        // 3. Check for global rule
        const globalRules = await admin.firestore()
            .collection('commission_rules')
            .where('isActive', '==', true)
            .where('storeId', '==', null)
            .where('category', '==', null)
            .where('minOrderValue', '<=', orderValue)
            .orderBy('minOrderValue', 'desc')
            .limit(1)
            .get();
        if (!globalRules.empty) {
            return Object.assign({ id: globalRules.docs[0].id }, globalRules.docs[0].data());
        }
        return null;
    }
    catch (error) {
        console.error('Error getting commission rule:', error);
        return null;
    }
}
// Helper function to calculate commission based on rule
function calculateCommission(rule, orderValue) {
    if (orderValue < (rule.minOrderValue || 0))
        return 0;
    switch (rule.type) {
        case 'percentage':
            const commission = orderValue * ((rule.value || 0) / 100);
            const maxCommission = rule.maxCommission || Number.MAX_VALUE;
            return Math.min(commission, maxCommission);
        case 'fixedAmount':
            return rule.value || 0;
        case 'tiered':
            return calculateTieredCommission(rule, orderValue);
        default:
            return 0;
    }
}
// Helper function for tiered commission calculation
function calculateTieredCommission(rule, orderValue) {
    if (!rule.tieredRates || !rule.tieredRates.tiers)
        return 0;
    let commission = 0;
    let remaining = orderValue;
    // Sort tiers by threshold
    const sortedTiers = rule.tieredRates.tiers
        .filter(tier => tier.threshold !== null && tier.rate !== null)
        .sort((a, b) => a.threshold - b.threshold);
    for (let i = 0; i < sortedTiers.length; i++) {
        const tier = sortedTiers[i];
        const threshold = tier.threshold;
        const rate = tier.rate;
        if (remaining <= 0)
            break;
        let tierAmount;
        if (i === sortedTiers.length - 1) {
            // Last tier - use all remaining
            tierAmount = remaining;
        }
        else {
            const nextThreshold = sortedTiers[i + 1].threshold;
            tierAmount = Math.min(remaining, nextThreshold - threshold);
        }
        commission += tierAmount * (rate / 100);
        remaining -= tierAmount;
    }
    const maxCommission = rule.maxCommission || Number.MAX_VALUE;
    return Math.min(commission, maxCommission);
}
// Initialize default commission rules for marketplace
exports.initializeCommissionRules = functions.https.onCall(async (data, context) => {
    var _a;
    try {
        // Verify user is authenticated and is a super admin
        if (!context.auth) {
            throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
        }
        // Check if user is a super admin
        const superAdminDoc = await admin.firestore()
            .collection('super_admins')
            .doc(context.auth.uid)
            .get();
        if (!superAdminDoc.exists || !((_a = superAdminDoc.data()) === null || _a === void 0 ? void 0 : _a.isActive)) {
            throw new functions.https.HttpsError('permission-denied', 'Only super admins can initialize commission rules');
        }
        // Check if commission rules already exist
        const existingRules = await admin.firestore()
            .collection('commission_rules')
            .where('isActive', '==', true)
            .limit(1)
            .get();
        if (!existingRules.empty) {
            return {
                success: false,
                message: 'Commission rules already exist',
            };
        }
        // Create default global commission rule (5%)
        const defaultRule = {
            storeId: null,
            category: null,
            type: 'percentage',
            value: 5.0,
            minOrderValue: 0.0,
            maxCommission: 100.0,
            isActive: true,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            createdBy: context.auth.uid,
            tieredRates: null,
        };
        await admin.firestore().collection('commission_rules').add(defaultRule);
        console.log('Default commission rules initialized by:', context.auth.uid);
        return {
            success: true,
            message: 'Default commission rules initialized successfully',
            defaultRule: {
                type: 'percentage',
                value: 5.0,
                description: 'Default 5% commission on all orders',
            },
        };
    }
    catch (error) {
        console.error('Error initializing commission rules:', error);
        throw new functions.https.HttpsError('internal', 'Unable to initialize commission rules');
    }
});
// Get commission statistics for Super Admin dashboard
exports.getCommissionStats = functions.https.onCall(async (data, context) => {
    var _a;
    try {
        // Verify user is authenticated and is a super admin
        if (!context.auth) {
            throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
        }
        const superAdminDoc = await admin.firestore()
            .collection('super_admins')
            .doc(context.auth.uid)
            .get();
        if (!superAdminDoc.exists || !((_a = superAdminDoc.data()) === null || _a === void 0 ? void 0 : _a.isActive)) {
            throw new functions.https.HttpsError('permission-denied', 'Only super admins can access commission statistics');
        }
        const { startDate, endDate } = data;
        const start = startDate ? admin.firestore.Timestamp.fromDate(new Date(startDate)) :
            admin.firestore.Timestamp.fromDate(new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)); // 30 days ago
        const end = endDate ? admin.firestore.Timestamp.fromDate(new Date(endDate)) :
            admin.firestore.Timestamp.now();
        // Get all commission transactions in the period
        const transactionsSnapshot = await admin.firestore()
            .collection('commission_transactions')
            .where('createdAt', '>=', start)
            .where('createdAt', '<=', end)
            .get();
        let totalCommissionEarned = 0;
        let totalVendorPayouts = 0;
        let pendingCommissions = 0;
        let paidCommissions = 0;
        let totalTransactions = 0;
        let pendingTransactions = 0;
        const storeCommissions = {};
        transactionsSnapshot.docs.forEach(doc => {
            const data = doc.data();
            const commissionAmount = data.commissionAmount || 0;
            const vendorAmount = data.vendorAmount || 0;
            const status = data.status || 'pending';
            const storeId = data.storeId;
            totalCommissionEarned += commissionAmount;
            totalVendorPayouts += vendorAmount;
            totalTransactions++;
            if (status === 'pending' || status === 'calculated') {
                pendingCommissions += commissionAmount;
                pendingTransactions++;
            }
            else if (status === 'paid') {
                paidCommissions += commissionAmount;
            }
            // Store-wise breakdown
            if (!storeCommissions[storeId]) {
                storeCommissions[storeId] = {
                    storeId,
                    totalCommission: 0,
                    totalOrders: 0,
                    totalRevenue: 0,
                };
            }
            storeCommissions[storeId].totalCommission += commissionAmount;
            storeCommissions[storeId].totalOrders += 1;
            storeCommissions[storeId].totalRevenue += (data.orderTotal || 0);
        });
        // Sort stores by commission earned
        const topStores = Object.values(storeCommissions)
            .sort((a, b) => b.totalCommission - a.totalCommission)
            .slice(0, 10);
        return {
            summary: {
                totalCommissionEarned,
                totalVendorPayouts,
                pendingCommissions,
                paidCommissions,
                totalTransactions,
                pendingTransactions,
                averageCommissionPerTransaction: totalTransactions > 0 ? totalCommissionEarned / totalTransactions : 0,
            },
            topStores,
            periodStart: start.toDate().toISOString(),
            periodEnd: end.toDate().toISOString(),
        };
    }
    catch (error) {
        console.error('Error getting commission statistics:', error);
        throw new functions.https.HttpsError('internal', 'Unable to get commission statistics');
    }
});
// Process notification queue and send push notifications
exports.processNotificationQueue = functions.firestore
    .document('notification_queue/{queueId}')
    .onCreate(async (snap, context) => {
    try {
        const data = snap.data();
        const { userId, payload } = data;
        if (!userId || !payload) {
            console.error('Invalid notification data');
            return;
        }
        // Send the push notification
        const message = {
            notification: payload.notification,
            data: payload.data || {},
            token: payload.token,
            android: {
                priority: 'high',
                notification: {
                    sound: 'default',
                    clickAction: 'FLUTTER_NOTIFICATION_CLICK',
                },
            },
            apns: {
                payload: {
                    aps: {
                        sound: 'default',
                        category: 'GENERAL',
                    },
                },
            },
        };
        const response = await admin.messaging().send(message);
        console.log('Successfully sent message:', response);
        // Update queue document with success status
        await snap.ref.update({
            status: 'sent',
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
            messageId: response,
        });
    }
    catch (error) {
        console.error('Error sending push notification:', error);
        // Update queue document with error status
        await snap.ref.update({
            status: 'failed',
            error: error instanceof Error ? error.message : String(error),
            failedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
});
// Send notification on order status change
exports.sendOrderNotification = functions.firestore
    .document('orders/{orderId}')
    .onUpdate(async (change, context) => {
    try {
        const before = change.before.data();
        const after = change.after.data();
        // Check if status changed
        if (before.status === after.status) {
            return;
        }
        const { userId, status: newStatus } = after;
        const orderId = context.params.orderId;
        // Get user's FCM token
        const userDoc = await admin.firestore()
            .collection('users')
            .doc(userId)
            .get();
        if (!userDoc.exists) {
            console.log('User not found:', userId);
            return;
        }
        const userData = userDoc.data();
        const fcmToken = userData === null || userData === void 0 ? void 0 : userData.fcmToken;
        if (!fcmToken) {
            console.log('No FCM token found for user:', userId);
            return;
        }
        // Check if user has order notifications enabled
        const notificationSettings = (userData === null || userData === void 0 ? void 0 : userData.notificationSettings) || {};
        if (notificationSettings.orderTracking === false) {
            console.log('Order tracking notifications disabled for user:', userId);
            return;
        }
        // Create notification message based on status
        let title = '';
        let body = '';
        switch (newStatus) {
            case 'confirmed':
                title = 'Захиалга баталгаажлаа!';
                body = `Таны захиалга: #${orderId.substring(0, 6)} баталгаажлаа.`;
                break;
            case 'shipped':
                title = 'Захиалга замдаа гарлаа!';
                body = `Таны захиалга: #${orderId.substring(0, 6)} замдаа гарлаа.`;
                break;
            case 'delivered':
                title = 'Захиалга амжилттай хүлээгдлээ!';
                body = `Таны захиалга: #${orderId.substring(0, 6)} амжилттай хүлээгдлээ.`;
                break;
            case 'canceled':
                title = 'Захиалга цуцлагдсан!';
                body = `Таны захиалга: #${orderId.substring(0, 6)} цуцлагдсан.`;
                break;
            default:
                return; // Don't send notification for other status changes
        }
        // Queue notification for processing
        await admin.firestore().collection('notification_queue').add({
            userId: userId,
            payload: {
                notification: { title, body },
                data: {
                    type: 'orderTracking',
                    orderId: orderId,
                    status: newStatus,
                },
                token: fcmToken,
            },
            status: 'pending',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`Order notification queued for user ${userId}, order ${orderId}`);
    }
    catch (error) {
        console.error('Error processing order notification:', error);
    }
});
// Send notification when products go on sale (price drops)
exports.sendPriceDropNotification = functions.firestore
    .document('products/{productId}')
    .onUpdate(async (change, context) => {
    var _a, _b;
    try {
        const before = change.before.data();
        const after = change.after.data();
        // Check if discount was added or increased
        const beforeDiscount = ((_a = before.discount) === null || _a === void 0 ? void 0 : _a.isDiscounted) ? before.discount.percent || 0 : 0;
        const afterDiscount = ((_b = after.discount) === null || _b === void 0 ? void 0 : _b.isDiscounted) ? after.discount.percent || 0 : 0;
        if (afterDiscount <= beforeDiscount) {
            return; // No price drop
        }
        const productId = context.params.productId;
        const { name: productName, storeId } = after;
        // Get users who follow this store
        const followersQuery = await admin.firestore()
            .collection('users')
            .where('followerStoreIds', 'array-contains', storeId)
            .get();
        if (followersQuery.empty) {
            console.log('No followers found for store:', storeId);
            return;
        }
        const notifications = [];
        for (const userDoc of followersQuery.docs) {
            const userData = userDoc.data();
            const fcmToken = userData.fcmToken;
            // Check if user has price drop notifications enabled
            const notificationSettings = userData.notificationSettings || {};
            if (notificationSettings.priceDrops === false || !fcmToken) {
                continue;
            }
            notifications.push({
                userId: userDoc.id,
                payload: {
                    notification: {
                        title: 'Price Drop Alert! 🔥',
                        body: `${productName} is now ${afterDiscount}% off! Don't miss out!`,
                    },
                    data: {
                        type: 'priceDrops',
                        productId: productId,
                        storeId: storeId,
                        discountPercent: afterDiscount.toString(),
                    },
                    token: fcmToken,
                },
                status: 'pending',
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        // Batch write notifications
        if (notifications.length > 0) {
            const batch = admin.firestore().batch();
            notifications.forEach(notification => {
                const docRef = admin.firestore().collection('notification_queue').doc();
                batch.set(docRef, notification);
            });
            await batch.commit();
            console.log(`Queued ${notifications.length} price drop notifications for product ${productId}`);
        }
    }
    catch (error) {
        console.error('Error processing price drop notification:', error);
    }
});
// **PHASE 2: PAYOUT AUTOMATION CLOUD FUNCTIONS**
// Scheduled function to process automatic payouts (runs daily at 10 AM UTC)
exports.processScheduledPayouts = functions.pubsub.schedule('0 10 * * *')
    .timeZone('UTC')
    .onRun(async (context) => {
    console.log('Starting scheduled payout processing...');
    try {
        const db = admin.firestore();
        const now = admin.firestore.Timestamp.now();
        // Get all active payout schedules that are due
        const schedulesSnapshot = await db.collection('payout_schedules')
            .where('isActive', '==', true)
            .where('nextPayoutDate', '<=', now)
            .get();
        let processedCount = 0;
        const batch = db.batch();
        for (const scheduleDoc of schedulesSnapshot.docs) {
            try {
                const schedule = scheduleDoc.data();
                const vendorId = schedule.vendorId;
                const storeId = schedule.storeId;
                // Get vendor financial profile
                const profileDoc = await db.collection('vendor_financial_profiles').doc(vendorId).get();
                if (!profileDoc.exists)
                    continue;
                const profile = profileDoc.data();
                // Check if vendor has sufficient balance and is eligible
                if (profile.availableBalance >= schedule.minimumAmount && profile.isEligibleForPayouts) {
                    // Get unpaid commission transactions
                    const transactionsSnapshot = await db.collection('commission_transactions')
                        .where('vendorId', '==', vendorId)
                        .where('status', '==', 'calculated')
                        .orderBy('createdAt')
                        .get();
                    let payoutAmount = 0;
                    const transactionIds = [];
                    // Calculate payout amount up to available balance
                    for (const transactionDoc of transactionsSnapshot.docs) {
                        const transaction = transactionDoc.data();
                        const vendorAmount = transaction.vendorAmount || 0;
                        if (payoutAmount + vendorAmount <= profile.availableBalance) {
                            payoutAmount += vendorAmount;
                            transactionIds.push(transactionDoc.id);
                        }
                        else {
                            break;
                        }
                    }
                    if (payoutAmount >= schedule.minimumAmount) {
                        // Create payout request
                        const platformFee = payoutAmount * 0.025; // 2.5% platform fee
                        const netAmount = payoutAmount - platformFee;
                        const payoutRequest = {
                            vendorId,
                            storeId,
                            amount: payoutAmount,
                            platformFee,
                            netAmount,
                            currency: 'MNT',
                            status: 'scheduled',
                            method: schedule.method,
                            bankAccount: schedule.bankAccount,
                            mobileWallet: schedule.mobileWallet,
                            transactionIds,
                            requestDate: now,
                            scheduledDate: now,
                            notes: 'Automatic scheduled payout',
                            metadata: {
                                scheduleId: scheduleDoc.id,
                                automaticPayout: true,
                            }
                        };
                        // Add to batch
                        const payoutRef = db.collection('payout_requests').doc();
                        batch.set(payoutRef, payoutRequest);
                        // Update vendor financial profile
                        batch.update(profileDoc.ref, {
                            pendingBalance: admin.firestore.FieldValue.increment(payoutAmount),
                            availableBalance: admin.firestore.FieldValue.increment(-payoutAmount),
                            updatedAt: now,
                        });
                        // Mark commission transactions as pending payout
                        for (const transactionId of transactionIds) {
                            batch.update(db.collection('commission_transactions').doc(transactionId), {
                                status: 'pending_payout',
                                payoutId: payoutRef.id,
                                updatedAt: now,
                            });
                        }
                        // Update schedule next payout date
                        const nextPayoutDate = calculateNextPayoutDate(schedule.frequency, schedule.dayOfWeek, schedule.dayOfMonth);
                        batch.update(scheduleDoc.ref, {
                            lastPayoutDate: now,
                            nextPayoutDate: admin.firestore.Timestamp.fromDate(nextPayoutDate),
                        });
                        processedCount++;
                    }
                }
            }
            catch (error) {
                console.error(`Error processing schedule ${scheduleDoc.id}:`, error);
            }
        }
        // Commit all changes
        if (processedCount > 0) {
            await batch.commit();
        }
        console.log(`Processed ${processedCount} scheduled payouts`);
        return { success: true, processedCount };
    }
    catch (error) {
        console.error('Error in scheduled payout processing:', error);
        throw error;
    }
});
// Helper function to calculate next payout date
function calculateNextPayoutDate(frequency, dayOfWeek, dayOfMonth) {
    const now = new Date();
    switch (frequency) {
        case 'daily':
            return new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
        case 'weekly': {
            const daysUntilTarget = (dayOfWeek - now.getDay() + 7) % 7;
            const nextDate = new Date(now);
            nextDate.setDate(now.getDate() + (daysUntilTarget === 0 ? 7 : daysUntilTarget));
            return nextDate;
        }
        case 'monthly': {
            let nextMonth = now.getMonth() + 1;
            let nextYear = now.getFullYear();
            if (nextMonth > 11) {
                nextMonth = 0;
                nextYear++;
            }
            const targetDay = Math.min(dayOfMonth, new Date(nextYear, nextMonth + 1, 0).getDate());
            return new Date(nextYear, nextMonth, targetDay);
        }
        case 'quarterly': {
            const currentQuarter = Math.floor(now.getMonth() / 3);
            const nextQuarter = (currentQuarter + 1) % 4;
            const nextYear = nextQuarter === 0 ? now.getFullYear() + 1 : now.getFullYear();
            const nextMonth = nextQuarter * 3;
            return new Date(nextYear, nextMonth, Math.min(dayOfMonth, 28));
        }
        default:
            return new Date(now.getFullYear(), now.getMonth(), now.getDate() + 30);
    }
}
// Process QPay payouts integration
exports.processQPayPayout = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const { payoutId } = data;
    try {
        const db = admin.firestore();
        // Get payout request
        const payoutDoc = await db.collection('payout_requests').doc(payoutId).get();
        if (!payoutDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'Payout request not found');
        }
        const payout = payoutDoc.data();
        // Update status to processing
        await payoutDoc.ref.update({
            status: 'processing',
            processedDate: admin.firestore.FieldValue.serverTimestamp(),
        });
        // QPay integration would go here
        try {
            // Simulate QPay API call
            const qpayResponse = await simulateQPayTransfer(payout);
            if (qpayResponse.success) {
                // Mark as completed
                await payoutDoc.ref.update({
                    status: 'completed',
                    metadata: Object.assign(Object.assign({}, payout.metadata), { qpayTransactionId: qpayResponse.transactionId, processedAt: new Date().toISOString() })
                });
                // Update vendor financial profile
                await db.collection('vendor_financial_profiles').doc(payout.vendorId).update({
                    totalWithdrawn: admin.firestore.FieldValue.increment(payout.amount),
                    pendingBalance: admin.firestore.FieldValue.increment(-payout.amount),
                    lastPayoutDate: admin.firestore.FieldValue.serverTimestamp(),
                });
                // Mark commission transactions as paid
                const batch = db.batch();
                for (const transactionId of payout.transactionIds) {
                    batch.update(db.collection('commission_transactions').doc(transactionId), {
                        status: 'paid',
                        paidAt: admin.firestore.FieldValue.serverTimestamp(),
                    });
                }
                await batch.commit();
                return {
                    success: true,
                    message: 'Payout processed successfully',
                    transactionId: qpayResponse.transactionId,
                };
            }
            else {
                // Mark as failed
                await payoutDoc.ref.update({
                    status: 'failed',
                    failureReason: qpayResponse.error || 'QPay transfer failed',
                });
                // Restore vendor balance
                await db.collection('vendor_financial_profiles').doc(payout.vendorId).update({
                    pendingBalance: admin.firestore.FieldValue.increment(-payout.amount),
                    availableBalance: admin.firestore.FieldValue.increment(payout.amount),
                });
                // Mark commission transactions as calculated again
                const batch = db.batch();
                for (const transactionId of payout.transactionIds) {
                    batch.update(db.collection('commission_transactions').doc(transactionId), {
                        status: 'calculated',
                        payoutId: admin.firestore.FieldValue.delete(),
                    });
                }
                await batch.commit();
                throw new functions.https.HttpsError('internal', qpayResponse.error || 'QPay transfer failed');
            }
        }
        catch (error) {
            // Handle QPay API errors
            await payoutDoc.ref.update({
                status: 'failed',
                failureReason: `QPay error: ${error}`,
            });
            throw error;
        }
    }
    catch (error) {
        console.error('Error processing QPay payout:', error);
        throw new functions.https.HttpsError('internal', 'Error processing payout');
    }
});
// Simulate QPay transfer (replace with actual QPay API integration)
async function simulateQPayTransfer(payout) {
    // This would be replaced with actual QPay API calls
    // For demonstration, we'll simulate success/failure randomly
    try {
        // Simulate API delay
        await new Promise(resolve => setTimeout(resolve, 2000));
        // Simulate 95% success rate
        if (Math.random() > 0.05) {
            return {
                success: true,
                transactionId: `qpay_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
            };
        }
        else {
            return {
                success: false,
                error: 'Insufficient funds in QPay account',
            };
        }
    }
    catch (error) {
        return {
            success: false,
            error: `QPay API error: ${error}`,
        };
    }
}
// Process SMS queue for order notifications  
exports.processSMSQueue = functions.firestore
    .document('sms_queue/{smsId}')
    .onCreate(async (snap, context) => {
    try {
        const data = snap.data();
        const { phoneNumber, message, type, ownerId, orderId } = data;
        if (!phoneNumber || !message) {
            console.error('Invalid SMS data');
            await snap.ref.update({
                status: 'failed',
                error: 'Missing phoneNumber or message',
                failedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            return;
        }
        // For now, we'll just log the SMS (in production, integrate with Twilio or similar)
        console.log(`SMS to ${phoneNumber}: ${message}`);
        // Update the SMS queue document with success status
        await snap.ref.update({
            status: 'sent',
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        // Optional: Store SMS analytics
        if (type === 'new_order' && ownerId) {
            await admin.firestore().collection('sms_analytics').add({
                ownerId,
                orderId: orderId || null,
                type,
                phoneNumber: phoneNumber.replace(/\d(?=\d{4})/g, '*'),
                status: 'sent',
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
    }
    catch (error) {
        console.error('Error processing SMS queue:', error);
        // Update queue document with error status
        await snap.ref.update({
            status: 'failed',
            error: error instanceof Error ? error.message : String(error),
            failedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
});
//# sourceMappingURL=index.js.map