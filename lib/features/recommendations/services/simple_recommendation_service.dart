import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/simple_user_preferences.dart';
import '../../stores/models/store_model.dart';

class SimpleRecommendationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get user preferences
  Future<SimpleUserPreferences?> getUserPreferences() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;

    try {
      final doc = await _firestore
          .collection('user_preferences_simple')
          .doc(userId)
          .get();

      if (doc.exists) {
        return SimpleUserPreferences.fromMap(doc.data()!, userId);
      }
      return null;
    } catch (e) {
      // Error getting user preferences
      return null;
    }
  }

  // Save user preferences
  Future<void> saveUserPreferences(SimpleUserPreferences preferences) async {
    try {
      await _firestore
          .collection('user_preferences_simple')
          .doc(preferences.userId)
          .set(preferences.toMap());
    } catch (e) {
      // Error saving user preferences
    }
  }

  // Create initial preferences for new users
  Future<void> createInitialPreferences({
    required String shoppingFor,
    required List<String> interests,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final preferences = SimpleUserPreferences(
      userId: userId,
      shoppingFor: shoppingFor,
      interests: interests,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await saveUserPreferences(preferences);
  }

  // Get recommended stores based on preferences
  Future<List<StoreModel>> getRecommendedStores({int limit = 6}) async {
    final preferences = await getUserPreferences();
    if (preferences == null) {
      // If no preferences, return random stores
      return await _getRandomStores(limit);
    }

    try {
      // Get user's not interested stores
      final notInterestedStores = await _getNotInterestedStores();

      // Get all stores
      final storesSnapshot = await _firestore.collection('stores').get();
      final allStores = storesSnapshot.docs
          .map((doc) => StoreModel.fromFirestore(doc))
          .where((store) => store.status == 'active')
          .where((store) => !notInterestedStores
              .contains(store.id)) // Exclude not interested stores
          .toList();

      // Filter stores based on preferences
      final filteredStores = _filterStoresByPreferences(allStores, preferences);

      // Remove recently shown stores
      final availableStores = filteredStores
          .where((store) => !preferences.recentlyShownStores.contains(store.id))
          .toList();

      // If we don't have enough stores, mix in some recently shown ones
      if (availableStores.length < limit &&
          filteredStores.length > availableStores.length) {
        final recentStores = filteredStores
            .where(
                (store) => preferences.recentlyShownStores.contains(store.id))
            .take(limit - availableStores.length)
            .toList();
        availableStores.addAll(recentStores);
      }

      // Shuffle for variety
      availableStores.shuffle();

      // Take requested number of stores
      final recommendedStores = availableStores.take(limit).toList();

      // Update recently shown stores
      await _updateRecentlyShownStores(
        preferences,
        recommendedStores.map((s) => s.id).toList(),
      );

      return recommendedStores;
    } catch (e) {
      // Error getting recommended stores
      return await _getRandomStores(limit);
    }
  }

  // Filter stores based on user preferences
  List<StoreModel> _filterStoresByPreferences(
      List<StoreModel> stores, SimpleUserPreferences preferences) {
    return stores.where((store) {
      // Filter by shopping preference (men/women/both)
      if (preferences.shoppingFor != null &&
          preferences.shoppingFor != 'both') {
        // Simple matching based on store name and description
        final storeName = store.name.toLowerCase();
        final storeDescription = store.description.toLowerCase();
        final storeText = '$storeName $storeDescription';

        if (preferences.shoppingFor == 'men') {
          if (storeText.contains('women') && !storeText.contains('men')) {
            return false;
          }
        } else if (preferences.shoppingFor == 'women') {
          if (storeText.contains('men') && !storeText.contains('women')) {
            return false;
          }
        }
      }

      // Filter by interests (match against store name and description)
      if (preferences.interests.isNotEmpty) {
        final storeName = store.name.toLowerCase();
        final storeDescription = store.description.toLowerCase();
        final storeText = '$storeName $storeDescription';

        final hasMatchingInterest = preferences.interests.any((interest) =>
            storeText.contains(interest.toLowerCase()) ||
            interest.toLowerCase().contains(storeName) ||
            interest.toLowerCase().contains(storeDescription));

        return hasMatchingInterest;
      }

      return true;
    }).toList();
  }

  // Get user's not interested stores
  Future<List<String>> _getNotInterestedStores() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return [];

      final userData = userDoc.data() as Map<String, dynamic>;
      return List<String>.from(userData['notInterestedStoreIds'] ?? []);
    } catch (e) {
      // Error getting not interested stores
      return [];
    }
  }

  // Get random stores as fallback
  Future<List<StoreModel>> _getRandomStores(int limit) async {
    try {
      // Get user's not interested stores to exclude them
      final notInterestedStores = await _getNotInterestedStores();

      final storesSnapshot = await _firestore
          .collection('stores')
          .where('status', isEqualTo: 'active')
          .limit(limit * 3) // Get more to ensure variety after filtering
          .get();

      final stores = storesSnapshot.docs
          .map((doc) => StoreModel.fromFirestore(doc))
          .where((store) => !notInterestedStores
              .contains(store.id)) // Exclude not interested stores
          .toList();

      stores.shuffle();
      return stores.take(limit).toList();
    } catch (e) {
      // Error getting random stores
      return [];
    }
  }

  // Update recently shown stores (keep last 20 to ensure good rotation)
  Future<void> _updateRecentlyShownStores(
    SimpleUserPreferences preferences,
    List<String> newStoreIds,
  ) async {
    final updatedRecentStores = [
      ...preferences.recentlyShownStores,
      ...newStoreIds
    ];

    // Keep only the last 20 stores to ensure good rotation
    if (updatedRecentStores.length > 20) {
      updatedRecentStores.removeRange(0, updatedRecentStores.length - 20);
    }

    final updatedPreferences = preferences.copyWith(
      recentlyShownStores: updatedRecentStores,
    );

    await saveUserPreferences(updatedPreferences);
  }
}
