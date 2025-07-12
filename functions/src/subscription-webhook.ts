import { onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";
import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import * as crypto from "crypto";

// Initialize Firebase Admin
const app = initializeApp();
const db = getFirestore(app);

// QPay webhook verification (if QPay provides webhook signature verification)
function verifyQPayWebhook(payload: string, signature: string, secret: string): boolean {
  try {
    const expectedSignature = crypto
      .createHmac('sha256', secret)
      .update(payload)
      .digest('hex');
    return crypto.timingSafeEqual(
      Buffer.from(signature, 'hex'),
      Buffer.from(expectedSignature, 'hex')
    );
  } catch (error) {
    logger.error('Webhook signature verification failed:', error);
    return false;
  }
}

export const subscriptionWebhook = onRequest(
  {
    cors: true,
    secrets: ["QPAY_WEBHOOK_SECRET"],
  },
  async (req, res) => {
    logger.info('QPay subscription webhook received', { 
      method: req.method,
      headers: req.headers,
      body: req.body 
    });

    // Only accept POST requests
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method not allowed' });
      return;
    }

    try {
      const payload = req.body;
      
      // Verify webhook signature if QPay provides it
      const signature = req.headers['x-qpay-signature'] as string;
      const webhookSecret = process.env.QPAY_WEBHOOK_SECRET || '';
      
      if (signature && webhookSecret) {
        const payloadString = JSON.stringify(payload);
        if (!verifyQPayWebhook(payloadString, signature, webhookSecret)) {
          logger.error('Invalid webhook signature');
          res.status(401).json({ error: 'Invalid signature' });
          return;
        }
      }

      // Extract payment information from QPay webhook
      const paymentId = payload.sender_invoice_no || payload.invoice_id;
      const paymentStatus = payload.payment_status || payload.status;
      const paidAmount = parseFloat(payload.payment_amount || payload.amount || '0');
      const paymentDate = payload.payment_date || payload.paid_at;
      const qpayInvoiceId = payload.qpay_invoice_id || payload.invoice_id;
      const qpayPaymentId = payload.payment_id;

      logger.info('Processing subscription payment', {
        paymentId,
        paymentStatus,
        paidAmount,
        paymentDate,
        qpayInvoiceId,
        qpayPaymentId
      });

      if (!paymentId) {
        logger.error('No payment ID found in webhook payload');
        res.status(400).json({ error: 'Invalid payment data' });
        return;
      }

      // Extract store ID from payment ID (format: storeId_timestamp)
      const storeId = paymentId.split('_')[0];
      
      if (!storeId) {
        logger.error('Could not extract store ID from payment ID:', paymentId);
        res.status(400).json({ error: 'Invalid payment ID format' });
        return;
      }

      // Update payment status in Firestore
      const paymentRef = db
        .collection('store_subscriptions')
        .doc(storeId)
        .collection('payment_history')
        .doc(paymentId);

      const paymentDoc = await paymentRef.get();
      if (!paymentDoc.exists) {
        logger.error('Payment document not found:', paymentId);
        res.status(404).json({ error: 'Payment not found' });
        return;
      }

      const currentPaymentData = paymentDoc.data()!;
      const currentStatus = currentPaymentData.status;

      // Only process if payment is currently pending
      if (currentStatus !== 'pending') {
        logger.info('Payment already processed:', paymentId, 'current status:', currentStatus);
        res.status(200).json({ message: 'Payment already processed' });
        return;
      }

      // Determine new payment status
      let newStatus = 'pending';
      if (paymentStatus === 'PAID' || paymentStatus === 'COMPLETED' || paymentStatus === 'SUCCESS') {
        newStatus = 'completed';
      } else if (paymentStatus === 'FAILED' || paymentStatus === 'CANCELED' || paymentStatus === 'EXPIRED') {
        newStatus = 'failed';
      }

      // Update payment document
      await paymentRef.update({
        status: newStatus,
        paymentDate: paymentDate ? new Date(paymentDate) : FieldValue.serverTimestamp(),
        paidAmount: paidAmount,
        qpayPaymentId: qpayPaymentId,
        qpayInvoiceId: qpayInvoiceId,
        updatedAt: FieldValue.serverTimestamp(),
        webhookData: payload, // Store original webhook data for debugging
      });

      logger.info('Payment status updated to:', newStatus, 'for payment:', paymentId);

      // If payment is completed, update subscription status
      if (newStatus === 'completed') {
        await updateSubscriptionStatus(storeId, paidAmount);
      }

      res.status(200).json({ message: 'Webhook processed successfully' });
    } catch (error) {
      logger.error('Error processing subscription webhook:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

async function updateSubscriptionStatus(storeId: string, paidAmount: number): Promise<void> {
  try {
    const subscriptionRef = db.collection('store_subscriptions').doc(storeId);
    
    // Get current subscription data
    const subscriptionDoc = await subscriptionRef.get();
    if (!subscriptionDoc.exists) {
      logger.error('Subscription document not found for store:', storeId);
      return;
    }

    const subscriptionData = subscriptionDoc.data()!;
    const currentDate = new Date();
    
    // Calculate next payment date (30 days from now)
    const nextPaymentDate = new Date(currentDate);
    nextPaymentDate.setDate(nextPaymentDate.getDate() + 30);

    // Update subscription document
    await subscriptionRef.update({
      isActive: true,
      lastPaymentDate: FieldValue.serverTimestamp(),
      nextPaymentDate: nextPaymentDate,
      totalPaid: (subscriptionData.totalPaid || 0) + paidAmount,
      paymentCount: (subscriptionData.paymentCount || 0) + 1,
      updatedAt: FieldValue.serverTimestamp(),
    });

    logger.info('Subscription status updated for store:', storeId, {
      isActive: true,
      nextPaymentDate: nextPaymentDate.toISOString(),
      totalPaid: (subscriptionData.totalPaid || 0) + paidAmount,
    });

    // Update store status to active if it was suspended
    const storeRef = db.collection('stores').doc(storeId);
    const storeDoc = await storeRef.get();
    
    if (storeDoc.exists) {
      const storeData = storeDoc.data()!;
      if (storeData.status === 'suspended' || storeData.status === 'payment_overdue') {
        await storeRef.update({
          status: 'active',
          updatedAt: FieldValue.serverTimestamp(),
        });
        logger.info('Store status updated to active for store:', storeId);
      }
    }

  } catch (error) {
    logger.error('Error updating subscription status:', error);
  }
}

// Daily scheduled function to check for overdue subscriptions
export const checkSubscriptionStatus = onSchedule(
  "0 9 * * *", // Run daily at 9 AM
  async (event) => {
    logger.info('Running daily subscription status check');

    try {
      const currentDate = new Date();
      
      // Get all active subscriptions
      const subscriptionsSnapshot = await db
        .collection('store_subscriptions')
        .where('isActive', '==', true)
        .get();

      let processedCount = 0;
      let overdueCount = 0;

      for (const doc of subscriptionsSnapshot.docs) {
        const subscriptionData = doc.data();
        const storeId = doc.id;
        const nextPaymentDate = subscriptionData.nextPaymentDate?.toDate();

        if (nextPaymentDate && nextPaymentDate < currentDate) {
          // Subscription is overdue
          const daysPastDue = Math.floor((currentDate.getTime() - nextPaymentDate.getTime()) / (1000 * 60 * 60 * 24));
          
          logger.info(`Subscription overdue for store ${storeId}: ${daysPastDue} days`);
          
          if (daysPastDue > 7) {
            // Suspend store after 7 days
            await db.collection('stores').doc(storeId).update({
              status: 'suspended',
              suspendedAt: FieldValue.serverTimestamp(),
              suspendedReason: 'Payment overdue',
              updatedAt: FieldValue.serverTimestamp(),
            });

            // Update subscription status
            await db.collection('store_subscriptions').doc(storeId).update({
              isActive: false,
              suspendedAt: FieldValue.serverTimestamp(),
              suspendedReason: 'Payment overdue',
              updatedAt: FieldValue.serverTimestamp(),
            });

            logger.info(`Store ${storeId} suspended due to overdue payment`);
          } else {
            // Mark as payment overdue but don't suspend yet
            await db.collection('stores').doc(storeId).update({
              status: 'payment_overdue',
              overdueDate: nextPaymentDate,
              daysPastDue: daysPastDue,
              updatedAt: FieldValue.serverTimestamp(),
            });

            logger.info(`Store ${storeId} marked as payment overdue`);
          }
          
          overdueCount++;
        }
        
        processedCount++;
      }

      logger.info(`Subscription status check completed: ${processedCount} subscriptions processed, ${overdueCount} overdue`);
      
    } catch (error) {
      logger.error('Error in subscription status check:', error);
      throw error;
    }
  }
); 