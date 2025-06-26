import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shoppy/features/products/models/product_model.dart';
import 'package:provider/provider.dart';
import 'package:shoppy/features/cart/providers/cart_provider.dart';
import 'package:shoppy/features/cart/models/cart_item.dart';
import 'package:shoppy/features/profile/providers/recently_viewed_provider.dart';
import 'package:shoppy/features/checkout/presentation/checkout_page.dart';
import 'package:shoppy/features/checkout/models/checkout_item.dart';
import 'package:shoppy/features/auth/providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shoppy/features/addresses/providers/address_provider.dart';
import 'package:shoppy/features/addresses/presentation/manage_addresses_page.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'dart:async';
import 'package:shoppy/features/stores/models/store_model.dart';
import 'package:shoppy/features/stores/presentation/store_screen.dart';
import 'package:shoppy/features/home/presentation/main_scaffold.dart';

class ProductPage extends StatefulWidget {
  final ProductModel product;
  final String storeName;
  final String storeLogoUrl;
  final double storeRating;
  final int storeRatingCount;

  const ProductPage({
    super.key,
    required this.product,
    required this.storeName,
    required this.storeLogoUrl,
    required this.storeRating,
    required this.storeRatingCount,
  });

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  // State variables
  String _selectedSize = '';
  int _quantity = 1;
  bool _isFavorite = false;
  String _storeName = '';
  String _storeLogoUrl = '';
  List<Map<String, dynamic>> _reviews = [];
  int _reviewCount = 0;
  double _avgRating = 0;
  StreamSubscription<QuerySnapshot>? _reviewSub;
  final GlobalKey _imageKey = GlobalKey();

  // Dynamic variant data
  List<Map<String, dynamic>> _availableVariants = [];
  String _variantType = '';

  @override
  void initState() {
    super.initState();

    _storeName = widget.storeName;
    _storeLogoUrl = widget.storeLogoUrl;

    // Extract variant information from product
    _extractVariantInfo();

    if (_storeName.isEmpty || _storeLogoUrl.isEmpty) {
      _fetchStoreInfo();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final recent =
          Provider.of<RecentlyViewedProvider>(context, listen: false);
      recent.add(widget.product);
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(auth.user!.uid)
          .get()
          .then((doc) {
        final saved = List<String>.from(doc.data()?['savedProductIds'] ?? []);
        if (saved.contains(widget.product.id)) {
          setState(() => _isFavorite = true);
        }
      });
    }

    // Listen to reviews
    _reviewSub = FirebaseFirestore.instance
        .collection('products')
        .doc(widget.product.id)
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      _reviews = snap.docs.map((d) => d.data()).toList();
      _reviewCount = _reviews.length;
      if (_reviewCount > 0) {
        final total =
            _reviews.fold<int>(0, (sum, r) => sum + (r['rating'] ?? 0) as int);
        _avgRating = total / _reviewCount;
      } else {
        _avgRating = 0;
      }
      if (mounted) setState(() {});
    }, onError: (e) {
      if (mounted) {
        setState(() {
          _reviews = [];
          _reviewCount = 0;
          _avgRating = 0;
        });
      }
    });
  }

  Future<void> _fetchStoreInfo() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('stores')
          .doc(widget.product.storeId)
          .get();
      if (doc.exists) {
        final store = StoreModel.fromFirestore(doc);
        if (mounted) {
          setState(() {
            if (_storeName.isEmpty) _storeName = store.name;
            if (_storeLogoUrl.isEmpty) {
              _storeLogoUrl = store.logo.isNotEmpty ? store.logo : store.banner;
            }
          });
        }
      }
    } catch (_) {}
  }

  void _extractVariantInfo() {
    _availableVariants.clear();
    _variantType = '';

    if (widget.product.variants.isEmpty) {
      return; // No variants configured for this product
    }

    // Get variant type and options from product variants
    // The admin panel stores variants differently, so we need to handle both structures
    for (final variant in widget.product.variants) {
      if (variant.name.isNotEmpty && variant.options.isNotEmpty) {
        // This is the complex ProductVariant structure from the model
        _variantType = variant.name; // "Size", "Color", etc.
        for (final option in variant.options) {
          _availableVariants.add({
            'size': option,
            'inventory':
                10, // Default inventory since complex variants don't track individual inventory
            'available': true,
          });
        }
        break; // Take the first variant type for now
      }
    }

    // Also check for simplified admin-style variants in the product data
    // This handles the case where variants are stored as simple name/inventory pairs
    if (_availableVariants.isEmpty) {
      // Try to get variants from the raw Firestore data structure used by admin panel
      // We'll need to fetch this from Firestore since the ProductModel might not include it
      _loadVariantsFromFirestore();
    }
  }

  Future<void> _loadVariantsFromFirestore() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.product.id)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final hasVariants = data['hasVariants'] ?? false;

        if (hasVariants) {
          _variantType = data['variantType'] ?? 'Size';
          final variants = data['variants'] as List<dynamic>? ?? [];

          for (final variant in variants) {
            if (variant is Map<String, dynamic>) {
              final name = variant['name'] ?? '';
              final inventory = variant['inventory'] ?? 0;

              if (name.isNotEmpty) {
                _availableVariants.add({
                  'size': name,
                  'inventory': inventory,
                  'available': inventory > 0,
                });
              }
            }
          }
        }

        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      // Handle error silently, product will just show without variants
    }
  }

  @override
  void dispose() {
    _reviewSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      currentIndex: -1, // Not on main navigation pages
      showBackButton: true,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Custom top bar with back button
              _buildTopBar(),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product image
                      _buildProductImage(),

                      // Product info with action buttons below image
                      _buildProductInfoWithActions(),

                      // Price section
                      _buildPriceSection(),

                      // Coupon banner
                      _buildCouponBanner(),

                      // Shipping info
                      _buildShippingInfo(),

                      // Size selector
                      _buildSizeSelector(),

                      // Quantity selector
                      _buildQuantitySection(),

                      // Purchase buttons
                      _buildPurchaseButtons(),

                      const SizedBox(height: 24),
                      _buildDescriptionSection(),
                      const SizedBox(height: 16),
                      _buildRatingsSection(),
                      const SizedBox(height: 16),
                      _buildReviewsList(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Store info in top left corner
          GestureDetector(
            onTap: () => _navigateToStore(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Store avatar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _storeLogoUrl.isNotEmpty
                      ? Image.network(
                          _storeLogoUrl,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 32,
                          height: 32,
                          color: Colors.black,
                          alignment: Alignment.center,
                          child: Text(
                            _storeName.isNotEmpty ? _storeName[0] : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                ),

                const SizedBox(width: 8),

                // Store name and rating
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _storeName.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.storeRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.star, size: 12, color: Colors.black),
                        const SizedBox(width: 4),
                        Text(
                          '(${_formatCount(widget.storeRatingCount)})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(),

          // Contact store button
          GestureDetector(
            onTap: () => _showContactBottomSheet(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send,
                color: Colors.black,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductImage() {
    return Container(
      key: _imageKey,
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.5,
      color: Colors.grey.shade50,
      child: widget.product.images.isNotEmpty
          ? (widget.product.images.first.startsWith('http')
              ? Image.network(
                  widget.product.images.first,
                  fit: BoxFit.cover,
                )
              : Image.asset(
                  widget.product.images.first,
                  fit: BoxFit.cover,
                ))
          : Container(
              color: Colors.grey.shade200,
              child: const Icon(Icons.image, size: 80, color: Colors.grey),
            ),
    );
  }

  Widget _buildProductInfoWithActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product name and ratings on the left
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.product.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildStarRating(widget.product.reviewStars.round()),
                    const SizedBox(width: 8),
                    Text(
                      '$_reviewCount ratings',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Action buttons on the right
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Heart button
              GestureDetector(
                onTap: () async {
                  final auth = context.read<AuthProvider>();
                  if (auth.user == null) return;
                  final uid = auth.user!.uid;
                  final doc =
                      FirebaseFirestore.instance.collection('users').doc(uid);
                  await doc.update({
                    'savedProductIds': _isFavorite
                        ? FieldValue.arrayRemove([widget.product.id])
                        : FieldValue.arrayUnion([widget.product.id])
                  });
                  if (mounted) {
                    setState(() => _isFavorite = !_isFavorite);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? Colors.red : Colors.black,
                    size: 24,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Share button - non-functioning
              GestureDetector(
                onTap: () {
                  // Share functionality disabled for now
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Share feature coming soon!'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.share_outlined,
                    color: Colors.black,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStarRating(int roundedStars) {
    if (widget.product.reviewStars == 0) {
      return Row(
        children: List.generate(
          5,
          (_) => const Icon(Icons.star_border, size: 16, color: Colors.black),
        ),
      );
    }

    return Row(
      children: List.generate(5, (i) {
        if (i < roundedStars) {
          return const Icon(Icons.star, size: 16, color: Colors.black);
        }
        return const Icon(Icons.star_border, size: 16, color: Colors.black);
      }),
    );
  }

  Widget _buildPriceSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Text(
            '\$${widget.product.price.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 12),
          if (widget.product.isDiscounted)
            Text(
              _originalPriceFormatted(),
              style: const TextStyle(
                fontSize: 20,
                color: Colors.black45,
                decoration: TextDecoration.lineThrough,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCouponBanner() {
    if (widget.product.discountPercent <= 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.purple,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Save \$${(widget.product.price * widget.product.discountPercent / 100).toStringAsFixed(0)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'on orders over \$45',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.purple,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Icon(
            Icons.keyboard_arrow_down,
            color: Colors.purple,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildShippingInfo() {
    final addressProvider = Provider.of<AddressProvider>(context);
    final defaultAddress = addressProvider.defaultAddress;

    String shippingText = 'Enter your address';
    if (defaultAddress != null) {
      // Use the actual address line instead of the formatted string that starts with name
      String addressLine = defaultAddress.line1;
      if (defaultAddress.apartment.isNotEmpty) {
        addressLine += ', ${defaultAddress.apartment}';
      }
      shippingText = 'Ship to $addressLine';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageAddressesPage()),
              );
            },
            child: Row(
              children: [
                Text(
                  shippingText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: defaultAddress != null ? Colors.black : Colors.blue,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 20,
                  color: defaultAddress != null ? Colors.black : Colors.blue,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            defaultAddress != null
                ? 'Estimated delivery Thu, Jul 3'
                : 'Add an address to see delivery estimates',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSizeSelector() {
    // Don't show size selector if no variants are configured
    if (_availableVariants.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _variantType.isNotEmpty ? _variantType : 'Size',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: _availableVariants
                .map((variant) => _buildSizeChip(variant))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSizeChip(Map<String, dynamic> variant) {
    final variantName = variant['size'] as String;
    final isSelected = _selectedSize == variantName;
    final isAvailable = variant['available'] as bool? ?? false;
    final inventory = variant['inventory'] as int? ?? 0;

    return GestureDetector(
      onTap: isAvailable
          ? () {
              setState(() {
                _selectedSize = variantName;
              });
            }
          : null,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          border: Border.all(
            color: isAvailable ? Colors.black : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                variantName,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : isAvailable
                          ? Colors.black
                          : Colors.grey.shade400,
                  fontWeight: FontWeight.w600,
                  fontSize: variantName.length > 3
                      ? 12
                      : 16, // Smaller font for longer text
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // Cross out unavailable sizes
            if (!isAvailable)
              Positioned.fill(
                child: CustomPaint(
                  painter: _CrossOutPainter(),
                ),
              ),
            // Show inventory count for available variants
            if (isAvailable && inventory <= 5 && inventory > 0)
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$inventory',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantitySection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quantity',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _quantityButton(Icons.remove, () {
                if (_quantity > 1) {
                  setState(() => _quantity--);
                }
              }),
              Container(
                width: 60,
                height: 48,
                alignment: Alignment.center,
                child: Text(
                  '$_quantity',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _quantityButton(Icons.add, () {
                setState(() => _quantity++);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quantityButton(IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(icon, color: Colors.black),
      ),
    );
  }

  Widget _buildPurchaseButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 22, 14, 179),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _addToCart,
              child: const Text(
                'Add to Cart',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _buyNow,
              child: const Text(
                'Buy Now',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    final bulletDescription = widget.product.description.contains('\n')
        ? widget.product.description
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList()
        : [widget.product.description.trim()];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Description',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...bulletDescription.asMap().entries.map((entry) {
            if (bulletDescription.length == 1) {
              return Text(
                entry.value,
                style: const TextStyle(fontSize: 14, height: 1.5),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '— ${entry.value}',
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRatingsSection() {
    if (_reviewCount == 0) {
      return const SizedBox.shrink();
    }

    final dist = List<int>.filled(5, 0);
    for (final r in _reviews) {
      final rating = (r['rating'] ?? 0) as int;
      if (rating >= 1 && rating <= 5) {
        dist[5 - rating] += 1;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ratings and reviews',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _avgRating.toStringAsFixed(1),
                style:
                    const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.star, size: 32),
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text('$_reviewCount ratings'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(5, (i) {
            final stars = 5 - i;
            return _starDistributionRow(stars, dist[i]);
          }),
        ],
      ),
    );
  }

  Widget _starDistributionRow(int stars, int count) {
    const maxBarWidth = 200.0;
    final width =
        _reviewCount == 0 ? 0.0 : (count / _reviewCount) * maxBarWidth;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(stars.toString()),
          const SizedBox(width: 4),
          const Icon(Icons.star, size: 12),
          const SizedBox(width: 8),
          Stack(
            children: [
              Container(
                width: maxBarWidth,
                height: 6,
                color: Colors.grey.shade200,
              ),
              Container(
                width: width,
                height: 6,
                color: Colors.black,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsList() {
    if (_reviewCount == 0) return const SizedBox.shrink();

    return SizedBox(
      height: 200,
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemBuilder: (context, i) => _reviewCard(_reviews[i]),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: _reviews.length,
      ),
    );
  }

  Widget _reviewCard(Map review) {
    final int rating = (review['rating'] ?? 0) as int;
    final String comment = (review['comment'] ?? '') as String;
    final String name = (review['displayName'] ?? '') as String;
    final String photo = (review['photoUrl'] ?? '') as String;
    final Timestamp? ts = review['createdAt'] as Timestamp?;
    final String dateStr;
    if (ts != null) {
      final dt = ts.toDate();
      dateStr = '${dt.month}/${dt.day}/${dt.year}';
    } else {
      dateStr = '';
    }

    return Container(
      width: 300,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                child: photo.isEmpty
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name.isNotEmpty ? name : 'Anonymous',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 116,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              comment,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Row(
                children: List.generate(
                  rating,
                  (_) => const Icon(Icons.star, size: 16, color: Colors.black),
                ),
              ),
              const Spacer(),
              Text(
                dateStr,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  String _originalPriceFormatted() {
    if (!widget.product.isDiscounted || widget.product.discountPercent == 0) {
      return '';
    }
    final original =
        widget.product.price / (1 - widget.product.discountPercent / 100);
    return '\$${original.toStringAsFixed(2)}';
  }

  void _addToCart() {
    // Check if variant selection is required but not made
    if (_availableVariants.isNotEmpty && _selectedSize.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a ${_variantType.toLowerCase()}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final cart = Provider.of<CartProvider>(context, listen: false);
    cart.addItem(CartItem(
      product: widget.product,
      variant: _selectedSize.isNotEmpty ? _selectedSize : null,
      quantity: _quantity,
    ));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added to cart')),
    );

    _animateAddToCart();
  }

  void _buyNow() {
    // Check if variant selection is required but not made
    if (_availableVariants.isNotEmpty && _selectedSize.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a ${_variantType.toLowerCase()}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final addrProvider = Provider.of<AddressProvider>(context, listen: false);

    // Allow proceeding to checkout even without addresses
    // The checkout page will handle address collection
    String fullAddress = 'Address to be added';
    if (addrProvider.addresses.isNotEmpty) {
      final shippingAddr =
          addrProvider.defaultAddress ?? addrProvider.addresses.first;
      fullAddress = shippingAddr.formatted();
    }

    // Determine variant text for display
    String variantText = 'Standard';
    if (_availableVariants.isNotEmpty && _selectedSize.isNotEmpty) {
      variantText = _selectedSize;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutPage(
          email: '${fb_auth.FirebaseAuth.instance.currentUser?.email ?? ''}',
          fullAddress: fullAddress,
          subtotal: widget.product.price * _quantity,
          shippingCost: 0,
          tax: (widget.product.price * _quantity) * 0.0825,
          item: CheckoutItem(
            imageUrl: widget.product.images.isNotEmpty
                ? widget.product.images.first
                : '',
            name: widget.product.name,
            variant: variantText,
            price: widget.product.price,
          ),
        ),
      ),
    );
  }

  void _animateAddToCart() {
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final renderBox =
        _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final startOffset = renderBox.localToGlobal(Offset.zero);

    final endOffset = MediaQuery.of(context).size.bottomRight(Offset.zero) -
        const Offset(70, 100);

    final overlayEntry = OverlayEntry(builder: (context) {
      return _FlyingImage(
        image: widget.product.images.isNotEmpty
            ? widget.product.images.first
            : null,
        start: startOffset,
        end: endOffset,
      );
    });

    overlay.insert(overlayEntry);
    Future.delayed(
        const Duration(milliseconds: 800), () => overlayEntry.remove());
  }

  void _showContactBottomSheet() async {
    try {
      // Fetch store information from Firestore
      final storeDoc = await FirebaseFirestore.instance
          .collection('stores')
          .doc(widget.product.storeId)
          .get();

      if (!storeDoc.exists) {
        _showNoContactInfoDialog();
        return;
      }

      final storeData = storeDoc.data() as Map<String, dynamic>;
      final settings = storeData['settings'] as Map<String, dynamic>? ?? {};

      final instagram = settings['instagram'] as String? ?? '';
      final facebook = settings['facebook'] as String? ?? '';

      if (instagram.isEmpty && facebook.isEmpty) {
        _showNoContactInfoDialog();
        return;
      }

      _showContactDialog(instagram, facebook);
    } catch (e) {
      _showNoContactInfoDialog();
    }
  }

  void _showContactDialog(String instagram, String facebook) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Contact ${_storeName.toUpperCase()}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 24),

            // Contact options
            if (instagram.isNotEmpty) ...[
              _buildContactOption(
                icon: Icons.camera_alt,
                label: 'Instagram',
                value: instagram,
                onTap: () {
                  // Could implement URL launcher here
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Instagram: $instagram')),
                  );
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
            ],

            if (facebook.isNotEmpty) ...[
              _buildContactOption(
                icon: Icons.facebook,
                label: 'Facebook',
                value: facebook,
                onTap: () {
                  // Could implement URL launcher here
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Facebook: $facebook')),
                  );
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildContactOption({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  void _showNoContactInfoDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Contact ${_storeName.toUpperCase()}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 24),

            // Sad emoji
            const Text(
              '😔',
              style: TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 16),

            // No contact info message
            const Text(
              'Sorry, no contact information available :(',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _navigateToStore() async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading store...'),
          duration: Duration(seconds: 1),
        ),
      );

      final db = FirebaseFirestore.instance;
      final storeDoc =
          await db.collection('stores').doc(widget.product.storeId).get();

      if (!storeDoc.exists) {
        throw Exception('Store not found');
      }

      final storeModel = StoreModel.fromFirestore(storeDoc);

      // Fetch products (up to 20)
      List<ProductModel> products = [];
      final lowerSnap = await db
          .collection('products')
          .where('storeId', isEqualTo: storeModel.id)
          .limit(20)
          .get();
      if (lowerSnap.docs.isNotEmpty) {
        products =
            lowerSnap.docs.map((d) => ProductModel.fromFirestore(d)).toList();
      } else {
        final upperSnap = await db
            .collection('products')
            .where('StoreId', isEqualTo: storeModel.id)
            .limit(20)
            .get();
        products =
            upperSnap.docs.map((d) => ProductModel.fromFirestore(d)).toList();
      }

      // Load collections for this store
      final collectionsSnapshot = await db
          .collection('collections')
          .where('storeId', isEqualTo: storeModel.id)
          .where('isActive', isEqualTo: true)
          .get();

      final collections = collectionsSnapshot.docs
          .map((doc) => StoreCollection(
                id: doc.id,
                name: doc.data()['name'] ?? '',
                imageUrl: doc.data()['backgroundImage'] ?? '',
              ))
          .toList();

      // Load managed categories for this store
      final categoriesSnapshot = await db
          .collection('store_categories')
          .where('storeId', isEqualTo: storeModel.id)
          .where('isActive', isEqualTo: true)
          .orderBy('sortOrder', descending: false)
          .orderBy('createdAt', descending: false)
          .get();

      final categoryNames = <String>['All'];
      categoryNames.addAll(
        categoriesSnapshot.docs
            .map((doc) => doc.data()['name'] as String? ?? '')
            .where((name) => name.isNotEmpty),
      );

      // Build StoreData for StoreScreen
      final storeData = StoreData(
        id: storeModel.id,
        name: storeModel.name,
        displayName: storeModel.name.toUpperCase(),
        heroImageUrl:
            storeModel.banner.isNotEmpty ? storeModel.banner : storeModel.logo,
        backgroundColor: const Color(0xFF01BCE7),
        rating: 4.9,
        reviewCount: '25',
        collections: collections,
        categories: categoryNames,
        productCount: products.length,
        products: products
            .map((p) => StoreProduct(
                  id: p.id,
                  name: p.name,
                  imageUrl: p.images.isNotEmpty ? p.images.first : '',
                  price: p.price,
                  category: _getProductCategory(p.id, categoriesSnapshot.docs),
                ))
            .toList(),
        showFollowButton: true,
        hasNotification: false,
      );

      // Navigate to store
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StoreScreen(storeData: storeData),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to load store: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getProductCategory(
      String productId, List<QueryDocumentSnapshot> categoryDocs) {
    for (final doc in categoryDocs) {
      final data = doc.data() as Map<String, dynamic>?;
      final productIds = List<String>.from(data?['productIds'] ?? []);
      if (productIds.contains(productId)) {
        return data?['name'] as String? ?? '';
      }
    }
    return ''; // Product not in any category
  }
}

class _CrossOutPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.8),
      Offset(size.width * 0.8, size.height * 0.2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FlyingImage extends StatefulWidget {
  final String? image;
  final Offset start;
  final Offset end;
  const _FlyingImage(
      {required this.image, required this.start, required this.end});

  @override
  State<_FlyingImage> createState() => __FlyingImageState();
}

class __FlyingImageState extends State<_FlyingImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _position;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _position = Tween<Offset>(begin: widget.start, end: widget.end)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _scale = Tween<double>(begin: 1.0, end: 0.1)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Positioned(
          left: _position.value.dx,
          top: _position.value.dy,
          child: Transform.scale(
            scale: _scale.value,
            child: Opacity(
              opacity: 1 - _controller.value,
              child: widget.image != null
                  ? (widget.image!.startsWith('http')
                      ? Image.network(widget.image!, width: 80, height: 80)
                      : Image.asset(widget.image!, width: 80, height: 80))
                  : const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}
