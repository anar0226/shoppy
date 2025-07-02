import 'package:cloud_firestore/cloud_firestore.dart';
import '../../products/models/product_model.dart';

class CategoryProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Load products based on category hierarchy
  /// [category] - Main category (e.g., "Men", "Women", "Electronics")
  /// [subCategory] - Subcategory (e.g., "Clothing", "Shoes")
  /// [leafCategory] - Leaf category (e.g., "T-Shirts", "Sneakers")
  /// [limit] - Maximum number of products to return
  Future<List<ProductModel>> loadProductsByCategory({
    String? category,
    String? subCategory,
    String? leafCategory,
    int limit = 20,
  }) async {
    try {
      print(
          '🔍 Loading products for category: $category, subcategory: $subCategory, leaf: $leafCategory');

      Query query = _firestore.collectionGroup('products');

      // Add filters based on available parameters
      if (leafCategory != null && leafCategory.isNotEmpty) {
        query = query.where('leafCategory', isEqualTo: leafCategory);
      } else if (subCategory != null && subCategory.isNotEmpty) {
        query = query.where('subCategory', isEqualTo: subCategory);
      } else if (category != null && category.isNotEmpty) {
        query = query.where('category', isEqualTo: category);
      }

      // Only include active products
      query = query.where('isActive', isEqualTo: true);

      // Order by creation date (newest first) and limit results
      query = query.orderBy('createdAt', descending: true).limit(limit);

      final querySnapshot = await query.get();
      print('📋 Found ${querySnapshot.docs.length} products');

      final products = querySnapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc))
          .toList();

      return products;
    } catch (e) {
      print('❌ Error loading products by category: $e');

      // Fallback: try loading by simple category field if categorization fields don't exist
      return await _loadProductsByCategoryFallback(
        category: category,
        subCategory: subCategory,
        leafCategory: leafCategory,
        limit: limit,
      );
    }
  }

  /// Fallback method that uses the older 'category' field
  Future<List<ProductModel>> _loadProductsByCategoryFallback({
    String? category,
    String? subCategory,
    String? leafCategory,
    int limit = 20,
  }) async {
    try {
      print('🔄 Using fallback category loading method');

      Query query = _firestore.collectionGroup('products');

      // Use the basic category field for filtering
      if (leafCategory != null && leafCategory.isNotEmpty) {
        query = query.where('category', isEqualTo: leafCategory);
      } else if (subCategory != null && subCategory.isNotEmpty) {
        query = query.where('category', isEqualTo: subCategory);
      } else if (category != null && category.isNotEmpty) {
        query = query.where('category', isEqualTo: category);
      }

      // Only include active products
      query = query.where('isActive', isEqualTo: true);

      // Order by creation date and limit results
      query = query.orderBy('createdAt', descending: true).limit(limit);

      final querySnapshot = await query.get();
      print('📋 Fallback found ${querySnapshot.docs.length} products');

      final products = querySnapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc))
          .toList();

      return products;
    } catch (e) {
      print('❌ Error in fallback category loading: $e');
      return [];
    }
  }

  /// Load products that match any of the given category terms (for broader search)
  Future<List<ProductModel>> loadProductsByTerms({
    required List<String> searchTerms,
    int limit = 20,
  }) async {
    try {
      print('🔍 Loading products matching terms: $searchTerms');

      final allProducts = <ProductModel>[];
      final processedIds = <String>{};

      for (final term in searchTerms) {
        if (term.isEmpty) continue;

        try {
          // Search in category field
          final categoryQuery = await _firestore
              .collectionGroup('products')
              .where('category', isEqualTo: term)
              .where('isActive', isEqualTo: true)
              .orderBy('createdAt', descending: true)
              .limit(limit ~/ searchTerms.length +
                  2) // Distribute limit across terms
              .get();

          for (final doc in categoryQuery.docs) {
            if (!processedIds.contains(doc.id)) {
              allProducts.add(ProductModel.fromFirestore(doc));
              processedIds.add(doc.id);
            }
          }

          // Search in subCategory field (if available)
          try {
            final subCategoryQuery = await _firestore
                .collectionGroup('products')
                .where('subCategory', isEqualTo: term)
                .where('isActive', isEqualTo: true)
                .orderBy('createdAt', descending: true)
                .limit(limit ~/ searchTerms.length + 2)
                .get();

            for (final doc in subCategoryQuery.docs) {
              if (!processedIds.contains(doc.id)) {
                allProducts.add(ProductModel.fromFirestore(doc));
                processedIds.add(doc.id);
              }
            }
          } catch (e) {
            // Ignore if subCategory field doesn't exist
          }

          // Search in leafCategory field (if available)
          try {
            final leafCategoryQuery = await _firestore
                .collectionGroup('products')
                .where('leafCategory', isEqualTo: term)
                .where('isActive', isEqualTo: true)
                .orderBy('createdAt', descending: true)
                .limit(limit ~/ searchTerms.length + 2)
                .get();

            for (final doc in leafCategoryQuery.docs) {
              if (!processedIds.contains(doc.id)) {
                allProducts.add(ProductModel.fromFirestore(doc));
                processedIds.add(doc.id);
              }
            }
          } catch (e) {
            // Ignore if leafCategory field doesn't exist
          }
        } catch (e) {
          print('❌ Error searching for term "$term": $e');
        }
      }

      // Sort by creation date (newest first) and limit
      allProducts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final result = allProducts.take(limit).toList();
      print('📋 Found ${result.length} total products matching terms');

      return result;
    } catch (e) {
      print('❌ Error loading products by terms: $e');
      return [];
    }
  }

  /// Load all active products (fallback when no category filters work)
  Future<List<ProductModel>> loadAllActiveProducts({int limit = 20}) async {
    try {
      print('🔍 Loading all active products as fallback');

      final query = await _firestore
          .collectionGroup('products')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final products =
          query.docs.map((doc) => ProductModel.fromFirestore(doc)).toList();

      print('📋 Found ${products.length} active products');
      return products;
    } catch (e) {
      print('❌ Error loading all active products: $e');
      return [];
    }
  }
}
