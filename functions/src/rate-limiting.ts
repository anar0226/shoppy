import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Rate limiting configuration
const RATE_LIMITS = {
  auth: { requests: 5, windowMs: 300000 }, // 5 requests per 5 minutes
  firestore_write: { requests: 20, windowMs: 60000 }, // 20 writes per minute
  email_verification: { requests: 3, windowMs: 600000 }, // 3 per 10 minutes
  password_reset: { requests: 3, windowMs: 600000 }, // 3 per 10 minutes
  order_creation: { requests: 10, windowMs: 300000 }, // 10 orders per 5 minutes
  image_upload: { requests: 10, windowMs: 300000 }, // 10 uploads per 5 minutes
};

interface RateLimitEntry {
  count: number;
  resetTime: number;
}

/**
 * Check if request is within rate limits
 */
async function checkRateLimit(
  operation: string,
  identifier: string,
  customLimits?: { requests: number; windowMs: number }
): Promise<{ allowed: boolean; retryAfter?: number }> {
  const limits = customLimits || RATE_LIMITS[operation as keyof typeof RATE_LIMITS];
  
  if (!limits) {
    console.warn(`No rate limit configured for operation: ${operation}`);
    return { allowed: true };
  }

  const now = Date.now();
  const key = `rate_limit:${operation}:${identifier}`;
  
  try {
    const db = admin.firestore();
    const doc = await db.collection('rate_limits').doc(key).get();
    
    let entry: RateLimitEntry = { count: 0, resetTime: now + limits.windowMs };
    
    if (doc.exists) {
      const data = doc.data() as RateLimitEntry;
      
      // Check if window has expired
      if (now >= data.resetTime) {
        entry = { count: 0, resetTime: now + limits.windowMs };
      } else {
        entry = data;
      }
    }
    
    // Check if limit exceeded
    if (entry.count >= limits.requests) {
      const retryAfter = Math.ceil((entry.resetTime - now) / 1000);
      return { allowed: false, retryAfter };
    }
    
    // Increment counter
    entry.count++;
    
    // Update in Firestore
    await db.collection('rate_limits').doc(key).set(entry);
    
    return { allowed: true };
    
  } catch (error) {
    console.error(`Rate limit check failed for ${operation}:${identifier}`, error);
    // Allow on error to prevent blocking legitimate requests
    return { allowed: true };
  }
}

/**
 * Middleware to enforce rate limiting on callable functions
 */
export function withRateLimit(
  operation: string,
  handler: (data: any, context: functions.https.CallableContext) => Promise<any>
) {
  return async (data: any, context: functions.https.CallableContext) => {
    const uid = context.auth?.uid;
    const ip = context.rawRequest.ip;
    
    // Use UID if authenticated, otherwise use IP
    const identifier = uid || ip || 'anonymous';
    
    const rateLimitResult = await checkRateLimit(operation, identifier);
    
    if (!rateLimitResult.allowed) {
      throw new functions.https.HttpsError(
        'resource-exhausted',
        `Rate limit exceeded for ${operation}. Try again in ${rateLimitResult.retryAfter} seconds.`,
        { retryAfter: rateLimitResult.retryAfter }
      );
    }
    
    return handler(data, context);
  };
}

/**
 * Rate-limited email verification
 */
export const sendVerificationEmail = functions.https.onCall(
  withRateLimit('email_verification', async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
    }
    
    try {
      const user = await admin.auth().getUser(context.auth.uid);
      
      if (user.emailVerified) {
        throw new functions.https.HttpsError('already-exists', 'Email already verified');
      }
      
      // Generate verification link
      await admin.auth().generateEmailVerificationLink(user.email!);
      
      // Here you would send the email using your preferred service
      // For now, we'll just return success
      
      return { success: true, message: 'Verification email sent' };
      
    } catch (error) {
      console.error('Email verification error:', error);
      throw new functions.https.HttpsError('internal', 'Failed to send verification email');
    }
  })
);

/**
 * Rate-limited password reset
 */
export const sendPasswordResetEmail = functions.https.onCall(
  withRateLimit('password_reset', async (data, context) => {
    const { email } = data;
    
    if (!email || typeof email !== 'string') {
      throw new functions.https.HttpsError('invalid-argument', 'Email is required');
    }
    
    try {
      // Generate password reset link
      await admin.auth().generatePasswordResetLink(email);
      
      // Here you would send the email using your preferred service
      // For now, we'll just return success
      
      return { success: true, message: 'Password reset email sent' };
      
    } catch (error) {
      console.error('Password reset error:', error);
      throw new functions.https.HttpsError('internal', 'Failed to send password reset email');
    }
  })
);

/**
 * Rate-limited order creation
 */
export const createOrderWithRateLimit = functions.https.onCall(
  withRateLimit('order_creation', async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
    }
    
    const { orderData } = data;
    
    if (!orderData) {
      throw new functions.https.HttpsError('invalid-argument', 'Order data is required');
    }
    
    try {
      const db = admin.firestore();
      const batch = db.batch();
      
      // Create order document
      const orderRef = db.collection('orders').doc();
      const order = {
        ...orderData,
        id: orderRef.id,
        userId: context.auth.uid,
        status: 'pending',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      
      batch.set(orderRef, order);
      
      // Commit batch
      await batch.commit();
      
      return { success: true, orderId: orderRef.id };
      
    } catch (error) {
      console.error('Order creation error:', error);
      throw new functions.https.HttpsError('internal', 'Failed to create order');
    }
  })
);

/**
 * Rate-limited image upload token generation
 */
export const generateUploadToken = functions.https.onCall(
  withRateLimit('image_upload', async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
    }
    
    const { fileName, contentType } = data;
    
    if (!fileName || !contentType) {
      throw new functions.https.HttpsError('invalid-argument', 'fileName and contentType are required');
    }
    
    // Validate file type
    const allowedTypes = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
    if (!allowedTypes.includes(contentType)) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid file type');
    }
    
    try {
      const bucket = admin.storage().bucket();
      const filePath = `uploads/${context.auth.uid}/${Date.now()}_${fileName}`;
      const file = bucket.file(filePath);
      
      // Generate signed URL for upload
      const [url] = await file.getSignedUrl({
        version: 'v4',
        action: 'write',
        expires: Date.now() + 15 * 60 * 1000, // 15 minutes
        contentType,
      });
      
      return { 
        success: true, 
        uploadUrl: url,
        filePath,
        expiresAt: Date.now() + 15 * 60 * 1000
      };
      
    } catch (error) {
      console.error('Upload token generation error:', error);
      throw new functions.https.HttpsError('internal', 'Failed to generate upload token');
    }
  })
);

/**
 * Cleanup expired rate limit entries
 */
export const cleanupRateLimits = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async () => {
    const db = admin.firestore();
    const now = Date.now();
    
    try {
      const snapshot = await db.collection('rate_limits')
        .where('resetTime', '<', now)
        .get();
      
      const batch = db.batch();
      snapshot.docs.forEach(doc => {
        batch.delete(doc.ref);
      });
      
      await batch.commit();
      
      console.log(`Cleaned up ${snapshot.size} expired rate limit entries`);
      
    } catch (error) {
      console.error('Rate limit cleanup error:', error);
    }
  });

/**
 * Monitor rate limit violations
 */
export const monitorRateLimits = functions.firestore
  .document('rate_limits/{documentId}')
  .onWrite(async (change, context) => {
    if (!change.after.exists) return;
    
    const data = change.after.data() as RateLimitEntry;
    const [, operation, identifier] = context.params.documentId.split(':');
    
    const limits = RATE_LIMITS[operation as keyof typeof RATE_LIMITS];
    if (!limits) return;
    
    // Alert if user is hitting rate limits frequently
    if (data.count >= limits.requests * 0.8) {
      console.warn(`Rate limit warning: ${operation} for ${identifier} at ${data.count}/${limits.requests}`);
      
      // You could send alerts to monitoring services here
      // await sendSlackAlert(`Rate limit warning: ${operation} for ${identifier}`);
    }
  }); 