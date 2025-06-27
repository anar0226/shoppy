import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../models/review_model.dart';
import '../services/reviews_service.dart';
import 'review_submission_dialog.dart';

class StoreReviewsSection extends StatefulWidget {
  final String storeId;
  final String storeName;

  const StoreReviewsSection({
    Key? key,
    required this.storeId,
    required this.storeName,
  }) : super(key: key);

  @override
  State<StoreReviewsSection> createState() => _StoreReviewsSectionState();
}

class _StoreReviewsSectionState extends State<StoreReviewsSection> {
  final ReviewsService _reviewsService = ReviewsService();
  List<ReviewModel> _reviews = [];
  StoreRatingsSummary? _ratingsSummary;
  bool _isLoading = true;
  bool _canUserReview = false;

  @override
  void initState() {
    super.initState();
    _loadReviewsData();
  }

  Future<void> _loadReviewsData() async {
    setState(() => _isLoading = true);

    try {
      final futures = await Future.wait([
        _reviewsService.getStoreReviews(storeId: widget.storeId, limit: 10),
        _reviewsService.getStoreRatingsSummary(widget.storeId),
        _reviewsService.canUserReviewStore(widget.storeId),
      ]);

      setState(() {
        _reviews = futures[0] as List<ReviewModel>;
        _ratingsSummary = futures[1] as StoreRatingsSummary;
        _canUserReview = futures[2] as bool;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading reviews: $e')),
        );
      }
    }
  }

  Future<void> _showReviewDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ReviewSubmissionDialog(
        storeId: widget.storeId,
        storeName: widget.storeName,
      ),
    );

    if (result == true) {
      // Refresh reviews after submission
      _loadReviewsData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_ratingsSummary == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reviews Header
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Text(
                'Reviews & Ratings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_canUserReview)
                ElevatedButton.icon(
                  onPressed: _showReviewDialog,
                  icon: const Icon(Icons.rate_review, size: 16),
                  label: const Text('Write Review'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                  ),
                ),
            ],
          ),
        ),

        // Ratings Summary
        _buildRatingsSummary(),

        // Reviews List
        if (_reviews.isNotEmpty) ...[
          const Divider(),
          ..._reviews.map((review) => _buildReviewCard(review)),
        ] else
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                'No reviews yet. Be the first to review this store!',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRatingsSummary() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // Overall rating
          Column(
            children: [
              Text(
                _ratingsSummary!.averageRatingDisplay,
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              RatingBarIndicator(
                rating: _ratingsSummary!.averageRating,
                itemBuilder: (context, index) => const Icon(
                  Icons.star,
                  color: Colors.amber,
                ),
                itemCount: 5,
                itemSize: 20.0,
              ),
              const SizedBox(height: 4),
              Text(
                '${_ratingsSummary!.totalReviewsDisplay} reviews',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),

          const SizedBox(width: 24),

          // Rating breakdown
          Expanded(
            child: Column(
              children: [
                for (int i = 5; i >= 1; i--)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      children: [
                        Text('$i ★', style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: _ratingsSummary!.getStarPercentage(i),
                            backgroundColor: Colors.grey[300],
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.amber),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(_ratingsSummary!.ratingDistribution[i] ?? 0)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(ReviewModel review) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Review header
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: review.userAvatar.isNotEmpty
                    ? NetworkImage(review.userAvatar)
                    : null,
                child: review.userAvatar.isEmpty
                    ? Text(review.userName.isNotEmpty
                        ? review.userName[0].toUpperCase()
                        : 'U')
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          review.userName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (review.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified,
                            color: Colors.green,
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                    RatingBarIndicator(
                      rating: review.rating,
                      itemBuilder: (context, index) => const Icon(
                        Icons.star,
                        color: Colors.amber,
                      ),
                      itemCount: 5,
                      itemSize: 16.0,
                    ),
                  ],
                ),
              ),
              Text(
                review.timeAgo,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Review content
          if (review.title.isNotEmpty) ...[
            Text(
              review.title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
          ],

          if (review.comment.isNotEmpty) ...[
            Text(
              review.comment,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
          ],

          // Store response
          if (review.storeResponse != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.store, color: Colors.blue.shade600, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Response from ${widget.storeName}',
                        style: TextStyle(
                          color: Colors.blue.shade600,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    review.storeResponse!,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],

          const Divider(height: 24),
        ],
      ),
    );
  }
}
