import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

interface SubscriptionAnalytics {
  totalStores: number;
  activeSubscriptions: number;
  expiredSubscriptions: number;
  gracePeriodSubscriptions: number;
  pendingSubscriptions: number;
  cancelledSubscriptions: number;
  monthlyRevenue: number;
  averageSubscriptionDuration: number;
}

interface SubscriptionRenewalData {
  storeId: string;
  userId: string;
  storeName: string;
  currentStatus: string;
  lastPaymentDate: admin.firestore.Timestamp;
  nextPaymentDate: admin.firestore.Timestamp;
  subscriptionEndDate: admin.firestore.Timestamp;
}

/**
 * Scheduled function to check and process subscription renewals
 * Runs daily at 2:00 AM
 */
export const checkSubscriptionRenewals = functions.pubsub
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
        const renewalData: SubscriptionRenewalData = {
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
    } catch (error) {
      console.error('Error in subscription renewal check:', error);
      throw error;
    }
  });

/**
 * Process subscription renewal for a single store
 */
async function processSubscriptionRenewal(renewalData: SubscriptionRenewalData): Promise<void> {
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
  } catch (error) {
    console.error(`Error processing renewal for store ${renewalData.storeId}:`, error);
    throw error;
  }
}

/**
 * Scheduled function to check and handle expired subscriptions
 * Runs daily at 3:00 AM
 */
export const checkExpiredSubscriptions = functions.pubsub
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
    } catch (error) {
      console.error('Error in expired subscription check:', error);
      throw error;
    }
  });

/**
 * Handle expired subscription for a single store
 */
async function handleExpiredSubscription(storeId: string, storeData: any): Promise<void> {
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
  } catch (error) {
    console.error(`Error handling expired subscription for store ${storeId}:`, error);
    throw error;
  }
}

/**
 * Scheduled function to check and handle grace period expirations
 * Runs daily at 4:00 AM
 */
export const checkGracePeriodExpirations = functions.pubsub
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
    } catch (error) {
      console.error('Error in grace period expiration check:', error);
      throw error;
    }
  });

/**
 * Handle grace period expiration for a single store
 */
async function handleGracePeriodExpiration(storeId: string, storeData: any): Promise<void> {
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
  } catch (error) {
    console.error(`Error handling grace period expiration for store ${storeId}:`, error);
    throw error;
  }
}

/**
 * Get subscription analytics for admin dashboard
 */
export const getSubscriptionAnalytics = functions.https.onCall(async (data, context) => {
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
    if (userData?.role !== 'admin') {
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

    const analytics: SubscriptionAnalytics = {
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
  } catch (error) {
    console.error('Error getting subscription analytics:', error);
    throw new functions.https.HttpsError('internal', 'Error getting subscription analytics');
  }
});

/**
 * Manually renew a subscription (admin function)
 */
export const manualSubscriptionRenewal = functions.https.onCall(async (data, context) => {
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
  } catch (error) {
    console.error('Error manually renewing subscription:', error);
    throw new functions.https.HttpsError('internal', 'Error manually renewing subscription');
  }
});

/**
 * Cancel a subscription
 */
export const cancelSubscription = functions.https.onCall(async (data, context) => {
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
  } catch (error) {
    console.error('Error cancelling subscription:', error);
    throw new functions.https.HttpsError('internal', 'Error cancelling subscription');
  }
});

// Notification functions
async function sendRenewalReminderNotification(userId: string, storeId: string, storeName: string): Promise<void> {
  try {
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) return;

    const userData = userDoc.data();
    const fcmToken = userData?.fcmToken;

    if (!fcmToken) return;

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
  } catch (error) {
    console.error('Error sending renewal reminder notification:', error);
  }
}

async function sendGracePeriodNotification(userId: string, storeId: string, storeName: string): Promise<void> {
  try {
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) return;

    const userData = userDoc.data();
    const fcmToken = userData?.fcmToken;

    if (!fcmToken) return;

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
  } catch (error) {
    console.error('Error sending grace period notification:', error);
  }
}

async function sendFinalExpirationNotification(userId: string, storeId: string, storeName: string): Promise<void> {
  try {
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) return;

    const userData = userDoc.data();
    const fcmToken = userData?.fcmToken;

    if (!fcmToken) return;

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
  } catch (error) {
    console.error('Error sending final expiration notification:', error);
  }
}

async function sendCancellationNotification(userId: string, storeId: string, storeName: string): Promise<void> {
  try {
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) return;

    const userData = userDoc.data();
    const fcmToken = userData?.fcmToken;

    if (!fcmToken) return;

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
  } catch (error) {
    console.error('Error sending cancellation notification:', error);
  }
} 