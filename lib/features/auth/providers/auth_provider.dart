import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get user => _auth.currentUser;
  bool _loading = false;
  bool get loading => _loading;

  Future<void> _setLoading(bool value) async {
    _loading = value;
    notifyListeners();
  }

  Future<User?> signIn(String email, String password) async {
    try {
      await _setLoading(true);
      final credential = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'Sign-in failed';
    } finally {
      await _setLoading(false);
    }
  }

  Future<User?> signUp(String name, String email, String password) async {
    try {
      await _setLoading(true);
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      await cred.user?.updateDisplayName(name);
      return cred.user;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'Sign-up failed';
    } finally {
      await _setLoading(false);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<User?> signInWithGoogle() async {
    try {
      await _setLoading(true);
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null; // user canceled
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCred = await _auth.signInWithCredential(credential);
      return userCred.user;
    } finally {
      await _setLoading(false);
    }
  }

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
      return userCred.user;
    } catch (_) {
      return null;
    } finally {
      await _setLoading(false);
    }
  }
}
