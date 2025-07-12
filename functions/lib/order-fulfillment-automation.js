"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getOrderFulfillmentMetrics = exports.updateOrderStatus = exports.processScheduledTasks = exports.processAutomaticOrderTransitions = exports.handleOrderStatusChange = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const db = admin.firestore();
/**
 * Automated Order Status Transition Function
 * Triggers when an order document is updated
 */
exports.handleOrderStatusChange = functions.firestore
    .document('orders/{orderId}')
    .onUpdate(async (change, context) => {
    var _a, _b, _c;
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const orderId = context.params.orderId;
    // Check if status actually changed
    if (beforeData.status === afterData.status) {
        return;
    }
    try {
        // Log the status transition
        await logStatusTransition({
            orderId,
            fromStatus: beforeData.status,
            toStatus: afterData.status,
            reason: ((_a = afterData.lastTransition) === null || _a === void 0 ? void 0 : _a.reason) || 'Status updated',
            automated: ((_b = afterData.lastTransition) === null || _b === void 0 ? void 0 : _b.automated) || false,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            userId: (_c = afterData.lastTransition) === null || _c === void 0 ? void 0 : _c.userId,
        });
        // Handle status-specific actions
        await handleStatusSpecificActions(orderId, afterData);
        // Send notifications
        await sendStatusUpdateNotifications(orderId, afterData);
        // Update analytics
        await updateOrderAnalytics(orderId, afterData);
        console.log(`Order ${orderId} status changed from ${beforeData.status} to ${afterData.status}`);
    }
    catch (error) {
        console.error(`Error handling status change for order ${orderId}:`, error);
    }
});
/**
 * Scheduled function to check for orders that need automatic processing
 */
exports.processAutomaticOrderTransitions = functions.pubsub
    .schedule('every 5 minutes')
    .timeZone('Asia/Ulaanbaatar')
    .onRun(async (context) => {
    try {
        console.log('Starting automatic order transition processing...');
        // Process different order states
        await Promise.all([
            processPendingOrders(),
            processPaymentPendingOrders(),
            processPaidOrders(),
            processProcessingOrders(),
            processDeliveryOrders(),
            checkStuckOrders(),
        ]);
        console.log('Automatic order transition processing completed');
    }
    catch (error) {
        console.error('Error in automatic order transition processing:', error);
    }
});
/**
 * Process orders in pending status
 */
async function processPendingOrders() {
    try {
        const thirtyMinutesAgo = new Date(Date.now() - 30 * 60 * 1000);
        const pendingOrders = await db
            .collection('orders')
            .where('status', '==', 'pending')
            .where('updatedAt', '<', admin.firestore.Timestamp.fromDate(thirtyMinutesAgo))
            .get();
        for (const doc of pendingOrders.docs) {
            const orderData = doc.data();
            const paymentMethod = orderData.paymentMethod || 'card';
            if (paymentMethod === 'cash' || paymentMethod === 'pickup') {
                // Auto-confirm cash/pickup orders
                await transitionOrderStatus(doc.id, 'paid', 'Cash/pickup payment method - auto-confirmed', true);
            }
            else {
                // Check payment status for online payments
                await checkPaymentStatus(doc.id, orderData);
            }
        }
    }
    catch (error) {
        console.error('Error processing pending orders:', error);
    }
}
/**
 * Process orders with payment pending
 */
async function processPaymentPendingOrders() {
    try {
        const twoHoursAgo = new Date(Date.now() - 2 * 60 * 60 * 1000);
        const paymentPendingOrders = await db
            .collection('orders')
            .where('status', '==', 'paymentPending')
            .where('updatedAt', '<', admin.firestore.Timestamp.fromDate(twoHoursAgo))
            .get();
        for (const doc of paymentPendingOrders.docs) {
            // Auto-cancel orders with payment pending for more than 2 hours
            await transitionOrderStatus(doc.id, 'cancelled', 'Payment timeout - order auto-cancelled', true);
        }
    }
    catch (error) {
        console.error('Error processing payment pending orders:', error);
    }
}
/**
 * Process paid orders
 */
async function processPaidOrders() {
    try {
        const paidOrders = await db
            .collection('orders')
            .where('status', '==', 'paid')
            .get();
        for (const doc of paidOrders.docs) {
            const orderData = doc.data();
            // Automatically move to processing
            await transitionOrderStatus(doc.id, 'processing', 'Payment confirmed - moving to processing', true);
            // Reserve inventory
            await reserveOrderInventory(doc.id, orderData);
            // Notify store owner
            await notifyStoreOwner(doc.id, orderData, 'New paid order ready for processing');
        }
    }
    catch (error) {
        console.error('Error processing paid orders:', error);
    }
}
/**
 * Process orders in processing status
 */
async function processProcessingOrders() {
    var _a;
    try {
        const processingOrders = await db
            .collection('orders')
            .where('status', '==', 'processing')
            .get();
        for (const doc of processingOrders.docs) {
            const orderData = doc.data();
            const processingStartTime = ((_a = orderData.processingStartedAt) === null || _a === void 0 ? void 0 : _a.toDate()) || orderData.updatedAt.toDate();
            const avgProcessingTime = await getStoreAverageProcessingTime(orderData.storeId);
            const processingDuration = Date.now() - processingStartTime.getTime();
            const avgProcessingTimeMs = avgProcessingTime * 60 * 1000; // Convert to milliseconds
            if (processingDuration > avgProcessingTimeMs) {
                await transitionOrderStatus(doc.id, 'readyForPickup', 'Auto-transition based on processing time', true);
            }
        }
    }
    catch (error) {
        console.error('Error processing orders in processing status:', error);
    }
}
/**
 * Process delivery-related orders
 */
async function processDeliveryOrders() {
    try {
        // Handle ready for pickup orders
        const readyOrders = await db
            .collection('orders')
            .where('status', '==', 'readyForPickup')
            .get();
        for (const doc of readyOrders.docs) {
            const orderData = doc.data();
            if (orderData.deliveryAddress && Object.keys(orderData.deliveryAddress).length > 0) {
                await requestDelivery(doc.id, orderData);
            }
            else {
                await notifyCustomer(doc.id, orderData, 'Your order is ready for pickup');
            }
        }
        // Handle delivery requested orders
        const thirtyMinutesAgo = new Date(Date.now() - 30 * 60 * 1000);
        const deliveryRequestedOrders = await db
            .collection('orders')
            .where('status', '==', 'deliveryRequested')
            .where('deliveryRequestedAt', '<', admin.firestore.Timestamp.fromDate(thirtyMinutesAgo))
            .get();
        for (const doc of deliveryRequestedOrders.docs) {
            await checkDeliveryStatus(doc.id, doc.data());
        }
        // Handle driver assigned orders
        const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
        const driverAssignedOrders = await db
            .collection('orders')
            .where('status', '==', 'driverAssigned')
            .where('driverAssignedAt', '<', admin.firestore.Timestamp.fromDate(oneHourAgo))
            .get();
        for (const doc of driverAssignedOrders.docs) {
            await escalateDeliveryIssue(doc.id, doc.data(), 'Driver pickup delay');
        }
        // Auto-transition picked up orders to in transit
        const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
        const pickedUpOrders = await db
            .collection('orders')
            .where('status', '==', 'pickedUp')
            .where('pickedUpAt', '<', admin.firestore.Timestamp.fromDate(fiveMinutesAgo))
            .get();
        for (const doc of pickedUpOrders.docs) {
            await transitionOrderStatus(doc.id, 'inTransit', 'Order picked up - now in transit', true);
        }
    }
    catch (error) {
        console.error('Error processing delivery orders:', error);
    }
}
/**
 * Check for stuck orders and escalate
 */
async function checkStuckOrders() {
    try {
        const sixHoursAgo = new Date(Date.now() - 6 * 60 * 60 * 1000);
        const stuckOrders = await db
            .collection('orders')
            .where('updatedAt', '<', admin.firestore.Timestamp.fromDate(sixHoursAgo))
            .where('status', 'in', ['processing', 'deliveryRequested', 'driverAssigned', 'inTransit'])
            .get();
        for (const doc of stuckOrders.docs) {
            const orderData = doc.data();
            await escalateDeliveryIssue(doc.id, orderData, `Order stuck in ${orderData.status} state`);
        }
    }
    catch (error) {
        console.error('Error checking stuck orders:', error);
    }
}
/**
 * Transition order status with proper logging
 */
async function transitionOrderStatus(orderId, newStatus, reason, automated, userId) {
    try {
        const updateData = {
            status: newStatus,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            lastTransition: {
                status: newStatus,
                reason,
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                automated,
                userId,
            },
        };
        // Add status-specific timestamps
        switch (newStatus) {
            case 'paid':
                updateData.paidAt = admin.firestore.FieldValue.serverTimestamp();
                break;
            case 'processing':
                updateData.processingStartedAt = admin.firestore.FieldValue.serverTimestamp();
                break;
            case 'readyForPickup':
                updateData.readyAt = admin.firestore.FieldValue.serverTimestamp();
                break;
            case 'deliveryRequested':
                updateData.deliveryRequestedAt = admin.firestore.FieldValue.serverTimestamp();
                break;
            case 'driverAssigned':
                updateData.driverAssignedAt = admin.firestore.FieldValue.serverTimestamp();
                break;
            case 'pickedUp':
                updateData.pickedUpAt = admin.firestore.FieldValue.serverTimestamp();
                break;
            case 'inTransit':
                updateData.inTransitAt = admin.firestore.FieldValue.serverTimestamp();
                break;
            case 'outForDelivery':
                updateData.outForDeliveryAt = admin.firestore.FieldValue.serverTimestamp();
                break;
            case 'delivered':
                updateData.deliveredAt = admin.firestore.FieldValue.serverTimestamp();
                break;
            case 'completed':
                updateData.completedAt = admin.firestore.FieldValue.serverTimestamp();
                break;
            case 'cancelled':
                updateData.cancelledAt = admin.firestore.FieldValue.serverTimestamp();
                break;
        }
        await db.collection('orders').doc(orderId).update(updateData);
        console.log(`Order ${orderId} transitioned to ${newStatus}: ${reason}`);
    }
    catch (error) {
        console.error(`Error transitioning order ${orderId} to ${newStatus}:`, error);
    }
}
/**
 * Log status transition for audit trail
 */
async function logStatusTransition(transition) {
    try {
        await db.collection('order_transitions').add(transition);
    }
    catch (error) {
        console.error('Error logging status transition:', error);
    }
}
/**
 * Handle status-specific actions
 */
async function handleStatusSpecificActions(orderId, orderData) {
    switch (orderData.status) {
        case 'delivered':
            await scheduleCompletionCheck(orderId);
            break;
        case 'cancelled':
            await releaseOrderInventory(orderId, orderData);
            break;
    }
}
/**
 * Schedule order completion check
 */
async function scheduleCompletionCheck(orderId) {
    try {
        // Schedule completion check for 24 hours later
        const completionTime = new Date(Date.now() + 24 * 60 * 60 * 1000);
        await db.collection('scheduled_tasks').add({
            type: 'complete_order',
            orderId,
            scheduledFor: admin.firestore.Timestamp.fromDate(completionTime),
            status: 'pending',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    catch (error) {
        console.error(`Error scheduling completion check for order ${orderId}:`, error);
    }
}
/**
 * Process scheduled tasks
 */
exports.processScheduledTasks = functions.pubsub
    .schedule('every 1 hours')
    .timeZone('Asia/Ulaanbaatar')
    .onRun(async (context) => {
    try {
        const now = admin.firestore.Timestamp.now();
        const dueTasks = await db
            .collection('scheduled_tasks')
            .where('status', '==', 'pending')
            .where('scheduledFor', '<=', now)
            .get();
        for (const doc of dueTasks.docs) {
            const task = doc.data();
            try {
                switch (task.type) {
                    case 'complete_order':
                        await processOrderCompletion(task.orderId);
                        break;
                }
                // Mark task as completed
                await doc.ref.update({
                    status: 'completed',
                    completedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            }
            catch (error) {
                console.error(`Error processing task ${doc.id}:`, error);
                await doc.ref.update({
                    status: 'failed',
                    error: String(error),
                    failedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            }
        }
    }
    catch (error) {
        console.error('Error processing scheduled tasks:', error);
    }
});
/**
 * Process order completion
 */
async function processOrderCompletion(orderId) {
    try {
        const orderDoc = await db.collection('orders').doc(orderId).get();
        if (orderDoc.exists) {
            const orderData = orderDoc.data();
            if (orderData.status === 'delivered') {
                await transitionOrderStatus(orderId, 'completed', 'Auto-completed after 24 hours', true);
            }
        }
    }
    catch (error) {
        console.error(`Error completing order ${orderId}:`, error);
    }
}
/**
 * Check payment status with payment provider
 */
async function checkPaymentStatus(orderId, orderData) {
    try {
        const paymentIntentId = orderData.paymentIntentId;
        if (paymentIntentId) {
            // TODO: Integrate with actual payment provider API
            const isPaymentConfirmed = await simulatePaymentCheck(paymentIntentId);
            if (isPaymentConfirmed) {
                await transitionOrderStatus(orderId, 'paid', 'Payment confirmed by provider', true);
            }
            else {
                await transitionOrderStatus(orderId, 'paymentFailed', 'Payment failed or declined', true);
            }
        }
    }
    catch (error) {
        console.error(`Error checking payment status for order ${orderId}:`, error);
    }
}
/**
 * Simulate payment check (replace with actual payment provider integration)
 */
async function simulatePaymentCheck(paymentIntentId) {
    // Simulate API call delay
    await new Promise(resolve => setTimeout(resolve, 1000));
    // Simulate 90% success rate
    return Date.now() % 10 !== 0;
}
/**
 * Reserve inventory for order
 */
async function reserveOrderInventory(orderId, orderData) {
    try {
        const items = orderData.items || [];
        await db.runTransaction(async (transaction) => {
            var _a;
            for (const item of items) {
                const productId = item.productId;
                const quantity = item.quantity || 1;
                const selectedVariants = item.selectedVariants;
                if (productId) {
                    const productRef = db.collection('products').doc(productId);
                    const productSnap = await transaction.get(productRef);
                    if (productSnap.exists) {
                        const product = productSnap.data();
                        if (selectedVariants && Object.keys(selectedVariants).length > 0) {
                            // Handle variant inventory
                            const variants = product.variants || [];
                            const updatedVariants = [...variants];
                            for (const variant of updatedVariants) {
                                const selectedOption = selectedVariants[variant.name];
                                if (selectedOption && variant.trackInventory) {
                                    const currentStock = ((_a = variant.stockByOption) === null || _a === void 0 ? void 0 : _a[selectedOption]) || 0;
                                    const newStock = Math.max(0, currentStock - quantity);
                                    if (!variant.stockByOption)
                                        variant.stockByOption = {};
                                    variant.stockByOption[selectedOption] = newStock;
                                }
                            }
                            transaction.update(productRef, {
                                variants: updatedVariants,
                                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                            });
                        }
                        else {
                            // Handle simple product inventory
                            const currentStock = product.stock || 0;
                            const newStock = Math.max(0, currentStock - quantity);
                            transaction.update(productRef, {
                                stock: newStock,
                                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                            });
                        }
                    }
                }
            }
        });
        console.log(`Reserved inventory for order ${orderId}`);
    }
    catch (error) {
        console.error(`Error reserving inventory for order ${orderId}:`, error);
    }
}
/**
 * Release inventory for cancelled order
 */
async function releaseOrderInventory(orderId, orderData) {
    try {
        const items = orderData.items || [];
        await db.runTransaction(async (transaction) => {
            var _a;
            for (const item of items) {
                const productId = item.productId;
                const quantity = item.quantity || 1;
                const selectedVariants = item.selectedVariants;
                if (productId) {
                    const productRef = db.collection('products').doc(productId);
                    const productSnap = await transaction.get(productRef);
                    if (productSnap.exists) {
                        const product = productSnap.data();
                        if (selectedVariants && Object.keys(selectedVariants).length > 0) {
                            // Handle variant inventory
                            const variants = product.variants || [];
                            const updatedVariants = [...variants];
                            for (const variant of updatedVariants) {
                                const selectedOption = selectedVariants[variant.name];
                                if (selectedOption && variant.trackInventory) {
                                    const currentStock = ((_a = variant.stockByOption) === null || _a === void 0 ? void 0 : _a[selectedOption]) || 0;
                                    if (!variant.stockByOption)
                                        variant.stockByOption = {};
                                    variant.stockByOption[selectedOption] = currentStock + quantity;
                                }
                            }
                            transaction.update(productRef, {
                                variants: updatedVariants,
                                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                            });
                        }
                        else {
                            // Handle simple product inventory
                            const currentStock = product.stock || 0;
                            transaction.update(productRef, {
                                stock: currentStock + quantity,
                                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                            });
                        }
                    }
                }
            }
        });
        console.log(`Released inventory for cancelled order ${orderId}`);
    }
    catch (error) {
        console.error(`Error releasing inventory for order ${orderId}:`, error);
    }
}
/**
 * Request delivery from provider
 */
async function requestDelivery(orderId, orderData) {
    try {
        await transitionOrderStatus(orderId, 'deliveryRequested', 'Delivery automatically requested', true);
        // TODO: Integrate with actual delivery provider API
        console.log(`Delivery requested for order ${orderId}`);
    }
    catch (error) {
        console.error(`Error requesting delivery for order ${orderId}:`, error);
    }
}
/**
 * Check delivery status with provider
 */
async function checkDeliveryStatus(orderId, orderData) {
    try {
        const trackingId = orderData.deliveryTrackingId;
        if (trackingId) {
            // TODO: Check with delivery provider API
            console.log(`Checking delivery status for order ${orderId} with tracking ${trackingId}`);
        }
    }
    catch (error) {
        console.error(`Error checking delivery status for order ${orderId}:`, error);
    }
}
/**
 * Escalate delivery issues
 */
async function escalateDeliveryIssue(orderId, orderData, issue) {
    try {
        await db.collection('delivery_escalations').add({
            orderId,
            issue,
            orderData,
            escalatedAt: admin.firestore.FieldValue.serverTimestamp(),
            status: 'open',
        });
        // Notify support team
        await notifySupport(orderId, issue);
        console.log(`Escalated delivery issue for order ${orderId}: ${issue}`);
    }
    catch (error) {
        console.error(`Error escalating delivery issue for order ${orderId}:`, error);
    }
}
/**
 * Get store's average processing time
 */
async function getStoreAverageProcessingTime(storeId) {
    var _a, _b;
    try {
        const recentOrders = await db
            .collection('orders')
            .where('storeId', '==', storeId)
            .where('status', '==', 'completed')
            .orderBy('completedAt', 'desc')
            .limit(10)
            .get();
        if (recentOrders.empty)
            return 30; // Default 30 minutes
        let totalProcessingTime = 0;
        let validOrders = 0;
        for (const doc of recentOrders.docs) {
            const data = doc.data();
            const paidAt = (_a = data.paidAt) === null || _a === void 0 ? void 0 : _a.toDate();
            const readyAt = (_b = data.readyAt) === null || _b === void 0 ? void 0 : _b.toDate();
            if (paidAt && readyAt) {
                totalProcessingTime += (readyAt.getTime() - paidAt.getTime()) / (1000 * 60); // Convert to minutes
                validOrders++;
            }
        }
        return validOrders > 0 ? Math.round(totalProcessingTime / validOrders) : 30;
    }
    catch (error) {
        console.error(`Error calculating average processing time for store ${storeId}:`, error);
        return 30;
    }
}
/**
 * Send status update notifications
 */
async function sendStatusUpdateNotifications(orderId, orderData) {
    try {
        switch (orderData.status) {
            case 'paid':
                await sendOrderConfirmationNotification(orderId, orderData);
                break;
            case 'processing':
                await sendProcessingNotification(orderId, orderData);
                break;
            case 'readyForPickup':
                await sendReadyNotification(orderId, orderData);
                break;
            case 'inTransit':
                await sendInTransitNotification(orderId, orderData);
                break;
            case 'delivered':
                await sendDeliveredNotification(orderId, orderData);
                break;
            case 'cancelled':
                await sendCancellationNotification(orderId, orderData);
                break;
        }
    }
    catch (error) {
        console.error(`Error sending notifications for order ${orderId}:`, error);
    }
}
/**
 * Send various notification types
 */
async function sendOrderConfirmationNotification(orderId, orderData) {
    console.log(`Sending order confirmation for ${orderId}`);
    // TODO: Implement actual notification sending
}
async function sendProcessingNotification(orderId, orderData) {
    console.log(`Sending processing notification for ${orderId}`);
}
async function sendReadyNotification(orderId, orderData) {
    console.log(`Sending ready notification for ${orderId}`);
}
async function sendInTransitNotification(orderId, orderData) {
    console.log(`Sending in transit notification for ${orderId}`);
}
async function sendDeliveredNotification(orderId, orderData) {
    console.log(`Sending delivered notification for ${orderId}`);
}
async function sendCancellationNotification(orderId, orderData) {
    console.log(`Sending cancellation notification for ${orderId}`);
}
async function notifyStoreOwner(orderId, orderData, message) {
    console.log(`Notifying store owner for order ${orderId}: ${message}`);
}
async function notifyCustomer(orderId, orderData, message) {
    console.log(`Notifying customer for order ${orderId}: ${message}`);
}
async function notifySupport(orderId, issue) {
    console.log(`Notifying support for order ${orderId}: ${issue}`);
}
/**
 * Update order analytics
 */
async function updateOrderAnalytics(orderId, orderData) {
    var _a;
    try {
        const analyticsData = {
            orderId,
            storeId: orderData.storeId,
            status: orderData.status,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            total: orderData.total,
            itemCount: ((_a = orderData.items) === null || _a === void 0 ? void 0 : _a.length) || 0,
        };
        await db.collection('order_analytics').add(analyticsData);
    }
    catch (error) {
        console.error(`Error updating analytics for order ${orderId}:`, error);
    }
}
/**
 * Manual order status update endpoint
 */
exports.updateOrderStatus = functions.https.onCall(async (data, context) => {
    var _a;
    // Verify user is authenticated
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const { orderId, newStatus, reason } = data;
    if (!orderId || !newStatus) {
        throw new functions.https.HttpsError('invalid-argument', 'Order ID and new status are required');
    }
    try {
        // Verify user has permission to update this order
        const orderDoc = await db.collection('orders').doc(orderId).get();
        if (!orderDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'Order not found');
        }
        const orderData = orderDoc.data();
        // Check if user owns the store or is the customer
        if (orderData.storeId) {
            const storeDoc = await db.collection('stores').doc(orderData.storeId).get();
            const isStoreOwner = storeDoc.exists && ((_a = storeDoc.data()) === null || _a === void 0 ? void 0 : _a.ownerId) === context.auth.uid;
            const isCustomer = orderData.userId === context.auth.uid;
            if (!isStoreOwner && !isCustomer) {
                throw new functions.https.HttpsError('permission-denied', 'Not authorized to update this order');
            }
        }
        // Update the order status
        await transitionOrderStatus(orderId, newStatus, reason || 'Manual update', false, context.auth.uid);
        return {
            success: true,
            message: 'Order status updated successfully',
        };
    }
    catch (error) {
        console.error('Error updating order status:', error);
        throw new functions.https.HttpsError('internal', 'Failed to update order status');
    }
});
/**
 * Get order fulfillment metrics
 */
exports.getOrderFulfillmentMetrics = functions.https.onCall(async (data, context) => {
    var _a, _b, _c, _d, _e;
    // Verify user is authenticated
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const { storeId, startDate, endDate } = data;
    try {
        const start = startDate ? admin.firestore.Timestamp.fromDate(new Date(startDate)) :
            admin.firestore.Timestamp.fromDate(new Date(Date.now() - 30 * 24 * 60 * 60 * 1000));
        const end = endDate ? admin.firestore.Timestamp.fromDate(new Date(endDate)) :
            admin.firestore.Timestamp.now();
        let query = db.collection('orders')
            .where('createdAt', '>=', start)
            .where('createdAt', '<=', end);
        if (storeId) {
            // Verify user owns the store
            const storeDoc = await db.collection('stores').doc(storeId).get();
            if (!storeDoc.exists || ((_a = storeDoc.data()) === null || _a === void 0 ? void 0 : _a.ownerId) !== context.auth.uid) {
                throw new functions.https.HttpsError('permission-denied', 'Not authorized to access this store');
            }
            query = query.where('storeId', '==', storeId);
        }
        const orders = await query.get();
        const metrics = {
            totalOrders: orders.size,
            completedOrders: 0,
            cancelledOrders: 0,
            averageProcessingTime: 0,
            averageDeliveryTime: 0,
            onTimeDeliveryRate: 0,
            statusBreakdown: {},
        };
        let totalProcessingTime = 0;
        let totalDeliveryTime = 0;
        let onTimeDeliveries = 0;
        let validProcessingOrders = 0;
        let validDeliveryOrders = 0;
        for (const doc of orders.docs) {
            const data = doc.data();
            const status = data.status || 'pending';
            metrics.statusBreakdown[status] = (metrics.statusBreakdown[status] || 0) + 1;
            if (status === 'completed') {
                metrics.completedOrders++;
            }
            else if (status === 'cancelled') {
                metrics.cancelledOrders++;
            }
            // Calculate processing time
            const paidAt = (_b = data.paidAt) === null || _b === void 0 ? void 0 : _b.toDate();
            const readyAt = (_c = data.readyAt) === null || _c === void 0 ? void 0 : _c.toDate();
            if (paidAt && readyAt) {
                totalProcessingTime += (readyAt.getTime() - paidAt.getTime()) / (1000 * 60);
                validProcessingOrders++;
            }
            // Calculate delivery time
            const deliveryRequestedAt = (_d = data.deliveryRequestedAt) === null || _d === void 0 ? void 0 : _d.toDate();
            const deliveredAt = (_e = data.deliveredAt) === null || _e === void 0 ? void 0 : _e.toDate();
            if (deliveryRequestedAt && deliveredAt) {
                const deliveryTime = (deliveredAt.getTime() - deliveryRequestedAt.getTime()) / (1000 * 60);
                totalDeliveryTime += deliveryTime;
                validDeliveryOrders++;
                // Check if delivery was on time (within 60 minutes)
                if (deliveryTime <= 60) {
                    onTimeDeliveries++;
                }
            }
        }
        if (validProcessingOrders > 0) {
            metrics.averageProcessingTime = totalProcessingTime / validProcessingOrders;
        }
        if (validDeliveryOrders > 0) {
            metrics.averageDeliveryTime = totalDeliveryTime / validDeliveryOrders;
            metrics.onTimeDeliveryRate = (onTimeDeliveries / validDeliveryOrders) * 100;
        }
        return {
            success: true,
            metrics,
        };
    }
    catch (error) {
        console.error('Error getting fulfillment metrics:', error);
        throw new functions.https.HttpsError('internal', 'Failed to get fulfillment metrics');
    }
});
//# sourceMappingURL=order-fulfillment-automation.js.map