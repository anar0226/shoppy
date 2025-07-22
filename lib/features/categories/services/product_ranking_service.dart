import 'package:cloud_firestore/cloud_firestore.dart';
import '../../products/models/product_model.dart';
import '../../../core/services/database_service.dart';

import 'dart:developer';

/// Product ranking service that implements e-commerce best practices
/// for determining product display order in category pages
class ProductRankingService {
  final DatabaseService _db = DatabaseService();

  /// Ranking factors and their weights (industry standard)
  static const Map<String, double> _rankingWeights = {
    'featured': 1.0, // Featured products get highest priority
    'sales_performance': 0.8, // Units sold, conversion rate
    'engagement': 0.6, // Views, clicks, time on page
    'recency': 0.4, // Newest products
    'inventory': 0.3, // In-stock products
    'price_competitiveness': 0.2, // Competitive pricing
    'reviews': 0.2, // Rating and review count
    'store_performance': 0.1, // Store rating, fulfillment
  };

  /// Get ranked products for a category with smart ordering
  Future<List<ProductModel>> getRankedProducts({
    String? category,
    String? subCategory,
    String? leafCategory,
    int limit = 20,
    String? userId, // For personalization
  }) async {
    try {
      log('🔍 Getting ranked products for category: $category, sub: $subCategory, leaf: $leafCategory');

      // Step 1: Load all products for the category
      final allProducts = await _loadCategoryProducts(
        category: category,
        subCategory: subCategory,
        leafCategory: leafCategory,
        limit: limit * 2, // Get more to have variety for ranking
      );

      if (allProducts.isEmpty) {
        log('📋 No products found for category');
        return [];
      }

      // Step 2: Load featured products for this category
      final featuredProducts = await _loadFeaturedProducts(
        category: category,
        subCategory: subCategory,
        leafCategory: leafCategory,
      );

      // Step 3: Calculate ranking scores for each product
      final rankedProducts = await _calculateProductRankings(
        products: allProducts,
        featuredProducts: featuredProducts,
        userId: userId,
      );

      // Step 4: Sort by ranking score and return top results
      rankedProducts.sort((a, b) => b.rankingScore.compareTo(a.rankingScore));

      final result = rankedProducts.take(limit).map((p) => p.product).toList();
      log('✅ Returned ${result.length} ranked products');

      return result;
    } catch (e) {
      log('❌ Error getting ranked products: $e');
      return [];
    }
  }

  /// Load products for a specific category
  Future<List<ProductModel>> _loadCategoryProducts({
    String? category,
    String? subCategory,
    String? leafCategory,
    int limit = 40,
  }) async {
    try {
      Query query = _db.firestore.collectionGroup('products');

      // Apply category filters
      if (leafCategory != null && leafCategory.isNotEmpty) {
        query = query.where('leafCategory', isEqualTo: leafCategory);
      } else if (subCategory != null && subCategory.isNotEmpty) {
        query = query.where('subCategory', isEqualTo: subCategory);
      } else if (category != null && category.isNotEmpty) {
        query = query.where('category', isEqualTo: category);
      }

      // Only active products
      query = query.where('isActive', isEqualTo: true);

      // Order by creation date for initial load
      query = query.orderBy('createdAt', descending: true).limit(limit);

      final querySnapshot = await query.get();
      final products = querySnapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc))
          .toList();

      log('📋 Loaded ${products.length} products for ranking');
      return products;
    } catch (e) {
      log('❌ Error loading category products: $e');
      return [];
    }
  }

  /// Load featured products for the category
  Future<List<String>> _loadFeaturedProducts({
    String? category,
    String? subCategory,
    String? leafCategory,
  }) async {
    try {
      // Build featured products path
      String featuredPath = category ?? '';
      if (subCategory != null) featuredPath += '_$subCategory';
      if (leafCategory != null) featuredPath += '_$leafCategory';

      final featuredDoc =
          await _db.firestore.doc('featured_products/$featuredPath').get();

      if (featuredDoc.exists) {
        final data = featuredDoc.data() as Map<String, dynamic>;
        return List<String>.from(data['productIds'] ?? []);
      }

      return [];
    } catch (e) {
      log('❌ Error loading featured products: $e');
      return [];
    }
  }

  /// Calculate ranking scores for products
  Future<List<RankedProduct>> _calculateProductRankings({
    required List<ProductModel> products,
    required List<String> featuredProducts,
    String? userId,
  }) async {
    final rankedProducts = <RankedProduct>[];

    for (final product in products) {
      try {
        final rankingScore = await _calculateProductScore(
          product: product,
          isFeatured: featuredProducts.contains(product.id),
          userId: userId,
        );

        rankedProducts.add(RankedProduct(
          product: product,
          rankingScore: rankingScore,
        ));
      } catch (e) {
        log('❌ Error calculating score for product ${product.id}: $e');
        // Add product with default score
        rankedProducts.add(RankedProduct(
          product: product,
          rankingScore: 0.1,
        ));
      }
    }

    return rankedProducts;
  }

  /// Calculate individual product ranking score
  Future<double> _calculateProductScore({
    required ProductModel product,
    required bool isFeatured,
    String? userId,
  }) async {
    double totalScore = 0.0;

    // 1. Featured products get highest priority
    if (isFeatured) {
      totalScore += _rankingWeights['featured']!;
    }

    // 2. Sales performance (if available)
    final salesScore = await _calculateSalesScore(product.id);
    totalScore += salesScore * _rankingWeights['sales_performance']!;

    // 3. Engagement metrics (if available)
    final engagementScore = await _calculateEngagementScore(product.id);
    totalScore += engagementScore * _rankingWeights['engagement']!;

    // 4. Recency score (newer products get higher score)
    final recencyScore = _calculateRecencyScore(product.createdAt);
    totalScore += recencyScore * _rankingWeights['recency']!;

    // 5. Inventory score (in-stock products preferred)
    final inventoryScore = _calculateInventoryScore(product.stock);
    totalScore += inventoryScore * _rankingWeights['inventory']!;

    // 6. Price competitiveness
    final priceScore = await _calculatePriceCompetitivenessScore(product);
    totalScore += priceScore * _rankingWeights['price_competitiveness']!;

    // 7. Review score
    final reviewScore =
        _calculateReviewScore(product.reviewStars, product.reviewCount);
    totalScore += reviewScore * _rankingWeights['reviews']!;

    // 8. Store performance score
    final storeScore = await _calculateStorePerformanceScore(product.storeId);
    totalScore += storeScore * _rankingWeights['store_performance']!;

    return totalScore;
  }

  /// Calculate sales performance score
  Future<double> _calculateSalesScore(String productId) async {
    try {
      // Get recent orders for this product (last 30 days)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

      final ordersSnapshot = await _db.firestore
          .collection('orders')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      int unitsSold = 0;
      // ignore: unused_local_variable
      double totalRevenue = 0.0;

      for (final orderDoc in ordersSnapshot.docs) {
        final orderData = orderDoc.data();
        final items = orderData['items'] as List<dynamic>? ?? [];

        for (final item in items) {
          if (item['productId'] == productId) {
            final quantity = (item['quantity'] ?? 0) as int;
            final price = (item['price'] ?? 0).toDouble();

            unitsSold += quantity;
            totalRevenue += price * quantity;
          }
        }
      }

      // Normalize sales score (0-1 scale)
      // Higher sales = higher score
      final salesScore =
          unitsSold > 0 ? (unitsSold / 100.0).clamp(0.0, 1.0) : 0.0;

      return salesScore;
    } catch (e) {
      log('❌ Error calculating sales score: $e');
      return 0.0;
    }
  }

  /// Calculate engagement score
  Future<double> _calculateEngagementScore(String productId) async {
    try {
      // Get product views and interactions (if tracking is implemented)
      // Note: We can't use doc() on collectionGroup query, so we'll use a different approach
      final productQuery = await _db.firestore
          .collectionGroup('products')
          .where(FieldPath.documentId, isEqualTo: productId)
          .limit(1)
          .get();

      if (productQuery.docs.isNotEmpty) {
        final productDoc = productQuery.docs.first;
        final data = productDoc.data();
        final views = data['views'] ?? 0;
        final clicks = data['clicks'] ?? 0;

        // Simple engagement score based on views and clicks
        final engagementScore = ((views + clicks * 2) / 100.0).clamp(0.0, 1.0);
        return engagementScore;
      }

      return 0.0;
    } catch (e) {
      log('❌ Error calculating engagement score: $e');
      return 0.0;
    }
  }

  /// Calculate recency score
  double _calculateRecencyScore(DateTime createdAt) {
    final daysSinceCreation = DateTime.now().difference(createdAt).inDays;

    // Newer products get higher scores
    // Products less than 7 days old get full score
    // Products older than 90 days get minimum score
    if (daysSinceCreation <= 7) return 1.0;
    if (daysSinceCreation >= 90) return 0.1;

    // Linear decay between 7 and 90 days
    return 1.0 - ((daysSinceCreation - 7) / 83.0) * 0.9;
  }

  /// Calculate inventory score
  double _calculateInventoryScore(int stock) {
    if (stock <= 0) return 0.0; // Out of stock
    if (stock >= 10) return 1.0; // Well stocked

    // Linear scale for low stock
    return stock / 10.0;
  }

  /// Calculate price competitiveness score
  Future<double> _calculatePriceCompetitivenessScore(
      ProductModel product) async {
    try {
      // Get average price for similar products in the same category
      final similarProductsQuery = await _db.firestore
          .collectionGroup('products')
          .where('category', isEqualTo: product.category)
          .where('isActive', isEqualTo: true)
          .get();

      if (similarProductsQuery.docs.isEmpty) return 0.5; // Default score

      double totalPrice = 0.0;
      int productCount = 0;

      for (final doc in similarProductsQuery.docs) {
        final data = doc.data();
        final price = (data['price'] ?? 0).toDouble();
        if (price > 0) {
          totalPrice += price;
          productCount++;
        }
      }

      if (productCount == 0) return 0.5;

      final averagePrice = totalPrice / productCount;
      final priceRatio = product.price / averagePrice;

      // Products priced at or below average get higher scores
      if (priceRatio <= 1.0) return 1.0;
      if (priceRatio >= 2.0) return 0.0;

      // Linear decay for overpriced products
      return 1.0 - (priceRatio - 1.0);
    } catch (e) {
      log('❌ Error calculating price competitiveness: $e');
      return 0.5;
    }
  }

  /// Calculate review score
  double _calculateReviewScore(double stars, int reviewCount) {
    if (reviewCount == 0) return 0.0;

    // Combine rating and review count
    final ratingScore = stars / 5.0; // Normalize to 0-1
    final countScore = (reviewCount / 100.0).clamp(0.0, 1.0); // Normalize count

    // Weighted average: 70% rating, 30% count
    return (ratingScore * 0.7) + (countScore * 0.3);
  }

  /// Calculate store performance score
  Future<double> _calculateStorePerformanceScore(String storeId) async {
    try {
      final storeDoc =
          await _db.firestore.collection('stores').doc(storeId).get();

      if (!storeDoc.exists) return 0.5;

      final data = storeDoc.data()!;

      // Get store rating
      final rating = (data['rating'] ?? 0.0).toDouble();
      final ratingScore = rating / 5.0; // Normalize to 0-1

      // Get store status
      final isActive = data['isActive'] ?? true;
      final statusScore = isActive ? 1.0 : 0.0;

      // Combine factors
      return (ratingScore * 0.8) + (statusScore * 0.2);
    } catch (e) {
      log('❌ Error calculating store performance: $e');
      return 0.5;
    }
  }
}

/// Wrapper class for ranked products
class RankedProduct {
  final ProductModel product;
  final double rankingScore;

  RankedProduct({
    required this.product,
    required this.rankingScore,
  });
}
