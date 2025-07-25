import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/services/rate_limiter_service.dart';

class AuthProvider extends ChangeNotifier with RateLimitedService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  User? get user => _auth.currentUser;
  bool _loading = false;
  bool get loading => _loading;

  // Phone verification state
  String? _verificationId;
  String? get verificationId => _verificationId;

  Future<void> _setLoading(bool value) async {
    _loading = value;
    notifyListeners();
  }

  /// Sign in with email and password
  Future<User?> signIn(String email, String password) async {
    checkRateLimit('auth_attempt');
    try {
      await _setLoading(true);
      final credential = await _auth.signInWithEmailAndPassword(
          email: email, password: password);

      // Create user document if needed (fixed: moved before return)
      if (credential.user != null) {
        await _createUserDocIfNeeded(credential.user!);
      }

      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw _mnMessageForCode(e.code);
    } finally {
      await _setLoading(false);
    }
  }

  /// Sign up with email and password
  Future<User?> signUp(String name, String email, String password) async {
    checkRateLimit('auth_attempt');
    try {
      await _setLoading(true);
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);

      // Update display name first
      await cred.user?.updateDisplayName(name);

      // Create user document (fixed: only call once)
      if (cred.user != null) {
        await _createUserDocIfNeeded(cred.user!);
      }

      return cred.user;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'Бүртгүүлэхэд алдаа гарлаа';
    } finally {
      await _setLoading(false);
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    await _auth.signOut();
    _verificationId = null; // Clear phone verification state
    notifyListeners();
  }

  /// Sign in with Google - fixed implementation
  Future<User?> signInWithGoogle() async {
    try {
      await _setLoading(true);

      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null; // User canceled

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCred =
          await _auth.signInWithCredential(credential);

      // Create user document if needed
      if (userCred.user != null) {
        await _createUserDocIfNeeded(userCred.user!);
      }

      return userCred.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        throw 'Энэ имэйл хаягтай хэрэглэгч байна';
      } else if (e.code == 'invalid-credential') {
        throw 'Google бүртгэл алдаа';
      }
      throw 'Google бүртгэлд алдаа гарлаа: ${e.message}';
    } catch (e) {
      throw 'Google бүртгэлд алдаа гарлаа: $e';
    } finally {
      await _setLoading(false);
    }
  }

  /// Sign in with Apple (fixed: proper error handling)
  Future<User?> signInWithApple() async {
    try {
      await _setLoading(true);
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

      // Create user document (fixed: moved before return)
      if (userCred.user != null) {
        await _createUserDocIfNeeded(userCred.user!);
      }

      return userCred.user;
    } on SignInWithAppleAuthorizationException catch (e) {
      switch (e.code) {
        case AuthorizationErrorCode.canceled:
          throw 'Apple бүртгэлд алдаа гарлаа';
        case AuthorizationErrorCode.failed:
          throw 'Apple бүртгэлд алдаа гарлаа';
        case AuthorizationErrorCode.invalidResponse:
          throw 'Apple бүртгэлд алдаа гарлаа';
        case AuthorizationErrorCode.notHandled:
          throw 'Apple бүртгэлд алдаа гарлаа';
        case AuthorizationErrorCode.unknown:
        default:
          throw 'Apple бүртгэлд алдаа гарлаа';
      }
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'Apple бүртгэлд алдаа гарлаа';
    } catch (e) {
      throw 'Apple бүртгэлд алдаа гарлаа ${e.toString()}';
    } finally {
      await _setLoading(false);
    }
  }

  /// Enhanced phone verification with proper error handling
  Future<void> sendPhoneVerificationCode(String phoneNumber) async {
    try {
      await _setLoading(true);

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification completed (Android only)
          try {
            await _auth.signInWithCredential(credential);
          } catch (e) {
            debugPrint('Auto-verification failed: $e');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          throw _getPhoneAuthErrorMessage(e.code);
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
    } finally {
      await _setLoading(false);
    }
  }

  /// Verify phone number with SMS code
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

      // Create user document if needed
      if (userCred.user != null) {
        await _createUserDocIfNeeded(userCred.user!);
      }

      // Clear verification state on success
      _verificationId = null;

      return userCred.user;
    } on FirebaseAuthException catch (e) {
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

  /// Create user document in Firestore if it doesn't exist
  Future<void> _createUserDocIfNeeded(User user) async {
    try {
      final doc = _firestore.collection('users').doc(user.uid);
      final snap = await doc.get();

      if (snap.exists) {
        // If user exists, just update lastSeen
        await doc.update({'lastSeen': FieldValue.serverTimestamp()});
        return;
      }

      // Create new user document
      await doc.set({
        'displayName': user.displayName ?? '',
        'email': user.email ?? '',
        'phoneNumber': user.phoneNumber ?? '',
        'photoURL': user.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
        'followerStoreIds': [],
        'pushTokens': [],
        'savedProductIds': [],
        'isEmailVerified': user.emailVerified,
        'isPhoneVerified': user.phoneNumber?.isNotEmpty ?? false,
        'userType': 'customer', // default user type
      });
    } catch (e) {
      // Log error but don't throw to avoid breaking authentication flow
      // Failed to create user document
    }
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

    // Check if user has a display name
    final hasName = currentUser.displayName?.isNotEmpty == true;

    // Check if user signed up with phone only (no email)
    final isPhoneOnly = currentUser.phoneNumber?.isNotEmpty == true &&
        (currentUser.email?.isEmpty != false);

    return isPhoneOnly && !hasName;
  }

  /// Update the current user's profile (name and/or picture) and refresh UI.
  Future<void> updateProfile({String? displayName, File? photo}) async {
    final current = _auth.currentUser;
    if (current == null) return;
    try {
      await _setLoading(true);
      String? photoURL;

      // 1. If photo is provided, upload to Firebase Storage
      if (photo != null) {
        final ref = _storage.ref().child('users/${current.uid}/profile.jpg');
        await ref.putFile(photo);
        photoURL = await ref.getDownloadURL();
      }

      // 2. Update Auth user profile
      if (displayName != null && displayName.isNotEmpty) {
        await current.updateDisplayName(displayName);
      }
      if (photoURL != null) {
        await current.updatePhotoURL(photoURL);
      }

      // 3. Update the user document in Firestore
      final userDoc = _firestore.collection('users').doc(current.uid);
      final Map<String, dynamic> docUpdate = {};
      if (displayName != null && displayName.isNotEmpty) {
        docUpdate['displayName'] = displayName;
      }
      if (photoURL != null) {
        docUpdate['photoURL'] = photoURL;
      }
      if (docUpdate.isNotEmpty) {
        await userDoc.update(docUpdate);
      }

      // 4. Refresh user state and notify listeners
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
      default:
        return 'Нэвтрэхэд алдаа гарлаа';
    }
  }

  String _getPhoneAuthErrorMessage(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'Утасны дугаар буруу байна';
      case 'too-many-requests':
        return 'Хэт олон оролдлого. Түр хүлээгээд дахин оролдоно уу';
      case 'quota-exceeded':
        return 'жооxон хүлээж байгаад дахин оролдоно уу';
      case 'operation-not-allowed':
        return 'Утасны баталгаажуулалтын тохиргоог өөрчлөх боломжгүй байна';
      default:
        return 'Утасны баталгаажуулаx явцад алдаа гарлаа';
    }
  }

  /// Check if current user's email is verified
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  /// Send email verification
  Future<void> sendEmailVerification() async {
    checkRateLimit('email_verification');
    try {
      await _setLoading(true);
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } catch (e) {
      if (e is RateLimitExceededException) {
        throw 'Хэт олон хүсэлт илгээлээ. ${e.retryAfterSeconds} секундын дараа дахин оролдоно уу.';
      } else {
        throw 'Имэйл илгээхэд алдаа гарлаа: $e';
      }
    } finally {
      await _setLoading(false);
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    checkRateLimit('password_reset');
    try {
      await _setLoading(true);
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      if (e is RateLimitExceededException) {
        throw 'Хэт олон хүсэлт илгээлээ. ${e.retryAfterSeconds} секундын дараа дахин оролдоно уу.';
      } else {
        throw 'Нууц үг сэргээх имэйл илгээхэд алдаа гарлаа: $e';
      }
    } finally {
      await _setLoading(false);
    }
  }

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

  /// Check if user can perform purchase operations
  bool get canPurchase {
    final currentUser = user;
    if (currentUser == null) return false;

    // Must have verified email to purchase
    return currentUser.emailVerified;
  }
}
