import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/review_model.dart';
import '../../../core/services/error_handler_service.dart';

class ReviewsService {
  static final ReviewsService _instance = ReviewsService._internal();
  factory ReviewsService() => _instance;
  ReviewsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Submit a new review for a store
  Future<bool> submitReview({
    required String storeId,
    required double rating,
    required String title,
    required String comment,
    List<String> images = const [],
    String? orderId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get user profile data
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      final reviewData = ReviewModel(
        id: '', // Will be set by Firestore
        storeId: storeId,
        userId: user.uid,
        userName: userData['name'] ?? user.displayName ?? 'Anonymous',
        userAvatar: userData['profilePicture'] ?? user.photoURL ?? '',
        rating: rating,
        title: title,
        comment: comment,
        images: images,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isVerified: orderId != null,
        orderId: orderId,
        status: ReviewStatus.active,
      );

      // Add review to store's reviews subcollection
      await _firestore
          .collection('stores')
          .doc(storeId)
          .collection('reviews')
          .add(reviewData.toFirestore());

      // Update store's aggregate rating
      await _updateStoreAggregateRating(storeId);

      // Add analytics event
      await _firestore.collection('analytics_events').add({
        'type': 'review_submitted',
        'userId': user.uid,
        'storeId': storeId,
        'rating': rating,
        'hasComment': comment.isNotEmpty,
        'hasImages': images.isNotEmpty,
        'isVerified': orderId != null,
        'timestamp': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      await ErrorHandlerService.instance.handleError(
        operation: 'submit_review',
        error: e,
        showUserMessage: false,
        logError: true,
        fallbackValue: false,
      );
      return false;
    }
  }

  /// Get reviews for a store with pagination
  Future<List<ReviewModel>> getStoreReviews({
    required String storeId,
    int limit = 20,
    DocumentSnapshot? lastDocument,
    ReviewSortOrder sortOrder = ReviewSortOrder.newest,
    ReviewFilter filter = ReviewFilter.all,
  }) async {
    try {
      Query query = _firestore
          .collection('stores')
          .doc(storeId)
          .collection('reviews')
          .where('status', isEqualTo: ReviewStatus.active.name);

      // Apply filters
      switch (filter) {
        case ReviewFilter.verified:
          query = query.where('isVerified', isEqualTo: true);
          break;
        case ReviewFilter.withImages:
          query = query.where('images', isNotEqualTo: []);
          break;
        case ReviewFilter.withComments:
          query = query.where('comment', isNotEqualTo: '');
          break;
        case ReviewFilter.fiveStars:
          query = query.where('rating', isEqualTo: 5.0);
          break;
        case ReviewFilter.fourStars:
          query = query.where('rating', isEqualTo: 4.0);
          break;
        case ReviewFilter.threeStars:
          query = query.where('rating', isEqualTo: 3.0);
          break;
        case ReviewFilter.twoStars:
          query = query.where('rating', isEqualTo: 2.0);
          break;
        case ReviewFilter.oneStar:
          query = query.where('rating', isEqualTo: 1.0);
          break;
        case ReviewFilter.all:
          break;
      }

      // Apply sorting
      switch (sortOrder) {
        case ReviewSortOrder.newest:
          query = query.orderBy('createdAt', descending: true);
          break;
        case ReviewSortOrder.oldest:
          query = query.orderBy('createdAt', descending: false);
          break;
        case ReviewSortOrder.highestRating:
          query = query.orderBy('rating', descending: true);
          break;
        case ReviewSortOrder.lowestRating:
          query = query.orderBy('rating', descending: false);
          break;
        case ReviewSortOrder.mostHelpful:
          // Note: This would require a computed field for helpfulness score
          query = query.orderBy('createdAt', descending: true);
          break;
      }

      // Apply pagination
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => ReviewModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      // Error getting store reviews
      return [];
    }
  }

  /// Get store ratings summary
  Future<StoreRatingsSummary> getStoreRatingsSummary(String storeId) async {
    try {
      final reviewsSnapshot = await _firestore
          .collection('stores')
          .doc(storeId)
          .collection('reviews')
          .where('status', isEqualTo: ReviewStatus.active.name)
          .get();

      if (reviewsSnapshot.docs.isEmpty) {
        return StoreRatingsSummary.empty();
      }

      final reviews = reviewsSnapshot.docs
          .map((doc) => ReviewModel.fromFirestore(doc))
          .toList();

      // Calculate aggregate data
      double totalRating = 0;
      final ratingDistribution = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      int verifiedReviews = 0;
      int reviewsWithImages = 0;
      int reviewsWithComments = 0;

      for (final review in reviews) {
        totalRating += review.rating;
        ratingDistribution[review.rating.round()] =
            (ratingDistribution[review.rating.round()] ?? 0) + 1;

        if (review.isVerified) verifiedReviews++;
        if (review.images.isNotEmpty) reviewsWithImages++;
        if (review.comment.isNotEmpty) reviewsWithComments++;
      }

      final averageRating = totalRating / reviews.length;

      return StoreRatingsSummary(
        averageRating: averageRating,
        totalReviews: reviews.length,
        ratingDistribution: ratingDistribution,
        verifiedReviews: verifiedReviews,
        reviewsWithImages: reviewsWithImages,
        reviewsWithComments: reviewsWithComments,
      );
    } catch (e) {
      // Error getting store ratings summary
      return StoreRatingsSummary.empty();
    }
  }

  /// Like/unlike a review
  Future<bool> toggleReviewLike(String storeId, String reviewId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final reviewRef = _firestore
          .collection('stores')
          .doc(storeId)
          .collection('reviews')
          .doc(reviewId);

      await _firestore.runTransaction((transaction) async {
        final reviewDoc = await transaction.get(reviewRef);
        if (!reviewDoc.exists) return;

        final review = ReviewModel.fromFirestore(reviewDoc);
        final likes = List<String>.from(review.likes);
        final dislikes = List<String>.from(review.dislikes);

        if (likes.contains(user.uid)) {
          likes.remove(user.uid);
        } else {
          likes.add(user.uid);
          dislikes.remove(user.uid); // Remove from dislikes if present
        }

        transaction.update(reviewRef, {
          'likes': likes,
          'dislikes': dislikes,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      return true;
    } catch (e) {
      // Error toggling review like
      return false;
    }
  }

  /// Dislike/un-dislike a review
  Future<bool> toggleReviewDislike(String storeId, String reviewId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final reviewRef = _firestore
          .collection('stores')
          .doc(storeId)
          .collection('reviews')
          .doc(reviewId);

      await _firestore.runTransaction((transaction) async {
        final reviewDoc = await transaction.get(reviewRef);
        if (!reviewDoc.exists) return;

        final review = ReviewModel.fromFirestore(reviewDoc);
        final likes = List<String>.from(review.likes);
        final dislikes = List<String>.from(review.dislikes);

        if (dislikes.contains(user.uid)) {
          dislikes.remove(user.uid);
        } else {
          dislikes.add(user.uid);
          likes.remove(user.uid); // Remove from likes if present
        }

        transaction.update(reviewRef, {
          'likes': likes,
          'dislikes': dislikes,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      return true;
    } catch (e) {
      // Error toggling review dislike
      return false;
    }
  }

  /// Store owner response to a review
  Future<bool> respondToReview({
    required String storeId,
    required String reviewId,
    required String response,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Verify user owns the store
      final storeDoc = await _firestore.collection('stores').doc(storeId).get();
      if (!storeDoc.exists || storeDoc.data()?['ownerId'] != user.uid) {
        throw Exception('Unauthorized: User does not own this store');
      }

      await _firestore
          .collection('stores')
          .doc(storeId)
          .collection('reviews')
          .doc(reviewId)
          .update({
        'storeResponse': response,
        'storeResponseAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      // Error responding to review
      return false;
    }
  }

  /// Check if user can review a store (hasn't reviewed recently)
  Future<bool> canUserReviewStore(String storeId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Check if user has reviewed this store in the last 30 days
      final recentReview = await _firestore
          .collection('stores')
          .doc(storeId)
          .collection('reviews')
          .where('userId', isEqualTo: user.uid)
          .where('createdAt',
              isGreaterThan: Timestamp.fromDate(
                  DateTime.now().subtract(const Duration(days: 30))))
          .limit(1)
          .get();

      return recentReview.docs.isEmpty;
    } catch (e) {
      // Error checking if user can review
      return false;
    }
  }

  /// Update store's aggregate rating (called after new review)
  Future<void> _updateStoreAggregateRating(String storeId) async {
    try {
      final summary = await getStoreRatingsSummary(storeId);

      await _firestore.collection('stores').doc(storeId).update({
        'averageRating': summary.averageRating,
        'totalReviews': summary.totalReviews,
        'ratingDistribution': summary.ratingDistribution,
        'lastReviewAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      await ErrorHandlerService.instance.handleError(
        operation: 'update_store_aggregate_rating',
        error: e,
        showUserMessage: false,
        logError: true,
        fallbackValue: null,
      );
    }
  }

  /// Get user's reviews
  Future<List<ReviewModel>> getUserReviews({
    String? userId,
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      final targetUserId = userId ?? _auth.currentUser?.uid;
      if (targetUserId == null) return [];

      Query query = _firestore
          .collectionGroup('reviews')
          .where('userId', isEqualTo: targetUserId)
          .where('status', isEqualTo: ReviewStatus.active.name)
          .orderBy('createdAt', descending: true);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => ReviewModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      // Error getting user reviews
      return [];
    }
  }
}

enum ReviewSortOrder {
  newest,
  oldest,
  highestRating,
  lowestRating,
  mostHelpful,
}

enum ReviewFilter {
  all,
  verified,
  withImages,
  withComments,
  fiveStars,
  fourStars,
  threeStars,
  twoStars,
  oneStar,
}
