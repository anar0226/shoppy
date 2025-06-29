import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../services/reviews_service.dart';

class ReviewSubmissionDialog extends StatefulWidget {
  final String storeId;
  final String storeName;
  final String? orderId;

  const ReviewSubmissionDialog({
    Key? key,
    required this.storeId,
    required this.storeName,
    this.orderId,
  }) : super(key: key);

  @override
  State<ReviewSubmissionDialog> createState() => _ReviewSubmissionDialogState();
}

class _ReviewSubmissionDialogState extends State<ReviewSubmissionDialog> {
  final _reviewsService = ReviewsService();
  final _titleController = TextEditingController();
  final _commentController = TextEditingController();

  double _rating = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _showPopupMessage({
    required String title,
    required String message,
    required bool isSuccess,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                color: isSuccess ? Colors.green : Colors.red,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isSuccess ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (isSuccess) {
                  // Close the review dialog after success popup is dismissed
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('Хаах'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitReview() async {
    if (_rating == 0) {
      _showPopupMessage(
        title: 'Алдаа',
        message: '1-5 хооронд үнэлгээ сонгоно уу',
        isSuccess: false,
      );
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      _showPopupMessage(
        title: 'Алдаа',
        message: 'Үнэлгээний гарчиг оруулна уу',
        isSuccess: false,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final success = await _reviewsService.submitReview(
        storeId: widget.storeId,
        rating: _rating,
        title: _titleController.text.trim(),
        comment: _commentController.text.trim(),
        orderId: widget.orderId,
      );

      if (success) {
        if (mounted) {
          _showPopupMessage(
            title: 'Амжилттай',
            message: 'Үнэлгээ амжилттай илгээгдлээ',
            isSuccess: true,
          );
        }
      } else {
        throw Exception('Үнэлгээ илгээх үед алдаа гарлаа');
      }
    } catch (e) {
      if (mounted) {
        _showPopupMessage(
          title: 'Алдаа',
          message: 'Үнэлгээ илгээх үед алдаа гарлаа: ${e.toString()}',
          isSuccess: false,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Үнэлгээ ${widget.storeName}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Rating section
            const Text(
              'Таны үнэлгээ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: RatingBar.builder(
                initialRating: _rating,
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: false,
                itemCount: 5,
                itemSize: 40,
                itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                itemBuilder: (context, _) => const Icon(
                  Icons.star,
                  color: Colors.amber,
                ),
                onRatingUpdate: (rating) {
                  setState(() => _rating = rating);
                },
              ),
            ),

            const SizedBox(height: 24),

            // Title field
            const Text(
              'Үнэлгээний гарчиг',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'Үнэлгээний гарчиг оруулна уу',
                border: OutlineInputBorder(),
              ),
              maxLength: 100,
            ),

            const SizedBox(height: 16),

            // Comment field
            const Text(
              'Таны үнэлгээ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                hintText: 'Та үнэлгээгээ тодорхойлно уу...',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              maxLength: 500,
            ),

            if (widget.orderId != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified,
                        color: Colors.green.shade600, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Баталгаажсан дэлгүүр',
                      style: TextStyle(
                        color: Colors.green.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Цуцалгах'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitReview,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Илгээх'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
