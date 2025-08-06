import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // Added for debugPrint

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
          email: email, password: password);
    } on FirebaseAuthException {
      // Re-throw with the original exception to maintain error codes
      rethrow;
    } catch (e) {
      // Convert other errors to FirebaseAuthException-like format
      throw FirebaseAuthException(
        code: 'unknown',
        message: 'An unexpected error occurred during signin: $e',
      );
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<UserCredential> signUp(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);

      // Automatically send email verification
      try {
        await credential.user?.sendEmailVerification(
          ActionCodeSettings(
            url: 'https://avii.mn/_auth/action',
            handleCodeInApp: true,
          ),
        );
      } catch (e) {
        // Don't fail signup if email verification fails
        debugPrint('Failed to send email verification: $e');
      }

      return credential;
    } on FirebaseAuthException {
      // Re-throw with the original exception to maintain error codes
      rethrow;
    } catch (e) {
      // Convert other errors to FirebaseAuthException-like format
      throw FirebaseAuthException(
        code: 'unknown',
        message: 'An unexpected error occurred during signup: $e',
      );
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> sendEmailVerification() async {
    try {
      // Ensure user is properly loaded
      await reloadUser();

      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      if (currentUser!.emailVerified) {
        debugPrint('User email is already verified');
        return;
      }

      // Force token refresh to ensure valid authentication
      await currentUser!.getIdToken(true);

      debugPrint('Sending email verification to: ${currentUser!.email}');
      debugPrint('Using Firebase project: ${_auth.app.options.projectId}');
      debugPrint('Using Firebase auth domain: ${_auth.app.options.authDomain}');

      await currentUser!.sendEmailVerification(
        ActionCodeSettings(
          url: 'https://avii.mn/_auth/action',
          handleCodeInApp: true,
        ),
      );

      debugPrint('Email verification sent successfully');
    } catch (e) {
      debugPrint('Failed to send email verification: $e');

      // Provide more specific error messages
      if (e.toString().contains('network')) {
        throw Exception(
            'Сүлжээний холболттой холбоотой асуудал. Дахин оролдоно уу.');
      } else if (e.toString().contains('too-many-requests')) {
        throw Exception(
            'Хэт олон хүсэлт илгээлээ. Хэсэг хүлээгээд дахин оролдоно уу.');
      } else if (e.toString().contains('user-not-found')) {
        throw Exception('Хэрэглэгч олдсонгүй. Дахин нэвтэрнэ үү.');
      } else if (e.toString().contains('400')) {
        throw Exception('Тохиргооны алдаа. Админтай холбогдоно уу.');
      } else {
        throw Exception('Имэйл илгээхэд алдаа гарлаа: ${e.toString()}');
      }
    }
  }

  Future<void> reloadUser() async {
    if (currentUser != null) {
      await currentUser!.reload();
    }
  }
}
