import 'package:flutter/material.dart';
import 'package:avii/features/products/models/product_model.dart';
import 'package:provider/provider.dart';
import 'package:avii/features/cart/providers/cart_provider.dart';
import 'package:avii/features/cart/models/cart_item.dart';
import 'package:avii/features/profile/providers/recently_viewed_provider.dart';
import 'package:avii/features/checkout/presentation/checkout_page.dart';
import 'package:avii/features/checkout/models/checkout_item.dart';
import 'package:avii/features/auth/providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:avii/features/addresses/providers/address_provider.dart';
import 'package:avii/features/addresses/presentation/manage_addresses_page.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'dart:async';
import 'package:avii/features/stores/models/store_model.dart';
import 'package:avii/features/stores/presentation/store_screen.dart';
import 'package:avii/features/home/presentation/main_scaffold.dart';
import 'package:avii/core/services/inventory_service.dart';
import 'package:avii/core/services/rate_limiter_service.dart';
import 'package:avii/core/constants/shipping.dart';
import 'package:avii/core/services/listener_manager.dart';
import 'package:avii/core/services/database_service.dart';

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

class _ProductPageState extends State<ProductPage> with ListenerManagerMixin {
  // State variables
  String _selectedSize = '';
  int _quantity = 1;
  bool _isFavorite = false;
  String _storeName = '';
  String _storeLogoUrl = '';
  double _storeRating = 0.0;
  int _storeReviewCount = 0;
  List<Map<String, dynamic>> _reviews = [];
  int _reviewCount = 0;
  double _avgRating = 0;
  final GlobalKey _imageKey = GlobalKey();

  // Dynamic variant data
  final List<Map<String, dynamic>> _availableVariants = [];
  String _variantType = '';
  final InventoryService _inventoryService = InventoryService();
  final DatabaseService _db = DatabaseService();
  bool _addingToCart = false;

  @override
  void initState() {
    super.initState();

    _storeName = widget.storeName;
    _storeLogoUrl = widget.storeLogoUrl;
    _storeRating = widget.storeRating;
    _storeReviewCount = widget.storeRatingCount;

    // Extract variant information from product
    _extractVariantInfo();

    // Always fetch actual store info from Firestore
    _fetchStoreInfo();

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

    // Listen to reviews with managed listener
    addManagedCollectionListener(
      query: _db.firestore
          .collection('products')
          .doc(widget.product.id)
          .collection('reviews')
          .orderBy('createdAt', descending: true),
      onData: (snap) {
        _reviews =
            snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
        _reviewCount = _reviews.length;
        if (_reviewCount > 0) {
          final total = _reviews.fold<int>(
              0, (sum, r) => sum + (r['rating'] ?? 0) as int);
          _avgRating = total / _reviewCount;
        } else {
          _avgRating = 0;
        }
        if (mounted) setState(() {});
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _reviews = [];
            _reviewCount = 0;
            _avgRating = 0;
          });
        }
      },
      description: 'Product reviews listener for product: ${widget.product.id}',
    );
  }

  Future<void> _fetchStoreInfo() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('stores')
          .doc(widget.product.storeId)
          .get();
      if (doc.exists) {
        final store = StoreModel.fromFirestore(doc);

        // Get actual store rating from reviews
        double storeRating = 0.0;
        int storeReviewCount = 0;

        try {
          final reviewsSnapshot = await FirebaseFirestore.instance
              .collection('stores')
              .doc(widget.product.storeId)
              .collection('reviews')
              .where('status', isEqualTo: 'active')
              .get();

          if (reviewsSnapshot.docs.isNotEmpty) {
            final reviews = reviewsSnapshot.docs;
            final totalRating = reviews.fold<double>(0, (sum, doc) {
              final data = doc.data();
              return sum + ((data['rating'] as num?)?.toDouble() ?? 0);
            });
            storeRating = totalRating / reviews.length;
            storeReviewCount = reviews.length;
          }
        } catch (e) {
          // If store reviews fail, keep default values
        }

        if (mounted) {
          setState(() {
            // Always update store name and logo from Firestore data
            _storeName = store.name;
            _storeLogoUrl = store.logo.isNotEmpty ? store.logo : store.banner;
            // Update the local state variables with actual store data
            _storeRating = storeRating;
            _storeReviewCount = storeReviewCount;
          });
        }
      }
    } catch (_) {}
  }

  void _extractVariantInfo() {
    _availableVariants.clear();
    _variantType = '';

    for (final variant in widget.product.variants) {
      if (variant.options.isNotEmpty) {
        // Variant with option list and possible stockByOption
        _variantType = variant.name.isNotEmpty ? variant.name : 'Хэмжээ';
        for (final opt in variant.options) {
          int inv = 0;
          if (variant.trackInventory) {
            inv = variant.getStockForOption(opt);
          } else if (widget.product.stock > 0) {
            // Fallback to product stock when inventory not tracked per option
            inv = widget.product.stock;
          }
          _availableVariants.add({
            'size': opt,
            'inventory': inv,
            'available': inv > 0,
          });
        }
        if (_availableVariants.isNotEmpty) return; // done
      } else if (variant.name.isNotEmpty) {
        // Simple admin-style variant with inventory field
        final inv = variant.totalStock;
        _variantType = _variantType.isNotEmpty ? _variantType : 'Хэмжээ';
        _availableVariants.add({
          'size': variant.name,
          'inventory': inv,
          'available': inv > 0,
        });
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

  // dispose() is handled by ListenerManagerMixin automatically

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
                          _storeRating > 0
                              ? _storeRating.toStringAsFixed(1)
                              : '0.0',
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
                          '(${_formatCount(_storeReviewCount)})',
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
                    _buildStarRating(_avgRating.round()),
                    const SizedBox(width: 8),
                    Text(
                      '$_reviewCount Үнэлгээ',
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
                  _showPopupMessage(
                    'уучлаарай, одоогоор энэ функц ажилгаагүй байна :(',
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
    if (_avgRating == 0) {
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
            '₮${widget.product.price.toStringAsFixed(2)}',
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
              'Save ₮${(widget.product.price * widget.product.discountPercent / 100).toStringAsFixed(0)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'on orders over ₮45',
              style: TextStyle(
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

    String shippingText = 'Xүргэх xаягаа оруулна yy';
    if (defaultAddress != null) {
      // Use the actual address line instead of the formatted string that starts with name
      String addressLine = defaultAddress.line1;
      if (defaultAddress.apartment.isNotEmpty) {
        addressLine += ', ${defaultAddress.apartment}';
      }
      shippingText = 'Xүргэх xаяг:$addressLine';
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
                Expanded(
                  child: Text(
                    shippingText,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color:
                          defaultAddress != null ? Colors.black : Colors.blue,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
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
                ? 'Xүргэлтийн хугацааг дэлгүүрээс асууна уу'
                : 'Хаяг оруулна уу',
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
    if (_availableVariants.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _variantType.isNotEmpty ? _variantType : 'Хэмжээ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableVariants.map((variant) {
              final size = variant['size'] as String;
              final inventory = variant['inventory'] as int? ?? 0;
              final isSelected = _selectedSize == size;
              final isAvailable = inventory > 0;

              return VariantOptionChip(
                label: size,
                isSelected: isSelected,
                isInStock: isAvailable,
                onTap: () {
                  setState(() {
                    _selectedSize = isSelected ? '' : size;
                  });
                },
              );
            }).toList(),
          ),
          // Stock text display
          if (_selectedSize.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildStockText(),
          ],
        ],
      ),
    );
  }

  Widget _buildStockText() {
    if (_selectedSize.isEmpty) return const SizedBox.shrink();

    final variant = _availableVariants.firstWhere(
      (v) => v['size'] == _selectedSize,
      orElse: () => {'inventory': 0},
    );

    final inventory = variant['inventory'] as int? ?? 0;

    if (inventory <= 0) {
      return const Text(
        'Дууссан',
        style: TextStyle(
          color: Colors.red,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return Text(
      '$inventory ширхэг бэлэн байна',
      style: const TextStyle(
        color: Colors.green,
        fontSize: 14,
        fontWeight: FontWeight.w500,
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
            'Тоо',
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
              onPressed:
                  _addingToCart || !_isProductAvailable() ? null : _addToCart,
              child: const Text(
                'Сагсанд нэмэх',
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
              onPressed:
                  _addingToCart || !_isProductAvailable() ? null : _buyNow,
              child: const Text(
                'Шууд авах',
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

  bool _isProductAvailable() {
    if (_availableVariants.isEmpty) {
      return widget.product.hasStock;
    }

    if (_selectedSize.isEmpty) {
      return false; // Must select variant
    }

    return _getSelectedVariantStock() > 0;
  }

  int _getSelectedVariantStock() {
    if (_availableVariants.isEmpty || _selectedSize.isEmpty) {
      return 0;
    }

    final variant = _availableVariants.firstWhere(
      (v) => v['size'] == _selectedSize,
      orElse: () => {'inventory': 0},
    );

    return variant['inventory'] ?? 0;
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
            'Дэлгэрэнгүй мэдээлэл',
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
            'Үнэлгээ, сэтгэгдэл',
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
                child: Text('$_reviewCount Үнэлгээ'),
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
                  name.isNotEmpty ? name : 'нэргүй хэрэглэгч',
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
    return '₮${original.toStringAsFixed(2)}';
  }

  void _addToCart() {
    // Check if variant selection is required but not made
    if (_availableVariants.isNotEmpty && _selectedSize.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_variantType.toLowerCase()} сонгоно уу'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _addToCartAsync();
  }

  Future<void> _addToCartAsync() async {
    setState(() => _addingToCart = true);

    try {
      final cart = Provider.of<CartProvider>(context, listen: false);

      // Create cart item with selected variants
      final selectedVariants = _selectedSize.isNotEmpty
          ? {_variantType.toLowerCase(): _selectedSize}
          : null;

      final cartItem = CartItem(
        product: widget.product,
        selectedVariants: selectedVariants,
        quantity: _quantity,
      );

      await cart.addItem(cartItem);

      _showPopupMessage('Сагсанд нэмлээ');
      _animateAddToCart();
    } catch (e) {
      if (e is RateLimitExceededException) {
        _showPopupMessage(
            'Хэт олон хүсэлт илгээлээ. ${e.retryAfterSeconds} секундын дараа дахин оролдоно уу.',
            isError: true);
      } else {
        _showPopupMessage('Сагсанд нэмэхэд алдаа гарлаа: $e', isError: true);
      }
    } finally {
      setState(() => _addingToCart = false);
    }
  }

  void _buyNow() {
    // Check if variant selection is required but not made
    if (_availableVariants.isNotEmpty && _selectedSize.isEmpty) {
      _showPopupMessage(
        '${_variantType.toLowerCase()} сонгоно уу',
        isError: true,
      );
      return;
    }

    final addrProvider = Provider.of<AddressProvider>(context, listen: false);

    // Allow proceeding to checkout even without addresses
    // The checkout page will handle address collection
    String fullAddress = 'Хаяг оруулна уу';
    if (addrProvider.addresses.isNotEmpty) {
      final shippingAddr =
          addrProvider.defaultAddress ?? addrProvider.addresses.first;
      fullAddress = shippingAddr.formatted();
    }

    // Determine variant text for display
    String variantText = 'Стандарт';
    if (_availableVariants.isNotEmpty && _selectedSize.isNotEmpty) {
      variantText = _selectedSize;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutPage(
          email: fb_auth.FirebaseAuth.instance.currentUser?.email ?? '',
          fullAddress: fullAddress,
          subtotal: widget.product.price * _quantity,
          shippingCost: kStandardShippingFee,
          tax: 0.0, // Tax disabled for Mongolia
          items: [
            CheckoutItem(
              // Wrap in list for consistency
              imageUrl: widget.product.images.isNotEmpty
                  ? widget.product.images.first
                  : '',
              name: widget.product.name,
              variant: variantText,
              price: widget.product.price,
              storeId: widget.product.storeId, // Include storeId for validation
            )
          ],
        ),
      ),
    );
  }

  void _animateAddToCart() {
    final overlay = Overlay.of(context);

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

      // Check if widget is still mounted after async operation
      if (!mounted) return;

      if (!storeDoc.exists) {
        _showNoContactInfoDialog();
        return;
      }

      final storeData = storeDoc.data() as Map<String, dynamic>;

      // Get contact information from direct fields
      final phone = storeData['phone'] as String? ?? '';
      final instagram = storeData['instagram'] as String? ?? '';
      final facebook = storeData['facebook'] as String? ?? '';

      // Fallback to settings for backward compatibility
      if (phone.isEmpty && instagram.isEmpty && facebook.isEmpty) {
        final settings = storeData['settings'] as Map<String, dynamic>? ?? {};
        final settingsInstagram = settings['instagram'] as String? ?? '';
        final settingsFacebook = settings['facebook'] as String? ?? '';

        if (settingsInstagram.isEmpty && settingsFacebook.isEmpty) {
          _showNoContactInfoDialog();
          return;
        }

        _showContactDialog(
          phone: '',
          instagram: settingsInstagram,
          facebook: settingsFacebook,
        );
        return;
      }

      _showContactDialog(
        phone: phone,
        instagram: instagram,
        facebook: facebook,
      );
    } catch (e) {
      if (!mounted) return;
      _showNoContactInfoDialog();
    }
  }

  void _showContactDialog({
    required String phone,
    required String instagram,
    required String facebook,
  }) {
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
              ' ${_storeName.toUpperCase()}-тай холбогдох',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 24),

            // Contact options
            if (phone.isNotEmpty) ...[
              _buildContactOption(
                icon: Icons.phone,
                label: 'Утас',
                value: phone,
                onTap: () {
                  Navigator.pop(context);
                  _showPopupMessage('Утас: $phone');
                },
              ),
              const SizedBox(height: 16),
            ],

            if (instagram.isNotEmpty) ...[
              _buildContactOption(
                icon: Icons.camera_alt,
                label: 'Instagram',
                value: instagram,
                onTap: () {
                  Navigator.pop(context);
                  _showPopupMessage('Instagram: $instagram');
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
                  Navigator.pop(context);
                  _showPopupMessage('Facebook: $facebook');
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
              ' ${_storeName.toUpperCase()}-тай холбогдох',
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
              'Уучлаарай, холбогдох мэдээлэл олдсонгүй :(',
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
                  'Хаах',
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
      _showPopupMessage('Уншиж байна');

      final db = FirebaseFirestore.instance;
      final storeDoc =
          await db.collection('stores').doc(widget.product.storeId).get();

      if (!storeDoc.exists) {
        throw Exception('Дэлгүүр олдсонгүй');
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

      // Use the current store rating data
      final rating = _storeRating > 0 ? _storeRating : 0.0;
      final reviewCount =
          _storeReviewCount > 0 ? _storeReviewCount.toString() : '0';

      // Build StoreData for StoreScreen
      final storeData = StoreData(
        id: storeModel.id,
        name: storeModel.name,
        displayName: storeModel.name.toUpperCase(),
        heroImageUrl:
            storeModel.banner.isNotEmpty ? storeModel.banner : storeModel.logo,
        backgroundColor: const Color(0xFF01BCE7),
        rating: rating,
        reviewCount: reviewCount,
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
        _showPopupMessage(
          'Дэлгүүр олох явцад алдаа гарлаа: $e',
          isError: true,
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

  void _showPopupMessage(String message,
      {Color? backgroundColor, bool isError = false}) {
    final overlay = Overlay.of(context);

    final overlayEntry = OverlayEntry(
      builder: (context) => _PopupMessage(
        message: message,
        backgroundColor:
            backgroundColor ?? (isError ? Colors.red : Colors.black87),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 3), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  String _getVariantNameForStockIndicator() {
    if (_availableVariants.isEmpty || _selectedSize.isEmpty) {
      return '';
    }

    // Find the variant that contains the selected size
    for (final variant in widget.product.variants) {
      if (variant.options.contains(_selectedSize)) {
        // Return the exact variant name as it appears in the product model
        return variant.name;
      }
    }

    // If no match found in product variants, try to find it in the available variants
    // This handles the case where variants are loaded from Firestore
    for (final variant in _availableVariants) {
      if (variant['size'] == _selectedSize) {
        // For Firestore-loaded variants, use the variant type
        return _variantType;
      }
    }

    // Fallback to the variant type
    return _variantType;
  }
}

/// Widget for variant option that shows if it's out of stock
class VariantOptionChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isInStock;
  final VoidCallback? onTap;

  const VariantOptionChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.isInStock,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isInStock ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _getBackgroundColor(),
          border: Border.all(color: _getBorderColor()),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: _getTextColor(),
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            decoration: !isInStock ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    if (!isInStock) return Colors.grey.shade100;
    if (isSelected) return Colors.blue.shade50;
    return Colors.white;
  }

  Color _getBorderColor() {
    if (!isInStock) return Colors.grey.shade300;
    if (isSelected) return Colors.blue.shade400;
    return Colors.grey.shade300;
  }

  Color _getTextColor() {
    if (!isInStock) return Colors.grey.shade400;
    if (isSelected) return Colors.blue.shade700;
    return Colors.black87;
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

class _PopupMessage extends StatefulWidget {
  final String message;
  final Color backgroundColor;

  const _PopupMessage({
    required this.message,
    required this.backgroundColor,
  });

  @override
  State<_PopupMessage> createState() => __PopupMessageState();
}

class __PopupMessageState extends State<_PopupMessage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();

    // Start fade out animation after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        _controller.reverse();
      }
    });
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
      builder: (context, child) {
        return Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: Transform.scale(
                scale: _scale.value,
                child: Opacity(
                  opacity: _opacity.value,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: widget.backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
