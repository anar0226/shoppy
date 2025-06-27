import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const firestore = admin.firestore();

/**
 * Cloud Function to create the initial super admin user
 * This should be called only once to set up the first admin
 * 
 * Call this function with:
 * {
 *   "email": "admin@shoppy.com",
 *   "password": "secure_password",
 *   "name": "Super Administrator"
 * }
 */
export const createSuperAdmin = functions.https.onCall(async (data, context) => {
  try {
    const { email, password, name } = data;

    if (!email || !password || !name) {
      throw new functions.https.HttpsError('invalid-argument', 'Email, password, and name are required');
    }

    // Create user in Firebase Auth
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      displayName: name,
    });

    // Add super admin document to Firestore
    await firestore.collection('super_admins').doc(userRecord.uid).set({
      name: name,
      email: email,
      role: 'super_administrator',
      permissions: ['all'], // Full access
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: 'system',
    });

    // Log the admin creation
    await firestore.collection('admin_activity_logs').add({
      adminId: userRecord.uid,
      action: 'super_admin_created',
      data: {
        email: email,
        name: name,
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      message: 'Super admin created successfully',
      adminId: userRecord.uid,
    };

  } catch (error) {
    console.error('Error creating super admin:', error);
    throw new functions.https.HttpsError('internal', 'Failed to create super admin');
  }
});

/**
 * Cloud Function to list all super admins (for debugging)
 */
export const listSuperAdmins = functions.https.onCall(async (data, context) => {
  try {
    // Verify the caller is already a super admin
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
    }

    const callerDoc = await firestore.collection('super_admins').doc(context.auth.uid).get();
    if (!callerDoc.exists || !callerDoc.data()?.isActive) {
      throw new functions.https.HttpsError('permission-denied', 'Access denied');
    }

    const snapshot = await firestore.collection('super_admins').get();
    const admins = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    }));

    return { admins };

  } catch (error) {
    console.error('Error listing super admins:', error);
    throw new functions.https.HttpsError('internal', 'Failed to list super admins');
  }
});

/**
 * Cloud Function to get platform statistics
 */
export const getPlatformStats = functions.https.onCall(async (data, context) => {
  try {
    // Verify the caller is a super admin
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
    }

    const callerDoc = await firestore.collection('super_admins').doc(context.auth.uid).get();
    if (!callerDoc.exists || !callerDoc.data()?.isActive) {
      throw new functions.https.HttpsError('permission-denied', 'Access denied');
    }

    // Get collections data
    const [storesSnapshot, usersSnapshot, ordersSnapshot, notificationsSnapshot] = await Promise.all([
      firestore.collection('stores').get(),
      firestore.collection('users').get(),
      firestore.collection('orders').get(),
      firestore.collection('notification_queue').get(),
    ]);

    // Calculate active stores
    const activeStores = storesSnapshot.docs.filter(doc => {
      const data = doc.data();
      return data.status === 'active';
    }).length;

    // Calculate active users (last 30 days)
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    
    const activeUsers = usersSnapshot.docs.filter(doc => {
      const data = doc.data();
      const lastLogin = data.lastLoginAt?.toDate();
      return lastLogin && lastLogin > thirtyDaysAgo;
    }).length;

    // Calculate total revenue
    const totalRevenue = ordersSnapshot.docs.reduce((sum, doc) => {
      const data = doc.data();
      return sum + (data.total || 0);
    }, 0);

    // Calculate notification success rate
    const sentNotifications = notificationsSnapshot.docs.filter(doc => {
      const data = doc.data();
      return data.status === 'sent';
    }).length;

    const notificationSuccessRate = notificationsSnapshot.docs.length > 0 
      ? (sentNotifications / notificationsSnapshot.docs.length) * 100 
      : 0;

    const stats = {
      totalStores: storesSnapshot.docs.length,
      activeStores: activeStores,
      totalUsers: usersSnapshot.docs.length,
      activeUsers: activeUsers,
      totalOrders: ordersSnapshot.docs.length,
      totalRevenue: totalRevenue,
      platformCommission: totalRevenue * 0.05, // 5% commission
      notificationsSent: notificationsSnapshot.docs.length,
      notificationSuccessRate: notificationSuccessRate,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    };

    return stats;

  } catch (error) {
    console.error('Error getting platform stats:', error);
    throw new functions.https.HttpsError('internal', 'Failed to get platform statistics');
  }
}); 