"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createSuperAdminSimple = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const firestore = admin.firestore();
/**
 * Simplified super admin creation function with detailed error handling
 */
exports.createSuperAdminSimple = functions.https.onCall(async (data, context) => {
    try {
        console.log('Starting super admin creation with data:', { email: data === null || data === void 0 ? void 0 : data.email, name: data === null || data === void 0 ? void 0 : data.name });
        // Validate input
        if (!data || typeof data !== 'object') {
            console.error('Invalid data format:', data);
            throw new functions.https.HttpsError('invalid-argument', 'Invalid data format');
        }
        const { email, password, name } = data;
        if (!email || typeof email !== 'string') {
            console.error('Invalid email:', email);
            throw new functions.https.HttpsError('invalid-argument', 'Valid email is required');
        }
        if (!password || typeof password !== 'string' || password.length < 6) {
            console.error('Invalid password length');
            throw new functions.https.HttpsError('invalid-argument', 'Password must be at least 6 characters');
        }
        if (!name || typeof name !== 'string') {
            console.error('Invalid name:', name);
            throw new functions.https.HttpsError('invalid-argument', 'Valid name is required');
        }
        console.log('Input validation passed');
        // Check if user already exists
        try {
            const existingUser = await admin.auth().getUserByEmail(email);
            console.log('User already exists:', existingUser.uid);
            throw new functions.https.HttpsError('already-exists', 'User with this email already exists');
        }
        catch (error) {
            if (error.code !== 'auth/user-not-found') {
                console.error('Error checking existing user:', error);
                throw error;
            }
            console.log('User does not exist, proceeding with creation');
        }
        // Create user in Firebase Auth
        console.log('Creating Firebase Auth user...');
        const userRecord = await admin.auth().createUser({
            email: email,
            password: password,
            displayName: name,
        });
        console.log('Firebase Auth user created:', userRecord.uid);
        // Create super admin document
        console.log('Creating super admin document...');
        const adminDoc = {
            name: name,
            email: email,
            role: 'super_administrator',
            permissions: ['all'],
            isActive: true,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            createdBy: 'cloud_function',
        };
        await firestore.collection('super_admins').doc(userRecord.uid).set(adminDoc);
        console.log('Super admin document created');
        // Log the creation
        console.log('Creating activity log...');
        await firestore.collection('admin_activity_logs').add({
            adminId: userRecord.uid,
            action: 'super_admin_created',
            data: {
                email: email,
                name: name,
                method: 'cloud_function',
            },
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log('Activity log created');
        console.log('Super admin creation completed successfully');
        return {
            success: true,
            message: 'Super admin created successfully',
            adminId: userRecord.uid,
            email: email,
            name: name,
        };
    }
    catch (error) {
        console.error('Detailed error in createSuperAdminSimple:', {
            message: error.message,
            code: error.code,
            stack: error.stack,
            type: typeof error,
        });
        // Return specific error messages
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        if (error.code === 'auth/email-already-exists') {
            throw new functions.https.HttpsError('already-exists', 'User with this email already exists');
        }
        if (error.code === 'auth/invalid-email') {
            throw new functions.https.HttpsError('invalid-argument', 'Invalid email format');
        }
        if (error.code === 'auth/weak-password') {
            throw new functions.https.HttpsError('invalid-argument', 'Password is too weak');
        }
        // Generic error
        throw new functions.https.HttpsError('internal', `Failed to create super admin: ${error.message}`);
    }
});
//# sourceMappingURL=simple-admin-setup.js.map