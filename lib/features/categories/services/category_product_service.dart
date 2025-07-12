import 'package:cloud_firestore/cloud_firestore.dart';
import '../../products/models/product_model.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/paginated_query_service.dart';

class CategoryProductService {
  final DatabaseService _db = DatabaseService();
  final PaginatedQueryService _paginatedQuery = PaginatedQueryService();

  /// Load products based on category hierarchy with pagination
  /// [category] - Main category (e.g., "Men", "Women", "Electronics")
  /// [subCategory] - Subcategory (e.g., "Clothing", "Shoes")
  /// [leafCategory] - Leaf category (e.g., "T-Shirts", "Sneakers")
  /// [limit] - Maximum number of products to return
  /// [lastDocument] - Document to start after for pagination
  Future<List<ProductModel>> loadProductsByCategory({
    String? category,
    String? subCategory,
    String? leafCategory,
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      print(
          '🔍 Loading products for category: $category, subcategory: $subCategory, leaf: $leafCategory');

      final result = await _paginatedQuery.getPaginatedProducts(
        category: category,
        subCategory: subCategory,
        leafCategory: leafCategory,
        pageSize: limit,
        lastDocument: lastDocument,
        activeOnly: true,
      );

      print('📋 Found ${result.items.length} products');

      final products = result.items.map((item) {
        // Convert Map to ProductModel
        return ProductModel(
          id: item['id'] as String,
          name: item['name'] as String? ?? '',
          price: (item['price'] as num?)?.toDouble() ?? 0.0,
          images: List<String>.from(item['images'] as List? ?? []),
          description: item['description'] as String? ?? '',
          category: item['category'] as String? ?? '',
          storeId: item['storeId'] as String? ?? '',
          stock: item['stock'] as int? ?? 0,
          variants: (item['variants'] as List<dynamic>? ?? [])
              .map((v) => ProductVariant.fromMap(v as Map<String, dynamic>))
              .toList(),
          isActive: item['isActive'] as bool? ?? true,
          createdAt: _parseTimestamp(item['createdAt']),
          updatedAt: _parseTimestamp(item['updatedAt']),
          isDiscounted: (item['discount']?['isDiscounted']) ?? false,
          discountPercent:
              (item['discount']?['percent'] as num?)?.toDouble() ?? 0.0,
          reviewCount: (item['review']?['numberOfReviews'] as int?) ?? 0,
          reviewStars: (item['review']?['stars'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();

      return products;
    } catch (e) {
      print('❌ Error loading products by category: $e');

      // Fallback: try loading by simple category field if categorization fields don't exist
      return await _loadProductsByCategoryFallback(
        category: category,
        subCategory: subCategory,
        leafCategory: leafCategory,
        limit: limit,
        lastDocument: lastDocument,
      );
    }
  }

  /// Parse timestamp from dynamic value
  DateTime _parseTimestamp(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    if (ts is DateTime) return ts;
    return DateTime.now();
  }

  /// Fallback method that uses the older 'category' field
  Future<List<ProductModel>> _loadProductsByCategoryFallback({
    String? category,
    String? subCategory,
    String? leafCategory,
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      print('🔄 Using fallback category loading method');

      Query query = _db.firestore.collectionGroup('products');

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
          final categoryQuery = await _db.firestore
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
            final subCategoryQuery = await _db.firestore
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
            final leafCategoryQuery = await _db.firestore
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

      final query = await _db.firestore
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
