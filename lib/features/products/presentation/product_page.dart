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

  @override
  void initState() {
    super.initState();
    // add to recently viewed provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final recent =
          Provider.of<RecentlyViewedProvider>(context, listen: false);
      recent.add(widget.product);
    });
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
          onPressed: () {
            setState(() => _isFavorite = !_isFavorite);
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
      child: widget.storeLogoUrl.isNotEmpty
          ? Image.network(widget.storeLogoUrl,
              width: 32, height: 32, fit: BoxFit.cover)
          : Container(
              width: 32,
              height: 32,
              color: Colors.grey.shade300,
              alignment: Alignment.center,
              child: Text(
                widget.storeName.isNotEmpty ? widget.storeName[0] : '?',
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
          widget.storeName,
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
              _buildStarRating(5),
              const SizedBox(width: 6),
              Text(
                '369 ratings', // Static for template; replace with real data if available
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
              const Text(
                '\$250.00', // Original price placeholder
                style: TextStyle(
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
            child: const Text(
              'Save \$50',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('on orders over \$190'),
          ),
          const Icon(Icons.keyboard_arrow_down),
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
    final sizes = ['28', '30', '32', '33', '34', '36', '38'];

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

  Widget _buildStarRating(int stars) {
    return Row(
      children: List.generate(
        stars,
        (index) => const Icon(Icons.star, size: 14, color: Colors.black),
      ),
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
    final bulletDescription = widget.product.description
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

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
          ...bulletDescription.map((d) => Text('— $d')),
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
          final uri = Uri.tryParse(widget.storeLogoUrl ?? '') ?? Uri();
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
              Text('Visit ${widget.storeName.toUpperCase()}'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingsSection() {
    const average = 5.0; // placeholder
    const totalRatings = 11;

    const distribution = [
      10, // 5 stars
      0, // 4
      0, // 3
      0, // 2
      1, // 1
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ratings and reviews',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                average.toStringAsFixed(1),
                style:
                    const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.star, size: 32),
              Padding(
                padding: const EdgeInsets.only(top: 14.0),
                child: Text('$totalRatings ratings'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(5, (i) {
            final index = 5 - i; // 5 to 1
            return _starDistributionRow(index, distribution[5 - index]);
          }),
        ],
      ),
    );
  }

  Widget _starDistributionRow(int stars, int count) {
    const maxBarWidth = 200.0;
    const total = 11; // same as above placeholder
    final width = total == 0 ? 0.0 : (count / total) * maxBarWidth;

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
    final reviews = [
      {
        'author': 'RICARDO',
        'daysAgo': 3,
        'text':
            'Super comfortable, thick material, high quality and nice graphics, Worth it',
        'stars': 5
      },
      {
        'author': 'JOHN',
        'daysAgo': 6,
        'text': 'Good quality, fits as expected.',
        'stars': 5
      },
      {'author': 'ALICE', 'daysAgo': 10, 'text': 'Awesome shirt!', 'stars': 4},
    ];

    return SizedBox(
      height: 200,
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemBuilder: (context, i) => _reviewCard(reviews[i]),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: reviews.length,
      ),
    );
  }

  Widget _reviewCard(Map review) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(review['text'], maxLines: 3, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Row(
              children: List.generate(
                  review['stars'], (_) => const Icon(Icons.star, size: 14))),
          const Spacer(),
          Text('${review['author']} • ${review['daysAgo']} days ago',
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
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

  void _addToCart() {
    final cart = Provider.of<CartProvider>(context, listen: false);
    cart.addItem(CartItem(product: widget.product, quantity: _quantity));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added to cart')),
    );

    _animateAddToCart();
  }

  void _buyNow() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutPage(
          email: 'anar0226@gmail.com',
          fullAddress:
              'Anar Borgil, 201 E South Temple, Brigham Apartments 815, Salt Lake City UT 84111, US',
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
