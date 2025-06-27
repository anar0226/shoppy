import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String id;
  final String storeId;
  final String userId;
  final String userName;
  final String userAvatar;
  final double rating; // 1-5 stars
  final String title;
  final String comment;
  final List<String> images; // Optional review images
  final List<String> likes; // User IDs who liked this review
  final List<String> dislikes; // User IDs who disliked this review
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isVerified; // Verified purchase review
  final String? orderId; // Associated order ID if verified
  final ReviewStatus status;
  final String? storeResponse; // Store owner response
  final DateTime? storeResponseAt;

  ReviewModel({
    required this.id,
    required this.storeId,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.rating,
    required this.title,
    required this.comment,
    this.images = const [],
    this.likes = const [],
    this.dislikes = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isVerified = false,
    this.orderId,
    this.status = ReviewStatus.active,
    this.storeResponse,
    this.storeResponseAt,
  });

  // Create from Firestore document
  factory ReviewModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReviewModel(
      id: doc.id,
      storeId: data['storeId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      userAvatar: data['userAvatar'] ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      title: data['title'] ?? '',
      comment: data['comment'] ?? '',
      images: List<String>.from(data['images'] ?? []),
      likes: List<String>.from(data['likes'] ?? []),
      dislikes: List<String>.from(data['dislikes'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isVerified: data['isVerified'] ?? false,
      orderId: data['orderId'],
      status: ReviewStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => ReviewStatus.active,
      ),
      storeResponse: data['storeResponse'],
      storeResponseAt: (data['storeResponseAt'] as Timestamp?)?.toDate(),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'storeId': storeId,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'rating': rating,
      'title': title,
      'comment': comment,
      'images': images,
      'likes': likes,
      'dislikes': dislikes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isVerified': isVerified,
      'orderId': orderId,
      'status': status.name,
      'storeResponse': storeResponse,
      'storeResponseAt':
          storeResponseAt != null ? Timestamp.fromDate(storeResponseAt!) : null,
    };
  }

  // Helper getters
  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inDays > 30) {
      return '${(diff.inDays / 30).floor()} month${(diff.inDays / 30).floor() > 1 ? 's' : ''} ago';
    } else if (diff.inDays > 0) {
      return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    } else {
      return '${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''} ago';
    }
  }

  int get helpfulScore => likes.length - dislikes.length;

  bool hasUserLiked(String userId) => likes.contains(userId);
  bool hasUserDisliked(String userId) => dislikes.contains(userId);

  // Copy with method for updates
  ReviewModel copyWith({
    String? id,
    String? storeId,
    String? userId,
    String? userName,
    String? userAvatar,
    double? rating,
    String? title,
    String? comment,
    List<String>? images,
    List<String>? likes,
    List<String>? dislikes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isVerified,
    String? orderId,
    ReviewStatus? status,
    String? storeResponse,
    DateTime? storeResponseAt,
  }) {
    return ReviewModel(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      rating: rating ?? this.rating,
      title: title ?? this.title,
      comment: comment ?? this.comment,
      images: images ?? this.images,
      likes: likes ?? this.likes,
      dislikes: dislikes ?? this.dislikes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isVerified: isVerified ?? this.isVerified,
      orderId: orderId ?? this.orderId,
      status: status ?? this.status,
      storeResponse: storeResponse ?? this.storeResponse,
      storeResponseAt: storeResponseAt ?? this.storeResponseAt,
    );
  }
}

enum ReviewStatus {
  active,
  hidden,
  flagged,
  deleted,
}

class StoreRatingsSummary {
  final double averageRating;
  final int totalReviews;
  final Map<int, int> ratingDistribution; // star -> count
  final int verifiedReviews;
  final int reviewsWithImages;
  final int reviewsWithComments;

  StoreRatingsSummary({
    required this.averageRating,
    required this.totalReviews,
    required this.ratingDistribution,
    required this.verifiedReviews,
    required this.reviewsWithImages,
    required this.reviewsWithComments,
  });

  factory StoreRatingsSummary.empty() {
    return StoreRatingsSummary(
      averageRating: 0.0,
      totalReviews: 0,
      ratingDistribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
      verifiedReviews: 0,
      reviewsWithImages: 0,
      reviewsWithComments: 0,
    );
  }

  String get averageRatingDisplay => averageRating.toStringAsFixed(1);

  String get totalReviewsDisplay {
    if (totalReviews > 1000) {
      return '${(totalReviews / 1000).toStringAsFixed(1)}K';
    }
    return totalReviews.toString();
  }

  double getStarPercentage(int star) {
    if (totalReviews == 0) return 0.0;
    return (ratingDistribution[star] ?? 0) / totalReviews;
  }
}
