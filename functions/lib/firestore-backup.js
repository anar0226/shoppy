"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.exportUserData = exports.getBackupHistory = exports.restoreFromBackup = exports.triggerManualBackup = exports.scheduledFirestoreBackup = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const firestore_1 = require("firebase-admin/firestore");
const db = (0, firestore_1.getFirestore)();
/**
 * Automated Firestore Backup System
 * Runs daily at 2 AM UTC and backs up critical collections
 */
exports.scheduledFirestoreBackup = functions.pubsub
    .schedule('0 2 * * *') // Daily at 2 AM UTC
    .timeZone('UTC')
    .onRun(async (context) => {
    console.log('🔄 Starting scheduled Firestore backup...');
    const config = {
        collections: [
            'users',
            'stores',
            'orders',
            'products',
            'reviews',
            'discounts',
            'notifications',
            'super_admins',
            'admin_activity_logs',
            'analytics_events',
            'categories'
        ],
        bucketName: 'your-project-id-backups',
        retentionDays: 30,
        compression: true
    };
    try {
        const backupResult = await performBackup(config);
        console.log('✅ Backup completed successfully:', backupResult);
        // Clean up old backups
        await cleanupOldBackups(config.bucketName, config.retentionDays);
        // Send success notification
        await sendBackupNotification('success', backupResult);
        return { success: true, backup: backupResult };
    }
    catch (error) {
        console.error('❌ Backup failed:', error);
        // Log failure
        await logBackupFailure(error);
        // Send failure notification
        await sendBackupNotification('failure', null, error);
        throw error;
    }
});
/**
 * Manual backup trigger for admin use
 */
exports.triggerManualBackup = functions.https.onCall(async (data, context) => {
    var _a, _b;
    // Verify admin permissions
    if (!((_a = context.auth) === null || _a === void 0 ? void 0 : _a.uid)) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    try {
        // Check if user is super admin
        const adminDoc = await db.collection('super_admins').doc(context.auth.uid).get();
        if (!adminDoc.exists || !((_b = adminDoc.data()) === null || _b === void 0 ? void 0 : _b.isActive)) {
            throw new functions.https.HttpsError('permission-denied', 'Only super admins can trigger manual backups');
        }
        console.log(`🔄 Manual backup triggered by admin: ${context.auth.uid}`);
        const config = {
            collections: data.collections || [
                'users', 'stores', 'orders', 'products', 'reviews',
                'discounts', 'notifications', 'super_admins', 'admin_activity_logs',
                'analytics_events', 'categories'
            ],
            bucketName: 'your-project-id-backups',
            retentionDays: 30,
            compression: true
        };
        const backupResult = await performBackup(config);
        // Log admin activity
        await db.collection('admin_activity_logs').add({
            adminId: context.auth.uid,
            action: 'manual_backup_triggered',
            data: {
                collections: config.collections,
                backupPath: backupResult.backupPath,
                documentCount: backupResult.documentCount
            },
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
        return {
            success: true,
            message: 'Manual backup completed successfully',
            backup: backupResult
        };
    }
    catch (error) {
        console.error('❌ Manual backup failed:', error);
        throw new functions.https.HttpsError('internal', `Backup failed: ${error.message}`);
    }
});
/**
 * Restore data from backup
 */
exports.restoreFromBackup = functions.https.onCall(async (data, context) => {
    var _a, _b;
    // Verify admin permissions
    if (!((_a = context.auth) === null || _a === void 0 ? void 0 : _a.uid)) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    try {
        // Check if user is super admin
        const adminDoc = await db.collection('super_admins').doc(context.auth.uid).get();
        if (!adminDoc.exists || !((_b = adminDoc.data()) === null || _b === void 0 ? void 0 : _b.isActive)) {
            throw new functions.https.HttpsError('permission-denied', 'Only super admins can restore from backups');
        }
        const { backupPath, collections, confirmationCode } = data;
        if (!backupPath || !collections || confirmationCode !== 'RESTORE_CONFIRMED') {
            throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters or confirmation code');
        }
        console.log(`🔄 Restore triggered by admin: ${context.auth.uid} for backup: ${backupPath}`);
        const restoreResult = await performRestore(backupPath, collections);
        // Log admin activity
        await db.collection('admin_activity_logs').add({
            adminId: context.auth.uid,
            action: 'data_restore_performed',
            data: {
                backupPath,
                collections,
                restoredDocuments: restoreResult.restoredCount
            },
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
        return {
            success: true,
            message: 'Data restored successfully',
            restore: restoreResult
        };
    }
    catch (error) {
        console.error('❌ Restore failed:', error);
        throw new functions.https.HttpsError('internal', `Restore failed: ${error.message}`);
    }
});
/**
 * Get backup history and status
 */
exports.getBackupHistory = functions.https.onCall(async (data, context) => {
    var _a, _b;
    if (!((_a = context.auth) === null || _a === void 0 ? void 0 : _a.uid)) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    try {
        // Check if user is admin
        const adminDoc = await db.collection('super_admins').doc(context.auth.uid).get();
        if (!adminDoc.exists || !((_b = adminDoc.data()) === null || _b === void 0 ? void 0 : _b.isActive)) {
            throw new functions.https.HttpsError('permission-denied', 'Only admins can view backup history');
        }
        const backupsSnapshot = await db
            .collection('backup_logs')
            .orderBy('timestamp', 'desc')
            .limit(data.limit || 50)
            .get();
        const backups = backupsSnapshot.docs.map(doc => (Object.assign({ id: doc.id }, doc.data())));
        return {
            success: true,
            backups,
            total: backups.length
        };
    }
    catch (error) {
        console.error('❌ Failed to get backup history:', error);
        throw new functions.https.HttpsError('internal', `Failed to get backup history: ${error.message}`);
    }
});
/**
 * Core backup function
 */
async function performBackup(config) {
    const timestamp = new Date();
    const backupId = `backup_${timestamp.getTime()}`;
    const backupPath = `gs://${config.bucketName}/${backupId}`;
    console.log(`📦 Starting backup to: ${backupPath}`);
    // Log backup start
    const backupLogRef = db.collection('backup_logs').doc(backupId);
    await backupLogRef.set({
        timestamp: admin.firestore.Timestamp.fromDate(timestamp),
        collections: config.collections,
        status: 'in_progress',
        backupPath,
        documentCount: 0,
        size: 0
    });
    try {
        let totalDocuments = 0;
        const backupData = {};
        // Backup each collection
        for (const collectionName of config.collections) {
            console.log(`📄 Backing up collection: ${collectionName}`);
            const snapshot = await db.collection(collectionName).get();
            const documents = snapshot.docs.map(doc => ({
                id: doc.id,
                data: doc.data()
            }));
            backupData[collectionName] = documents;
            totalDocuments += documents.length;
            console.log(`✅ Backed up ${documents.length} documents from ${collectionName}`);
        }
        // Store backup data in Cloud Storage
        const bucket = admin.storage().bucket(config.bucketName);
        const file = bucket.file(`${backupId}/firestore_backup.json`);
        const backupContent = JSON.stringify({
            metadata: {
                timestamp: timestamp.toISOString(),
                collections: config.collections,
                documentCount: totalDocuments,
                version: '1.0'
            },
            data: backupData
        }, null, config.compression ? 0 : 2);
        await file.save(backupContent, {
            metadata: {
                contentType: 'application/json',
                metadata: {
                    backupId,
                    timestamp: timestamp.toISOString(),
                    collections: config.collections.join(','),
                    documentCount: totalDocuments.toString()
                }
            }
        });
        const fileSize = Buffer.byteLength(backupContent, 'utf8');
        // Update backup log with success
        const metadata = {
            timestamp: admin.firestore.Timestamp.fromDate(timestamp),
            collections: config.collections,
            documentCount: totalDocuments,
            size: fileSize,
            status: 'success',
            backupPath
        };
        await backupLogRef.update({
            timestamp: admin.firestore.Timestamp.fromDate(timestamp),
            collections: metadata.collections,
            documentCount: metadata.documentCount,
            size: metadata.size,
            status: metadata.status,
            backupPath: metadata.backupPath
        });
        console.log(`✅ Backup completed: ${totalDocuments} documents, ${(fileSize / 1024 / 1024).toFixed(2)} MB`);
        return metadata;
    }
    catch (error) {
        // Update backup log with failure
        await backupLogRef.update({
            status: 'failed',
            error: error.message
        });
        throw error;
    }
}
/**
 * Restore data from backup
 */
async function performRestore(backupPath, collections) {
    console.log(`🔄 Starting restore from: ${backupPath}`);
    try {
        // Parse backup path to get bucket and file
        const pathMatch = backupPath.match(/gs:\/\/([^\/]+)\/(.+)/);
        if (!pathMatch) {
            throw new Error('Invalid backup path format');
        }
        const [, bucketName, filePath] = pathMatch;
        const bucket = admin.storage().bucket(bucketName);
        const file = bucket.file(`${filePath}/firestore_backup.json`);
        // Download backup file
        const [contents] = await file.download();
        const backupData = JSON.parse(contents.toString());
        let restoredCount = 0;
        // Restore each collection
        for (const collectionName of collections) {
            if (!backupData.data[collectionName]) {
                console.warn(`⚠️ Collection ${collectionName} not found in backup`);
                continue;
            }
            console.log(`📄 Restoring collection: ${collectionName}`);
            const documents = backupData.data[collectionName];
            const batch = db.batch();
            let batchCount = 0;
            for (const doc of documents) {
                const docRef = db.collection(collectionName).doc(doc.id);
                batch.set(docRef, doc.data);
                batchCount++;
                restoredCount++;
                // Firestore batch limit is 500 operations
                if (batchCount >= 500) {
                    await batch.commit();
                    batchCount = 0;
                }
            }
            // Commit remaining documents
            if (batchCount > 0) {
                await batch.commit();
            }
            console.log(`✅ Restored ${documents.length} documents to ${collectionName}`);
        }
        console.log(`✅ Restore completed: ${restoredCount} documents restored`);
        return { restoredCount };
    }
    catch (error) {
        console.error('❌ Restore failed:', error);
        throw error;
    }
}
/**
 * Clean up old backups beyond retention period
 */
async function cleanupOldBackups(bucketName, retentionDays) {
    try {
        const cutoffDate = new Date();
        cutoffDate.setDate(cutoffDate.getDate() - retentionDays);
        console.log(`🧹 Cleaning up backups older than ${cutoffDate.toISOString()}`);
        const bucket = admin.storage().bucket(bucketName);
        const [files] = await bucket.getFiles();
        let deletedCount = 0;
        for (const file of files) {
            const [metadata] = await file.getMetadata();
            const fileDate = new Date(metadata.timeCreated);
            if (fileDate < cutoffDate) {
                await file.delete();
                deletedCount++;
                console.log(`🗑️ Deleted old backup: ${file.name}`);
            }
        }
        console.log(`✅ Cleanup completed: ${deletedCount} old backups deleted`);
    }
    catch (error) {
        console.error('❌ Cleanup failed:', error);
        // Don't throw - cleanup failure shouldn't break backup process
    }
}
/**
 * Log backup failure to Firestore
 */
async function logBackupFailure(error) {
    try {
        await db.collection('backup_logs').add({
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            status: 'failed',
            error: error.message,
            stack: error.stack
        });
    }
    catch (logError) {
        console.error('Failed to log backup failure:', logError);
    }
}
/**
 * Send backup status notifications
 */
async function sendBackupNotification(status, backupResult, error) {
    try {
        // Get super admins to notify
        const adminSnapshot = await db
            .collection('super_admins')
            .where('isActive', '==', true)
            .get();
        const notifications = [];
        for (const adminDoc of adminSnapshot.docs) {
            if (status === 'success' && backupResult) {
                notifications.push({
                    adminId: adminDoc.id,
                    title: '✅ Backup Completed Successfully',
                    message: `Firestore backup completed with ${backupResult.documentCount} documents (${(backupResult.size / 1024 / 1024).toFixed(2)} MB)`,
                    type: 'backup_success',
                    data: {
                        backupPath: backupResult.backupPath,
                        documentCount: backupResult.documentCount,
                        size: backupResult.size
                    },
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    isRead: false
                });
            }
            else if (status === 'failure') {
                notifications.push({
                    adminId: adminDoc.id,
                    title: '❌ Backup Failed',
                    message: `Firestore backup failed: ${(error === null || error === void 0 ? void 0 : error.message) || 'Unknown error'}`,
                    type: 'backup_failure',
                    data: {
                        error: error === null || error === void 0 ? void 0 : error.message,
                        timestamp: new Date().toISOString()
                    },
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    isRead: false,
                    priority: 'high'
                });
            }
        }
        // Send notifications
        for (const notification of notifications) {
            await db.collection('admin_notifications').add(notification);
        }
        console.log(`📧 Sent ${notifications.length} backup notifications to admins`);
    }
    catch (notificationError) {
        console.error('Failed to send backup notifications:', notificationError);
    }
}
/**
 * Export backup data for GDPR compliance
 */
exports.exportUserData = functions.https.onCall(async (data, context) => {
    var _a, _b;
    if (!((_a = context.auth) === null || _a === void 0 ? void 0 : _a.uid)) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const { userId, requestType } = data;
    try {
        // Verify user can export this data (self or admin)
        if (context.auth.uid !== userId) {
            const adminDoc = await db.collection('super_admins').doc(context.auth.uid).get();
            if (!adminDoc.exists || !((_b = adminDoc.data()) === null || _b === void 0 ? void 0 : _b.isActive)) {
                throw new functions.https.HttpsError('permission-denied', 'Insufficient permissions');
            }
        }
        const userData = {};
        // Collections that contain user data
        const userDataCollections = [
            'users',
            'orders',
            'reviews',
            'analytics_events',
            'notifications'
        ];
        for (const collection of userDataCollections) {
            let query;
            if (collection === 'users') {
                query = db.collection(collection).doc(userId);
                const doc = await query.get();
                if (doc.exists) {
                    userData[collection] = [{ id: doc.id, data: doc.data() }];
                }
            }
            else {
                // Query collections where user is referenced
                query = db.collection(collection).where('userId', '==', userId);
                const snapshot = await query.get();
                userData[collection] = snapshot.docs.map(doc => ({
                    id: doc.id,
                    data: doc.data()
                }));
            }
        }
        const exportData = {
            userId,
            exportedAt: new Date().toISOString(),
            requestType: requestType || 'user_request',
            data: userData
        };
        return {
            success: true,
            message: 'User data exported successfully',
            data: exportData
        };
    }
    catch (error) {
        console.error('❌ User data export failed:', error);
        throw new functions.https.HttpsError('internal', `Export failed: ${error.message}`);
    }
});
//# sourceMappingURL=firestore-backup.js.map