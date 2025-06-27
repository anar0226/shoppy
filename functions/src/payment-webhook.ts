import { https, Request, Response } from 'firebase-functions';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import * as crypto from 'crypto';

// Initialize Firebase Admin
if (!initializeApp.length) {
  initializeApp();
}

const db = getFirestore();

interface QPayWebhookData {
  invoice_id: string;
  payment_status: string;
  payment_amount: number;
  payment_currency: string;
  payment_date: string;
  signature: string;
}

interface UBCabWebhookData {
  tracking_id: string;
  order_reference: string;
  status: string;
  driver_id?: string;
  driver_name?: string;
  driver_phone?: string;
  estimated_arrival?: string;
}

/**
 * QPay Payment Webhook Handler
 */
export const qpayWebhook = https.onRequest(async (req: Request, res: Response) => {
  // Verify the request method
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  try {
    const webhookData: QPayWebhookData = req.body;
    
    // Verify webhook signature
    if (!verifyQPaySignature(webhookData, req.headers['x-qpay-signature'] as string)) {
      console.error('Invalid QPay webhook signature');
      res.status(401).send('Unauthorized');
      return;
    }

    // Process payment webhook
    const success = await processQPayWebhook(webhookData);
    
    if (success) {
      res.status(200).send('OK');
    } else {
      res.status(500).send('Processing failed');
    }
  } catch (error) {
    console.error('QPay webhook error:', error);
    res.status(500).send('Internal Server Error');
  }
});

/**
 * UBCab Delivery Webhook Handler
 */
export const ubcabWebhook = https.onRequest(async (req: Request, res: Response) => {
  // Verify the request method
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  try {
    const webhookData: UBCabWebhookData = req.body;
    
    // Verify webhook signature (implement based on UBCab's specs)
    if (!verifyUBCabSignature(webhookData, req.headers['x-ubcab-signature'] as string)) {
      console.error('Invalid UBCab webhook signature');
      res.status(401).send('Unauthorized');
      return;
    }

    // Process delivery webhook
    const success = await processUBCabWebhook(webhookData);
    
    if (success) {
      res.status(200).send('OK');
    } else {
      res.status(500).send('Processing failed');
    }
  } catch (error) {
    console.error('UBCab webhook error:', error);
    res.status(500).send('Internal Server Error');
  }
});

/**
 * Verify QPay webhook signature
 */
function verifyQPaySignature(data: QPayWebhookData, signature: string): boolean {
  try {
    const secret = process.env.QPAY_WEBHOOK_SECRET || '';
    const payload = `${data.payment_amount}${data.invoice_id}`;
    const expectedSignature = crypto.createHmac('sha256', secret).update(payload).digest('hex').toUpperCase();
    return signature === expectedSignature;
  } catch (error) {
    console.error('QPay signature verification error:', error);
    return false;
  }
}

/**
 * Verify UBCab webhook signature
 */
function verifyUBCabSignature(data: UBCabWebhookData, signature: string): boolean {
  try {
    // Implement based on UBCab's signature verification method
    const secret = process.env.UBCAB_WEBHOOK_SECRET || '';
    const payload = JSON.stringify(data);
    const expectedSignature = crypto.createHmac('sha256', secret).update(payload).digest('hex');
    return signature === expectedSignature;
  } catch (error) {
    console.error('UBCab signature verification error:', error);
    return false;
  }
}

/**
 * Process QPay payment webhook
 */
async function processQPayWebhook(data: QPayWebhookData): Promise<boolean> {
  try {
    const { invoice_id, payment_status, payment_amount, payment_currency, payment_date } = data;

    // Find the order by invoice ID
    const ordersQuery = await db.collection('orders')
      .where('paymentInvoiceId', '==', invoice_id)
      .limit(1)
      .get();

    if (ordersQuery.empty) {
      console.error(`Order not found for invoice ID: ${invoice_id}`);
      return false;
    }

    const orderDoc = ordersQuery.docs[0];
    const orderData = orderDoc.data();

    // Update order based on payment status
    if (payment_status === 'PAID') {
      // Payment successful - update order and trigger delivery
      await orderDoc.ref.update({
        paymentStatus: 'paid',
        fulfillmentStatus: 'payment_confirmed',
        paidAt: new Date(payment_date),
        paymentAmount: payment_amount,
        paymentCurrency: payment_currency,
        updatedAt: new Date(),
      });

      // Trigger delivery request
      await triggerDeliveryRequest(orderDoc.id, orderData);
      
      // Send notification to customer
      await sendPaymentNotification(orderData.userId, 'payment_successful', {
        orderId: orderDoc.id,
        amount: payment_amount,
      });

    } else if (payment_status === 'FAILED' || payment_status === 'CANCELLED') {
      // Payment failed or cancelled
      await orderDoc.ref.update({
        paymentStatus: 'failed',
        fulfillmentStatus: 'failed',
        failedAt: new Date(),
        updatedAt: new Date(),
      });

      // Send notification to customer
      await sendPaymentNotification(orderData.userId, 'payment_failed', {
        orderId: orderDoc.id,
      });
    }

    return true;
  } catch (error) {
    console.error('Process QPay webhook error:', error);
    return false;
  }
}

/**
 * Process UBCab delivery webhook
 */
async function processUBCabWebhook(data: UBCabWebhookData): Promise<boolean> {
  try {
    const { tracking_id, order_reference, status, driver_id, driver_name, driver_phone } = data;

    // Update order status
    const orderRef = db.collection('orders').doc(order_reference);
    const orderDoc = await orderRef.get();

    if (!orderDoc.exists) {
      console.error(`Order not found: ${order_reference}`);
      return false;
    }

    const updateData: any = {
      deliveryStatus: status.toLowerCase(),
      updatedAt: new Date(),
    };

    // Add driver information if provided
    if (driver_id) updateData.driverId = driver_id;
    if (driver_name) updateData.driverName = driver_name;
    if (driver_phone) updateData.driverPhone = driver_phone;

    // Update timestamps based on status
    switch (status.toLowerCase()) {
      case 'driver_assigned':
        updateData.fulfillmentStatus = 'driver_assigned';
        updateData.assignedAt = new Date();
        break;
      case 'pickup_confirmed':
        updateData.fulfillmentStatus = 'picked_up';
        updateData.pickedUpAt = new Date();
        break;
      case 'in_transit':
        updateData.fulfillmentStatus = 'in_transit';
        break;
      case 'delivered':
        updateData.fulfillmentStatus = 'delivered';
        updateData.deliveredAt = new Date();
        break;
      case 'cancelled':
        updateData.fulfillmentStatus = 'cancelled';
        updateData.cancelledAt = new Date();
        break;
    }

    await orderRef.update(updateData);

    // Update delivery order collection
    await db.collection('delivery_orders').doc(order_reference).update({
      status: status.toLowerCase(),
      driverId: driver_id,
      driverName: driver_name,
      driverPhone: driver_phone,
      updatedAt: new Date(),
    });

    // Send notification to customer
    const orderData = orderDoc.data();
    await sendDeliveryNotification(orderData?.userId, status, {
      orderId: order_reference,
      driverName: driver_name,
      trackingId: tracking_id,
    });

    return true;
  } catch (error) {
    console.error('Process UBCab webhook error:', error);
    return false;
  }
}

/**
 * Trigger delivery request after successful payment
 */
async function triggerDeliveryRequest(orderId: string, orderData: any): Promise<void> {
  try {
    // This would make an API call to UBCab to request delivery
    // For now, we'll just update the status
    await db.collection('orders').doc(orderId).update({
      fulfillmentStatus: 'delivery_requested',
      deliveryRequestedAt: new Date(),
    });

    console.log(`Delivery requested for order: ${orderId}`);
  } catch (error) {
    console.error('Trigger delivery request error:', error);
  }
}

/**
 * Send payment notification to customer
 */
async function sendPaymentNotification(userId: string, type: string, data: any): Promise<void> {
  try {
    const notificationData = {
      userId,
      type,
      title: getNotificationTitle(type),
      message: getNotificationMessage(type, data),
      data,
      createdAt: new Date(),
      read: false,
    };

    await db.collection('notifications').add(notificationData);
    console.log(`Payment notification sent to user: ${userId}`);
  } catch (error) {
    console.error('Send payment notification error:', error);
  }
}

/**
 * Send delivery notification to customer
 */
async function sendDeliveryNotification(userId: string, status: string, data: any): Promise<void> {
  try {
    const notificationData = {
      userId,
      type: 'delivery_update',
      title: getDeliveryNotificationTitle(status),
      message: getDeliveryNotificationMessage(status, data),
      data,
      createdAt: new Date(),
      read: false,
    };

    await db.collection('notifications').add(notificationData);
    console.log(`Delivery notification sent to user: ${userId}`);
  } catch (error) {
    console.error('Send delivery notification error:', error);
  }
}

/**
 * Get notification title based on type
 */
function getNotificationTitle(type: string): string {
  switch (type) {
    case 'payment_successful':
      return 'Payment Successful';
    case 'payment_failed':
      return 'Payment Failed';
    default:
      return 'Order Update';
  }
}

/**
 * Get notification message based on type
 */
function getNotificationMessage(type: string, data: any): string {
  switch (type) {
    case 'payment_successful':
      return `Your payment of ₮${data.amount} has been processed successfully. Your order is being prepared for delivery.`;
    case 'payment_failed':
      return 'Your payment could not be processed. Please try again or contact support.';
    default:
      return 'Your order has been updated.';
  }
}

/**
 * Get delivery notification title based on status
 */
function getDeliveryNotificationTitle(status: string): string {
  switch (status.toLowerCase()) {
    case 'driver_assigned':
      return 'Driver Assigned';
    case 'pickup_confirmed':
      return 'Order Picked Up';
    case 'in_transit':
      return 'Order In Transit';
    case 'delivered':
      return 'Order Delivered';
    case 'cancelled':
      return 'Delivery Cancelled';
    default:
      return 'Delivery Update';
  }
}

/**
 * Get delivery notification message based on status
 */
function getDeliveryNotificationMessage(status: string, data: any): string {
  switch (status.toLowerCase()) {
    case 'driver_assigned':
      return `A driver has been assigned to deliver your order. Driver: ${data.driverName || 'N/A'}`;
    case 'pickup_confirmed':
      return 'Your order has been picked up and is on the way to you!';
    case 'in_transit':
      return 'Your order is currently in transit and will arrive soon.';
    case 'delivered':
      return 'Your order has been successfully delivered. Thank you for shopping with us!';
    case 'cancelled':
      return 'Your delivery has been cancelled. Please contact support for assistance.';
    default:
      return 'Your delivery status has been updated.';
  }
} 