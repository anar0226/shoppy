import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../utils/type_utils.dart';

/// Service for fetching actual rating data instead of using placeholder values
class RatingService {
  static final RatingService _instance = RatingService._internal();
  factory RatingService() => _instance;
  RatingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get store rating data from Firestore
  Future<StoreRatingData> getStoreRating(String storeId) async {
    try {
      // First try to get cached rating from store document
      final storeDoc = await _firestore.collection('stores').doc(storeId).get();

      if (storeDoc.exists) {
        final data = storeDoc.data() as Map<String, dynamic>;
        final averageRating = (data['averageRating'] as num?)?.toDouble();
        final totalReviews = (data['totalReviews'] as num?)?.toInt();

        if (averageRating != null && totalReviews != null && totalReviews > 0) {
          return StoreRatingData(
            rating: averageRating,
            reviewCount: totalReviews,
            reviewCountDisplay: _formatReviewCount(totalReviews),
          );
        }
      }

      // Fallback: Calculate from reviews collection
      final reviewsSnapshot = await _firestore
          .collection('stores')
          .doc(storeId)
          .collection('reviews')
          .where('status', isEqualTo: 'active')
          .get();

      if (reviewsSnapshot.docs.isEmpty) {
        return StoreRatingData.placeholder();
      }

      double totalRating = 0;
      int reviewCount = 0;

      for (final doc in reviewsSnapshot.docs) {
        final rating = (doc.data()['rating'] as num?)?.toDouble() ?? 0.0;
        if (rating > 0) {
          totalRating += rating;
          reviewCount++;
        }
      }

      final averageRating = reviewCount > 0 ? totalRating / reviewCount : 0.0;

      // Update store document with calculated rating
      if (reviewCount > 0) {
        await _firestore.collection('stores').doc(storeId).update({
          'averageRating': averageRating,
          'totalReviews': reviewCount,
          'lastRatingUpdate': FieldValue.serverTimestamp(),
        });
      }

      return StoreRatingData(
        rating: averageRating,
        reviewCount: reviewCount,
        reviewCountDisplay: _formatReviewCount(reviewCount),
      );
    } catch (e) {
      debugPrint('Error fetching store rating for $storeId: $e');
      return StoreRatingData.placeholder();
    }
  }

  /// Get multiple store ratings efficiently
  Future<Map<String, StoreRatingData>> getMultipleStoreRatings(
      List<String> storeIds) async {
    final results = <String, StoreRatingData>{};

    try {
      // Fetch in batches of 10 (Firestore limit)
      for (int i = 0; i < storeIds.length; i += 10) {
        final batch = storeIds.skip(i).take(10).toList();

        final storesSnapshot = await _firestore
            .collection('stores')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (final doc in storesSnapshot.docs) {
          final data = doc.data();
          final averageRating = (data['averageRating'] as num?)?.toDouble();
          final totalReviews = (data['totalReviews'] as num?)?.toInt();

          if (averageRating != null &&
              totalReviews != null &&
              totalReviews > 0) {
            results[doc.id] = StoreRatingData(
              rating: averageRating,
              reviewCount: totalReviews,
              reviewCountDisplay: _formatReviewCount(totalReviews),
            );
          } else {
            results[doc.id] = StoreRatingData.placeholder();
          }
        }
      }

      // Fill in any missing stores with placeholder data
      for (final storeId in storeIds) {
        if (!results.containsKey(storeId)) {
          results[storeId] = StoreRatingData.placeholder();
        }
      }
    } catch (e) {
      debugPrint('Error fetching multiple store ratings: $e');
      // Return placeholder data for all stores on error
      for (final storeId in storeIds) {
        results[storeId] = StoreRatingData.placeholder();
      }
    }

    return results;
  }

  /// Get product rating data (if products have separate ratings)
  Future<StoreRatingData> getProductRating(String productId) async {
    try {
      // For now, products inherit store ratings
      // In future, could implement separate product reviews
      final productDoc =
          await _firestore.collection('products').doc(productId).get();

      if (productDoc.exists) {
        final data = productDoc.data() as Map<String, dynamic>;
        final storeId = TypeUtils.extractStoreId(data['storeId']);

        return await getStoreRating(storeId);
            }

      return StoreRatingData.placeholder();
    } catch (e) {
      debugPrint('Error fetching product rating for $productId: $e');
      return StoreRatingData.placeholder();
    }
  }

  /// Update store rating when review is submitted
  Future<void> updateStoreRating(String storeId) async {
    try {
      final reviewsSnapshot = await _firestore
          .collection('stores')
          .doc(storeId)
          .collection('reviews')
          .where('status', isEqualTo: 'active')
          .get();

      if (reviewsSnapshot.docs.isEmpty) {
        await _firestore.collection('stores').doc(storeId).update({
          'averageRating': 0.0,
          'totalReviews': 0,
          'lastRatingUpdate': FieldValue.serverTimestamp(),
        });
        return;
      }

      double totalRating = 0;
      int reviewCount = 0;

      for (final doc in reviewsSnapshot.docs) {
        final rating = (doc.data()['rating'] as num?)?.toDouble() ?? 0.0;
        if (rating > 0) {
          totalRating += rating;
          reviewCount++;
        }
      }

      final averageRating = reviewCount > 0 ? totalRating / reviewCount : 0.0;

      await _firestore.collection('stores').doc(storeId).update({
        'averageRating': averageRating,
        'totalReviews': reviewCount,
        'lastRatingUpdate': FieldValue.serverTimestamp(),
      });

      debugPrint(
          'Updated store $storeId rating: $averageRating ($reviewCount reviews)');
    } catch (e) {
      debugPrint('Error updating store rating for $storeId: $e');
    }
  }

  /// Format review count for display (e.g., "1.2K" for 1200 reviews)
  String _formatReviewCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }
}

/// Data class for store rating information
class StoreRatingData {
  final double rating;
  final int reviewCount;
  final String reviewCountDisplay;

  StoreRatingData({
    required this.rating,
    required this.reviewCount,
    required this.reviewCountDisplay,
  });

  /// Placeholder data when no reviews exist or on error
  factory StoreRatingData.placeholder() {
    return StoreRatingData(
      rating: 0.0,
      reviewCount: 0,
      reviewCountDisplay: '0',
    );
  }

  /// Empty data (no ratings yet)
  factory StoreRatingData.empty() {
    return StoreRatingData(
      rating: 0.0,
      reviewCount: 0,
      reviewCountDisplay: 'Үнэлгээ байхгүй',
    );
  }

  /// Check if this store has any reviews
  bool get hasReviews => reviewCount > 0;

  /// Get rating display with one decimal place
  String get ratingDisplay => rating.toStringAsFixed(1);

  /// Get rating display for UI (shows "Шинэ" if no ratings)
  String get ratingForDisplay => hasReviews ? ratingDisplay : 'Шинэ';

  /// Get review count display for UI
  String get reviewCountForDisplay =>
      hasReviews ? '($reviewCountDisplay)' : '(Үнэлгээ байхгүй)';

  @override
  String toString() =>
      'StoreRatingData(rating: $rating, reviewCount: $reviewCount)';
}
