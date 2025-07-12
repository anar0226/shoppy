import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

interface QPayWebhookData {
  payment_id: string;
  payment_status: 'NEW' | 'PAID' | 'FAILED' | 'REFUNDED';
  payment_amount: number;
  payment_date: string;
  sender_invoice_no: string;
  invoice_id: string;
  qpay_invoice_id: string;
  payment_currency: string;
  payment_description: string;
  object_type: string;
  object_id: string;
}

export const qpayWebhook = functions.https.onRequest(async (req, res) => {
  try {
    // Only accept POST requests
    if (req.method !== 'POST') {
      res.status(405).send('Method not allowed');
      return;
    }

    console.log('QPay Webhook received:', req.body);

    const webhookData: QPayWebhookData = req.body;

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

    // Check if this is a temporary order (new flow) or existing order (old flow)
    const tempOrderRef = admin.firestore().collection('temporary_orders').doc(orderId);
    const tempOrderDoc = await tempOrderRef.get();
    
    if (tempOrderDoc.exists) {
      // New flow: Handle temporary order
      await handleTemporaryOrder(tempOrderDoc, webhookData);
    } else {
      // Old flow: Handle existing order
      await handleExistingOrder(orderId, webhookData);
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
  } catch (error) {
    console.error('Error processing QPay webhook:', error);
    res.status(500).send('Internal server error');
  }
});

async function handleTemporaryOrder(tempOrderDoc: admin.firestore.DocumentSnapshot, webhookData: QPayWebhookData) {
  const tempOrderData = tempOrderDoc.data();
  if (!tempOrderData) {
    console.error('Temporary order data is empty');
    return;
  }

  const orderId = webhookData.sender_invoice_no;
  const paymentStatus = webhookData.payment_status;

  if (paymentStatus === 'PAID') {
    console.log(`Creating order ${orderId} after successful payment`);
    
    try {
      // Create the actual order
      await createOrderFromTemporaryData(tempOrderData, webhookData);
      
      // Delete the temporary order
      await tempOrderDoc.ref.delete();
      
      console.log(`Order ${orderId} created successfully and temporary order deleted`);
    } catch (error) {
      console.error(`Error creating order ${orderId}:`, error);
      throw error;
    }
  } else if (paymentStatus === 'FAILED') {
    console.log(`Payment failed for order ${orderId}, keeping temporary order for retry`);
    
    // Update temporary order status
    await tempOrderDoc.ref.update({
      status: 'payment_failed',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      paymentFailedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}

async function handleExistingOrder(orderId: string, webhookData: QPayWebhookData) {
  const orderRef = admin.firestore().collection('orders').doc(orderId);
  const orderDoc = await orderRef.get();

  if (!orderDoc.exists) {
    console.error(`Order ${orderId} not found`);
    return;
  }

  const paymentStatus = webhookData.payment_status;
  const paymentId = webhookData.payment_id;
  const paymentAmount = webhookData.payment_amount;

  const updateData: any = {
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
  } else if (paymentStatus === 'FAILED') {
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
      if (orderData?.userId) {
        await sendPaymentSuccessNotification(orderData.userId, orderId, paymentAmount);
      }
    } catch (notificationError) {
      console.error('Error sending notification:', notificationError);
      // Don't fail the webhook for notification errors
    }
  }
}

async function createOrderFromTemporaryData(tempOrderData: any, webhookData: QPayWebhookData) {
  const orderId = webhookData.sender_invoice_no;
  const paymentAmount = webhookData.payment_amount;
  const paymentId = webhookData.payment_id;
  
  // Group items by store
  const itemsByStore: { [storeId: string]: any[] } = {};
  
  for (const item of tempOrderData.items) {
    const storeId = item.storeId || 'unknown';
    if (!itemsByStore[storeId]) {
      itemsByStore[storeId] = [];
    }
    itemsByStore[storeId].push(item);
  }

  // Create orders for each store
  const orderPromises = [];
  const storeIds = Object.keys(itemsByStore);
  
  for (let i = 0; i < storeIds.length; i++) {
    const storeId = storeIds[i];
    const storeItems = itemsByStore[storeId];
    
    // Calculate totals for this store
    const storeSubtotal = storeItems.reduce((sum, item) => sum + item.price, 0);
    const storeShipping = tempOrderData.orderData.shipping || 0;
    const storeTax = tempOrderData.orderData.tax || 0;
    const storeTotal = storeSubtotal + storeShipping + storeTax;
    
    // Create unique order ID for multi-store orders
    const storeOrderId = storeIds.length > 1 ? `${orderId}_${i + 1}` : orderId;
    
    const orderData = {
      id: storeOrderId,
      userId: tempOrderData.userId,
      storeId: storeId,
      items: storeItems,
      subtotal: storeSubtotal,
      shipping: storeShipping,
      tax: storeTax,
      total: storeTotal,
      discountAmount: tempOrderData.orderData.discountAmount || 0,
      discountCode: tempOrderData.orderData.discountCode || null,
      status: 'paid',
      deliveryAddress: tempOrderData.deliveryAddress,
      customerEmail: tempOrderData.customerEmail,
      payment: {
        method: 'qpay',
        status: 'paid',
        qpayPaymentId: paymentId,
        paidAmount: paymentAmount,
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    orderPromises.push(
      admin.firestore().collection('orders').doc(storeOrderId).set(orderData)
    );
  }

  // Create all orders
  await Promise.all(orderPromises);

  // Send notification to user
  try {
    await sendPaymentSuccessNotification(tempOrderData.userId, orderId, paymentAmount);
  } catch (notificationError) {
    console.error('Error sending notification:', notificationError);
    // Don't fail the order creation for notification errors
  }

  // Send notifications to store owners
  for (let i = 0; i < storeIds.length; i++) {
    const storeId = storeIds[i];
    const storeItems = itemsByStore[storeId];
    const storeOrderId = storeIds.length > 1 ? `${orderId}_${i + 1}` : orderId;
    const storeSubtotal = storeItems.reduce((sum, item) => sum + item.price, 0);
    
    try {
      await sendStoreOwnerNotification(storeId, storeOrderId, tempOrderData.customerEmail, storeSubtotal);
    } catch (notificationError) {
      console.error('Error sending store owner notification:', notificationError);
      // Don't fail the order creation for notification errors
    }
  }
}

async function sendPaymentSuccessNotification(userId: string, orderId: string, amount: number) {
  try {
    // Get user's FCM token
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    const userData = userDoc.data();

    if (!userData?.fcmToken) {
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
  } catch (error) {
    console.error('Error sending payment notification:', error);
    throw error;
  }
}

async function sendStoreOwnerNotification(storeId: string, orderId: string, customerEmail: string, total: number) {
  try {
    // Get store owner information
    const storeDoc = await admin.firestore().collection('stores').doc(storeId).get();
    const storeData = storeDoc.data();
    
    if (!storeData?.ownerId) {
      console.log(`No owner found for store ${storeId}`);
      return;
    }

    // Get store owner's FCM token
    const ownerDoc = await admin.firestore().collection('users').doc(storeData.ownerId).get();
    const ownerData = ownerDoc.data();

    if (!ownerData?.fcmToken) {
      console.log(`No FCM token for store owner ${storeData.ownerId}`);
      return;
    }

    const message = {
      token: ownerData.fcmToken,
      notification: {
        title: 'Шинэ захиалга',
        body: `Таны дэлгүүрт шинэ захиалга ирлээ. #${orderId.substring(0, 8)} - ₮${total.toLocaleString()}`,
      },
      data: {
        type: 'new_order',
        orderId: orderId,
        storeId: storeId,
        total: total.toString(),
      },
      android: {
        notification: {
          icon: 'ic_notification',
          color: '#4CAF50',
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
    console.log(`New order notification sent to store owner ${storeData.ownerId}`);
  } catch (error) {
    console.error('Error sending store owner notification:', error);
    throw error;
  }
} 