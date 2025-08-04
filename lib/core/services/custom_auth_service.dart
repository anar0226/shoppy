import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../config/auth_action_config.dart';

/// Custom authentication service that uses custom action URLs
class CustomAuthService {
  static final CustomAuthService _instance = CustomAuthService._internal();
  factory CustomAuthService() => _instance;
  CustomAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Send email verification with custom action URL
  Future<void> sendEmailVerification({
    String? continueUrl,
    String? lang,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      if (user.emailVerified) {
        return; // Already verified
      }

      // For web, we need to handle this differently since Firebase doesn't support
      // custom action URLs directly. We'll use a custom implementation.
      if (kIsWeb) {
        await _sendCustomEmailVerification(user, continueUrl, lang);
      } else {
        // For mobile, use the standard Firebase method
        await user.sendEmailVerification(
          ActionCodeSettings(
            url: continueUrl ?? AuthActionConfig.actionUrl,
            handleCodeInApp: true,
            iOSBundleId: 'com.avii.marketplace',
            androidPackageName: 'com.avii.marketplace',
            androidInstallApp: true,
            androidMinimumVersion: '12',
          ),
        );
      }
    } catch (e) {
      throw Exception('Failed to send email verification: $e');
    }
  }

  /// Send password reset email with custom action URL
  Future<void> sendPasswordResetEmail(
    String email, {
    String? continueUrl,
    String? lang,
  }) async {
    try {
      if (kIsWeb) {
        await _sendCustomPasswordResetEmail(email, continueUrl, lang);
      } else {
        // For mobile, use the standard Firebase method
        await _auth.sendPasswordResetEmail(
          email: email,
          actionCodeSettings: ActionCodeSettings(
            url: continueUrl ?? AuthActionConfig.actionUrl,
            handleCodeInApp: true,
            iOSBundleId: 'com.avii.marketplace',
            androidPackageName: 'com.avii.marketplace',
            androidInstallApp: true,
            androidMinimumVersion: '12',
          ),
        );
      }
    } catch (e) {
      throw Exception('Failed to send password reset email: $e');
    }
  }

  /// Handle custom auth action URL
  Future<void> handleCustomAuthAction(String url) async {
    if (!AuthActionConfig.isCustomAuthActionUrl(url)) {
      throw Exception('Invalid auth action URL');
    }

    final params = AuthActionConfig.extractParamsFromUrl(url);
    final mode = params['mode'];
    final oobCode = params['oobCode'];

    if (mode == null || oobCode == null) {
      throw Exception('Missing required parameters');
    }

    switch (mode) {
      case 'verifyEmail':
        await _verifyEmail(oobCode);
        break;
      case 'resetPassword':
        await _confirmPasswordReset(oobCode);
        break;
      case 'recoverEmail':
        await _recoverEmail(oobCode);
        break;
      default:
        throw Exception('Unknown action mode: $mode');
    }
  }

  /// Custom email verification implementation for web
  Future<void> _sendCustomEmailVerification(
    User user,
    String? continueUrl,
    String? lang,
  ) async {
    // This would typically involve calling a Cloud Function
    // that generates the verification link with your custom domain
    // For now, we'll use the standard method but with custom action URL
    await user.sendEmailVerification(
      ActionCodeSettings(
        url: continueUrl ?? AuthActionConfig.actionUrl,
        handleCodeInApp: true,
      ),
    );
  }

  /// Custom password reset implementation for web
  Future<void> _sendCustomPasswordResetEmail(
    String email,
    String? continueUrl,
    String? lang,
  ) async {
    // This would typically involve calling a Cloud Function
    // that generates the reset link with your custom domain
    await _auth.sendPasswordResetEmail(
      email: email,
      actionCodeSettings: ActionCodeSettings(
        url: continueUrl ?? AuthActionConfig.actionUrl,
        handleCodeInApp: true,
      ),
    );
  }

  /// Verify email with action code
  Future<void> _verifyEmail(String actionCode) async {
    try {
      await _auth.applyActionCode(actionCode);
    } catch (e) {
      throw Exception('Failed to verify email: $e');
    }
  }

  /// Confirm password reset with action code
  Future<void> _confirmPasswordReset(String actionCode) async {
    try {
      await _auth.verifyPasswordResetCode(actionCode);
    } catch (e) {
      throw Exception('Failed to confirm password reset: $e');
    }
  }

  /// Recover email with action code
  Future<void> _recoverEmail(String actionCode) async {
    try {
      await _auth.checkActionCode(actionCode);
    } catch (e) {
      throw Exception('Failed to recover email: $e');
    }
  }
}
