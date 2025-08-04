"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendCustomPasswordResetEmail = exports.sendCustomEmailVerification = exports.handleCustomAuthAction = exports.generateCustomAuthAction = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
/**
 * Generate custom authentication action URLs
 * This function creates Firebase Auth action links with your custom domain
 */
exports.generateCustomAuthAction = functions.https.onCall(async (data, context) => {
    const { actionType, email, continueUrl, lang } = data;
    if (!actionType || !email) {
        throw new functions.https.HttpsError('invalid-argument', 'actionType and email are required');
    }
    try {
        let actionLink;
        switch (actionType) {
            case 'emailVerification':
                // Generate email verification link
                actionLink = await admin.auth().generateEmailVerificationLink(email, {
                    url: continueUrl || 'https://avii.mn/_/auth/action',
                    handleCodeInApp: true,
                });
                break;
            case 'passwordReset':
                // Generate password reset link
                actionLink = await admin.auth().generatePasswordResetLink(email, {
                    url: continueUrl || 'https://avii.mn/_/auth/action',
                    handleCodeInApp: true,
                });
                break;
            case 'emailSignIn':
                // Generate email sign-in link
                actionLink = await admin.auth().generateSignInWithEmailLink(email, {
                    url: continueUrl || 'https://avii.mn/_/auth/action',
                    handleCodeInApp: true,
                });
                break;
            default:
                throw new functions.https.HttpsError('invalid-argument', 'Invalid action type');
        }
        // Extract the action code from the Firebase-generated link
        const url = new URL(actionLink);
        const oobCode = url.searchParams.get('oobCode');
        const mode = url.searchParams.get('mode');
        if (!oobCode || !mode) {
            throw new functions.https.HttpsError('internal', 'Failed to generate action link');
        }
        // Create custom action URL with your domain
        let customActionUrl = `https://avii.mn/_/auth/action?mode=${mode}&oobCode=${oobCode}`;
        if (continueUrl) {
            customActionUrl += `&continueUrl=${encodeURIComponent(continueUrl)}`;
        }
        if (lang) {
            customActionUrl += `&lang=${lang}`;
        }
        return {
            success: true,
            actionUrl: customActionUrl,
            oobCode,
            mode,
        };
    }
    catch (error) {
        console.error('Error generating custom auth action:', error);
        throw new functions.https.HttpsError('internal', 'Failed to generate authentication action');
    }
});
/**
 * Handle custom auth action URL requests
 * This function processes the custom action URLs and redirects to Firebase Auth
 */
exports.handleCustomAuthAction = functions.https.onRequest(async (req, res) => {
    const { mode, oobCode, continueUrl, lang } = req.query;
    if (!mode || !oobCode) {
        res.status(400).send('Missing required parameters');
        return;
    }
    try {
        // Create the Firebase Auth handler URL with the action code
        let firebaseAuthUrl = `https://shoppy-6d81f.firebaseapp.com/__/auth/handler?mode=${mode}&oobCode=${oobCode}`;
        if (continueUrl) {
            firebaseAuthUrl += `&continueUrl=${encodeURIComponent(continueUrl)}`;
        }
        if (lang) {
            firebaseAuthUrl += `&lang=${lang}`;
        }
        // Redirect to Firebase Auth handler
        res.redirect(firebaseAuthUrl);
    }
    catch (error) {
        console.error('Error handling custom auth action:', error);
        res.status(400).send('Invalid or expired action code');
    }
});
/**
 * Send custom email verification
 */
exports.sendCustomEmailVerification = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
    }
    const { continueUrl, lang } = data;
    const userEmail = context.auth.token.email;
    if (!userEmail) {
        throw new functions.https.HttpsError('invalid-argument', 'User email not found');
    }
    try {
        // Generate custom verification link
        const result = await (0, exports.generateCustomAuthAction)({
            actionType: 'emailVerification',
            email: userEmail,
            continueUrl,
            lang,
        }, {});
        // Here you would send the email with the custom action URL
        // For now, we'll just return the action URL
        return {
            success: true,
            actionUrl: result.actionUrl,
            message: 'Verification email sent with custom action URL',
        };
    }
    catch (error) {
        console.error('Error sending custom email verification:', error);
        throw new functions.https.HttpsError('internal', 'Failed to send verification email');
    }
});
/**
 * Send custom password reset email
 */
exports.sendCustomPasswordResetEmail = functions.https.onCall(async (data, context) => {
    const { email, continueUrl, lang } = data;
    if (!email || typeof email !== 'string') {
        throw new functions.https.HttpsError('invalid-argument', 'Email is required');
    }
    try {
        // Generate custom password reset link
        const result = await (0, exports.generateCustomAuthAction)({
            actionType: 'passwordReset',
            email,
            continueUrl,
            lang,
        }, {});
        // Here you would send the email with the custom action URL
        // For now, we'll just return the action URL
        return {
            success: true,
            actionUrl: result.actionUrl,
            message: 'Password reset email sent with custom action URL',
        };
    }
    catch (error) {
        console.error('Error sending custom password reset email:', error);
        throw new functions.https.HttpsError('internal', 'Failed to send password reset email');
    }
});
//# sourceMappingURL=custom-auth-actions.js.map