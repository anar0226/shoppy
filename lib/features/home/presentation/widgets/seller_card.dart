import 'package:flutter/material.dart';
import '../../domain/models.dart';
import '../../../following/services/following_service.dart';

class SellerCard extends StatelessWidget {
  final String sellerName;
  final String profileLetter;
  final double rating;
  final int reviews;
  final List<SellerProduct> products;
  final VoidCallback? onShopAllTap;
  final String? storeId;
  final String? backgroundImageUrl;
  final String? storeLogoUrl; // Added store logo URL parameter
  final bool isRecommended; // Added recommended flag

  const SellerCard({
    super.key,
    required this.sellerName,
    required this.profileLetter,
    required this.rating,
    required this.reviews,
    required this.products,
    this.onShopAllTap,
    this.storeId,
    this.backgroundImageUrl,
    this.storeLogoUrl, // Added store logo URL parameter
    this.isRecommended = false, // Default to false
  });

  // Debounce mechanism to prevent spam tapping
  static DateTime? _lastTapTime;
  static const Duration _debounceDuration = Duration(milliseconds: 500);

  void _handleStoreNavigation(BuildContext context) {
    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) < _debounceDuration) {
      return; // Ignore rapid taps
    }
    _lastTapTime = now;

    if (onShopAllTap != null) {
      onShopAllTap!();
    } else {
      Navigator.pushNamed(context, '/store/${sellerName.toLowerCase()}');
    }
  }

  // Create a closure that captures the context for GestureDetector
  VoidCallback _createNavigationCallback(BuildContext context) {
    return () => _handleStoreNavigation(context);
  }

  void _showOptionsMenu(BuildContext context) {
    if (storeId == null) return;

    showModalBottomSheet(
      context: context,
      builder: (BuildContext modalContext) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.report_outlined, color: Colors.red),
              title: const Text('Рэпорт хийх'),
              onTap: () {
                Navigator.pop(modalContext);
                _showReportDialog(context);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.thumb_down_outlined, color: Colors.orange),
              title: const Text('Таалагдаxгүй байна'),
              onTap: () {
                Navigator.pop(modalContext);
                _handleNotInterested(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _ReportDialog(storeId: storeId!),
    );
  }

  void _handleNotInterested(BuildContext context) async {
    try {
      // Check if storeId is valid before proceeding
      if (storeId == null || storeId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Алдаа гарлаа: Дэлгүүрийн мэдээлэл олдсонгүй'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final success = await FollowingService().markNotInterested(storeId!);

      if (success) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Таныд дахиж энэ дэлгүүрийг санал болгоxгүй :)'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Алдаа гарлаа. Дахин оролдоно уу.'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Алдаа гарлаа: $error'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            // Background image with tap navigation
            if (backgroundImageUrl != null && backgroundImageUrl!.isNotEmpty)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _createNavigationCallback(context),
                  child: Image.network(
                    backgroundImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(color: Colors.white);
                    },
                  ),
                ),
              ),

            // Fallback background color with tap navigation
            if (backgroundImageUrl == null || backgroundImageUrl!.isEmpty)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _createNavigationCallback(context),
                  child: Container(color: Colors.white),
                ),
              ),

            // Content overlay - reduced opacity to show background
            GestureDetector(
              onTap: _createNavigationCallback(context),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white
                          .withValues(alpha: 0.3), // Reduced from 0.95 to 0.3
                      Colors.white
                          .withValues(alpha: 0.7), // Reduced from 0.98 to 0.7
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Seller Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Square store profile picture
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: const Color(0xFF444444),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: storeLogoUrl != null &&
                                      storeLogoUrl!.isNotEmpty
                                  ? Image.network(
                                      storeLogoUrl!,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          width: 48,
                                          height: 48,
                                          color: const Color(0xFF444444),
                                          child: Center(
                                            child: Text(
                                              profileLetter,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 22,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  : Container(
                                      width: 48,
                                      height: 48,
                                      color: const Color(0xFF444444),
                                      child: Center(
                                        child: Text(
                                          profileLetter,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 22,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sellerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                    color: Color(0xFF4285F4),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      rating.toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Color(0xFF4285F4),
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(Icons.star,
                                        color: Color(0xFF4285F4), size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      '($reviews)',
                                      style: const TextStyle(
                                        color: Color(0xFF4285F4),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _showOptionsMenu(context),
                            child: const Icon(Icons.more_horiz,
                                color: Colors.black54, size: 28),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Product Grid
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: products.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 18,
                          crossAxisSpacing: 18,
                          childAspectRatio: 1,
                        ),
                        itemBuilder: (context, i) {
                          final p = products[i];
                          return SellerProductCard(
                            imageUrl: p.imageUrl,
                            price: p.price,
                            productId: p.id,
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      // Shop all row
                      Row(
                        children: [
                          const Text(
                            'Дэлгүүрээр зочилоx',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                              color: Color(0xFF4285F4),
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: onShopAllTap ??
                                () {
                                  Navigator.pushNamed(context,
                                      '/store/${sellerName.toLowerCase()}');
                                },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade700.withValues(
                                    alpha: 0.8), // Dark grey with opacity
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(
                                  9), // Reduced from 14 to 9 (2/3 size)
                              child: const Icon(Icons.arrow_forward,
                                  size: 20,
                                  color: Colors
                                      .white), // Reduced size from 24 to 20 and changed color to white
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Removed recommended badge for production
          ],
        ),
      ),
    );
  }
}

class _ReportDialog extends StatefulWidget {
  final String storeId;

  const _ReportDialog({required this.storeId});

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String _selectedReason = 'Inappropriate content';
  final TextEditingController _additionalInfoController =
      TextEditingController();

  final List<String> _reportReasons = [
    'Зохисгүй контент',
    'Бүтэгдэхүүн зураг шигээ ирээгүй',
    'спам',
    'Харилцагчийн үйлчилгээ муу',
    'Бусад',
  ];

  @override
  void dispose() {
    _additionalInfoController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    final success = await FollowingService().reportStore(
      widget.storeId,
      _selectedReason,
      additionalInfo: _additionalInfoController.text.trim(),
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Рэпорт амжилттай илгээгдлээ'
              : 'Рэпорт илгээхэд алдаа гарлаа. Дахин оролдоно уу.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Дэлгүүрийг Рэпорт хийх'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Рэпорт хийх шалтгаан'),
            const SizedBox(height: 16),
            ...(_reportReasons.map((reason) => RadioListTile<String>(
                  title: Text(reason),
                  value: reason,
                  groupValue: _selectedReason,
                  onChanged: (value) {
                    setState(() {
                      _selectedReason = value!;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ))),
            const SizedBox(height: 16),
            const Text('нэмэлт мэдээлэл (заавал биш)'),
            const SizedBox(height: 8),
            TextField(
              controller: _additionalInfoController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Дэлгүүрийн талаарх мэдээлэл оруулна уу:',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Цуцлах'),
        ),
        ElevatedButton(
          onPressed: _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Рэпорт илгээх'),
        ),
      ],
    );
  }
}

class SellerProductCard extends StatefulWidget {
  final String imageUrl;
  final String price;
  final String? productId;
  const SellerProductCard({
    super.key,
    required this.imageUrl,
    required this.price,
    this.productId,
  });
  @override
  State<SellerProductCard> createState() => _SellerProductCardState();
}

class _SellerProductCardState extends State<SellerProductCard> {
  bool isFavorite = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigate to product page
        if (widget.productId != null) {
          Navigator.pushNamed(context, '/product/${widget.productId}');
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background image filling the entire card
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: Image.network(
                  widget.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFFF5F5F5),
                      child: const Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                        size: 50,
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: const Color(0xFFF5F5F5),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Price tag
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEEEE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.price,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            // Heart icon without circular outline
            Positioned(
              bottom: 12,
              right: 12,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    isFavorite = !isFavorite;
                  });
                },
                child: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite
                      ? const Color(0xFF4285F4)
                      : const Color(0xFF4285F4),
                  size: 28,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
