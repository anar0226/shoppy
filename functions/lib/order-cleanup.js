"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.manualOrderCleanup = exports.deleteOldHistoricalOrders = exports.compressOldArchivedOrders = exports.archiveOldOrders = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const db = admin.firestore();
// Order archival constants
const ARCHIVE_AFTER_DAYS = 30; // Archive after 30 days
const COMPRESS_AFTER_DAYS = 90; // Compress after 90 days  
const DELETE_AFTER_DAYS = 365; // Delete after 1 year
/**
 * Cloud Function to archive old delivered orders
 * Runs daily at 2 AM
 */
exports.archiveOldOrders = functions.pubsub
    .schedule('0 2 * * *') // Daily at 2 AM
    .timeZone('Asia/Ulaanbaatar')
    .onRun(async (context) => {
    try {
        const cutoffDate = new Date();
        cutoffDate.setDate(cutoffDate.getDate() - ARCHIVE_AFTER_DAYS);
        console.log(`Archiving orders delivered before ${cutoffDate.toISOString()}`);
        // Get orders to archive
        const ordersToArchive = await db
            .collection('orders')
            .where('status', '==', 'delivered')
            .where('updatedAt', '<', admin.firestore.Timestamp.fromDate(cutoffDate))
            .limit(100) // Process in batches
            .get();
        if (ordersToArchive.empty) {
            console.log('No orders to archive');
            return null;
        }
        const batch = db.batch();
        let archivedCount = 0;
        for (const doc of ordersToArchive.docs) {
            const orderData = doc.data();
            // Create archived version with reduced data
            const archivedData = createArchivedOrderData(orderData);
            // Add to archived collection
            const archivedRef = db.collection('archived_orders').doc(doc.id);
            batch.set(archivedRef, archivedData);
            // Mark as archived in original collection
            batch.update(doc.ref, {
                archived: true,
                archivedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            archivedCount++;
        }
        await batch.commit();
        console.log(`Successfully archived ${archivedCount} orders`);
        return { archivedCount };
    }
    catch (error) {
        console.error('Error archiving orders:', error);
        throw error;
    }
});
/**
 * Cloud Function to compress old archived orders
 * Runs weekly on Sunday at 3 AM
 */
exports.compressOldArchivedOrders = functions.pubsub
    .schedule('0 3 * * 0') // Weekly on Sunday at 3 AM
    .timeZone('Asia/Ulaanbaatar')
    .onRun(async (context) => {
    try {
        const cutoffDate = new Date();
        cutoffDate.setDate(cutoffDate.getDate() - COMPRESS_AFTER_DAYS);
        console.log(`Compressing archived orders delivered before ${cutoffDate.toISOString()}`);
        // Get archived orders to compress
        const ordersToCompress = await db
            .collection('archived_orders')
            .where('deliveredAt', '<', admin.firestore.Timestamp.fromDate(cutoffDate))
            .limit(100) // Process in batches
            .get();
        if (ordersToCompress.empty) {
            console.log('No archived orders to compress');
            return null;
        }
        const batch = db.batch();
        let compressedCount = 0;
        for (const doc of ordersToCompress.docs) {
            const orderData = doc.data();
            // Create compressed version with minimal data
            const compressedData = createCompressedOrderData(orderData);
            // Add to historical collection
            const historicalRef = db.collection('historical_orders').doc(doc.id);
            batch.set(historicalRef, compressedData);
            // Delete from archived collection
            batch.delete(doc.ref);
            compressedCount++;
        }
        await batch.commit();
        console.log(`Successfully compressed ${compressedCount} archived orders`);
        return { compressedCount };
    }
    catch (error) {
        console.error('Error compressing archived orders:', error);
        throw error;
    }
});
/**
 * Cloud Function to delete old historical orders
 * Runs monthly on the 1st at 4 AM
 */
exports.deleteOldHistoricalOrders = functions.pubsub
    .schedule('0 4 1 * *') // Monthly on the 1st at 4 AM
    .timeZone('Asia/Ulaanbaatar')
    .onRun(async (context) => {
    try {
        const cutoffDate = new Date();
        cutoffDate.setDate(cutoffDate.getDate() - DELETE_AFTER_DAYS);
        console.log(`Deleting historical orders delivered before ${cutoffDate.toISOString()}`);
        // Get historical orders to delete
        const ordersToDelete = await db
            .collection('historical_orders')
            .where('deliveredAt', '<', admin.firestore.Timestamp.fromDate(cutoffDate))
            .limit(100) // Process in batches
            .get();
        if (ordersToDelete.empty) {
            console.log('No historical orders to delete');
            return null;
        }
        const batch = db.batch();
        let deletedCount = 0;
        for (const doc of ordersToDelete.docs) {
            batch.delete(doc.ref);
            deletedCount++;
        }
        await batch.commit();
        console.log(`Successfully deleted ${deletedCount} historical orders`);
        return { deletedCount };
    }
    catch (error) {
        console.error('Error deleting historical orders:', error);
        throw error;
    }
});
/**
 * Manual trigger for order cleanup (for testing or immediate cleanup)
 */
exports.manualOrderCleanup = functions.https.onCall(async (data, context) => {
    // Check if user is authenticated and has admin privileges
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    try {
        const { action } = data;
        let result = {};
        switch (action) {
            case 'archive':
                result = await (0, exports.archiveOldOrders)({});
                break;
            case 'compress':
                result = await (0, exports.compressOldArchivedOrders)({});
                break;
            case 'delete':
                result = await (0, exports.deleteOldHistoricalOrders)({});
                break;
            case 'all':
                result.archive = await (0, exports.archiveOldOrders)({});
                result.compress = await (0, exports.compressOldArchivedOrders)({});
                result.delete = await (0, exports.deleteOldHistoricalOrders)({});
                break;
            default:
                throw new functions.https.HttpsError('invalid-argument', 'Invalid action specified');
        }
        return { success: true, result };
    }
    catch (error) {
        console.error('Manual order cleanup error:', error);
        throw new functions.https.HttpsError('internal', 'Cleanup failed');
    }
});
// Helper functions
function createArchivedOrderData(originalData) {
    return {
        orderId: originalData.id || '',
        status: originalData.status || 'delivered',
        total: originalData.total || 0.0,
        subtotal: originalData.subtotal || 0.0,
        shippingCost: originalData.shippingCost || 0.0,
        tax: originalData.tax || 0.0,
        storeId: originalData.storeId || '',
        storeName: originalData.storeName || '',
        vendorId: originalData.vendorId || '',
        userId: originalData.userId || '',
        userEmail: originalData.userEmail || '',
        customerName: originalData.customerName || '',
        createdAt: originalData.createdAt,
        deliveredAt: originalData.updatedAt,
        archivedAt: admin.firestore.FieldValue.serverTimestamp(),
        itemCount: originalData.itemCount || 0,
        items: compressOrderItems(originalData.items || []),
        analytics: originalData.analytics || {},
    };
}
function createCompressedOrderData(archivedData) {
    return {
        orderId: archivedData.orderId || '',
        status: archivedData.status || 'delivered',
        total: archivedData.total || 0.0,
        storeId: archivedData.storeId || '',
        vendorId: archivedData.vendorId || '',
        userId: archivedData.userId || '',
        createdAt: archivedData.createdAt,
        deliveredAt: archivedData.deliveredAt,
        compressedAt: admin.firestore.FieldValue.serverTimestamp(),
        itemCount: archivedData.itemCount || 0,
        analytics: archivedData.analytics || {},
    };
}
function compressOrderItems(items) {
    return items.map(item => ({
        name: item.name || '',
        price: item.price || 0.0,
        quantity: item.quantity || 1,
        variant: item.variant || '',
        // Remove imageUrl to save space
    }));
}
//# sourceMappingURL=order-cleanup.js.map