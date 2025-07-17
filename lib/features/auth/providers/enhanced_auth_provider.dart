import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/services/auth_security_service.dart';

class EnhancedAuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AuthSecurityService _security = AuthSecurityService();

  User? get user => _auth.currentUser;
  bool _loading = false;
  bool get loading => _loading;

  // Phone verification state
  String? _verificationId;
  String? get verificationId => _verificationId;

  // Security state
  AuthSecurityResult? _lastSecurityCheck;
  AuthSecurityResult? get lastSecurityCheck => _lastSecurityCheck;

  @override
  void dispose() {
    _security.dispose();
    super.dispose();
  }

  Future<void> _setLoading(bool value) async {
    _loading = value;
    notifyListeners();
  }

  /// Enhanced security check before any critical operation
  Future<AuthSecurityResult> checkSecurity({
    required String operation,
    bool requireEmailVerification = true,
    bool requireActiveAccount = true,
  }) async {
    _lastSecurityCheck = await _security.validateUserSecurity(
      operation: operation,
      requireEmailVerification: requireEmailVerification,
      requireActiveAccount: requireActiveAccount,
    );

    notifyListeners();
    return _lastSecurityCheck!;
  }

  /// Enhanced sign in with comprehensive security
  Future<User?> signIn(String email, String password) async {
    try {
      await _setLoading(true);

      // Check basic security constraints
      final securityResult = await _security.validateUserSecurity(
        operation: 'auth_attempt',
        requireEmailVerification: false,
        requireActiveAccount: false,
        requireAuthentication: false, // Don't require auth for login
      );

      if (!securityResult.success) {
        throw Exception(securityResult.message);
      }

      final credential = await _auth.signInWithEmailAndPassword(
          email: email, password: password);

      if (credential.user != null) {
        await _createUserDocIfNeeded(credential.user!);
        await _security.clearFailedAttempts(credential.user!.uid);
        _security.startSession();
      }

      return credential.user;
    } on FirebaseAuthException catch (e) {
      // Record failed attempt
      if (e.code == 'wrong-password' || e.code == 'user-not-found') {
        final userQuery = await _firestore
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          await _security.recordFailedAttempt(
              userQuery.docs.first.id, 'email_login');
        }
      }

      throw _mnMessageForCode(e.code);
    } finally {
      await _setLoading(false);
    }
  }

  /// Enhanced sign up with password strength validation
  Future<User?> signUp(String name, String email, String password) async {
    try {
      await _setLoading(true);

      // Validate password strength
      if (!_security.validatePasswordStrength(password)) {
        final strength = _security.getPasswordStrength(password);
        throw Exception(
            'Нууц үг хангалтгүй хүчтэй байна: ${strength.feedback.join(', ')}');
      }

      // Check security constraints
      final securityResult = await _security.validateUserSecurity(
        operation: 'auth_attempt',
        requireEmailVerification: false,
        requireActiveAccount: false,
        requireAuthentication: false, // Don't require auth for signup
      );

      if (!securityResult.success) {
        throw Exception(securityResult.message);
      }

      final cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);

      // Update display name first
      await cred.user?.updateDisplayName(name);

      // Create user document
      if (cred.user != null) {
        await _createUserDocIfNeeded(cred.user!);
        _security.startSession();
      }

      return cred.user;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'Бүртгүүлэхэд алдаа гарлаа';
    } finally {
      await _setLoading(false);
    }
  }

  /// Enhanced sign out with session cleanup
  Future<void> signOut() async {
    final user = _auth.currentUser;
    if (user != null) {
      // Log security event through Firestore directly
      try {
        await _firestore.collection('security_logs').add({
          'userId': user.uid,
          'event': 'user_logout',
          'operation': 'session_management',
          'timestamp': FieldValue.serverTimestamp(),
          'metadata': {},
          'userAgent': 'Flutter App',
          'platform': defaultTargetPlatform.name,
        });
      } catch (e) {
        debugPrint('Error logging logout event: $e');
      }
    }

    await _auth.signOut();
    _verificationId = null;
    _lastSecurityCheck = null;
    _security.dispose();
    notifyListeners();
  }

  /// Enhanced Google sign in
  Future<User?> signInWithGoogle() async {
    try {
      await _setLoading(true);

      // Check security constraints
      final securityResult = await _security.validateUserSecurity(
        operation: 'auth_attempt',
        requireEmailVerification: false,
        requireActiveAccount: false,
        requireAuthentication: false, // Don't require auth for Google login
      );

      if (!securityResult.success) {
        throw Exception(securityResult.message);
      }

      final googleUser = await GoogleSignIn(
        scopes: [
          'email',
          'profile',
        ],
      ).signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);

      if (userCred.user != null) {
        await _createUserDocIfNeeded(userCred.user!);
        await _security.clearFailedAttempts(userCred.user!.uid);
        _security.startSession();
      }

      return userCred.user;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'Google бүртгэлд алдаа гарлаа';
    } catch (e) {
      // Handle specific Google Sign-In errors
      if (e.toString().contains('APIException 10')) {
        throw 'Google бүртгэл тохиргооны алдаа.';
      } else if (e.toString().contains('sign_in_failed')) {
        throw 'Google бүртгэлд нэвтрэх боломжгүй байна. Дахин оролдоно уу.';
      } else if (e.toString().contains('network_error')) {
        throw 'Сүлжээний алдаа. Интернэт холболтоо шалгана уу.';
      }
      throw 'Google бүртгэлд алдаа гарлаа: ${e.toString()}';
    } finally {
      await _setLoading(false);
    }
  }

  /// Enhanced Apple sign in
  Future<User?> signInWithApple() async {
    try {
      await _setLoading(true);

      // Check security constraints
      final securityResult = await _security.validateUserSecurity(
        operation: 'auth_attempt',
        requireEmailVerification: false,
        requireActiveAccount: false,
        requireAuthentication: false, // Don't require auth for Apple login
      );

      if (!securityResult.success) {
        throw Exception(securityResult.message);
      }

      final appleCred = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName
        ],
      );

      final oAuthProvider = OAuthProvider('apple.com');
      final credential = oAuthProvider.credential(
        idToken: appleCred.identityToken,
        accessToken: appleCred.authorizationCode,
      );

      final userCred = await _auth.signInWithCredential(credential);

      if (userCred.user != null) {
        await _createUserDocIfNeeded(userCred.user!);
        await _security.clearFailedAttempts(userCred.user!.uid);
        _security.startSession();
      }

      return userCred.user;
    } on SignInWithAppleAuthorizationException catch (e) {
      throw 'Apple бүртгэлд алдаа гарлаа: ${e.code}';
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'Apple бүртгэлд алдаа гарлаа';
    } catch (e) {
      throw 'Apple бүртгэлд алдаа гарлаа ${e.toString()}';
    } finally {
      await _setLoading(false);
    }
  }

  /// Enhanced phone verification
  Future<void> sendPhoneVerificationCode(String phoneNumber) async {
    try {
      await _setLoading(true);

      // Check security constraints with enhanced rate limiting
      final securityResult = await _security.validateUserSecurity(
        operation: 'phone_verification',
        requireEmailVerification: false,
        requireActiveAccount: false,
        requireAuthentication:
            false, // Don't require auth for phone verification
      );

      if (!securityResult.success) {
        throw Exception(securityResult.message);
      }

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final userCred = await _auth.signInWithCredential(credential);
            if (userCred.user != null) {
              await _createUserDocIfNeeded(userCred.user!);
              await _security.clearFailedAttempts(userCred.user!.uid);
              _security.startSession();
            }
          } catch (e) {
            debugPrint('Auto-verification failed: $e');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          throw e.message ?? 'Утасны дугаар баталгаажуулахэд алдаа гарлаа';
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          notifyListeners();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
          notifyListeners();
        },
        timeout: const Duration(seconds: 60),
      );
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'Баталгаажуулах код илгээхэд алдаа гарлаа';
    } finally {
      await _setLoading(false);
    }
  }

  /// Enhanced phone code verification
  Future<User?> verifyPhoneCode(String smsCode) async {
    if (_verificationId == null) {
      throw 'Баталгаажуулах ID олдсонгүй. Дахин код илгээхэд оролдоно уу.';
    }

    try {
      await _setLoading(true);

      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      final userCred = await _auth.signInWithCredential(credential);

      if (userCred.user != null) {
        await _createUserDocIfNeeded(userCred.user!);
        await _security.clearFailedAttempts(userCred.user!.uid);
        _security.startSession();
      }

      _verificationId = null;
      return userCred.user;
    } on FirebaseAuthException catch (e) {
      // Record failed attempt for phone verification
      if (e.code == 'invalid-verification-code' && _auth.currentUser != null) {
        await _security.recordFailedAttempt(
            _auth.currentUser!.uid, 'phone_verification');
      }

      switch (e.code) {
        case 'invalid-verification-code':
          throw 'Баталгаажуулах код буруу байна';
        case 'invalid-verification-id':
          throw 'Баталгаажуулах ID буруу байна';
        case 'session-expired':
          throw 'Баталгаажуулах хугацаа дууссан байна. Дахин код илгээхэд оролдоно уу.';
        default:
          throw e.message ?? 'Баталгаажуулахэд алдаа гарлаа';
      }
    } finally {
      await _setLoading(false);
    }
  }

  /// Enhanced email verification with security integration
  Future<AuthSecurityResult> sendEmailVerification({bool force = false}) async {
    return await _security.sendEmailVerification(force: force);
  }

  /// Enhanced password reset with security checks
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _setLoading(true);

      // Check security constraints
      final securityResult = await _security.validateUserSecurity(
        operation: 'password_reset',
        requireEmailVerification: false,
        requireActiveAccount: false,
        requireAuthentication: false, // Don't require auth for password reset
      );

      if (!securityResult.success) {
        throw Exception(securityResult.message);
      }

      await _auth.sendPasswordResetEmail(email: email);
    } finally {
      await _setLoading(false);
    }
  }

  /// Create user document with enhanced security tracking
  Future<void> _createUserDocIfNeeded(User user) async {
    try {
      final doc = _firestore.collection('users').doc(user.uid);
      final snap = await doc.get();

      if (snap.exists) {
        await doc.update({
          'lastSeen': FieldValue.serverTimestamp(),
          'lastLoginMethod': _getLoginMethod(user),
        });
        return;
      }

      // Create new user document with security fields
      await doc.set({
        'displayName': user.displayName ?? '',
        'email': user.email ?? '',
        'phoneNumber': user.phoneNumber ?? '',
        'photoURL': user.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
        'lastLoginMethod': _getLoginMethod(user),
        'followerStoreIds': [],
        'pushTokens': [],
        'savedProductIds': [],
        'isEmailVerified': user.emailVerified,
        'isPhoneVerified': user.phoneNumber?.isNotEmpty ?? false,
        'userType': 'customer',
        'isActive': true,
        'isBlocked': false,
        'securityProfile': {
          'passwordChangeRequired': false,
          'twoFactorEnabled': false,
          'lastPasswordChange': FieldValue.serverTimestamp(),
        },
      });
    } catch (e) {
      debugPrint('Error creating user document: $e');
    }
  }

  String _getLoginMethod(User user) {
    final providerData = user.providerData;
    if (providerData.isNotEmpty) {
      final provider = providerData.first.providerId;
      switch (provider) {
        case 'google.com':
          return 'google';
        case 'apple.com':
          return 'apple';
        case 'phone':
          return 'phone';
        default:
          return 'email';
      }
    }
    return 'email';
  }

  /// Check if user can perform critical operations
  Future<bool> canPerformOperation(String operation) async {
    final result = await checkSecurity(
      operation: operation,
      requireEmailVerification: true,
      requireActiveAccount: true,
    );
    return result.success;
  }

  /// Simplified purchase check with comprehensive validation
  Future<bool> canPurchase() async {
    return await canPerformOperation('purchase');
  }

  /// Get password strength for UI feedback
  PasswordStrength getPasswordStrength(String password) {
    return _security.getPasswordStrength(password);
  }

  /// Clear phone verification state
  void clearPhoneVerification() {
    _verificationId = null;
    notifyListeners();
  }

  /// Check if phone verification is in progress
  bool get isPhoneVerificationInProgress => _verificationId != null;

  /// Check if current user needs profile completion
  bool get needsProfileCompletion {
    final currentUser = user;
    if (currentUser == null) return false;

    final hasName = currentUser.displayName?.isNotEmpty == true;
    final isPhoneOnly = currentUser.phoneNumber?.isNotEmpty == true &&
        (currentUser.email?.isEmpty != false);

    return isPhoneOnly && !hasName;
  }

  /// Check if current user's email is verified
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  /// Force email verification check
  Future<bool> checkEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      final refreshedUser = _auth.currentUser;
      notifyListeners();
      return refreshedUser?.emailVerified ?? false;
    }
    return false;
  }

  /// Update user profile with security tracking
  Future<void> updateProfile({String? displayName, File? photo}) async {
    final current = _auth.currentUser;
    if (current == null) return;

    try {
      await _setLoading(true);
      String? photoURL;

      if (photo != null) {
        final ref = _storage.ref().child('users/${current.uid}/profile.jpg');
        await ref.putFile(photo);
        photoURL = await ref.getDownloadURL();
      }

      if (displayName != null && displayName.isNotEmpty) {
        await current.updateDisplayName(displayName);
      }
      if (photoURL != null) {
        await current.updatePhotoURL(photoURL);
      }

      // Update Firestore document
      final userDoc = _firestore.collection('users').doc(current.uid);
      final Map<String, dynamic> docUpdate = {};
      if (displayName != null && displayName.isNotEmpty) {
        docUpdate['displayName'] = displayName;
      }
      if (photoURL != null) {
        docUpdate['photoURL'] = photoURL;
      }
      docUpdate['updatedAt'] = FieldValue.serverTimestamp();

      if (docUpdate.isNotEmpty) {
        await userDoc.update(docUpdate);
      }

      await current.reload();
      notifyListeners();
    } finally {
      await _setLoading(false);
    }
  }

  String _mnMessageForCode(String code) {
    switch (code) {
      case 'user-not-found':
        return 'И-майл бүртгэл олдсонгүй';
      case 'wrong-password':
        return 'Нууц үг буруу байна';
      case 'invalid-email':
        return 'Имэйл буруу байна';
      case 'user-disabled':
        return 'Энэ хэрэглэгч идэвхгүй байна';
      case 'expired-action-code':
      case 'expired-credential':
        return 'Нэвтрэх мэдээллийн хугацаа дууссан байна';
      case 'too-many-requests':
        return 'Хэт олон оролдлого. Түр хүлээгээд дахин оролдоно уу';
      case 'weak-password':
        return 'Нууц үг хэтэрхий энгийн байна';
      case 'email-already-in-use':
        return 'Энэ имэйл хаяг аль хэдийн ашиглагдаж байна';
      case 'account-exists-with-different-credential':
        return 'Энэ имэйл хаягтай бүртгэл аль хэдийн байна';
      default:
        return 'Нэвтрэхэд алдаа гарлаа';
    }
  }
}
