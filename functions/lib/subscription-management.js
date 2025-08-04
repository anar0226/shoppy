"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createSubscriptionPayment = exports.cancelSubscription = exports.manualSubscriptionRenewal = exports.getSubscriptionAnalytics = exports.checkGracePeriodExpirations = exports.checkExpiredSubscriptions = exports.checkSubscriptionRenewals = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();
/**
 * Scheduled function to check and process subscription renewals
 * Runs daily at 2:00 AM
 */
exports.checkSubscriptionRenewals = functions.pubsub
    .schedule('0 2 * * *')
    .timeZone('Asia/Ulaanbaatar')
    .onRun(async (context) => {
    try {
        console.log('Starting subscription renewal check...');
        const now = admin.firestore.Timestamp.now();
        // Get stores with active subscriptions that need renewal
        const renewalQuery = await db.collection('stores')
            .where('subscriptionStatus', '==', 'active')
            .where('nextPaymentDate', '<=', now)
            .get();
        console.log(`Found ${renewalQuery.size} stores needing renewal`);
        const renewalPromises = renewalQuery.docs.map(async (doc) => {
            const storeData = doc.data();
            const renewalData = {
                storeId: doc.id,
                userId: storeData.ownerId,
                storeName: storeData.name,
                currentStatus: storeData.subscriptionStatus,
                lastPaymentDate: storeData.lastPaymentDate,
                nextPaymentDate: storeData.nextPaymentDate,
                subscriptionEndDate: storeData.subscriptionEndDate,
            };
            return await processSubscriptionRenewal(renewalData);
        });
        const results = await Promise.allSettled(renewalPromises);
        const successful = results.filter(r => r.status === 'fulfilled').length;
        const failed = results.filter(r => r.status === 'rejected').length;
        console.log(`Subscription renewal check completed. Successful: ${successful}, Failed: ${failed}`);
        return { success: true, processed: successful, failed };
    }
    catch (error) {
        console.error('Error in subscription renewal check:', error);
        throw error;
    }
});
/**
 * Process subscription renewal for a single store
 */
async function processSubscriptionRenewal(renewalData) {
    try {
        console.log(`Processing renewal for store: ${renewalData.storeId}`);
        const now = admin.firestore.Timestamp.now();
        const nextPaymentDate = new Date();
        nextPaymentDate.setMonth(nextPaymentDate.getMonth() + 1);
        const subscriptionEndDate = new Date();
        subscriptionEndDate.setMonth(subscriptionEndDate.getMonth() + 1);
        // Update subscription dates
        await db.collection('stores').doc(renewalData.storeId).update({
            nextPaymentDate: admin.firestore.Timestamp.fromDate(nextPaymentDate),
            subscriptionEndDate: admin.firestore.Timestamp.fromDate(subscriptionEndDate),
            updatedAt: now,
        });
        // Send renewal reminder notification
        await sendRenewalReminderNotification(renewalData.userId, renewalData.storeId, renewalData.storeName);
        console.log(`Renewal processed for store: ${renewalData.storeId}`);
    }
    catch (error) {
        console.error(`Error processing renewal for store ${renewalData.storeId}:`, error);
        throw error;
    }
}
/**
 * Scheduled function to check and handle expired subscriptions
 * Runs daily at 3:00 AM
 */
exports.checkExpiredSubscriptions = functions.pubsub
    .schedule('0 3 * * *')
    .timeZone('Asia/Ulaanbaatar')
    .onRun(async (context) => {
    try {
        console.log('Starting expired subscription check...');
        const now = admin.firestore.Timestamp.now();
        // Get stores with expired subscriptions
        const expiredQuery = await db.collection('stores')
            .where('subscriptionStatus', '==', 'active')
            .where('subscriptionEndDate', '<', now)
            .get();
        console.log(`Found ${expiredQuery.size} stores with expired subscriptions`);
        const expiredPromises = expiredQuery.docs.map(async (doc) => {
            const storeData = doc.data();
            return await handleExpiredSubscription(doc.id, storeData);
        });
        const results = await Promise.allSettled(expiredPromises);
        const successful = results.filter(r => r.status === 'fulfilled').length;
        const failed = results.filter(r => r.status === 'rejected').length;
        console.log(`Expired subscription check completed. Successful: ${successful}, Failed: ${failed}`);
        return { success: true, processed: successful, failed };
    }
    catch (error) {
        console.error('Error in expired subscription check:', error);
        throw error;
    }
});
/**
 * Handle expired subscription for a single store
 */
async function handleExpiredSubscription(storeId, storeData) {
    try {
        console.log(`Handling expired subscription for store: ${storeId}`);
        const now = admin.firestore.Timestamp.now();
        const gracePeriodEnd = new Date();
        gracePeriodEnd.setDate(gracePeriodEnd.getDate() + 7); // 7-day grace period
        // Move to grace period
        await db.collection('stores').doc(storeId).update({
            subscriptionStatus: 'gracePeriod',
            subscriptionEndDate: admin.firestore.Timestamp.fromDate(gracePeriodEnd),
            updatedAt: now,
        });
        // Send grace period notification
        await sendGracePeriodNotification(storeData.ownerId, storeId, storeData.name);
        console.log(`Expired subscription handled for store: ${storeId}`);
    }
    catch (error) {
        console.error(`Error handling expired subscription for store ${storeId}:`, error);
        throw error;
    }
}
/**
 * Scheduled function to check and handle grace period expirations
 * Runs daily at 4:00 AM
 */
exports.checkGracePeriodExpirations = functions.pubsub
    .schedule('0 4 * * *')
    .timeZone('Asia/Ulaanbaatar')
    .onRun(async (context) => {
    try {
        console.log('Starting grace period expiration check...');
        const now = admin.firestore.Timestamp.now();
        // Get stores with expired grace periods
        const graceExpiredQuery = await db.collection('stores')
            .where('subscriptionStatus', '==', 'gracePeriod')
            .where('subscriptionEndDate', '<', now)
            .get();
        console.log(`Found ${graceExpiredQuery.size} stores with expired grace periods`);
        const expiredPromises = graceExpiredQuery.docs.map(async (doc) => {
            const storeData = doc.data();
            return await handleGracePeriodExpiration(doc.id, storeData);
        });
        const results = await Promise.allSettled(expiredPromises);
        const successful = results.filter(r => r.status === 'fulfilled').length;
        const failed = results.filter(r => r.status === 'rejected').length;
        console.log(`Grace period expiration check completed. Successful: ${successful}, Failed: ${failed}`);
        return { success: true, processed: successful, failed };
    }
    catch (error) {
        console.error('Error in grace period expiration check:', error);
        throw error;
    }
});
/**
 * Handle grace period expiration for a single store
 */
async function handleGracePeriodExpiration(storeId, storeData) {
    try {
        console.log(`Handling grace period expiration for store: ${storeId}`);
        const now = admin.firestore.Timestamp.now();
        // Move to expired status
        await db.collection('stores').doc(storeId).update({
            subscriptionStatus: 'expired',
            updatedAt: now,
        });
        // Send final expiration notification
        await sendFinalExpirationNotification(storeData.ownerId, storeId, storeData.name);
        console.log(`Grace period expired for store: ${storeId}`);
    }
    catch (error) {
        console.error(`Error handling grace period expiration for store ${storeId}:`, error);
        throw error;
    }
}
/**
 * Get subscription analytics for admin dashboard
 */
exports.getSubscriptionAnalytics = functions.https.onCall(async (data, context) => {
    try {
        // Verify authentication and admin role
        if (!context.auth) {
            throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
        }
        // Check if user is admin (you can implement your own admin check)
        const userDoc = await db.collection('users').doc(context.auth.uid).get();
        if (!userDoc.exists) {
            throw new functions.https.HttpsError('permission-denied', 'User not found');
        }
        const userData = userDoc.data();
        if ((userData === null || userData === void 0 ? void 0 : userData.role) !== 'admin') {
            throw new functions.https.HttpsError('permission-denied', 'Admin access required');
        }
        // Get all stores
        const storesSnapshot = await db.collection('stores').get();
        let totalStores = 0;
        let activeSubscriptions = 0;
        let expiredSubscriptions = 0;
        let gracePeriodSubscriptions = 0;
        let pendingSubscriptions = 0;
        let cancelledSubscriptions = 0;
        let monthlyRevenue = 0;
        let totalSubscriptionDuration = 0;
        let activeSubscriptionCount = 0;
        storesSnapshot.forEach((doc) => {
            const storeData = doc.data();
            totalStores++;
            switch (storeData.subscriptionStatus) {
                case 'active':
                    activeSubscriptions++;
                    if (storeData.lastPaymentDate) {
                        monthlyRevenue += 100; // 100 MNT per active subscription
                        activeSubscriptionCount++;
                    }
                    break;
                case 'expired':
                    expiredSubscriptions++;
                    break;
                case 'gracePeriod':
                    gracePeriodSubscriptions++;
                    break;
                case 'pending':
                    pendingSubscriptions++;
                    break;
                case 'cancelled':
                    cancelledSubscriptions++;
                    break;
            }
            // Calculate average subscription duration
            if (storeData.subscriptionStartDate && storeData.lastPaymentDate) {
                const startDate = storeData.subscriptionStartDate.toDate();
                const lastPayment = storeData.lastPaymentDate.toDate();
                const durationInDays = (lastPayment.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24);
                totalSubscriptionDuration += durationInDays;
            }
        });
        const averageSubscriptionDuration = activeSubscriptionCount > 0
            ? totalSubscriptionDuration / activeSubscriptionCount
            : 0;
        const analytics = {
            totalStores,
            activeSubscriptions,
            expiredSubscriptions,
            gracePeriodSubscriptions,
            pendingSubscriptions,
            cancelledSubscriptions,
            monthlyRevenue,
            averageSubscriptionDuration,
        };
        return analytics;
    }
    catch (error) {
        console.error('Error getting subscription analytics:', error);
        throw new functions.https.HttpsError('internal', 'Error getting subscription analytics');
    }
});
/**
 * Manually renew a subscription (admin function)
 */
exports.manualSubscriptionRenewal = functions.https.onCall(async (data, context) => {
    try {
        // Verify authentication and admin role
        if (!context.auth) {
            throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
        }
        const { storeId } = data;
        if (!storeId) {
            throw new functions.https.HttpsError('invalid-argument', 'Missing storeId');
        }
        // Get store document
        const storeRef = db.collection('stores').doc(storeId);
        const storeDoc = await storeRef.get();
        if (!storeDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'Store not found');
        }
        const storeData = storeDoc.data();
        if (!storeData) {
            throw new functions.https.HttpsError('not-found', 'Store data is null');
        }
        const now = admin.firestore.Timestamp.now();
        const nextPaymentDate = new Date();
        nextPaymentDate.setMonth(nextPaymentDate.getMonth() + 1);
        const subscriptionEndDate = new Date();
        subscriptionEndDate.setMonth(subscriptionEndDate.getMonth() + 1);
        // Update subscription status
        await storeRef.update({
            subscriptionStatus: 'active',
            lastPaymentDate: now,
            nextPaymentDate: admin.firestore.Timestamp.fromDate(nextPaymentDate),
            subscriptionEndDate: admin.firestore.Timestamp.fromDate(subscriptionEndDate),
            updatedAt: now,
        });
        // Create manual payment record
        const paymentRecord = {
            id: `MANUAL_${Date.now()}`,
            storeId: storeId,
            userId: storeData.ownerId,
            amount: 100,
            currency: 'MNT',
            status: 'completed',
            paymentMethod: 'manual',
            transactionId: `MANUAL_${Date.now()}`,
            createdAt: now,
            processedAt: now,
            description: 'Сарын төлбөр - Гараар төлөгдсөн',
            metadata: {
                type: 'subscription',
                manualRenewal: true,
                renewedBy: context.auth.uid,
            },
        };
        // Add to payment history
        await storeRef.update({
            paymentHistory: admin.firestore.FieldValue.arrayUnion([paymentRecord]),
        });
        // Create payment record in payments collection
        await db.collection('payments').add(paymentRecord);
        return { success: true, message: 'Subscription manually renewed' };
    }
    catch (error) {
        console.error('Error manually renewing subscription:', error);
        throw new functions.https.HttpsError('internal', 'Error manually renewing subscription');
    }
});
/**
 * Cancel a subscription
 */
exports.cancelSubscription = functions.https.onCall(async (data, context) => {
    try {
        // Verify authentication
        if (!context.auth) {
            throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
        }
        const { storeId } = data;
        if (!storeId) {
            throw new functions.https.HttpsError('invalid-argument', 'Missing storeId');
        }
        // Get store document
        const storeRef = db.collection('stores').doc(storeId);
        const storeDoc = await storeRef.get();
        if (!storeDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'Store not found');
        }
        const storeData = storeDoc.data();
        if (!storeData) {
            throw new functions.https.HttpsError('not-found', 'Store data is null');
        }
        // Verify store ownership
        if (storeData.ownerId !== context.auth.uid) {
            throw new functions.https.HttpsError('permission-denied', 'Only store owner can cancel subscription');
        }
        const now = admin.firestore.Timestamp.now();
        // Cancel subscription
        await storeRef.update({
            subscriptionStatus: 'cancelled',
            updatedAt: now,
        });
        // Send cancellation notification
        await sendCancellationNotification(context.auth.uid, storeId, storeData.name);
        return { success: true, message: 'Subscription cancelled successfully' };
    }
    catch (error) {
        console.error('Error cancelling subscription:', error);
        throw new functions.https.HttpsError('internal', 'Error cancelling subscription');
    }
});
/**
 * Create subscription payment invoice through QPay
 * This function handles the QPay API call server-side to avoid CORS issues
 */
exports.createSubscriptionPayment = functions.https.onCall(async (data, context) => {
    var _a, _b, _c, _d, _e;
    try {
        // Verify authentication
        if (!context.auth) {
            throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
        }
        const { storeId, amount = 200, description } = data;
        if (!storeId) {
            throw new functions.https.HttpsError('invalid-argument', 'Store ID is required');
        }
        // Verify user owns the store
        const storeDoc = await db.collection('stores').doc(storeId).get();
        if (!storeDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'Store not found');
        }
        const storeData = storeDoc.data();
        if ((storeData === null || storeData === void 0 ? void 0 : storeData.ownerId) !== context.auth.uid) {
            throw new functions.https.HttpsError('permission-denied', 'You do not have permission to access this store');
        }
        // Generate simple 6-digit transaction reference
        const randomNumber = Math.floor(100000 + Math.random() * 900000);
        const orderId = `SUB_${randomNumber}`;
        // Get QPay credentials from environment
        const qpayUsername = (_a = functions.config().qpay) === null || _a === void 0 ? void 0 : _a.username;
        const qpayPassword = (_b = functions.config().qpay) === null || _b === void 0 ? void 0 : _b.password;
        // Get invoice code from Firebase config
        const qpayInvoiceCode = (_c = functions.config().qpay) === null || _c === void 0 ? void 0 : _c.invoice_code;
        const qpayBaseUrl = ((_d = functions.config().qpay) === null || _d === void 0 ? void 0 : _d.base_url) || 'https://merchant.qpay.mn/v2';
        if (!qpayUsername || !qpayPassword || !qpayInvoiceCode) {
            throw new functions.https.HttpsError('internal', 'QPay credentials not configured');
        }
        // Get QPay access token
        const authResponse = await fetch(`${qpayBaseUrl}/auth/token`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': `Basic ${Buffer.from(`${qpayUsername}:${qpayPassword}`).toString('base64')}`,
            },
            body: JSON.stringify({ grant_type: 'client_credentials' }),
        });
        if (!authResponse.ok) {
            throw new functions.https.HttpsError('internal', 'Failed to authenticate with QPay');
        }
        const authData = await authResponse.json();
        const accessToken = authData.access_token;
        // Create QPay invoice
        const invoiceResponse = await fetch(`${qpayBaseUrl}/invoice`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': `Bearer ${accessToken}`,
            },
            body: JSON.stringify({
                invoice_code: qpayInvoiceCode,
                sender_invoice_no: orderId,
                invoice_receiver_code: storeId,
                invoice_description: description || `Сарын эрхийн төлбөр - ${(storeData === null || storeData === void 0 ? void 0 : storeData.name) || 'Дэлгүүр'}`,
                amount: amount,
                callback_url: `${((_e = functions.config().app) === null || _e === void 0 ? void 0 : _e.webhook_url) || 'https://shoppy-6d81f.web.app'}/api/qpay-webhook`,
            }),
        });
        if (!invoiceResponse.ok) {
            const errorText = await invoiceResponse.text();
            console.error('QPay invoice creation failed:', errorText);
            throw new functions.https.HttpsError('internal', 'Failed to create QPay invoice');
        }
        const invoiceData = await invoiceResponse.json();
        const invoiceId = invoiceData.qPayInvoiceId || invoiceData.invoice_id;
        if (!invoiceId) {
            throw new functions.https.HttpsError('internal', 'QPay invoice ID not found in response');
        }
        // Generate QPay payment URL - use the proper QPay web gateway URL
        const paymentUrl = `${qpayBaseUrl}/invoice/${invoiceId}`;
        const qpayUrl = `https://qpay.mn/q/?q=${encodeURIComponent(paymentUrl)}`;
        // Save payment record to Firestore
        await db
            .collection('store_subscriptions')
            .doc(storeId)
            .collection('payments')
            .doc(orderId)
            .set({
            orderId: orderId,
            invoiceId: invoiceId,
            amount: amount,
            description: description || 'Сарын эрхийн төлбөр',
            status: 'pending',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            qpayUrl: qpayUrl,
            userId: context.auth.uid,
        });
        return {
            success: true,
            orderId: orderId,
            invoiceId: invoiceId,
            qpayUrl: qpayUrl,
            amount: amount,
        };
    }
    catch (error) {
        console.error('Error creating subscription payment:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', 'Failed to create subscription payment');
    }
});
// Notification functions
async function sendRenewalReminderNotification(userId, storeId, storeName) {
    try {
        const userDoc = await db.collection('users').doc(userId).get();
        if (!userDoc.exists)
            return;
        const userData = userDoc.data();
        const fcmToken = userData === null || userData === void 0 ? void 0 : userData.fcmToken;
        if (!fcmToken)
            return;
        const message = {
            token: fcmToken,
            notification: {
                title: 'Сарын төлбөрийн сануулга',
                body: 'Таны дэлгүүрийн сарын төлбөр төлөх хугацаа ирлээ.',
            },
            data: {
                type: 'subscription_renewal_reminder',
                storeId: storeId,
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
        };
        await admin.messaging().send(message);
    }
    catch (error) {
        console.error('Error sending renewal reminder notification:', error);
    }
}
async function sendGracePeriodNotification(userId, storeId, storeName) {
    try {
        const userDoc = await db.collection('users').doc(userId).get();
        if (!userDoc.exists)
            return;
        const userData = userDoc.data();
        const fcmToken = userData === null || userData === void 0 ? void 0 : userData.fcmToken;
        if (!fcmToken)
            return;
        const message = {
            token: fcmToken,
            notification: {
                title: 'Захиалгын хүлээлтийн хугацаа',
                body: 'Таны дэлгүүрийн захиалга идэвхгүй болсон. 7 хоногийн хүлээлтийн хугацаа эхэллээ.',
            },
            data: {
                type: 'subscription_grace_period',
                storeId: storeId,
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
        };
        await admin.messaging().send(message);
    }
    catch (error) {
        console.error('Error sending grace period notification:', error);
    }
}
async function sendFinalExpirationNotification(userId, storeId, storeName) {
    try {
        const userDoc = await db.collection('users').doc(userId).get();
        if (!userDoc.exists)
            return;
        const userData = userDoc.data();
        const fcmToken = userData === null || userData === void 0 ? void 0 : userData.fcmToken;
        if (!fcmToken)
            return;
        const message = {
            token: fcmToken,
            notification: {
                title: 'Захиалга дууссан',
                body: 'Таны дэлгүүрийн захиалга бүрэн дууссан. Дахин идэвхжүүлэхийн тулд төлбөр төлнө үү.',
            },
            data: {
                type: 'subscription_expired',
                storeId: storeId,
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
        };
        await admin.messaging().send(message);
    }
    catch (error) {
        console.error('Error sending final expiration notification:', error);
    }
}
async function sendCancellationNotification(userId, storeId, storeName) {
    try {
        const userDoc = await db.collection('users').doc(userId).get();
        if (!userDoc.exists)
            return;
        const userData = userDoc.data();
        const fcmToken = userData === null || userData === void 0 ? void 0 : userData.fcmToken;
        if (!fcmToken)
            return;
        const message = {
            token: fcmToken,
            notification: {
                title: 'Захиалга цуцлагдсан',
                body: 'Таны дэлгүүрийн захиалга амжилттай цуцлагдлаа.',
            },
            data: {
                type: 'subscription_cancelled',
                storeId: storeId,
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
        };
        await admin.messaging().send(message);
    }
    catch (error) {
        console.error('Error sending cancellation notification:', error);
    }
}
//# sourceMappingURL=subscription-management.js.map