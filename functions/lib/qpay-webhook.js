"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.qpayWebhook = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
exports.qpayWebhook = functions.https.onRequest(async (req, res) => {
    try {
        // Only accept POST requests
        if (req.method !== 'POST') {
            res.status(405).send('Method not allowed');
            return;
        }
        console.log('QPay Webhook received:', req.body);
        const webhookData = req.body;
        // Validate required fields
        if (!webhookData.payment_id || !webhookData.sender_invoice_no) {
            console.error('Missing required webhook data');
            res.status(400).send('Missing required fields');
            return;
        }
        const orderId = webhookData.sender_invoice_no;
        const paymentStatus = webhookData.payment_status;
        const paymentId = webhookData.payment_id;
        const paymentAmount = webhookData.payment_amount;
        console.log(`Processing payment for order ${orderId}: ${paymentStatus}`);
        // Update order in Firestore
        const orderRef = admin.firestore().collection('orders').doc(orderId);
        const orderDoc = await orderRef.get();
        if (!orderDoc.exists) {
            console.error(`Order ${orderId} not found`);
            res.status(404).send('Order not found');
            return;
        }
        const updateData = {
            'payment.qpayPaymentId': paymentId,
            'payment.status': paymentStatus.toLowerCase(),
            'payment.updatedAt': admin.firestore.FieldValue.serverTimestamp(),
        };
        if (paymentStatus === 'PAID') {
            updateData['payment.paidAt'] = admin.firestore.FieldValue.serverTimestamp();
            updateData['payment.paidAmount'] = paymentAmount;
            updateData.status = 'paid';
            updateData.updatedAt = admin.firestore.FieldValue.serverTimestamp();
            console.log(`Order ${orderId} marked as PAID`);
        }
        else if (paymentStatus === 'FAILED') {
            updateData.status = 'payment_failed';
            updateData.updatedAt = admin.firestore.FieldValue.serverTimestamp();
            console.log(`Order ${orderId} marked as FAILED`);
        }
        // Update the order
        await orderRef.update(updateData);
        // Send notification to user if payment is successful
        if (paymentStatus === 'PAID') {
            try {
                const orderData = orderDoc.data();
                if (orderData === null || orderData === void 0 ? void 0 : orderData.userId) {
                    await sendPaymentSuccessNotification(orderData.userId, orderId, paymentAmount);
                }
            }
            catch (notificationError) {
                console.error('Error sending notification:', notificationError);
                // Don't fail the webhook for notification errors
            }
        }
        // Log the webhook for audit trail
        await admin.firestore().collection('qpay_webhooks').add({
            orderId,
            paymentId,
            paymentStatus,
            paymentAmount,
            webhookData,
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        res.status(200).send('Webhook processed successfully');
    }
    catch (error) {
        console.error('Error processing QPay webhook:', error);
        res.status(500).send('Internal server error');
    }
});
async function sendPaymentSuccessNotification(userId, orderId, amount) {
    try {
        // Get user's FCM token
        const userDoc = await admin.firestore().collection('users').doc(userId).get();
        const userData = userDoc.data();
        if (!(userData === null || userData === void 0 ? void 0 : userData.fcmToken)) {
            console.log(`No FCM token for user ${userId}`);
            return;
        }
        const message = {
            token: userData.fcmToken,
            notification: {
                title: 'Төлбөр амжилттай',
                body: `Таны захиалга #${orderId.substring(0, 8)} төлбөр амжилттай хийгдлээ. ₮${amount.toLocaleString()}`,
            },
            data: {
                type: 'payment_success',
                orderId: orderId,
                amount: amount.toString(),
            },
            android: {
                notification: {
                    icon: 'ic_notification',
                    color: '#1976D2',
                    sound: 'default',
                },
            },
            apns: {
                payload: {
                    aps: {
                        sound: 'default',
                        badge: 1,
                    },
                },
            },
        };
        await admin.messaging().send(message);
        console.log(`Payment success notification sent to user ${userId}`);
    }
    catch (error) {
        console.error('Error sending payment notification:', error);
        throw error;
    }
}
//# sourceMappingURL=qpay-webhook.js.map