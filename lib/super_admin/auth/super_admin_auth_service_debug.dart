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
      debugPrint('🔍 DEBUG: Starting login process...');
      debugPrint('🔍 DEBUG: Email: $email');

      // Step 1: Firebase Auth
      debugPrint('🔍 DEBUG: Step 1 - Attempting Firebase Auth login...');
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        debugPrint('❌ DEBUG: Firebase Auth returned null user');
        return false;
      }

      final user = credential.user!;
      debugPrint('✅ DEBUG: Firebase Auth successful');
      debugPrint('🔍 DEBUG: User UID: ${user.uid}');
      debugPrint('🔍 DEBUG: User Email: ${user.email}');

      // Step 2: Firestore Document Check
      debugPrint('🔍 DEBUG: Step 2 - Checking Firestore document...');
      debugPrint('🔍 DEBUG: Looking for document: super_admins/${user.uid}');

      final userDoc =
          await _firestore.collection('super_admins').doc(user.uid).get();

      debugPrint('🔍 DEBUG: Document exists: ${userDoc.exists}');

      if (!userDoc.exists) {
        debugPrint(
            '❌ DEBUG: No super_admins document found for UID: ${user.uid}');
        debugPrint(
            '❌ DEBUG: Expected document ID: rbA5yLk0vadvSWarOpzYW1bRRUz1');
        debugPrint('❌ DEBUG: Actual UID: ${user.uid}');
        debugPrint(
            '❌ DEBUG: UIDs match: ${user.uid == "rbA5yLk0vadvSWarOpzYW1bRRUz1"}');
        await _auth.signOut();
        return false;
      }

      // Step 3: Document Data Check
      final data = userDoc.data();
      debugPrint('🔍 DEBUG: Document data: $data');

      final isActive = data?['isActive'];
      debugPrint('🔍 DEBUG: isActive value: $isActive');
      debugPrint('🔍 DEBUG: isActive type: ${isActive.runtimeType}');
      debugPrint('🔍 DEBUG: isActive == true: ${isActive == true}');
      debugPrint('🔍 DEBUG: isActive ?? false: ${isActive ?? false}');

      if (!(isActive ?? false)) {
        debugPrint('❌ DEBUG: isActive check failed');
        debugPrint('❌ DEBUG: isActive value: $isActive');
        debugPrint('❌ DEBUG: isActive is not true');
        await _auth.signOut();
        return false;
      }

      debugPrint('✅ DEBUG: All checks passed - login successful!');

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
        debugPrint('✅ DEBUG: Activity logged successfully');
      } catch (e) {
        debugPrint('⚠️ DEBUG: Failed to log activity: $e');
      }

      return true;
    } catch (e) {
      debugPrint('❌ DEBUG: Login failed with error: $e');
      debugPrint('❌ DEBUG: Error type: ${e.runtimeType}');
      debugPrint('❌ DEBUG: Error details: ${e.toString()}');
      return false;
    }
  }

  // Check if current user is authenticated and has super admin role
  Future<bool> isAuthenticated() async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('🔍 DEBUG: No current user');
      return false;
    }

    try {
      debugPrint('🔍 DEBUG: Checking authentication for user: ${user.uid}');

      // Check if user has super admin role
      final userDoc =
          await _firestore.collection('super_admins').doc(user.uid).get();

      final exists = userDoc.exists;
      final isActive = userDoc.data()?['isActive'] ?? false;

      debugPrint('🔍 DEBUG: Document exists: $exists');
      debugPrint('🔍 DEBUG: isActive: $isActive');
      debugPrint('🔍 DEBUG: Authentication result: ${exists && isActive}');

      return exists && isActive;
    } catch (e) {
      debugPrint('❌ DEBUG: Authentication check failed: $e');
      return false;
    }
  }
}
