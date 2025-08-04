import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

interface PaymentVerificationData {
  orderId: string;
  storeId: string;
  amount: number;
  bankAccount: string;
  transactionReference?: string;
}



/**
 * Verify payment by checking bank transactions
 * This function can be called manually or scheduled to check for payments
 */
export const verifyBankPayment = functions.https.onCall(async (data: PaymentVerificationData, context) => {
  try {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Хэрэглэгч баталгаажуулалт хийнэ үү');
    }

    const { orderId, storeId, amount, bankAccount, transactionReference } = data;

    if (!orderId || !storeId || !amount || !bankAccount) {
      throw new functions.https.HttpsError('invalid-argument', 'Шаардлагатай мэдээлэл оруулна уу');
    }

    // Get payment record
    const paymentDoc = await db
      .collection('store_subscriptions')
      .doc(storeId)
      .collection('payments')
      .doc(orderId)
      .get();

    if (!paymentDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Төлбөр мэдээлэл олдсонгүй');
    }

    const paymentData = paymentDoc.data();
    if (!paymentData) {
      throw new functions.https.HttpsError('not-found', 'Төлбөр мэдээлэл олдсонгүй');
    }

    // Check if payment is already verified
    if (paymentData.status === 'completed') {
      return { success: true, message: 'Төлбөр амжилттай төлөгдлөө', status: 'completed' };
    }

    // Verify payment by checking bank transactions
    const isPaymentVerified = await checkBankTransaction(orderId, amount, bankAccount, transactionReference);

    if (isPaymentVerified) {
      // Update payment status
      await paymentDoc.ref.update({
        status: 'completed',
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        transactionReference: transactionReference,
      });

      // Update store subscription status
      await updateStoreSubscription(storeId, amount);

      return { success: true, message: 'Төлбөр амжилттай төлөгдлөө', status: 'completed' };
    } else {
      // Update last check time
      await paymentDoc.ref.update({
        lastChecked: admin.firestore.FieldValue.serverTimestamp(),
        status: 'pending',
      });

      return { success: false, message: 'Төлбөр олдсонгүй', status: 'pending' };
    }
  } catch (error) {
    console.error('Төлбөр баталгаажуулах явцад алдаа гарлаа:', error);
    throw new functions.https.HttpsError('internal', 'Төлбөр баталгаажуулах явцад алдаа гарлаа');
  }
});

/**
 * Check bank transaction for payment verification
 * This is a placeholder implementation - you'll need to integrate with your bank's API
 */
async function checkBankTransaction(
  orderId: string,
  expectedAmount: number,
  bankAccount: string,
  transactionReference?: string
): Promise<boolean> {
  try {
    // TODO: Implement actual bank API integration
    // This is where you would:
    // 1. Call your bank's API to get recent transactions
    // 2. Look for transactions matching the order ID in the reference field
    // 3. Verify the amount matches
    // 4. Verify the account number matches

    // For now, we'll simulate a check
    // In production, you would implement something like:
    
    /*
    const bankTransactions = await getBankTransactions(bankAccount);
    
    for (const transaction of bankTransactions) {
      if (transaction.reference.includes(orderId) && 
          transaction.amount === expectedAmount &&
          transaction.accountNumber === bankAccount) {
        return true;
      }
    }
    */

    // For demonstration, we'll check if there's a manual verification record
    const manualVerification = await db
      .collection('manual_payment_verifications')
      .where('orderId', '==', orderId)
      .where('verified', '==', true)
      .limit(1)
      .get();

    return !manualVerification.empty;
  } catch (error) {
    console.error('Төлбөр баталгаажуулах явцад алдаа гарлаа:', error);
    return false;
  }
}

/**
 * Update store subscription after payment verification
 */
async function updateStoreSubscription(storeId: string, amount: number): Promise<void> {
  try {
    const storeRef = db.collection('stores').doc(storeId);
    const storeDoc = await storeRef.get();

    if (!storeDoc.exists) {
      throw new Error('Дэлгүүрийн мэдээлэл олдсонгүй');
    }

    const storeData = storeDoc.data();
    if (!storeData) {
      throw new Error('Дэлгүүрийн мэдээлэл олдсонгүй');
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

    // Create payment record in payments collection
    const paymentRecord = {
      id: `BANK_${Date.now()}`,
      storeId: storeId,
      userId: storeData.ownerId,
      amount: amount,
      currency: 'MNT',
      status: 'completed',
      paymentMethod: 'bank_transfer',
      transactionId: `BANK_${Date.now()}`,
      createdAt: now,
      processedAt: now,
      description: 'Сарын төлбөр - Банкны шилжүүлгэ',
      metadata: {
        type: 'subscription',
        bankTransfer: true,
      },
    };

    await db.collection('payments').add(paymentRecord);

    // Send notification to user
    await sendPaymentConfirmationNotification(storeData.ownerId, storeId, storeData.name);
  } catch (error) {
    console.error('Төлбөр баталгаажуулах алдаа гарлаа:', error);
    throw error;
  }
}

/**
 * Send payment confirmation notification
 */
async function sendPaymentConfirmationNotification(userId: string, storeId: string, storeName: string): Promise<void> {
  try {
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) return;

    const userData = userDoc.data();
    const fcmToken = userData?.fcmToken;

    if (!fcmToken) return;

    const message = {
      token: fcmToken,
      notification: {
        title: 'Төлбөр амжилттай',
        body: 'Таны дэлгүүрийн сарын төлбөр амжилттай төлөгдлөө.',
      },
      data: {
        type: 'payment_confirmed',
        storeId: storeId,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
    };

    await admin.messaging().send(message);
  } catch (error) {
    console.error('Төлбөр баталгаажуулах мэдэгдлийг илгээхэд алдаа гарлаа:', error);
  }
}

/**
 * Manual payment verification (for admin use)
 */
export const manualPaymentVerification = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication and admin role
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Хэрэглэгчийн баталгаажуулалт хийнэ үү');
    }

    const { orderId, storeId, amount, transactionReference } = data;

    if (!orderId || !storeId || !amount) {
      throw new functions.https.HttpsError('invalid-argument', 'Шаардлагатай мэдээлэл оруулна уу');
    }

    // Create manual verification record
    await db.collection('manual_payment_verifications').add({
      orderId: orderId,
      storeId: storeId,
      amount: amount,
      transactionReference: transactionReference,
      verifiedBy: context.auth.uid,
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      verified: true,
    });

    // Verify the payment by calling the verification logic directly
    const paymentDoc = await db
      .collection('store_subscriptions')
      .doc(storeId)
      .collection('payments')
      .doc(orderId)
      .get();

    if (!paymentDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Төлбөр мэдээлэл олдсонгүй');
    }

    const paymentData = paymentDoc.data();
    if (!paymentData) {
      throw new functions.https.HttpsError('not-found', 'Payment data is null');
    }

    // Check if payment is already verified
    if (paymentData.status === 'completed') {
      return { success: true, message: 'Төлбөр амжилттай төлөгдлөө', status: 'completed' };
    }

    // Verify payment by checking bank transactions
    const isPaymentVerified = await checkBankTransaction(orderId, amount, '436 022 735', transactionReference);

    if (isPaymentVerified) {
      // Update payment status
      await paymentDoc.ref.update({
        status: 'completed',
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        transactionReference: transactionReference,
      });

      // Update store subscription status
      await updateStoreSubscription(storeId, amount);

      return { success: true, message: 'Төлбөр амжилттай төлөгдлөө', status: 'completed' };
    } else {
      // Update last check time
      await paymentDoc.ref.update({
        lastChecked: admin.firestore.FieldValue.serverTimestamp(),
        status: 'pending',
      });

      return { success: false, message: 'Төлбөр олдсонгүй', status: 'pending' };
    }
  } catch (error) {
    console.error('Төлбөр шалгах явцад алдаа гарлаа:', error);
    throw new functions.https.HttpsError('internal', 'Төлбөр шалгах явцад алдаа гарлаа');
  }
});

// Automatic payment checks removed - will be integrated later when bank API is available 