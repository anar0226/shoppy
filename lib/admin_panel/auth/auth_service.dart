import 'package:firebase_auth/firebase_auth.dart';

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
      return await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
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
    if (currentUser != null && !currentUser!.emailVerified) {
      await currentUser!.sendEmailVerification();
    }
  }

  Future<void> reloadUser() async {
    if (currentUser != null) {
      await currentUser!.reload();
    }
  }
}
