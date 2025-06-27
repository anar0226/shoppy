import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SuperAdminAuthService {
  static final SuperAdminAuthService _instance =
      SuperAdminAuthService._internal();
  static SuperAdminAuthService get instance => _instance;
  SuperAdminAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  // Check if current user is authenticated and has super admin role
  Future<bool> isAuthenticated() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      // Check if user has super admin role
      final userDoc =
          await _firestore.collection('super_admins').doc(user.uid).get();

      return userDoc.exists && (userDoc.data()?['isActive'] ?? false);
    } catch (e) {
      return false;
    }
  }

  // Super admin login with email and password
  Future<bool> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) return false;

      // Verify super admin role
      final userDoc = await _firestore
          .collection('super_admins')
          .doc(credential.user!.uid)
          .get();

      if (!userDoc.exists || !(userDoc.data()?['isActive'] ?? false)) {
        await _auth.signOut();
        return false;
      }

      // Log admin activity
      await _logAdminActivity('login', {
        'timestamp': FieldValue.serverTimestamp(),
        'email': email,
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _logAdminActivity('logout', {
        'timestamp': FieldValue.serverTimestamp(),
      });
      await _auth.signOut();
    } catch (e) {
      // Handle error silently
    }
  }

  // Log admin activity for audit trail
  Future<void> _logAdminActivity(
      String action, Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('admin_activity_logs').add({
        'adminId': user.uid,
        'action': action,
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Log error but don't throw
    }
  }

  // Get admin profile
  Future<Map<String, dynamic>?> getAdminProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc =
          await _firestore.collection('super_admins').doc(user.uid).get();

      if (!doc.exists) return null;

      return {
        ...doc.data()!,
        'email': user.email,
        'uid': user.uid,
      };
    } catch (e) {
      return null;
    }
  }

  // Check specific permissions
  Future<bool> hasPermission(String permission) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc =
          await _firestore.collection('super_admins').doc(user.uid).get();

      if (!doc.exists) return false;

      final permissions = List<String>.from(doc.data()?['permissions'] ?? []);
      return permissions.contains(permission) || permissions.contains('all');
    } catch (e) {
      return false;
    }
  }
}
