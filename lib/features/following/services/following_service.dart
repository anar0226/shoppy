import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FollowingService {
  static final FollowingService _instance = FollowingService._internal();
  factory FollowingService() => _instance;
  FollowingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check if the current user is following a specific store
  Future<bool> isFollowingStore(String storeId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return false;

      final data = userDoc.data() as Map<String, dynamic>;
      final followerStoreIds =
          List<String>.from(data['followerStoreIds'] ?? []);

      return followerStoreIds.contains(storeId);
    } catch (e) {
      debugPrint('Error checking if following store: $e');
      return false;
    }
  }

  /// Follow a store
  Future<bool> followStore(String storeId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Add store to user's following list (use set with merge to handle non-existent documents)
      await _firestore.collection('users').doc(user.uid).set({
        'followerStoreIds': FieldValue.arrayUnion([storeId]),
      }, SetOptions(merge: true));

      // Update store's follower count (use set with merge to handle non-existent documents)
      await _firestore.collection('stores').doc(storeId).set({
        'followerCount': FieldValue.increment(1),
        'followers': FieldValue.arrayUnion([user.uid]),
      }, SetOptions(merge: true));

      // Add analytics event
      await _addFollowEvent(storeId, 'follow');

      return true;
    } catch (e) {
      debugPrint('Error following store: $e');
      return false;
    }
  }

  /// Unfollow a store
  Future<bool> unfollowStore(String storeId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Check if user document exists before trying to update
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        // Remove store from user's following list
        await _firestore.collection('users').doc(user.uid).update({
          'followerStoreIds': FieldValue.arrayRemove([storeId]),
        });
      }

      // Check if store document exists before trying to update
      final storeDoc = await _firestore.collection('stores').doc(storeId).get();
      if (storeDoc.exists) {
        // Update store's follower count
        await _firestore.collection('stores').doc(storeId).update({
          'followerCount': FieldValue.increment(-1),
          'followers': FieldValue.arrayRemove([user.uid]),
        });
      }

      // Add analytics event
      await _addFollowEvent(storeId, 'unfollow');

      return true;
    } catch (e) {
      debugPrint('Error unfollowing store: $e');
      return false;
    }
  }

  /// Get the list of stores the current user is following
  Stream<List<String>> getFollowedStoresStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore.collection('users').doc(user.uid).snapshots().map((doc) {
      if (!doc.exists) return <String>[];
      final data = doc.data() as Map<String, dynamic>;
      return List<String>.from(data['followerStoreIds'] ?? []);
    });
  }

  /// Get follower count for a store
  Future<int> getStoreFollowerCount(String storeId) async {
    try {
      final storeDoc = await _firestore.collection('stores').doc(storeId).get();
      if (!storeDoc.exists) return 0;

      final data = storeDoc.data() as Map<String, dynamic>;
      return data['followerCount'] ?? 0;
    } catch (e) {
      debugPrint('Error getting store follower count: $e');
      return 0;
    }
  }

  /// Report a store
  Future<bool> reportStore(String storeId, String reason,
      {String? additionalInfo}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore.collection('reports').add({
        'type': 'store',
        'targetId': storeId,
        'reportedBy': user.uid,
        'reason': reason,
        'additionalInfo': additionalInfo ?? '',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Error reporting store: $e');
      return false;
    }
  }

  /// Mark store as "not interested"
  Future<bool> markNotInterested(String storeId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Use set with merge to handle cases where user document doesn't exist
      await _firestore.collection('users').doc(user.uid).set({
        'notInterestedStoreIds': FieldValue.arrayUnion([storeId]),
      }, SetOptions(merge: true));

      // Add analytics event (wrapped in try-catch to prevent crashes)
      try {
        await _addFollowEvent(storeId, 'not_interested');
      } catch (analyticsError) {
        // Don't fail the whole operation if analytics fail
        debugPrint('Analytics event failed: $analyticsError');
      }

      return true;
    } catch (e) {
      debugPrint('Error marking store as not interested: $e');
      return false;
    }
  }

  /// Add analytics event for following actions
  Future<void> _addFollowEvent(String storeId, String action) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('analytics_events').add({
        'type': 'store_follow',
        'action': action,
        'userId': user.uid,
        'storeId': storeId,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': defaultTargetPlatform.name,
      });
    } catch (e) {
      debugPrint('Error adding follow analytics event: $e');
    }
  }

  /// Stream to listen for follow status changes
  Stream<bool> followStatusStream(String storeId) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(false);
    }

    return _firestore.collection('users').doc(user.uid).snapshots().map((doc) {
      if (!doc.exists) return false;
      final data = doc.data() as Map<String, dynamic>;
      final followerStoreIds =
          List<String>.from(data['followerStoreIds'] ?? []);
      return followerStoreIds.contains(storeId);
    });
  }
}
