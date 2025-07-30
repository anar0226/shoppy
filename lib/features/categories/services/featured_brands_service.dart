import '../../../core/services/database_service.dart';

/// Service for managing featured brands within categories
class FeaturedBrandsService {
  final DatabaseService _db = DatabaseService();

  /// Load featured brand IDs for a specific category path
  Future<List<String>> getFeaturedBrandIds({
    String? category,
    String? subCategory,
    String? leafCategory,
  }) async {
    try {
      // Build featured brands path
      String featuredPath = category ?? '';
      if (subCategory != null) featuredPath += '_$subCategory';
      if (leafCategory != null) featuredPath += '_$leafCategory';

      final featuredDoc =
          await _db.firestore.doc('featured_brands/$featuredPath').get();

      if (featuredDoc.exists) {
        final data = featuredDoc.data() as Map<String, dynamic>;
        return List<String>.from(data['storeIds'] ?? []);
      }

      return [];
    } catch (e) {
      // Log error but don't throw - return empty list as fallback
      return [];
    }
  }

  /// Load featured brand details for a specific category path
  Future<List<Map<String, dynamic>>> getFeaturedBrands({
    String? category,
    String? subCategory,
    String? leafCategory,
  }) async {
    try {
      final brandIds = await getFeaturedBrandIds(
        category: category,
        subCategory: subCategory,
        leafCategory: leafCategory,
      );

      if (brandIds.isEmpty) return [];

      // Load store details for the featured brand IDs
      final stores = <Map<String, dynamic>>[];

      for (final storeId in brandIds) {
        try {
          final storeDoc =
              await _db.firestore.collection('stores').doc(storeId).get();
          if (storeDoc.exists) {
            stores.add({
              'id': storeDoc.id,
              ...storeDoc.data()!,
            });
          }
        } catch (e) {
          // Skip individual store if there's an error
          continue;
        }
      }

      return stores;
    } catch (e) {
      // Log error but don't throw - return empty list as fallback
      return [];
    }
  }

  /// Check if a store is featured in a specific category
  Future<bool> isStoreFeatured({
    required String storeId,
    String? category,
    String? subCategory,
    String? leafCategory,
  }) async {
    try {
      final featuredIds = await getFeaturedBrandIds(
        category: category,
        subCategory: subCategory,
        leafCategory: leafCategory,
      );

      return featuredIds.contains(storeId);
    } catch (e) {
      return false;
    }
  }

  /// Get all featured brands across all categories
  Future<Map<String, List<String>>> getAllFeaturedBrands() async {
    try {
      final featuredDocs =
          await _db.firestore.collection('featured_brands').get();

      final result = <String, List<String>>{};

      for (final doc in featuredDocs.docs) {
        final data = doc.data();
        final storeIds = List<String>.from(data['storeIds'] ?? []);
        if (storeIds.isNotEmpty) {
          result[doc.id] = storeIds;
        }
      }

      return result;
    } catch (e) {
      return {};
    }
  }
}
