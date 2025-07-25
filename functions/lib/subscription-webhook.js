"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getSubscriptionPaymentHistory = exports.verifySubscriptionPayment = exports.subscriptionWebhook = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();
/**
 * Webhook handler for QPay subscription payments
 * Handles payment notifications from QPay for subscription payments
 */
exports.subscriptionWebhook = functions.https.onRequest(async (req, res) => {
    var _a, _b, _c;
    try {
        // Verify request method
        if (req.method !== 'POST') {
            res.status(405).send('Method Not Allowed');
            return;
        }
        // Log the webhook data
        console.log('Subscription webhook received:', JSON.stringify(req.body, null, 2));
        const webhookData = req.body;
        // Validate required fields
        if (!webhookData.object_id || !webhookData.payment_status) {
            console.error('Missing required fields in webhook data');
            res.status(400).send('Bad Request - Missing required fields');
            return;
        }
        // Check if this is a subscription payment
        if (((_a = webhookData.metadata) === null || _a === void 0 ? void 0 : _a.type) !== 'subscription') {
            console.log('Not a subscription payment, ignoring');
            res.status(200).send('OK - Not a subscription payment');
            return;
        }
        // Extract subscription payment data
        const subscriptionPayment = {
            storeId: ((_b = webhookData.metadata) === null || _b === void 0 ? void 0 : _b.storeId) || '',
            userId: ((_c = webhookData.metadata) === null || _c === void 0 ? void 0 : _c.userId) || '',
            amount: webhookData.payment_amount || 0,
            status: webhookData.payment_status,
            paymentId: webhookData.payment_id || '',
            paymentDate: new Date(webhookData.payment_date),
            paymentMethod: webhookData.paid_by || 'QPay',
            currency: webhookData.payment_currency || 'MNT',
        };
        // Process the subscription payment
        await processSubscriptionPayment(subscriptionPayment);
        // Send success response
        res.status(200).send('OK');
    }
    catch (error) {
        console.error('Error processing subscription webhook:', error);
        res.status(500).send('Internal Server Error');
    }
});
/**
 * Process subscription payment and update store subscription status
 */
async function processSubscriptionPayment(payment) {
    try {
        console.log('Processing subscription payment:', JSON.stringify(payment, null, 2));
        // Validate payment data
        if (!payment.storeId || !payment.userId) {
            throw new Error('Missing storeId or userId in payment data');
        }
        // Check if payment is successful
        if (payment.status !== 'PAID') {
            console.log('Payment not successful, status:', payment.status);
            return;
        }
        // Get store document
        const storeRef = db.collection('stores').doc(payment.storeId);
        const storeDoc = await storeRef.get();
        if (!storeDoc.exists) {
            throw new Error(`Store not found: ${payment.storeId}`);
        }
        const storeData = storeDoc.data();
        if (!storeData) {
            throw new Error('Store data is null');
        }
        // Verify payment amount matches expected monthly fee
        const expectedAmount = 100; // 100 MNT monthly fee
        if (payment.amount !== expectedAmount) {
            console.warn(`Payment amount mismatch. Expected: ${expectedAmount}, Received: ${payment.amount}`);
            // You might want to handle this differently based on your business logic
        }
        // Update store subscription status
        const now = admin.firestore.Timestamp.now();
        const nextPaymentDate = new Date();
        nextPaymentDate.setMonth(nextPaymentDate.getMonth() + 1);
        const subscriptionEndDate = new Date();
        subscriptionEndDate.setMonth(subscriptionEndDate.getMonth() + 1);
        const updateData = {
            subscriptionStatus: 'active',
            lastPaymentDate: now,
            nextPaymentDate: admin.firestore.Timestamp.fromDate(nextPaymentDate),
            subscriptionEndDate: admin.firestore.Timestamp.fromDate(subscriptionEndDate),
            updatedAt: now,
        };
        // Add payment to history
        const paymentRecord = {
            id: payment.paymentId,
            storeId: payment.storeId,
            userId: payment.userId,
            amount: payment.amount,
            currency: payment.currency,
            status: 'completed',
            paymentMethod: 'qpay',
            transactionId: payment.paymentId,
            createdAt: now,
            processedAt: now,
            description: 'Сарын төлбөр - Shoppy дэлгүүр',
            metadata: {
                type: 'subscription',
                webhookProcessed: true,
            },
        };
        // Update store document
        await storeRef.update(Object.assign(Object.assign({}, updateData), { paymentHistory: admin.firestore.FieldValue.arrayUnion([paymentRecord]) }));
        // Create payment record in payments collection
        await db.collection('payments').add(paymentRecord);
        // Send notification to store owner (optional)
        await sendSubscriptionActivationNotification(payment.userId, payment.storeId);
        console.log('Subscription payment processed successfully for store:', payment.storeId);
    }
    catch (error) {
        console.error('Error processing subscription payment:', error);
        throw error;
    }
}
/**
 * Send notification to store owner about subscription activation
 */
async function sendSubscriptionActivationNotification(userId, storeId) {
    try {
        // Get user's FCM token
        const userDoc = await db.collection('users').doc(userId).get();
        if (!userDoc.exists) {
            console.log('User document not found for notification:', userId);
            return;
        }
        const userData = userDoc.data();
        const fcmToken = userData === null || userData === void 0 ? void 0 : userData.fcmToken;
        if (!fcmToken) {
            console.log('No FCM token found for user:', userId);
            return;
        }
        // Send notification
        const message = {
            token: fcmToken,
            notification: {
                title: 'Захиалга идэвхжлээ',
                body: 'Таны сарын төлбөр амжилттай төлөгдлөө. Дэлгүүрээ тохируулж эхлээрэй!',
            },
            data: {
                type: 'subscription_activated',
                storeId: storeId,
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
        };
        const response = await admin.messaging().send(message);
        console.log('Subscription activation notification sent:', response);
    }
    catch (error) {
        console.error('Error sending subscription activation notification:', error);
        // Don't throw error as notification is not critical
    }
}
/**
 * Manual subscription payment verification
 * Can be called to manually verify and process a subscription payment
 */
exports.verifySubscriptionPayment = functions.https.onCall(async (data, context) => {
    try {
        // Verify authentication
        if (!context.auth) {
            throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
        }
        const { paymentId, storeId } = data;
        if (!paymentId || !storeId) {
            throw new functions.https.HttpsError('invalid-argument', 'Missing paymentId or storeId');
        }
        // Get payment record
        const paymentQuery = await db.collection('payments')
            .where('transactionId', '==', paymentId)
            .where('storeId', '==', storeId)
            .limit(1)
            .get();
        if (paymentQuery.empty) {
            throw new functions.https.HttpsError('not-found', 'Payment record not found');
        }
        const paymentDoc = paymentQuery.docs[0];
        const paymentData = paymentDoc.data();
        // Create subscription payment object
        const subscriptionPayment = {
            storeId: paymentData.storeId,
            userId: paymentData.userId,
            amount: paymentData.amount,
            status: paymentData.status,
            paymentId: paymentData.transactionId,
            paymentDate: paymentData.createdAt.toDate(),
            paymentMethod: paymentData.paymentMethod,
            currency: paymentData.currency,
        };
        // Process the payment
        await processSubscriptionPayment(subscriptionPayment);
        return { success: true, message: 'Subscription payment verified and processed' };
    }
    catch (error) {
        console.error('Error verifying subscription payment:', error);
        throw new functions.https.HttpsError('internal', 'Error verifying subscription payment');
    }
});
/**
 * Get subscription payment history for a store
 */
exports.getSubscriptionPaymentHistory = functions.https.onCall(async (data, context) => {
    try {
        // Verify authentication
        if (!context.auth) {
            throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
        }
        const { storeId } = data;
        if (!storeId) {
            throw new functions.https.HttpsError('invalid-argument', 'Missing storeId');
        }
        // Get payment history
        const paymentsQuery = await db.collection('payments')
            .where('storeId', '==', storeId)
            .where('description', '==', 'Сарын төлбөр - Shoppy дэлгүүр')
            .orderBy('createdAt', 'desc')
            .get();
        const payments = paymentsQuery.docs.map(doc => {
            var _a;
            return (Object.assign(Object.assign({ id: doc.id }, doc.data()), { createdAt: doc.data().createdAt.toDate(), processedAt: (_a = doc.data().processedAt) === null || _a === void 0 ? void 0 : _a.toDate() }));
        });
        return { payments };
    }
    catch (error) {
        console.error('Error getting subscription payment history:', error);
        throw new functions.https.HttpsError('internal', 'Error getting payment history');
    }
});
//# sourceMappingURL=subscription-webhook.js.map