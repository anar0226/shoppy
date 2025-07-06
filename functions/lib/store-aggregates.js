"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.updateStoreProductPreview = exports.updateStoreRatings = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
// Ensure Firebase app is initialized elsewhere (index.ts does it)
const db = admin.firestore();
/**
 * Trigger: When a review is created, updated, or deleted under /stores/{storeId}/reviews/{reviewId}
 * Action: Recalculate ratingAvg and reviewCount on the parent store document.
 * Safety: Reads only active reviews (status == 'active'). Falls back gracefully if no reviews.
 */
exports.updateStoreRatings = functions.firestore
    .document('stores/{storeId}/reviews/{reviewId}')
    .onWrite(async (change, context) => {
    const { storeId } = context.params;
    try {
        // Query active reviews (status == 'active') for the store
        const reviewsSnap = await db
            .collection('stores')
            .doc(storeId)
            .collection('reviews')
            .where('status', '==', 'active')
            .get();
        if (reviewsSnap.empty) {
            // No active reviews – reset fields
            await db
                .collection('stores')
                .doc(storeId)
                .update({ ratingAvg: 0, reviewCount: 0 });
            return;
        }
        // Compute average rating
        let total = 0;
        reviewsSnap.docs.forEach((doc) => {
            const rating = doc.data().rating || 0;
            total += rating;
        });
        const reviewCount = reviewsSnap.size;
        const ratingAvg = parseFloat((total / reviewCount).toFixed(2));
        await db.collection('stores').doc(storeId).update({ ratingAvg, reviewCount });
    }
    catch (err) {
        console.error('Error updating store rating aggregates:', err);
    }
});
/**
 * Trigger: When a product is created, updated, or deleted.
 * Action: Maintain a productPreview (first 4 product image URLs) on its parent store doc.
 */
exports.updateStoreProductPreview = functions.firestore
    .document('products/{productId}')
    .onWrite(async (change, context) => {
    const afterData = change.after.exists ? change.after.data() : null;
    const beforeData = change.before.exists ? change.before.data() : null;
    // Determine storeId (prefer after, else before)
    const storeId = (afterData === null || afterData === void 0 ? void 0 : afterData.storeId) || (afterData === null || afterData === void 0 ? void 0 : afterData.StoreId) || (beforeData === null || beforeData === void 0 ? void 0 : beforeData.storeId) || (beforeData === null || beforeData === void 0 ? void 0 : beforeData.StoreId);
    if (!storeId) {
        console.warn('Product write without storeId — skipping preview update');
        return;
    }
    try {
        // Fetch up to 4 of the newest active products for the store
        const prodsSnap = await db
            .collection('products')
            .where('storeId', '==', storeId)
            .orderBy('createdAt', 'desc')
            .limit(4)
            .get();
        const previewImages = [];
        prodsSnap.docs.forEach((doc) => {
            const images = doc.data().images;
            if (images && images.length > 0) {
                previewImages.push(images[0]);
            }
        });
        await db.collection('stores').doc(storeId).update({ productPreview: previewImages });
    }
    catch (err) {
        console.error('Error updating store productPreview aggregate:', err);
    }
});
//# sourceMappingURL=store-aggregates.js.map