import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class SuperAdminAuthServiceDebug {
  static final SuperAdminAuthServiceDebug _instance =
      SuperAdminAuthServiceDebug._internal();
  static SuperAdminAuthServiceDebug get instance => _instance;
  SuperAdminAuthServiceDebug._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  // Debug version of login with detailed logging
  Future<bool> loginDebug(String email, String password) async {
    try {
      // Starting login process

      // Step 1: Firebase Auth
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        // Firebase Auth returned null user
        return false;
      }

      final user = credential.user!;
      // Firebase Auth successful

      // Step 2: Firestore Document Check

      final userDoc =
          await _firestore.collection('super_admins').doc(user.uid).get();

      if (!userDoc.exists) {
        // No super_admins document found
        await _auth.signOut();
        return false;
      }

      // Step 3: Document Data Check
      final data = userDoc.data();
      final isActive = data?['isActive'];

      if (!(isActive ?? false)) {
        // isActive check failed
        await _auth.signOut();
        return false;
      }

      // All checks passed - login successful

      // Log admin activity (optional for debug)
      try {
        await _firestore.collection('admin_activity_logs').add({
          'adminId': user.uid,
          'action': 'login_debug',
          'data': {
            'timestamp': FieldValue.serverTimestamp(),
            'email': email,
          },
          'timestamp': FieldValue.serverTimestamp(),
        });
        // Activity logged successfully
      } catch (e) {
        // Failed to log activity
      }

      return true;
    } catch (e) {
      // Login failed
      return false;
    }
  }

  // Check if current user is authenticated and has super admin role
  Future<bool> isAuthenticated() async {
    final user = _auth.currentUser;
    if (user == null) {
      // No current user
      return false;
    }

    try {
      // Checking authentication for user

      // Check if user has super admin role
      final userDoc =
          await _firestore.collection('super_admins').doc(user.uid).get();

      final exists = userDoc.exists;
      final isActive = userDoc.data()?['isActive'] ?? false;

      return exists && isActive;
    } catch (e) {
      // Authentication check failed
      return false;
    }
  }
}
