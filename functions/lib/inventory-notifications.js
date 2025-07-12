"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getInventoryAnalytics = exports.updateInventorySettings = exports.triggerInventoryCheck = exports.checkInventoryLevels = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const db = admin.firestore();
/**
 * Scheduled function that runs every hour to check inventory levels
 * and send notifications for low stock, out of stock, and reorder alerts
 */
exports.checkInventoryLevels = functions.pubsub
    .schedule('0 * * * *') // Run every hour
    .timeZone('Asia/Ulaanbaatar')
    .onRun(async (context) => {
    try {
        console.log('Starting inventory level check...');
        const stores = await db.collection('stores').where('isActive', '==', true).get();
        for (const storeDoc of stores.docs) {
            const storeId = storeDoc.id;
            const storeData = storeDoc.data();
            try {
                await checkStoreInventory(storeId, storeData);
            }
            catch (error) {
                console.error(`Error checking inventory for store ${storeId}:`, error);
            }
        }
        console.log('Inventory level check completed');
    }
    catch (error) {
        console.error('Error in inventory level check:', error);
    }
});
/**
 * Check inventory levels for a specific store
 */
async function checkStoreInventory(storeId, storeData) {
    const lowStockThreshold = storeData.lowStockThreshold || 5;
    const outOfStockThreshold = 0;
    const ownerId = storeData.ownerId;
    if (!ownerId) {
        console.warn(`No owner found for store ${storeId}`);
        return;
    }
    // Get all active products for this store
    const productsSnapshot = await db
        .collection('products')
        .where('storeId', '==', storeId)
        .where('isActive', '==', true)
        .get();
    const alerts = [];
    // Check each product's inventory level
    for (const productDoc of productsSnapshot.docs) {
        const product = productDoc.data();
        const productId = productDoc.id;
        try {
            const stockLevel = calculateTotalStock(product);
            const productAlerts = generateProductAlerts(storeId, productId, product, stockLevel, lowStockThreshold, outOfStockThreshold);
            alerts.push(...productAlerts);
        }
        catch (error) {
            console.error(`Error processing product ${productId}:`, error);
        }
    }
    // Check for reorder alerts
    const reorderAlerts = await checkReorderAlerts(storeId);
    alerts.push(...reorderAlerts);
    // Send notifications if there are alerts
    if (alerts.length > 0) {
        await sendInventoryNotifications(storeId, ownerId, alerts);
    }
    // Update store's last inventory check timestamp
    await db.collection('stores').doc(storeId).update({
        lastInventoryCheck: admin.firestore.FieldValue.serverTimestamp(),
        lastInventoryAlertCount: alerts.length
    });
}
/**
 * Calculate total available stock for a product
 */
function calculateTotalStock(product) {
    if (product.variants && product.variants.length > 0) {
        // For products with variants, sum up all variant stock
        let totalStock = 0;
        for (const variant of product.variants) {
            if (variant.trackInventory && variant.stockByOption) {
                const variantStock = Object.values(variant.stockByOption)
                    .reduce((sum, stock) => sum + (stock || 0), 0);
                totalStock += variantStock;
            }
        }
        return totalStock;
    }
    else {
        // Simple product
        return product.stock || 0;
    }
}
/**
 * Generate alerts for a specific product
 */
function generateProductAlerts(storeId, productId, product, stockLevel, lowStockThreshold, outOfStockThreshold) {
    const alerts = [];
    if (stockLevel <= outOfStockThreshold) {
        alerts.push({
            storeId,
            productId,
            productName: product.name || 'Unknown Product',
            currentStock: stockLevel,
            threshold: outOfStockThreshold,
            alertType: 'out_of_stock',
            severity: 'critical'
        });
    }
    else if (stockLevel <= lowStockThreshold) {
        alerts.push({
            storeId,
            productId,
            productName: product.name || 'Unknown Product',
            currentStock: stockLevel,
            threshold: lowStockThreshold,
            alertType: 'low_stock',
            severity: stockLevel <= 2 ? 'high' : 'medium'
        });
    }
    return alerts;
}
/**
 * Check for products that need reordering
 */
async function checkReorderAlerts(storeId) {
    const alerts = [];
    try {
        const reorderAlertsSnapshot = await db
            .collection('reorder_alerts')
            .where('isActive', '==', true)
            .get();
        for (const alertDoc of reorderAlertsSnapshot.docs) {
            const alertData = alertDoc.data();
            const productId = alertData.productId;
            // Get the product to check current stock
            const productDoc = await db.collection('products').doc(productId).get();
            if (productDoc.exists) {
                const product = productDoc.data();
                // Only check products from this store
                if (product.storeId !== storeId)
                    continue;
                const currentStock = calculateTotalStock(product);
                const reorderPoint = alertData.reorderPoint || 10;
                if (currentStock <= reorderPoint) {
                    alerts.push({
                        storeId,
                        productId,
                        productName: product.name || 'Unknown Product',
                        currentStock,
                        threshold: reorderPoint,
                        alertType: 'reorder_needed',
                        severity: currentStock <= (reorderPoint / 2) ? 'high' : 'medium'
                    });
                }
            }
        }
    }
    catch (error) {
        console.error('Error checking reorder alerts:', error);
    }
    return alerts;
}
/**
 * Send inventory notifications to store owner
 */
async function sendInventoryNotifications(storeId, ownerId, alerts) {
    try {
        // Group alerts by type and severity
        const alertGroups = groupAlertsByType(alerts);
        // Create notifications for each alert group
        for (const [alertType, alertList] of Object.entries(alertGroups)) {
            const notification = createNotificationFromAlerts(storeId, ownerId, alertType, alertList);
            // Check if similar notification was sent recently (within last 24 hours)
            const recentNotification = await checkRecentNotification(storeId, alertType);
            if (!recentNotification) {
                await db.collection('notifications').add(notification);
                console.log(`Sent ${alertType} notification to store ${storeId}`);
            }
        }
        // Send critical alerts immediately via push notification
        const criticalAlerts = alerts.filter(alert => alert.severity === 'critical');
        if (criticalAlerts.length > 0) {
            await sendPushNotification(ownerId, criticalAlerts);
        }
    }
    catch (error) {
        console.error('Error sending inventory notifications:', error);
    }
}
/**
 * Group alerts by type for better notification organization
 */
function groupAlertsByType(alerts) {
    const groups = {};
    for (const alert of alerts) {
        if (!groups[alert.alertType]) {
            groups[alert.alertType] = [];
        }
        groups[alert.alertType].push(alert);
    }
    return groups;
}
/**
 * Create a notification object from alerts
 */
function createNotificationFromAlerts(storeId, ownerId, alertType, alerts) {
    const count = alerts.length;
    let title = '';
    let message = '';
    switch (alertType) {
        case 'out_of_stock':
            title = 'Out of Stock Alert';
            message = `${count} product${count > 1 ? 's are' : ' is'} out of stock`;
            break;
        case 'low_stock':
            title = 'Low Stock Alert';
            message = `${count} product${count > 1 ? 's are' : ' is'} running low on stock`;
            break;
        case 'reorder_needed':
            title = 'Reorder Alert';
            message = `${count} product${count > 1 ? 's need' : ' needs'} to be reordered`;
            break;
        default:
            title = 'Inventory Alert';
            message = `${count} inventory alert${count > 1 ? 's' : ''}`;
    }
    return {
        storeId,
        ownerId,
        type: `inventory_${alertType}`,
        title,
        message,
        data: {
            alertType,
            alertCount: count,
            alerts: alerts.map(alert => ({
                productId: alert.productId,
                productName: alert.productName,
                currentStock: alert.currentStock,
                threshold: alert.threshold,
                severity: alert.severity
            }))
        },
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
    };
}
/**
 * Check if a similar notification was sent recently
 */
async function checkRecentNotification(storeId, alertType) {
    const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const recentNotifications = await db
        .collection('notifications')
        .where('storeId', '==', storeId)
        .where('type', '==', `inventory_${alertType}`)
        .where('createdAt', '>', admin.firestore.Timestamp.fromDate(twentyFourHoursAgo))
        .limit(1)
        .get();
    return !recentNotifications.empty;
}
/**
 * Send push notification for critical alerts
 */
async function sendPushNotification(ownerId, criticalAlerts) {
    try {
        // Get user's FCM tokens
        const userDoc = await db.collection('users').doc(ownerId).get();
        const userData = userDoc.data();
        if (!userData || !userData.fcmTokens) {
            console.warn(`No FCM tokens found for user ${ownerId}`);
            return;
        }
        const tokens = userData.fcmTokens;
        if (tokens.length === 0) {
            console.warn(`Empty FCM tokens for user ${ownerId}`);
            return;
        }
        const outOfStockCount = criticalAlerts.filter(alert => alert.alertType === 'out_of_stock').length;
        const message = {
            notification: {
                title: 'Critical Inventory Alert',
                body: `${outOfStockCount} product${outOfStockCount > 1 ? 's are' : ' is'} out of stock!`
            },
            data: {
                type: 'inventory_critical',
                alertCount: criticalAlerts.length.toString(),
                timestamp: Date.now().toString()
            },
            tokens
        };
        const response = await admin.messaging().sendMulticast(message);
        console.log(`Push notification sent to ${response.successCount} devices`);
        // Clean up invalid tokens
        if (response.failureCount > 0) {
            const invalidTokens = [];
            response.responses.forEach((resp, idx) => {
                if (!resp.success) {
                    invalidTokens.push(tokens[idx]);
                }
            });
            if (invalidTokens.length > 0) {
                await db.collection('users').doc(ownerId).update({
                    fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens)
                });
            }
        }
    }
    catch (error) {
        console.error('Error sending push notification:', error);
    }
}
/**
 * Manual trigger for inventory check (for testing or immediate checks)
 */
exports.triggerInventoryCheck = functions.https.onCall(async (data, context) => {
    // Verify user is authenticated
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const { storeId } = data;
    if (!storeId) {
        throw new functions.https.HttpsError('invalid-argument', 'Store ID is required');
    }
    try {
        // Verify user owns the store
        const storeDoc = await db.collection('stores').doc(storeId).get();
        if (!storeDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'Store not found');
        }
        const storeData = storeDoc.data();
        if (storeData.ownerId !== context.auth.uid) {
            throw new functions.https.HttpsError('permission-denied', 'Not authorized to access this store');
        }
        // Run inventory check for this store
        await checkStoreInventory(storeId, storeData);
        return {
            success: true,
            message: 'Inventory check completed successfully',
            timestamp: admin.firestore.FieldValue.serverTimestamp()
        };
    }
    catch (error) {
        console.error('Error in manual inventory check:', error);
        throw new functions.https.HttpsError('internal', 'Failed to check inventory');
    }
});
/**
 * Update inventory alert settings for a store
 */
exports.updateInventorySettings = functions.https.onCall(async (data, context) => {
    // Verify user is authenticated
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const { storeId, settings } = data;
    if (!storeId || !settings) {
        throw new functions.https.HttpsError('invalid-argument', 'Store ID and settings are required');
    }
    try {
        // Verify user owns the store
        const storeDoc = await db.collection('stores').doc(storeId).get();
        if (!storeDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'Store not found');
        }
        const storeData = storeDoc.data();
        if (storeData.ownerId !== context.auth.uid) {
            throw new functions.https.HttpsError('permission-denied', 'Not authorized to access this store');
        }
        // Validate settings
        const validatedSettings = validateInventorySettings(settings);
        // Update store settings
        await db.collection('stores').doc(storeId).update(Object.assign(Object.assign({}, validatedSettings), { updatedAt: admin.firestore.FieldValue.serverTimestamp() }));
        return {
            success: true,
            message: 'Inventory settings updated successfully',
            settings: validatedSettings
        };
    }
    catch (error) {
        console.error('Error updating inventory settings:', error);
        throw new functions.https.HttpsError('internal', 'Failed to update inventory settings');
    }
});
/**
 * Validate inventory settings
 */
function validateInventorySettings(settings) {
    const validatedSettings = {};
    if (typeof settings.lowStockThreshold === 'number' && settings.lowStockThreshold >= 0) {
        validatedSettings.lowStockThreshold = Math.min(settings.lowStockThreshold, 100);
    }
    if (typeof settings.enableLowStockAlerts === 'boolean') {
        validatedSettings.enableLowStockAlerts = settings.enableLowStockAlerts;
    }
    if (typeof settings.enableReorderAlerts === 'boolean') {
        validatedSettings.enableReorderAlerts = settings.enableReorderAlerts;
    }
    if (typeof settings.enablePushNotifications === 'boolean') {
        validatedSettings.enablePushNotifications = settings.enablePushNotifications;
    }
    if (typeof settings.alertFrequency === 'string' &&
        ['hourly', 'daily', 'weekly'].includes(settings.alertFrequency)) {
        validatedSettings.alertFrequency = settings.alertFrequency;
    }
    return validatedSettings;
}
/**
 * Get inventory analytics for a store
 */
exports.getInventoryAnalytics = functions.https.onCall(async (data, context) => {
    // Verify user is authenticated
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const { storeId, period = '30d' } = data;
    if (!storeId) {
        throw new functions.https.HttpsError('invalid-argument', 'Store ID is required');
    }
    try {
        // Verify user owns the store
        const storeDoc = await db.collection('stores').doc(storeId).get();
        if (!storeDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'Store not found');
        }
        const storeData = storeDoc.data();
        if (storeData.ownerId !== context.auth.uid) {
            throw new functions.https.HttpsError('permission-denied', 'Not authorized to access this store');
        }
        // Calculate date range
        const endDate = new Date();
        const startDate = new Date();
        switch (period) {
            case '7d':
                startDate.setDate(endDate.getDate() - 7);
                break;
            case '30d':
                startDate.setDate(endDate.getDate() - 30);
                break;
            case '90d':
                startDate.setDate(endDate.getDate() - 90);
                break;
            default:
                startDate.setDate(endDate.getDate() - 30);
        }
        // Get inventory audit logs for the period
        const auditLogsSnapshot = await db
            .collection('inventory_audit_log')
            .where('storeId', '==', storeId)
            .where('timestamp', '>=', admin.firestore.Timestamp.fromDate(startDate))
            .where('timestamp', '<=', admin.firestore.Timestamp.fromDate(endDate))
            .orderBy('timestamp', 'desc')
            .get();
        // Process analytics
        const analytics = processInventoryAnalytics(auditLogsSnapshot.docs);
        return {
            success: true,
            analytics,
            period,
            startDate: startDate.toISOString(),
            endDate: endDate.toISOString()
        };
    }
    catch (error) {
        console.error('Error getting inventory analytics:', error);
        throw new functions.https.HttpsError('internal', 'Failed to get inventory analytics');
    }
});
/**
 * Process inventory analytics from audit logs
 */
function processInventoryAnalytics(auditDocs) {
    var _a;
    const analytics = {
        totalAdjustments: 0,
        positiveAdjustments: 0,
        negativeAdjustments: 0,
        totalStockAdded: 0,
        totalStockRemoved: 0,
        adjustmentsByType: {},
        adjustmentsByReason: {},
        dailyAdjustments: {},
        topAdjustedProducts: {}
    };
    for (const doc of auditDocs) {
        const data = doc.data();
        const adjustment = data.adjustment || 0;
        const type = data.type || 'unknown';
        const reason = data.reason || 'unknown';
        const productId = data.productId;
        const productName = data.productName || 'Unknown Product';
        const timestamp = (_a = data.timestamp) === null || _a === void 0 ? void 0 : _a.toDate();
        // Count adjustments
        analytics.totalAdjustments++;
        if (adjustment > 0) {
            analytics.positiveAdjustments++;
            analytics.totalStockAdded += adjustment;
        }
        else if (adjustment < 0) {
            analytics.negativeAdjustments++;
            analytics.totalStockRemoved += Math.abs(adjustment);
        }
        // Group by type
        analytics.adjustmentsByType[type] = (analytics.adjustmentsByType[type] || 0) + 1;
        // Group by reason
        analytics.adjustmentsByReason[reason] = (analytics.adjustmentsByReason[reason] || 0) + 1;
        // Daily adjustments
        if (timestamp) {
            const dateKey = timestamp.toISOString().split('T')[0];
            analytics.dailyAdjustments[dateKey] = (analytics.dailyAdjustments[dateKey] || 0) + 1;
        }
        // Top adjusted products
        if (productId) {
            if (!analytics.topAdjustedProducts[productId]) {
                analytics.topAdjustedProducts[productId] = {
                    name: productName,
                    count: 0,
                    totalAdjustment: 0
                };
            }
            analytics.topAdjustedProducts[productId].count++;
            analytics.topAdjustedProducts[productId].totalAdjustment += adjustment;
        }
    }
    return analytics;
}
//# sourceMappingURL=inventory-notifications.js.map