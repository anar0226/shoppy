import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import Stripe from 'stripe';

// Initialize Firebase Admin
admin.initializeApp();

// Initialize Stripe with your secret key
const stripe = new Stripe('sk_test_51R8IZ6PLGzeo2gGVUOQ9k7DdR8PNwJb4eJjhEDAjkFSxmyEf6BpPNgTCcq0VQ5BGlZKHFKuGI7Rw3CfLMfPeaUrF00GNfRaVXY', {
  apiVersion: '2023-08-16',
});

// Create Payment Intent
export const createPaymentIntent = functions.https.onCall(async (data, context) => {
  try {
    // Verify user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { amount, currency, orderId, email } = data;

    // Validate input
    if (!amount || !currency || !orderId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }

    // Create payment intent
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amount, // Amount in cents
      currency: currency.toLowerCase(),
      metadata: {
        orderId: orderId,
        userId: context.auth.uid,
        email: email || '',
      },
    });

    return {
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id,
    };
  } catch (error) {
    console.error('Error creating payment intent:', error);
    throw new functions.https.HttpsError('internal', 'Unable to create payment intent');
  }
});

// Handle successful payment webhook (optional but recommended)
export const handleStripeWebhook = functions.https.onRequest(async (req, res) => {
  const sig = req.headers['stripe-signature'] as string;
  const endpointSecret = 'whsec_your_webhook_secret_here'; // Replace with your webhook secret

  let event: Stripe.Event;

  try {
    event = stripe.webhooks.constructEvent(req.body, sig, endpointSecret);
  } catch (err) {
    console.error('Webhook signature verification failed:', err);
    res.status(400).send(`Webhook Error: ${err}`);
    return;
  }

  // Handle the event
  switch (event.type) {
    case 'payment_intent.succeeded':
      const paymentIntent = event.data.object as Stripe.PaymentIntent;
      
      // Update order status in Firestore
      if (paymentIntent.metadata.orderId) {
        await admin.firestore()
          .collection('orders')
          .doc(paymentIntent.metadata.orderId)
          .update({
            status: 'paid',
            paymentIntentId: paymentIntent.id,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        
        console.log(`Payment succeeded for order ${paymentIntent.metadata.orderId}`);
      }
      break;

    case 'payment_intent.payment_failed':
      const failedPayment = event.data.object as Stripe.PaymentIntent;
      
      // Update order status to failed
      if (failedPayment.metadata.orderId) {
        await admin.firestore()
          .collection('orders')
          .doc(failedPayment.metadata.orderId)
          .update({
            status: 'payment_failed',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        
        console.log(`Payment failed for order ${failedPayment.metadata.orderId}`);
      }
      break;

    default:
      console.log(`Unhandled event type ${event.type}`);
  }

  res.json({ received: true });
});

// Function to create order after successful payment
export const createOrder = functions.https.onCall(async (data, context) => {
  try {
    // Verify user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { 
      items, 
      total, 
      subtotal, 
      tax, 
      shipping, 
      shippingAddress, 
      email,
      paymentIntentId 
    } = data;

    // Create order document
    const orderData = {
      userId: context.auth.uid,
      userEmail: email || context.auth.token.email,
      items: items,
      total: total,
      subtotal: subtotal,
      tax: tax,
      shipping: shipping,
      shippingAddress: shippingAddress,
      paymentIntentId: paymentIntentId,
      status: 'placed', // Will be updated to 'paid' by webhook
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      // Analytics fields
      month: new Date().getMonth() + 1,
      week: Math.ceil(new Date().getDate() / 7),
      day: new Date().getDate(),
    };

    // Add order to Firestore
    const orderRef = await admin.firestore().collection('orders').add(orderData);
    
    return {
      orderId: orderRef.id,
      success: true,
    };
  } catch (error) {
    console.error('Error creating order:', error);
    throw new functions.https.HttpsError('internal', 'Unable to create order');
  }
}); 