"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.deactivateProductsOnStoreDelete = exports.normalizeProductData = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const db = admin.firestore();
/**
 * Product onWrite trigger to ensure consistent field names and references.
 * 1. Normalizes `StoreId`, `StoreID` → `storeId`
 * 2. Ensures referenced store exists; if not, marks product inactive.
 */
exports.normalizeProductData = functions.firestore
    .document('products/{productId}')
    .onWrite(async (change, context) => {
    const after = change.after.exists ? change.after.data() : null;
    if (!after)
        return;
    const updates = {};
    let needsUpdate = false;
    // Normalize storeId casing
    const legacyKeys = ['StoreId', 'StoreID', 'storeID'];
    for (const key of legacyKeys) {
        if (after[key] && !after.storeId) {
            updates['storeId'] = after[key];
            updates[key] = admin.firestore.FieldValue.delete();
            needsUpdate = true;
        }
    }
    // Ensure store exists
    if (after.storeId) {
        const storeSnap = await db.collection('stores').doc(after.storeId).get();
        if (!storeSnap.exists) {
            functions.logger.warn(`Product ${context.params.productId} references missing store ${after.storeId}`);
            updates['isActive'] = false;
            needsUpdate = true;
        }
    }
    if (needsUpdate) {
        await change.after.ref.update(updates);
    }
});
/**
 * Store onDelete trigger – automatically mark products inactive when a store is deleted.
 */
exports.deactivateProductsOnStoreDelete = functions.firestore
    .document('stores/{storeId}')
    .onDelete(async (snap, context) => {
    const batch = db.batch();
    const productsSnap = await db
        .collection('products')
        .where('storeId', '==', context.params.storeId)
        .get();
    productsSnap.docs.forEach((doc) => {
        batch.update(doc.ref, { isActive: false });
    });
    await batch.commit();
    functions.logger.log(`Deactivated ${productsSnap.size} products for deleted store ${context.params.storeId}`);
});
//# sourceMappingURL=data-consistency.js.map