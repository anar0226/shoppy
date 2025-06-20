import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shoppy/features/products/models/product_model.dart';
import 'package:shoppy/features/home/presentation/main_scaffold.dart';
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

class ProductPage extends StatefulWidget {
  final ProductModel product;
  final String storeName;
  final String storeLogoUrl; // Can be empty if you want a placeholder avatar.
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
  String? _selectedSize;
  bool _isFavorite = false;
  int _quantity = 1;

  final GlobalKey _imageKey = GlobalKey();

  // Runtime store info (may be loaded from Firestore if missing).
  late String _storeName;
  late String _storeLogoUrl;

  // Reviews data
  double _avgRating = 0;
  int _reviewCount = 0;
  List<Map<String, dynamic>> _reviews = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _reviewSub;

  @override
  void initState() {
    super.initState();

    // Initialize store info with provided values.
    _storeName = widget.storeName;
    _storeLogoUrl = widget.storeLogoUrl;

    // If missing, attempt to load from Firestore using product.storeId.
    if (_storeName.isEmpty || _storeLogoUrl.isEmpty) {
      _fetchStoreInfo();
    }

    // add to recently viewed provider
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

    // Listen to reviews for this product
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
      // Permission denied or other errors – just hide reviews section.
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

  @override
  void dispose() {
    _reviewSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      currentIndex: 0,
      showBackButton: true,
      onBack: () => Navigator.of(context).maybePop(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(context),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProductImage(),
              _buildProductInfoSection(),
              const SizedBox(height: 12),
              _buildCouponBanner(),
              const SizedBox(height: 12),
              _buildShippingInfo(),
              const SizedBox(height: 12),
              _buildSizeSelector(),
              const SizedBox(height: 12),
              _buildQuantitySelector(),
              const SizedBox(height: 12),
              _buildActionButtons(),
              const SizedBox(height: 24),
              _buildDescriptionSection(),
              const SizedBox(height: 16),
              _buildPolicyButtons(),
              const SizedBox(height: 16),
              _buildVisitStore(),
              const SizedBox(height: 24),
              _buildRatingsSection(),
              const SizedBox(height: 16),
              _buildReviewsList(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          _buildStoreAvatar(),
          const SizedBox(width: 8),
          _buildStoreTitle(),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isFavorite ? Icons.favorite : Icons.favorite_border,
            color: _isFavorite ? Colors.red : Colors.black,
          ),
          onPressed: () async {
            final auth = context.read<AuthProvider>();
            if (auth.user == null) return;
            final uid = auth.user!.uid;
            final doc = FirebaseFirestore.instance.collection('users').doc(uid);
            await doc.update({
              'savedProductIds': _isFavorite
                  ? FieldValue.arrayRemove([widget.product.id])
                  : FieldValue.arrayUnion([widget.product.id])
            });
            if (mounted) {
              setState(() => _isFavorite = !_isFavorite);
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.more_horiz, color: Colors.black),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildStoreAvatar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: _storeLogoUrl.isNotEmpty
          ? Image.network(_storeLogoUrl,
              width: 32, height: 32, fit: BoxFit.cover)
          : Container(
              width: 32,
              height: 32,
              color: Colors.grey.shade300,
              alignment: Alignment.center,
              child: Text(
                _storeName.isNotEmpty ? _storeName[0] : '?',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
    );
  }

  Widget _buildStoreTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _storeName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            const Icon(Icons.star, size: 12, color: Colors.black),
            const SizedBox(width: 4),
            Text(
              widget.storeRating.toStringAsFixed(1),
              style: const TextStyle(fontSize: 12, color: Colors.black),
            ),
            Text(
              '  (${_formatCount(widget.storeRatingCount)})',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProductImage() {
    return AspectRatio(
      key: _imageKey,
      aspectRatio: 1,
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

  Widget _buildProductInfoSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.product.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStarRating(widget.product.reviewStars.round()),
              const SizedBox(width: 6),
              Text(
                '${widget.product.reviewCount} ratings',
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '\$${widget.product.price.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              if (widget.product.isDiscounted)
                Text(
                  _originalPriceFormatted(),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black45,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCouponBanner() {
    if (widget.product.discountPercent <= 0) return const SizedBox.shrink();

    final original = _originalPriceFormatted();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.purple,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '-${widget.product.discountPercent.toStringAsFixed(0)}%',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                'From $original to \$${widget.product.price.toStringAsFixed(2)}!'),
          ),
        ],
      ),
    );
  }

  Widget _buildShippingInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Text('Ship to 84111'),
              SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down, size: 16),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Estimated delivery Thu, Jun 19',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildSizeSelector() {
    // Try to find a variant named 'size' (case-insensitive). Fallback to first variant.
    ProductVariant? sizeVariant;
    sizeVariant ??= widget.product.variants.isNotEmpty
        ? widget.product.variants.first
        : ProductVariant(name: 'Size', options: [], priceAdjustments: {});

    // Flatten options; split by comma if only one string
    final List<String> sizes = [];
    for (final opt in sizeVariant.options) {
      if (opt.contains(',')) {
        sizes.addAll(opt.split(',').map((s) => s.trim()));
      } else {
        sizes.add(opt.trim());
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Size',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: sizes.map((size) => _buildSizeChip(size)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSizeChip(String size) {
    final isSelected = _selectedSize == size;

    return ChoiceChip(
      label: Text(size),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedSize = size;
        });
      },
      selectedColor: Colors.black,
      backgroundColor: Colors.grey.shade100,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _buildStarRating(int roundedStars) {
    // If no rating yet, show 5 outlined stars
    if (widget.product.reviewStars == 0) {
      return Row(
        children: List.generate(
          5,
          (_) => const Icon(Icons.star_border, size: 14, color: Colors.black),
        ),
      );
    }

    return Row(
      children: List.generate(5, (i) {
        if (i < roundedStars) {
          return const Icon(Icons.star, size: 14, color: Colors.black);
        }
        return const Icon(Icons.star_border, size: 14, color: Colors.black);
      }),
    );
  }

  Widget _buildQuantitySelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          _quantityButton(Icons.remove, () {
            if (_quantity > 1) {
              setState(() => _quantity--);
            }
          }),
          SizedBox(
            width: 40,
            child: Center(
              child: Text(
                '$_quantity',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          _quantityButton(Icons.add, () {
            setState(() => _quantity++);
          }),
        ],
      ),
    );
  }

  Widget _quantityButton(IconData icon, VoidCallback onPressed) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        splashRadius: 20,
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 22, 14, 179),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _addToCart,
              child: const Text('Сагсанд нэмэx'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _buyNow,
              child: const Text('Шууд аваx'),
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Description',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...bulletDescription.asMap().entries.map((entry) {
            if (bulletDescription.length == 1) {
              return Text(entry.value);
            }
            return Text('— ${entry.value}');
          }),
        ],
      ),
    );
  }

  Widget _buildPolicyButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          _policyButton('Refund policy'),
          const SizedBox(width: 8),
          _policyButton('Shipping policy'),
        ],
      ),
    );
  }

  Widget _policyButton(String text) {
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: Colors.grey.shade300),
          backgroundColor: Colors.grey.shade100,
        ),
        onPressed: () {},
        child: Text(text, style: const TextStyle(color: Colors.black)),
      ),
    );
  }

  Widget _buildVisitStore() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: InkWell(
        onTap: () async {
          final uri = Uri.tryParse(_storeLogoUrl) ?? Uri();
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.link),
              const SizedBox(width: 8),
              Text('Visit ${_storeName.toUpperCase()}'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingsSection() {
    if (_reviewCount == 0) {
      return const SizedBox.shrink();
    }

    // compute distribution (index0=>5stars)
    final dist = List<int>.filled(5, 0);
    for (final r in _reviews) {
      final rating = (r['rating'] ?? 0) as int;
      if (rating >= 1 && rating <= 5) {
        dist[5 - rating] += 1;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ratings and reviews',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_avgRating.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 48, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              const Icon(Icons.star, size: 32),
              Padding(
                padding: const EdgeInsets.only(top: 14.0),
                child: Text('$_reviewCount ratings'),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
      padding: const EdgeInsets.symmetric(vertical: 2.0),
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
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
          // Header row: avatar + name
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
                child: Text(name.isNotEmpty ? name : 'Anonymous',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Comment box
          Container(
            width: double.infinity,
            height: 116, // fixed height so card size stays consistent
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
          const Spacer(), // pushes stars/date row to bottom
          // Stars + date row
          Row(
            children: [
              Row(
                  children: List.generate(
                      rating,
                      (_) => const Icon(Icons.star,
                          size: 16, color: Colors.black))),
              const Spacer(),
              Text(dateStr,
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
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
    final cart = Provider.of<CartProvider>(context, listen: false);
    cart.addItem(CartItem(
      product: widget.product,
      variant: _selectedSize,
      quantity: _quantity,
    ));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added to cart')),
    );

    _animateAddToCart();
  }

  void _buyNow() {
    final addrProvider = Provider.of<AddressProvider>(context, listen: false);

    if (addrProvider.addresses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please add a shipping address before checkout')));
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ManageAddressesPage()),
      );
      return;
    }

    final shippingAddr =
        addrProvider.defaultAddress ?? addrProvider.addresses.first;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutPage(
          email: '${fb_auth.FirebaseAuth.instance.currentUser?.email ?? ''}',
          fullAddress: shippingAddr.formatted(),
          subtotal: widget.product.price * _quantity,
          shippingCost: 0,
          tax: (widget.product.price * _quantity) * 0.0825,
          item: CheckoutItem(
            imageUrl: widget.product.images.isNotEmpty
                ? widget.product.images.first
                : '',
            name: widget.product.name,
            variant: _selectedSize ?? 'One size',
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
        vsync: this, duration: const Duration(milliseconds: 800))
      ..forward();
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
