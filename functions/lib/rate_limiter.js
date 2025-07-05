"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.enforceRateLimit = void 0;
const admin = require("firebase-admin");
const functions = require("firebase-functions");
/**
 * Enforces simple sliding-window rate limiting per key (user UID or IP).
 * If the limit is exceeded an https.HttpsError('resource-exhausted') is thrown.
 * Firestore document structure  (collection: rate_limits)
 * { count:number, windowStart:number (ms since epoch) }
 */
async function enforceRateLimit(key, limit = 60, windowSeconds = 60) {
    if (!key) {
        // if we cannot determine a key, we skip rate limit to avoid locking out all users.
        return;
    }
    const ref = admin.firestore().collection('rate_limits').doc(key);
    const now = Date.now();
    try {
        await admin.firestore().runTransaction(async (tx) => {
            const snap = await tx.get(ref);
            if (!snap.exists) {
                tx.set(ref, { count: 1, windowStart: now });
                return;
            }
            const data = snap.data();
            let { count, windowStart } = data;
            // if window expired, reset
            if (now - windowStart > windowSeconds * 1000) {
                count = 0;
                windowStart = now;
            }
            if (count >= limit) {
                throw new functions.https.HttpsError('resource-exhausted', 'Too many requests – please wait and try again.');
            }
            tx.set(ref, { count: count + 1, windowStart }, { merge: true });
        });
    }
    catch (e) {
        if (e instanceof functions.https.HttpsError) {
            throw e;
        }
        console.error('Rate limiter transaction error', e);
    }
}
exports.enforceRateLimit = enforceRateLimit;
//# sourceMappingURL=rate_limiter.js.map