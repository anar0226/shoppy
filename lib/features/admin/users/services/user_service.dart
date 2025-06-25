import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get users with pagination and filtering
  Stream<QuerySnapshot> getUsersStream({
    String? searchQuery,
    String? statusFilter,
    String? userTypeFilter,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 50,
    DocumentSnapshot? lastDocument,
    bool onlyRelevantUsers = true,
  }) {
    Query query = _firestore.collection('users');

    // Apply filters
    if (statusFilter != null && statusFilter != 'All Status') {
      bool isActive = statusFilter == 'Active';
      query = query.where('isActive', isEqualTo: isActive);
    }

    if (userTypeFilter != null && userTypeFilter != 'All Types') {
      query = query.where('userType', isEqualTo: userTypeFilter.toLowerCase());
    }

    if (fromDate != null) {
      query = query.where('createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate));
    }

    if (toDate != null) {
      query = query.where('createdAt',
          isLessThanOrEqualTo: Timestamp.fromDate(toDate));
    }

    // Order by creation date (newest first)
    query = query.orderBy('createdAt', descending: true);

    // Apply pagination
    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    query = query.limit(limit);

    return query.snapshots();
  }

  // Get only relevant users (who have orders or are following stores)
  Stream<QuerySnapshot> getRelevantUsersStream({
    String? statusFilter,
    String? userTypeFilter,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 50,
    DocumentSnapshot? lastDocument,
  }) {
    Query query = _firestore.collection('users');

    // Apply filters
    if (statusFilter != null && statusFilter != 'All Status') {
      bool isActive = statusFilter == 'Active';
      query = query.where('isActive', isEqualTo: isActive);
    }

    if (userTypeFilter != null && userTypeFilter != 'All Types') {
      query = query.where('userType', isEqualTo: userTypeFilter.toLowerCase());
    }

    if (fromDate != null) {
      query = query.where('createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate));
    }

    if (toDate != null) {
      query = query.where('createdAt',
          isLessThanOrEqualTo: Timestamp.fromDate(toDate));
    }

    // Order by creation date (newest first)
    query = query.orderBy('createdAt', descending: true);

    // Apply pagination
    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    query = query.limit(limit);

    return query.snapshots();
  }

  // Search users by email or display name
  Future<List<UserModel>> searchUsers(String searchQuery) async {
    if (searchQuery.isEmpty) return [];

    try {
      // Search by email
      final emailQuery = await _firestore
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: searchQuery.toLowerCase())
          .where('email',
              isLessThanOrEqualTo: '${searchQuery.toLowerCase()}\uf8ff')
          .limit(20)
          .get();

      // Search by display name
      final nameQuery = await _firestore
          .collection('users')
          .where('displayName', isGreaterThanOrEqualTo: searchQuery)
          .where('displayName', isLessThanOrEqualTo: '$searchQuery\uf8ff')
          .limit(20)
          .get();

      final Set<String> seenIds = {};
      final List<UserModel> results = [];

      // Combine results and remove duplicates
      for (final doc in [...emailQuery.docs, ...nameQuery.docs]) {
        if (!seenIds.contains(doc.id)) {
          seenIds.add(doc.id);
          results.add(UserModel.fromMap(doc.data(), doc.id));
        }
      }

      return results;
    } catch (e) {
      throw Exception('Failed to search users: $e');
    }
  }

  // Get a single user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  // Create a new user
  Future<String> createUser({
    required String email,
    required String password,
    String? displayName,
    String? phoneNumber,
  }) async {
    try {
      // Create user in Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user!;

      // Update display name if provided
      if (displayName?.isNotEmpty == true) {
        await user.updateDisplayName(displayName);
      }

      // Create user document in Firestore
      final userData = UserModel(
        id: user.uid,
        email: email,
        displayName: displayName,
        phoneNumber: phoneNumber,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
        isActive: true,
        userType: 'customer',
      );

      await _firestore.collection('users').doc(user.uid).set(userData.toMap());

      return user.uid;
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  // Update user information
  Future<void> updateUser(String userId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        ...updates,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  // Toggle user active status
  Future<void> toggleUserStatus(String userId, bool isActive) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isActive': isActive,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to update user status: $e');
    }
  }

  // Delete user (soft delete - mark as inactive)
  Future<void> deleteUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isActive': false,
        'deletedAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  // Get user analytics
  Future<Map<String, dynamic>> getUserAnalytics() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final last30Days = now.subtract(const Duration(days: 30));

      // Get total users count
      final totalUsersSnapshot = await _firestore
          .collection('users')
          .where('isActive', isEqualTo: true)
          .get();

      // Get new users this month
      final newThisMonthSnapshot = await _firestore
          .collection('users')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('isActive', isEqualTo: true)
          .get();

      // Get active users (last 30 days)
      final activeUsersSnapshot = await _firestore
          .collection('users')
          .where('lastLoginAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(last30Days))
          .where('isActive', isEqualTo: true)
          .get();

      // Calculate average lifetime value
      double totalSpent = 0;
      int usersWithOrders = 0;

      for (final doc in totalUsersSnapshot.docs) {
        final userData = doc.data();
        final stats = userData['stats'] as Map<String, dynamic>?;
        if (stats != null) {
          final userSpent = (stats['totalSpent'] ?? 0).toDouble();
          if (userSpent > 0) {
            totalSpent += userSpent;
            usersWithOrders++;
          }
        }
      }

      final avgLifetimeValue =
          usersWithOrders > 0 ? totalSpent / usersWithOrders : 0.0;

      return {
        'totalUsers': totalUsersSnapshot.docs.length,
        'newThisMonth': newThisMonthSnapshot.docs.length,
        'activeUsers': activeUsersSnapshot.docs.length,
        'avgLifetimeValue': avgLifetimeValue,
      };
    } catch (e) {
      throw Exception('Failed to get user analytics: $e');
    }
  }

  // Get user registration trends (last 12 months)
  Future<List<Map<String, dynamic>>> getRegistrationTrends() async {
    try {
      final now = DateTime.now();
      final List<Map<String, dynamic>> trends = [];

      for (int i = 11; i >= 0; i--) {
        final monthStart = DateTime(now.year, now.month - i, 1);
        final monthEnd = DateTime(now.year, now.month - i + 1, 1);

        final snapshot = await _firestore
            .collection('users')
            .where('createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
            .where('createdAt', isLessThan: Timestamp.fromDate(monthEnd))
            .get();

        trends.add({
          'month':
              '${monthStart.year}-${monthStart.month.toString().padLeft(2, '0')}',
          'count': snapshot.docs.length,
          'date': monthStart,
        });
      }

      return trends;
    } catch (e) {
      throw Exception('Failed to get registration trends: $e');
    }
  }

  // Get user status distribution
  Future<Map<String, int>> getUserStatusDistribution() async {
    try {
      final activeSnapshot = await _firestore
          .collection('users')
          .where('isActive', isEqualTo: true)
          .get();

      final inactiveSnapshot = await _firestore
          .collection('users')
          .where('isActive', isEqualTo: false)
          .get();

      return {
        'active': activeSnapshot.docs.length,
        'inactive': inactiveSnapshot.docs.length,
      };
    } catch (e) {
      throw Exception('Failed to get user status distribution: $e');
    }
  }

  // Update user stats (typically called when orders are created/updated)
  Future<void> updateUserStats(
    String userId, {
    int? totalOrders,
    double? totalSpent,
    DateTime? lastOrderDate,
    int? savedItems,
    int? reviewsCount,
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final currentStats =
          userDoc.data()?['stats'] as Map<String, dynamic>? ?? {};

      final updatedStats = {
        'totalOrders': totalOrders ?? currentStats['totalOrders'] ?? 0,
        'totalSpent': totalSpent ?? currentStats['totalSpent'] ?? 0.0,
        'lastOrderDate': lastOrderDate != null
            ? Timestamp.fromDate(lastOrderDate)
            : currentStats['lastOrderDate'],
        'savedItems': savedItems ?? currentStats['savedItems'] ?? 0,
        'reviewsCount': reviewsCount ?? currentStats['reviewsCount'] ?? 0,
      };

      await _firestore.collection('users').doc(userId).update({
        'stats': updatedStats,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to update user stats: $e');
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception('Failed to send password reset email: $e');
    }
  }

  // Get users by IDs (for bulk operations)
  Future<List<UserModel>> getUsersByIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    try {
      final List<UserModel> users = [];

      // Firestore 'in' queries are limited to 10 items, so we need to batch
      for (int i = 0; i < userIds.length; i += 10) {
        final batch = userIds.skip(i).take(10).toList();
        final snapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (final doc in snapshot.docs) {
          users.add(UserModel.fromMap(doc.data(), doc.id));
        }
      }

      return users;
    } catch (e) {
      throw Exception('Failed to get users by IDs: $e');
    }
  }

  // Check if user is following a specific store
  Future<bool> isUserFollowingStore(String userId, String storeId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      final followerStoreIds =
          List<String>.from(userDoc.data()?['followerStoreIds'] ?? []);
      return followerStoreIds.contains(storeId);
    } catch (e) {
      return false;
    }
  }

  // Get user's following stores count
  Future<int> getUserFollowingCount(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return 0;

      final followerStoreIds =
          List<String>.from(userDoc.data()?['followerStoreIds'] ?? []);
      return followerStoreIds.length;
    } catch (e) {
      return 0;
    }
  }
}
