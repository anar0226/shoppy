import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as crypto from 'crypto';

interface QPayWebhookData {
  payment_id: string;
  payment_status: 'NEW' | 'PAID' | 'FAILED' | 'REFUNDED' | 'CANCELLED' | 'EXPIRED';
  payment_amount: number;
  payment_date: string;
  sender_invoice_no: string;
  invoice_id: string;
  qpay_invoice_id: string;
  payment_currency: string;
  payment_description: string;
  object_type: string;
  object_id: string;
  payment_method?: string;
  payment_wallet?: string;
  refund_id?: string;
  refund_amount?: number;
  refund_reason?: string;
  signature?: string;
}

interface WebhookProcessingResult {
  success: boolean;
  orderId: string;
  paymentId: string;
  status: string;
  message: string;
  processingTime: number;
  errors?: string[];
}

interface WebhookSecurityConfig {
  enableSignatureVerification: boolean;
  webhookSecret: string;
  maxProcessingTime: number;
  enableRateLimiting: boolean;
  maxRequestsPerMinute: number;
  enableDuplicateDetection: boolean;
  duplicateWindowMinutes: number;
}

// Enhanced webhook configuration
const WEBHOOK_CONFIG: WebhookSecurityConfig = {
  enableSignatureVerification: true,
  webhookSecret: process.env.QPAY_WEBHOOK_SECRET || '',
  maxProcessingTime: 30000, // 30 seconds
  enableRateLimiting: true,
  maxRequestsPerMinute: 100,
  enableDuplicateDetection: true,
  duplicateWindowMinutes: 5,
};

// Rate limiting tracking
const rateLimitTracker = new Map<string, { count: number; resetTime: number }>();

// Duplicate detection tracking
const duplicateTracker = new Map<string, number>();

export const qpayWebhook = functions.https.onRequest(async (req, res) => {
  const startTime = Date.now();
  let processingResult: WebhookProcessingResult | null = null;

  try {
    // Only accept POST requests
    if (req.method !== 'POST') {
      res.status(405).send('Method not allowed');
      return;
    }

    console.log('QPay Webhook received:', {
      headers: req.headers,
      body: req.body,
      timestamp: new Date().toISOString(),
    });

    // Security checks
    const securityResult = await performSecurityChecks(req);
    if (!securityResult.valid) {
      console.error('Security check failed:', securityResult.reason);
      res.status(securityResult.statusCode || 400).send(securityResult.reason);
      return;
    }

    const webhookData: QPayWebhookData = req.body;

    // Enhanced validation
    const validationResult = validateWebhookData(webhookData);
    if (!validationResult.valid) {
      console.error('Webhook validation failed:', validationResult.errors);
      res.status(400).json({
        error: 'Invalid webhook data',
        details: validationResult.errors
      });
      return;
    }

    // Duplicate detection
    if (WEBHOOK_CONFIG.enableDuplicateDetection) {
      const duplicateResult = checkForDuplicate(webhookData);
      if (duplicateResult.isDuplicate) {
        console.warn('Duplicate webhook detected:', duplicateResult.message);
        res.status(200).json({
          success: true,
          message: 'Duplicate webhook ignored',
          orderId: webhookData.sender_invoice_no,
        });
        return;
      }
    }

    // Process webhook with timeout
    processingResult = await processWebhookWithTimeout(webhookData);

    // Store processing result
    await storeWebhookProcessingResult(webhookData, processingResult);

    // Trigger reconciliation if configured
    await triggerReconciliation(webhookData);

    // Send success response
    res.status(200).json({
      success: true,
      message: processingResult.message,
      orderId: processingResult.orderId,
      processingTime: Date.now() - startTime,
    });

  } catch (error) {
    console.error('Error processing QPay webhook:', error);
    
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    
    // Create error processing result
    processingResult = {
      success: false,
      orderId: req.body?.sender_invoice_no || '',
      paymentId: req.body?.payment_id || '',
      status: 'ERROR',
      message: `Webhook processing failed: ${errorMessage}`,
      processingTime: Date.now() - startTime,
      errors: [errorMessage],
    };

    // Store error result
    if (req.body?.sender_invoice_no) {
      await storeWebhookProcessingResult(req.body, processingResult);
    }

    // Send error response
    res.status(500).json({
      success: false,
      error: 'Internal server error',
      message: 'Webhook processing failed',
      processingTime: Date.now() - startTime,
    });
  }
});

async function performSecurityChecks(req: functions.https.Request): Promise<{
  valid: boolean;
  reason?: string;
  statusCode?: number;
}> {
  try {
    // Rate limiting
    if (WEBHOOK_CONFIG.enableRateLimiting) {
      const forwardedFor = req.headers['x-forwarded-for'];
      const clientIp = req.ip || (Array.isArray(forwardedFor) ? forwardedFor[0] : forwardedFor) || 'unknown';
      const rateLimitResult = checkRateLimit(clientIp);
      if (!rateLimitResult.allowed) {
        return {
          valid: false,
          reason: 'Rate limit exceeded',
          statusCode: 429,
        };
      }
    }

    // Signature verification
    if (WEBHOOK_CONFIG.enableSignatureVerification && WEBHOOK_CONFIG.webhookSecret) {
      const signature = req.headers['x-qpay-signature'] as string;
      const body = JSON.stringify(req.body);
      
      if (!signature) {
        return {
          valid: false,
          reason: 'Missing signature',
          statusCode: 401,
        };
      }

      const expectedSignature = generateSignature(body, WEBHOOK_CONFIG.webhookSecret);
      if (!verifySignature(signature, expectedSignature)) {
        return {
          valid: false,
          reason: 'Invalid signature',
          statusCode: 401,
        };
      }
    }

    // Content-Type validation
    const contentType = req.headers['content-type'];
    if (!contentType || !contentType.includes('application/json')) {
      return {
        valid: false,
        reason: 'Invalid content type',
        statusCode: 400,
      };
    }

    return { valid: true };

  } catch (error) {
    console.error('Security check error:', error);
    return {
      valid: false,
      reason: 'Security check failed',
      statusCode: 500,
    };
  }
}

function checkRateLimit(clientIp: string): { allowed: boolean; remaining: number } {
  const now = Date.now();
  // const windowStart = now - (60 * 1000); // 1 minute window
  
  const tracker = rateLimitTracker.get(clientIp);
  
  if (!tracker || tracker.resetTime <= now) {
    // Reset or create new tracker
    rateLimitTracker.set(clientIp, {
      count: 1,
      resetTime: now + (60 * 1000),
    });
    return { allowed: true, remaining: WEBHOOK_CONFIG.maxRequestsPerMinute - 1 };
  }

  if (tracker.count >= WEBHOOK_CONFIG.maxRequestsPerMinute) {
    return { allowed: false, remaining: 0 };
  }

  tracker.count++;
  return { allowed: true, remaining: WEBHOOK_CONFIG.maxRequestsPerMinute - tracker.count };
}

function generateSignature(payload: string, secret: string): string {
  return crypto.createHmac('sha256', secret).update(payload).digest('hex');
}

function verifySignature(signature: string, expectedSignature: string): boolean {
  try {
    return crypto.timingSafeEqual(
      Buffer.from(signature, 'hex'),
      Buffer.from(expectedSignature, 'hex')
    );
  } catch (error) {
    console.error('Signature verification error:', error);
    return false;
  }
}

function validateWebhookData(data: QPayWebhookData): {
  valid: boolean;
  errors?: string[];
} {
  const errors: string[] = [];

  // Required fields
  if (!data.payment_id) errors.push('Missing payment_id');
  if (!data.sender_invoice_no) errors.push('Missing sender_invoice_no');
  if (!data.payment_status) errors.push('Missing payment_status');
  if (!data.payment_amount && data.payment_amount !== 0) errors.push('Missing payment_amount');

  // Validate payment status
  const validStatuses = ['NEW', 'PAID', 'FAILED', 'REFUNDED', 'CANCELLED', 'EXPIRED'];
  if (data.payment_status && !validStatuses.includes(data.payment_status)) {
    errors.push('Invalid payment_status');
  }

  // Validate payment amount
  if (data.payment_amount && (typeof data.payment_amount !== 'number' || data.payment_amount < 0)) {
    errors.push('Invalid payment_amount');
  }

  // Validate currency
  if (data.payment_currency && data.payment_currency !== 'MNT') {
    errors.push('Unsupported payment_currency');
  }

  return {
    valid: errors.length === 0,
    errors: errors.length > 0 ? errors : undefined,
  };
}

function checkForDuplicate(data: QPayWebhookData): {
  isDuplicate: boolean;
  message?: string;
} {
  const key = `${data.payment_id}_${data.payment_status}_${data.payment_amount}`;
  const now = Date.now();
  const windowMs = WEBHOOK_CONFIG.duplicateWindowMinutes * 60 * 1000;

  const lastProcessed = duplicateTracker.get(key);
  
  if (lastProcessed && (now - lastProcessed) < windowMs) {
    return {
      isDuplicate: true,
      message: `Duplicate webhook for payment ${data.payment_id} within ${WEBHOOK_CONFIG.duplicateWindowMinutes} minutes`,
    };
  }

  duplicateTracker.set(key, now);
  
  // Clean up old entries
  for (const [trackingKey, timestamp] of duplicateTracker.entries()) {
    if ((now - timestamp) > windowMs) {
      duplicateTracker.delete(trackingKey);
    }
  }

  return { isDuplicate: false };
}

async function processWebhookWithTimeout(webhookData: QPayWebhookData): Promise<WebhookProcessingResult> {
  return new Promise(async (resolve, reject) => {
    const timeout = setTimeout(() => {
      reject(new Error('Webhook processing timeout'));
    }, WEBHOOK_CONFIG.maxProcessingTime);

    try {
      const result = await processWebhook(webhookData);
      clearTimeout(timeout);
      resolve(result);
    } catch (error) {
      clearTimeout(timeout);
      reject(error);
    }
  });
}

async function processWebhook(webhookData: QPayWebhookData): Promise<WebhookProcessingResult> {
  const startTime = Date.now();
  const orderId = webhookData.sender_invoice_no;
  const paymentStatus = webhookData.payment_status;
  const paymentId = webhookData.payment_id;
  const paymentAmount = webhookData.payment_amount;

  console.log(`Processing payment for order ${orderId}: ${paymentStatus}`);

  try {
    // Check if this is a temporary order (new flow) or existing order (old flow)
    const tempOrderRef = admin.firestore().collection('temporary_orders').doc(orderId);
    const tempOrderDoc = await tempOrderRef.get();
    
    let processingMessage = '';
    
    if (tempOrderDoc.exists) {
      // New flow: Handle temporary order
      processingMessage = await handleTemporaryOrder(tempOrderDoc, webhookData);
    } else {
      // Old flow: Handle existing order
      processingMessage = await handleExistingOrder(orderId, webhookData);
    }

    // Log the webhook for audit trail with enhanced details
    await admin.firestore().collection('qpay_webhooks').add({
      orderId,
      paymentId,
      paymentStatus,
      paymentAmount,
      webhookData,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      processingTimeMs: Date.now() - startTime,
      success: true,
      message: processingMessage,
      userAgent: webhookData.payment_method || 'unknown',
      ipAddress: 'qpay-server',
    });

    // Create payment monitoring event
    await createPaymentMonitoringEvent(webhookData, 'WEBHOOK_PROCESSED');

    return {
      success: true,
      orderId,
      paymentId,
      status: paymentStatus,
      message: processingMessage,
      processingTime: Date.now() - startTime,
    };

  } catch (error) {
    console.error(`Error processing webhook for order ${orderId}:`, error);
    
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    const errorStack = error instanceof Error ? error.stack : undefined;
    
    // Log error webhook
    await admin.firestore().collection('qpay_webhooks').add({
      orderId,
      paymentId,
      paymentStatus,
      paymentAmount,
      webhookData,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      processingTimeMs: Date.now() - startTime,
      success: false,
      error: errorMessage,
      stack: errorStack,
    });

    throw error;
  }
}

async function handleTemporaryOrder(tempOrderDoc: admin.firestore.DocumentSnapshot, webhookData: QPayWebhookData): Promise<string> {
  const tempOrderData = tempOrderDoc.data();
  if (!tempOrderData) {
    throw new Error('Temporary order data is empty');
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
      return `Order ${orderId} created successfully from temporary order`;
      
    } catch (error) {
      console.error(`Error creating order ${orderId}:`, error);
      
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      
      // Mark temporary order as failed but don't delete
      await tempOrderDoc.ref.update({
        status: 'order_creation_failed',
        error: errorMessage,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      throw error;
    }
  } else if (paymentStatus === 'FAILED' || paymentStatus === 'CANCELLED' || paymentStatus === 'EXPIRED') {
    console.log(`Payment ${paymentStatus.toLowerCase()} for order ${orderId}, updating temporary order`);
    
    // Update temporary order status
    await tempOrderDoc.ref.update({
      status: `payment_${paymentStatus.toLowerCase()}`,
      paymentFailedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      webhookData: webhookData,
    });
    
    // Send failure notification
    await sendPaymentFailureNotification(tempOrderData.userId, orderId, paymentStatus);
    
    return `Temporary order ${orderId} updated with payment status: ${paymentStatus}`;
  } else if (paymentStatus === 'REFUNDED') {
    console.log(`Processing refund for order ${orderId}`);
    
    // Handle refund
    await handleRefundWebhook(orderId, webhookData);
    
    return `Refund processed for order ${orderId}`;
  }

  return `Temporary order ${orderId} processed with status: ${paymentStatus}`;
}

async function handleExistingOrder(orderId: string, webhookData: QPayWebhookData): Promise<string> {
  const orderRef = admin.firestore().collection('orders').doc(orderId);
  const orderDoc = await orderRef.get();

  if (!orderDoc.exists) {
    console.error(`Order ${orderId} not found`);
    throw new Error(`Order ${orderId} not found`);
  }

  const paymentStatus = webhookData.payment_status;
  const paymentId = webhookData.payment_id;
  const paymentAmount = webhookData.payment_amount;

  const updateData: any = {
    'payment.qpayPaymentId': paymentId,
    'payment.status': paymentStatus.toLowerCase(),
    'payment.updatedAt': admin.firestore.FieldValue.serverTimestamp(),
    'payment.webhookData': webhookData,
  };

  if (paymentStatus === 'PAID') {
    updateData['payment.paidAt'] = admin.firestore.FieldValue.serverTimestamp();
    updateData['payment.paidAmount'] = paymentAmount;
    updateData.status = 'paid';
    updateData.updatedAt = admin.firestore.FieldValue.serverTimestamp();

    console.log(`Order ${orderId} marked as PAID`);
    
    // Send success notification
    try {
      const orderData = orderDoc.data();
      if (orderData?.userId) {
        await sendPaymentSuccessNotification(orderData.userId, orderId, paymentAmount);
      }
    } catch (notificationError) {
      console.error('Error sending payment success notification:', notificationError);
    }
    
  } else if (paymentStatus === 'FAILED' || paymentStatus === 'CANCELLED' || paymentStatus === 'EXPIRED') {
    updateData.status = `payment_${paymentStatus.toLowerCase()}`;
    updateData.updatedAt = admin.firestore.FieldValue.serverTimestamp();
    updateData['payment.failedAt'] = admin.firestore.FieldValue.serverTimestamp();

    console.log(`Order ${orderId} marked as ${paymentStatus}`);
    
    // Send failure notification
    try {
      const orderData = orderDoc.data();
      if (orderData?.userId) {
        await sendPaymentFailureNotification(orderData.userId, orderId, paymentStatus);
      }
    } catch (notificationError) {
      console.error('Error sending payment failure notification:', notificationError);
    }
    
  } else if (paymentStatus === 'REFUNDED') {
    // Handle refund
    await handleRefundWebhook(orderId, webhookData);
    return `Refund processed for order ${orderId}`;
  }

  // Update the order
  await orderRef.update(updateData);
  
  return `Order ${orderId} updated with payment status: ${paymentStatus}`;
}

async function handleRefundWebhook(orderId: string, webhookData: QPayWebhookData): Promise<void> {
  const refundAmount = webhookData.refund_amount || webhookData.payment_amount;
  const refundReason = webhookData.refund_reason || 'Refund processed via QPay';

  // Create refund record
  await admin.firestore().collection('refunds').add({
    orderId,
    paymentId: webhookData.payment_id,
    refundId: webhookData.refund_id || webhookData.payment_id,
    amount: refundAmount,
    reason: refundReason,
    status: 'completed',
    processedAt: admin.firestore.FieldValue.serverTimestamp(),
    webhookData: webhookData,
  });

  // Update order status
  await admin.firestore().collection('orders').doc(orderId).update({
    status: 'refunded',
    refundAmount: refundAmount,
    refundedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(`Refund processed for order ${orderId}, amount: ${refundAmount}`);
}

async function createOrderFromTemporaryData(tempOrderData: any, webhookData: QPayWebhookData): Promise<void> {
  const orderId = webhookData.sender_invoice_no;
  const paymentId = webhookData.payment_id;
  const paymentAmount = webhookData.payment_amount;

  // Group items by store ID
  const itemsByStore: { [key: string]: any[] } = {};
  const items = tempOrderData.items || [];
  
  for (const item of items) {
    const storeId = item.storeId || 'avii-store';
    if (!itemsByStore[storeId]) {
      itemsByStore[storeId] = [];
    }
    itemsByStore[storeId].push(item);
  }

  const storeIds = Object.keys(itemsByStore);
  const orderPromises: Promise<admin.firestore.WriteResult>[] = [];

  for (let i = 0; i < storeIds.length; i++) {
    const storeId = storeIds[i];
    const storeItems = itemsByStore[storeId];
    
    // Create unique order ID for each store
    const storeOrderId = storeIds.length > 1 ? `${orderId}_${i + 1}` : orderId;
    
    // Calculate store-specific totals
    const storeSubtotal = storeItems.reduce((sum, item) => sum + item.price, 0);
    const storeShipping = (tempOrderData.orderData?.shipping || 0) / storeIds.length;
    const storeTax = ((tempOrderData.orderData?.tax || 0) / (tempOrderData.orderData?.subtotal || 1)) * storeSubtotal;
    const storeTotal = storeSubtotal + storeShipping + storeTax;

    const orderData = {
      id: storeOrderId,
      userId: tempOrderData.userId,
      storeId: storeId,
      items: storeItems,
      subtotal: storeSubtotal,
      shipping: storeShipping,
      tax: storeTax,
      total: storeTotal,
      discountAmount: tempOrderData.orderData?.discountAmount || 0,
      discountCode: tempOrderData.orderData?.discountCode || null,
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
        webhookData: webhookData,
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      
      // Analytics fields
      month: new Date().getMonth() + 1,
      week: Math.ceil(new Date().getDate() / 7),
      day: new Date().getDate(),
      
      // Enhanced tracking fields
      orderSource: 'qpay_webhook',
      processingTime: Date.now() - (tempOrderData.createdAt?.toMillis() || Date.now()),
    };

    orderPromises.push(
      admin.firestore().collection('orders').doc(storeOrderId).set(orderData)
    );

    // Send notification to store owner
    try {
      await sendStoreOwnerNotification(storeId, storeOrderId, tempOrderData.customerEmail, storeTotal);
    } catch (notificationError) {
      console.error('Error sending store owner notification:', notificationError);
    }
  }

  // Create all orders
  await Promise.all(orderPromises);

  // Send notification to customer
  try {
    await sendPaymentSuccessNotification(tempOrderData.userId, orderId, paymentAmount);
  } catch (notificationError) {
    console.error('Error sending payment success notification:', notificationError);
  }
}

async function sendPaymentSuccessNotification(userId: string, orderId: string, amount: number): Promise<void> {
  try {
    // Get user's FCM token
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    const userData = userDoc.data();
    
    if (!userData || !userData.fcmToken) {
      console.warn(`No FCM token found for user ${userId}`);
      return;
    }

    const message = {
      token: userData.fcmToken,
      notification: {
        title: 'Payment Successful',
        body: `Your payment of ₮${amount.toFixed(0)} for order ${orderId} has been processed successfully.`,
      },
      data: {
        type: 'payment_success',
        orderId: orderId,
        amount: amount.toString(),
        timestamp: new Date().toISOString(),
      },
    };

    await admin.messaging().send(message);
    console.log(`Payment success notification sent to user ${userId}`);
  } catch (error) {
    console.error('Error sending payment success notification:', error);
  }
}

async function sendPaymentFailureNotification(userId: string, orderId: string, status: string): Promise<void> {
  try {
    // Get user's FCM token
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    const userData = userDoc.data();
    
    if (!userData || !userData.fcmToken) {
      console.warn(`No FCM token found for user ${userId}`);
      return;
    }

    const message = {
      token: userData.fcmToken,
      notification: {
        title: 'Payment Failed',
        body: `Your payment for order ${orderId} has ${status.toLowerCase()}. Please try again.`,
      },
      data: {
        type: 'payment_failure',
        orderId: orderId,
        status: status,
        timestamp: new Date().toISOString(),
      },
    };

    await admin.messaging().send(message);
    console.log(`Payment failure notification sent to user ${userId}`);
  } catch (error) {
    console.error('Error sending payment failure notification:', error);
  }
}

async function sendStoreOwnerNotification(storeId: string, orderId: string, customerEmail: string, total: number): Promise<void> {
  try {
    // Get store owner information
    const storeDoc = await admin.firestore().collection('stores').doc(storeId).get();
    const storeData = storeDoc.data();
    
    if (!storeData || !storeData.ownerId) {
      console.warn(`No owner found for store ${storeId}`);
      return;
    }

    // Get owner's FCM token
    const ownerDoc = await admin.firestore().collection('users').doc(storeData.ownerId).get();
    const ownerData = ownerDoc.data();
    
    if (!ownerData || !ownerData.fcmToken) {
      console.warn(`No FCM token found for store owner ${storeData.ownerId}`);
      return;
    }

    const message = {
      token: ownerData.fcmToken,
      notification: {
        title: 'Шинэ захиалга ирлээ!',
        body: `Шинэ захиалга #${orderId.substring(0, 6)} ${customerEmail}-с ₮${total.toFixed(0)}`,
      },
      data: {
        type: 'new_order',
        orderId: orderId,
        storeId: storeId,
        customerEmail: customerEmail,
        total: total.toString(),
        timestamp: new Date().toISOString(),
      },
    };

    await admin.messaging().send(message);
    console.log(`New order notification sent to store owner ${storeData.ownerId}`);
  } catch (error) {
    console.error('Error sending store owner notification:', error);
  }
}

async function storeWebhookProcessingResult(webhookData: QPayWebhookData, result: WebhookProcessingResult): Promise<void> {
  try {
    await admin.firestore().collection('webhook_processing_results').add({
      orderId: result.orderId,
      paymentId: result.paymentId,
      status: result.status,
      success: result.success,
      message: result.message,
      processingTime: result.processingTime,
      errors: result.errors,
      webhookData: webhookData,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.error('Error storing webhook processing result:', error);
  }
}

async function createPaymentMonitoringEvent(webhookData: QPayWebhookData, eventType: string): Promise<void> {
  try {
    await admin.firestore().collection('payment_events').add({
      paymentId: webhookData.payment_id,
      orderId: webhookData.sender_invoice_no,
      type: eventType,
      status: webhookData.payment_status,
      amount: webhookData.payment_amount,
      currency: webhookData.payment_currency,
      method: webhookData.payment_method || 'qpay',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      data: {
        webhookData: webhookData,
        eventSource: 'qpay_webhook',
      },
    });
  } catch (error) {
    console.error('Error creating payment monitoring event:', error);
  }
}

async function triggerReconciliation(webhookData: QPayWebhookData): Promise<void> {
  try {
    // Store reconciliation trigger
    await admin.firestore().collection('reconciliation_triggers').add({
      paymentId: webhookData.payment_id,
      orderId: webhookData.sender_invoice_no,
      status: webhookData.payment_status,
      amount: webhookData.payment_amount,
      triggeredAt: admin.firestore.FieldValue.serverTimestamp(),
      triggerSource: 'qpay_webhook',
      processed: false,
    });

    console.log(`Reconciliation trigger created for payment ${webhookData.payment_id}`);
  } catch (error) {
    console.error('Error triggering reconciliation:', error);
  }
}

// Enhanced error handling and logging
process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
});

process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
}); 