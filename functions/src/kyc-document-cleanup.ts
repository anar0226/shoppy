import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// KYC Document Cleanup Function
// Automatically deletes KYC documents after 90 days for privacy compliance
export const cleanupKYCDocuments = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    try {
      const db = admin.firestore();
      const now = admin.firestore.Timestamp.now();
      const ninetyDaysAgo = new Date(now.toDate().getTime() - (90 * 24 * 60 * 60 * 1000));


      console.log('Starting KYC document cleanup...');

      // Find stores with KYC documents that are older than 90 days
      const storesSnapshot = await db
        .collection('stores')
        .where('kycStatus', 'in', ['verified', 'rejected'])
        .get();

      let deletedCount = 0;
      const batch = db.batch();

      for (const storeDoc of storesSnapshot.docs) {
        const storeData = storeDoc.data();
        const kycVerifiedAt = storeData.kycVerifiedAt;
        const kycRejectedAt = storeData.kycRejectedAt;
        
        // Check if KYC was processed more than 90 days ago
        const processedAt = kycVerifiedAt || kycRejectedAt;
        if (processedAt && processedAt.toDate() < ninetyDaysAgo) {
          // Remove KYC documents from store data
          batch.update(storeDoc.ref, {
            idCardFrontImage: admin.firestore.FieldValue.delete(),
            idCardBackImage: admin.firestore.FieldValue.delete(),
          });

          // Also delete from Firebase Storage if URLs exist
          const documentUrls = [
            storeData.idCardFrontImage,
            storeData.idCardBackImage,
          ].filter(url => url);

          // Delete files from Firebase Storage
          for (const url of documentUrls) {
            try {
              if (url && url.startsWith('gs://')) {
                const bucket = admin.storage().bucket();
                const filePath = url.replace('gs://shoppy-6d81f.appspot.com/', '');
                await bucket.file(filePath).delete();
                console.log(`Deleted KYC document: ${filePath}`);
              }
            } catch (error) {
              console.error(`Error deleting KYC document ${url}:`, error);
            }
          }

          deletedCount++;
          console.log(`Marked KYC documents for deletion for store: ${storeDoc.id}`);
        }
      }

      // Commit the batch
      if (deletedCount > 0) {
        await batch.commit();
        console.log(`Successfully cleaned up KYC documents for ${deletedCount} stores`);
      } else {
        console.log('No KYC documents found for cleanup');
      }

      return { success: true, deletedCount };
    } catch (error) {
      console.error('Error in KYC document cleanup:', error);
      throw error;
    }
  });

// Manual KYC document cleanup function (for admin use)
export const manualKYCCleanup = functions.https.onCall(async (data, context) => {
  try {
    // Verify super admin access
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
    }

    const superAdminDoc = await admin.firestore()
      .collection('super_admins')
      .doc(context.auth.uid)
      .get();

    if (!superAdminDoc.exists) {
      throw new functions.https.HttpsError('permission-denied', 'Super admin access required');
    }

    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const daysToKeep = data.daysToKeep || 90;
    const cutoffDate = new Date(now.toDate().getTime() - (daysToKeep * 24 * 60 * 60 * 1000));


    console.log(`Manual KYC cleanup: deleting documents older than ${daysToKeep} days`);

    // Find stores with KYC documents older than specified days
    const storesSnapshot = await db
      .collection('stores')
      .where('kycStatus', 'in', ['verified', 'rejected'])
      .get();

    let deletedCount = 0;
    const batch = db.batch();

    for (const storeDoc of storesSnapshot.docs) {
      const storeData = storeDoc.data();
      const kycVerifiedAt = storeData.kycVerifiedAt;
      const kycRejectedAt = storeData.kycRejectedAt;
      
      const processedAt = kycVerifiedAt || kycRejectedAt;
      if (processedAt && processedAt.toDate() < cutoffDate) {
        // Remove KYC documents
        batch.update(storeDoc.ref, {
          idCardFrontImage: admin.firestore.FieldValue.delete(),
          idCardBackImage: admin.firestore.FieldValue.delete(),
        });

        // Delete from Firebase Storage
        const documentUrls = [
          storeData.idCardFrontImage,
          storeData.idCardBackImage,
        ].filter(url => url);

        for (const url of documentUrls) {
          try {
            if (url && url.startsWith('gs://')) {
              const bucket = admin.storage().bucket();
              const filePath = url.replace('gs://shoppy-6d81f.appspot.com/', '');
              await bucket.file(filePath).delete();
            }
          } catch (error) {
            console.error(`Error deleting KYC document ${url}:`, error);
          }
        }

        deletedCount++;
      }
    }

    if (deletedCount > 0) {
      await batch.commit();
    }

    return {
      success: true,
      deletedCount,
      message: `Cleaned up KYC documents for ${deletedCount} stores`,
    };
  } catch (error) {
    console.error('Error in manual KYC cleanup:', error);
    throw new functions.https.HttpsError('internal', 'Failed to cleanup KYC documents');
  }
});

// Get KYC document statistics
export const getKYCDocumentStats = functions.https.onCall(async (data, context) => {
  try {
    // Verify super admin access
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
    }

    const superAdminDoc = await admin.firestore()
      .collection('super_admins')
      .doc(context.auth.uid)
      .get();

    if (!superAdminDoc.exists) {
      throw new functions.https.HttpsError('permission-denied', 'Super admin access required');
    }

    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const thirtyDaysAgo = new Date(now.toDate().getTime() - (30 * 24 * 60 * 60 * 1000));
    const sixtyDaysAgo = new Date(now.toDate().getTime() - (60 * 24 * 60 * 60 * 1000));
    const ninetyDaysAgo = new Date(now.toDate().getTime() - (90 * 24 * 60 * 60 * 1000));

    const storesSnapshot = await db
      .collection('stores')
      .where('kycStatus', 'in', ['verified', 'rejected'])
      .get();

    let totalWithDocuments = 0;
    let documentsOlderThan30Days = 0;
    let documentsOlderThan60Days = 0;
    let documentsOlderThan90Days = 0;

    for (const storeDoc of storesSnapshot.docs) {
      const storeData = storeDoc.data();

      
      if (storeData.idCardFrontImage || storeData.idCardBackImage) {
        totalWithDocuments++;
        
        const kycVerifiedAt = storeData.kycVerifiedAt;
        const kycRejectedAt = storeData.kycRejectedAt;
        const processedAt = kycVerifiedAt || kycRejectedAt;
        
        if (processedAt) {
          const processedDate = processedAt.toDate();
          
          if (processedDate < ninetyDaysAgo) {
            documentsOlderThan90Days++;
          } else if (processedDate < sixtyDaysAgo) {
            documentsOlderThan60Days++;
          } else if (processedDate < thirtyDaysAgo) {
            documentsOlderThan30Days++;
          }
        }
      }
    }

    return {
      success: true,
      stats: {
        totalWithDocuments,
        documentsOlderThan30Days,
        documentsOlderThan60Days,
        documentsOlderThan90Days,
      },
    };
  } catch (error) {
    console.error('Error getting KYC document stats:', error);
    throw new functions.https.HttpsError('internal', 'Failed to get KYC document statistics');
  }
}); 