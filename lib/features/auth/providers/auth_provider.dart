import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

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
      if (credential.user != null) {
        await _createUserDocIfNeeded(credential.user!);
      }
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
      await _createUserDocIfNeeded(cred.user!);
      if (cred.user != null) {
        await _createUserDocIfNeeded(cred.user!);
      }
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
      await _createUserDocIfNeeded(userCred.user!);
      if (userCred.user != null) {
        await _createUserDocIfNeeded(userCred.user!);
      }
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
      await _createUserDocIfNeeded(userCred.user!);
      return userCred.user;
    } catch (_) {
      return null;
    } finally {
      await _setLoading(false);
    }
  }

  Future<void> _createUserDocIfNeeded(User user) async {
    final doc = _firestore.collection('users').doc(user.uid);
    final snap = await doc.get();
    if (snap.exists) {
      // If user exists, just update lastSeen
      await doc.update({'lastSeen': FieldValue.serverTimestamp()});
      return;
    }

    await doc.set({
      'displayName': user.displayName ?? '',
      'email': user.email ?? '',
      'photoURL': user.photoURL ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'lastSeen': FieldValue.serverTimestamp(),
      'followerStoreIds': [],
      'pushTokens': [],
      'savedProductIds': [],
    });
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
}
