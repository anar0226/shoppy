import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'rate_limiter_service.dart';

/// Comprehensive authentication security service
/// Handles email verification enforcement, enhanced rate limiting, and security validation
class AuthSecurityService {
  static final AuthSecurityService _instance = AuthSecurityService._internal();
  factory AuthSecurityService() => _instance;
  AuthSecurityService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RateLimiterService _rateLimiter = RateLimiterService();

  // Session management
  Timer? _sessionTimer;
  static const Duration _sessionTimeout = Duration(minutes: 30);
  static const int _maxFailedAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 15);

  /// Enhanced authentication check with security validation
  Future<AuthSecurityResult> validateUserSecurity({
    required String operation,
    bool requireEmailVerification = true,
    bool requireActiveAccount = true,
    bool checkAccountLockout = true,
    bool requireAuthentication = true,
  }) async {
    try {
      // 1. Check if user is authenticated (skip for auth operations)
      final user = _auth.currentUser;
      if (requireAuthentication && user == null) {
        return AuthSecurityResult.failure(
          code: AuthSecurityCode.notAuthenticated,
          message: 'Эхлээд нэвтэрнэ үү',
        );
      }

      // 2. Check rate limiting
      if (!_rateLimiter.isAllowed(operation)) {
        return AuthSecurityResult.failure(
          code: AuthSecurityCode.rateLimitExceeded,
          message:
              'Хэт олон оролдлого хийлээ. Түр хүлээгээд дахин оролдоно уу.',
        );
      }

      // 3. Check account lockout status (only if user exists)
      if (checkAccountLockout && user != null) {
        final lockoutResult = await _checkAccountLockout(user.uid);
        if (!lockoutResult.success) {
          return lockoutResult;
        }
      }

      // 4. Check email verification (only if user exists)
      if (requireEmailVerification && user != null) {
        // Force refresh verification status
        await user.reload();
        final refreshedUser = _auth.currentUser;

        if (refreshedUser?.emailVerified != true) {
          return AuthSecurityResult.failure(
            code: AuthSecurityCode.emailNotVerified,
            message: 'Имэйл хаягаа баталгаажуулаад дахин оролдоно уу',
            action: AuthSecurityAction.sendEmailVerification,
          );
        }
      }

      // 5. Check account status in Firestore (only if user exists)
      if (requireActiveAccount && user != null) {
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final isActive = userData['isActive'] ?? true;
          final isBlocked = userData['isBlocked'] ?? false;

          if (!isActive || isBlocked) {
            return AuthSecurityResult.failure(
              code: AuthSecurityCode.accountDisabled,
              message:
                  'Таны бүртгэл идэвхгүй болжээ. Тусламж авахын тулд холбогдоно уу.',
            );
          }
        }
      }

      // 6. Update last activity (only if user exists)
      if (user != null) {
        await _updateLastActivity(user.uid);
      }

      // 7. Record successful operation
      _rateLimiter.recordSuccess(operation);

      return AuthSecurityResult.success();
    } catch (e) {
      debugPrint('Error in validateUserSecurity: $e');
      return AuthSecurityResult.failure(
        code: AuthSecurityCode.systemError,
        message: 'Системийн алдаа гарлаа. Дахин оролдоно уу.',
      );
    }
  }

  /// Check account lockout status
  Future<AuthSecurityResult> _checkAccountLockout(String userId) async {
    try {
      final lockoutDoc =
          await _firestore.collection('account_security').doc(userId).get();

      if (lockoutDoc.exists) {
        final data = lockoutDoc.data()!;
        final failedAttempts = data['failedAttempts'] ?? 0;
        final lockedUntil = data['lockedUntil'] as Timestamp?;

        // Check if account is currently locked
        if (lockedUntil != null &&
            lockedUntil.toDate().isAfter(DateTime.now())) {
          final remainingMinutes =
              lockedUntil.toDate().difference(DateTime.now()).inMinutes;
          return AuthSecurityResult.failure(
            code: AuthSecurityCode.accountLocked,
            message:
                'Бүртгэл түр хаагдсан байна. $remainingMinutes минутын дараа дахин оролдоно уу.',
          );
        }

        // Check if approaching lockout threshold
        if (failedAttempts >= _maxFailedAttempts - 1) {
          return AuthSecurityResult.warning(
            message:
                'Сүүлчийн оролдлого. Дараагийн алдаанд бүртгэл түр хаагдах болно.',
          );
        }
      }

      return AuthSecurityResult.success();
    } catch (e) {
      debugPrint('Error checking account lockout: $e');
      return AuthSecurityResult
          .success(); // Allow on error to avoid blocking legitimate users
    }
  }

  /// Record failed authentication attempt
  Future<void> recordFailedAttempt(String userId, String operation) async {
    try {
      final securityDoc = _firestore.collection('account_security').doc(userId);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(securityDoc);

        int failedAttempts = 1;
        if (doc.exists) {
          failedAttempts = (doc.data()!['failedAttempts'] ?? 0) + 1;
        }

        final updateData = <String, dynamic>{
          'failedAttempts': failedAttempts,
          'lastFailedAttempt': FieldValue.serverTimestamp(),
          'lastFailedOperation': operation,
        };

        // Lock account if threshold reached
        if (failedAttempts >= _maxFailedAttempts) {
          updateData['lockedUntil'] =
              Timestamp.fromDate(DateTime.now().add(_lockoutDuration));
          updateData['lockReason'] = 'Хэт олон оролдлого';
        }

        transaction.set(securityDoc, updateData, SetOptions(merge: true));
      });

      // Log security event
      await _logSecurityEvent(
        userId: userId,
        event: 'failed_attempt',
        operation: operation,
        metadata: {'failedAttempts': await _getFailedAttempts(userId)},
      );
    } catch (e) {
      debugPrint('Error recording failed attempt: $e');
    }
  }

  /// Clear failed attempts on successful authentication
  Future<void> clearFailedAttempts(String userId) async {
    try {
      await _firestore.collection('account_security').doc(userId).update({
        'failedAttempts': 0,
        'lockedUntil': FieldValue.delete(),
        'lastSuccessfulLogin': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error clearing failed attempts: $e');
    }
  }

  /// Get current failed attempts count
  Future<int> _getFailedAttempts(String userId) async {
    try {
      final doc =
          await _firestore.collection('account_security').doc(userId).get();
      if (doc.exists) {
        return doc.data()!['failedAttempts'] ?? 0;
      }
    } catch (e) {
      debugPrint('Error getting failed attempts: $e');
    }
    return 0;
  }

  /// Send email verification with enhanced security
  Future<AuthSecurityResult> sendEmailVerification({
    bool force = false,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthSecurityResult.failure(
          code: AuthSecurityCode.notAuthenticated,
          message: 'Нэвтэрч орно уу',
        );
      }

      // Check rate limiting
      if (!_rateLimiter.isAllowed('email_verification')) {
        return AuthSecurityResult.failure(
          code: AuthSecurityCode.rateLimitExceeded,
          message:
              'Хэт олон имэйл илгээлээ. 10 минутын дараа дахин оролдоно уу.',
        );
      }

      // Check if already verified
      if (user.emailVerified && !force) {
        return AuthSecurityResult.success(
            message: 'Имэйл аль хэдийн баталгаажсан байна');
      }

      // Send verification email
      await user.sendEmailVerification();

      // Record success
      _rateLimiter.recordSuccess('email_verification');

      // Log security event
      await _logSecurityEvent(
        userId: user.uid,
        event: 'email_verification_sent',
        operation: 'email_verification',
      );

      return AuthSecurityResult.success(
        message:
            'Баталгаажуулах имэйл илгээгдлээ. Имэйлээ шалгаад холбоос дээр дарна уу.',
      );
    } catch (e) {
      debugPrint('Error sending email verification: $e');
      return AuthSecurityResult.failure(
        code: AuthSecurityCode.systemError,
        message: 'Имэйл илгээхэд алдаа гарлаа: ${e.toString()}',
      );
    }
  }

  /// Enhanced password validation
  bool validatePasswordStrength(String password) {
    // Check minimum length
    if (password.length < 8) return false;

    // Check for at least one uppercase letter
    if (!RegExp(r'[A-Z]').hasMatch(password)) return false;

    // Check for at least one lowercase letter
    if (!RegExp(r'[a-z]').hasMatch(password)) return false;

    // Check for at least one digit
    if (!RegExp(r'[0-9]').hasMatch(password)) return false;

    // Check for at least one special character
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) return false;

    return true;
  }

  /// Get password strength score
  PasswordStrength getPasswordStrength(String password) {
    int score = 0;
    List<String> feedback = [];

    if (password.length >= 8) {
      score += 1;
    } else {
      feedback.add('Хамгийн багадаа 8 тэмдэгт');
    }

    if (RegExp(r'[A-Z]').hasMatch(password)) {
      score += 1;
    } else {
      feedback.add('Том үсэг оруулна уу');
    }

    if (RegExp(r'[a-z]').hasMatch(password)) {
      score += 1;
    } else {
      feedback.add('Жижиг үсэг оруулна уу');
    }

    if (RegExp(r'[0-9]').hasMatch(password)) {
      score += 1;
    } else {
      feedback.add('Тоо оруулна уу');
    }

    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      score += 1;
    } else {
      feedback.add('Тусгай тэмдэгт оруулна уу');
    }

    PasswordStrengthLevel level;
    if (score <= 2) {
      level = PasswordStrengthLevel.weak;
    } else if (score <= 3) {
      level = PasswordStrengthLevel.medium;
    } else if (score <= 4) {
      level = PasswordStrengthLevel.strong;
    } else {
      level = PasswordStrengthLevel.veryStrong;
    }

    return PasswordStrength(
      score: score,
      level: level,
      feedback: feedback,
    );
  }

  /// Start session management
  void startSession() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(_sessionTimeout, (_) {
      _handleSessionTimeout();
    });
  }

  /// Handle session timeout
  void _handleSessionTimeout() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _logSecurityEvent(
          userId: user.uid,
          event: 'session_timeout',
          operation: 'session_management',
        );
      }

      await _auth.signOut();
    } catch (e) {
      debugPrint('Error handling session timeout: $e');
    }
  }

  /// Update last activity timestamp
  Future<void> _updateLastActivity(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'lastActivity': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating last activity: $e');
    }
  }

  /// Log security events
  Future<void> _logSecurityEvent({
    required String userId,
    required String event,
    required String operation,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore.collection('security_logs').add({
        'userId': userId,
        'event': event,
        'operation': operation,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': metadata ?? {},
        'userAgent': 'Flutter App',
        'platform': defaultTargetPlatform.name,
      });
    } catch (e) {
      debugPrint('Error logging security event: $e');
    }
  }

  /// Clean up resources
  void dispose() {
    _sessionTimer?.cancel();
  }
}

/// Authentication security result
class AuthSecurityResult {
  final bool success;
  final AuthSecurityCode? code;
  final String? message;
  final AuthSecurityAction? action;
  final bool isWarning;

  AuthSecurityResult._({
    required this.success,
    this.code,
    this.message,
    this.action,
    this.isWarning = false,
  });

  factory AuthSecurityResult.success({String? message}) {
    return AuthSecurityResult._(
      success: true,
      message: message,
    );
  }

  factory AuthSecurityResult.failure({
    required AuthSecurityCode code,
    required String message,
    AuthSecurityAction? action,
  }) {
    return AuthSecurityResult._(
      success: false,
      code: code,
      message: message,
      action: action,
    );
  }

  factory AuthSecurityResult.warning({required String message}) {
    return AuthSecurityResult._(
      success: true,
      message: message,
      isWarning: true,
    );
  }
}

/// Authentication security codes
enum AuthSecurityCode {
  notAuthenticated,
  emailNotVerified,
  accountDisabled,
  accountLocked,
  rateLimitExceeded,
  systemError,
}

/// Security actions that can be taken
enum AuthSecurityAction {
  sendEmailVerification,
  contactSupport,
  waitAndRetry,
}

/// Password strength evaluation
class PasswordStrength {
  final int score;
  final PasswordStrengthLevel level;
  final List<String> feedback;

  PasswordStrength({
    required this.score,
    required this.level,
    required this.feedback,
  });
}

enum PasswordStrengthLevel {
  weak,
  medium,
  strong,
  veryStrong,
}
