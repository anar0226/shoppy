import 'package:flutter/material.dart';
import 'package:avii/features/products/models/product_model.dart';
import 'package:avii/features/products/presentation/product_page.dart';
import '../../following/services/following_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StoreScreen extends StatefulWidget {
  final StoreData storeData;

  const StoreScreen({
    super.key,
    required this.storeData,
  });

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen>
    with TickerProviderStateMixin {
  String _selectedCategory = 'All';
  final FollowingService _followingService = FollowingService();
  late AnimationController _followAnimationController;
  late Animation<double> _followAnimation;
  bool _isFollowing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _followAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _followAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _followAnimationController,
      curve: Curves.elasticInOut,
    ));

    _checkFollowStatus();
  }

  @override
  void dispose() {
    _followAnimationController.dispose();
    super.dispose();
  }

  Future<void> _checkFollowStatus() async {
    final isFollowing =
        await _followingService.isFollowingStore(widget.storeData.id);
    if (mounted) {
      setState(() {
        _isFollowing = isFollowing;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_isLoading) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to follow stores')),
      );
      return;
    }

    if (_isFollowing) {
      _showUnfollowConfirmation();
    } else {
      await _followStore();
    }
  }

  Future<void> _followStore() async {
    setState(() {
      _isLoading = true;
    });

    final success = await _followingService.followStore(widget.storeData.id);

    if (success && mounted) {
      _followAnimationController.forward().then((_) {
        _followAnimationController.reverse();
      });

      setState(() {
        _isFollowing = true;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Following ${widget.storeData.name}'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (mounted) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to follow store')),
      );
    }
  }

  void _showUnfollowConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unfollow Store'),
        content:
            Text('Are you sure you want to unfollow ${widget.storeData.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _unfollowStore();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Unfollow'),
          ),
        ],
      ),
    );
  }

  Future<void> _unfollowStore() async {
    setState(() {
      _isLoading = true;
    });

    final success = await _followingService.unfollowStore(widget.storeData.id);

    if (success && mounted) {
      setState(() {
        _isFollowing = false;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unfollowed ${widget.storeData.name}'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (mounted) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to unfollow store')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bannerHeight = screenHeight * 0.4;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner section
            _buildHoursBanner(bannerHeight),

            // Collections section - only show if store has collections
            if (widget.storeData.collections.isNotEmpty)
              _buildCollectionsSection(),

            // Category filters
            _buildCategoryFilters(),

            // Products count
            _buildProductsCount(),

            // Products grid
            _buildProductsGrid(),

            const SizedBox(height: 100), // Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildHoursBanner(double bannerHeight) {
    return Container(
      height: bannerHeight,
      width: double.infinity,
      child: Stack(
        children: [
          // Banner image
          Positioned.fill(
            child: widget.storeData.heroImageUrl.isNotEmpty
                ? Image.network(
                    widget.storeData.heroImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildFallbackBanner();
                    },
                  )
                : _buildFallbackBanner(),
          ),

          // Dark overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.7),
                    Colors.black,
                  ],
                  stops: const [0.0, 0.8, 1.0],
                ),
              ),
            ),
          ),

          // Store name overlay (dynamic)
          Positioned(
            left: 0,
            right: 0,
            top: kToolbarHeight + MediaQuery.of(context).padding.top,
            bottom: 100,
            child: Center(
              child: Text(
                widget.storeData.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8.0,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Store info at bottom
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.storeData.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            widget.storeData.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.star,
                            color: Colors.orange,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(${widget.storeData.reviewCount})',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    _buildFollowButton(),
                    const SizedBox(width: 12),
                    _buildActionIcon(Icons.search),
                    const SizedBox(width: 12),
                    _buildActionIcon(Icons.more_horiz),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackBanner() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2D2D2D),
            Color(0xFF1A1A1A),
          ],
        ),
      ),
    );
  }

  Widget _buildActionIcon(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 18,
      ),
    );
  }

  Widget _buildFollowButton() {
    if (_isLoading) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _toggleFollow,
      child: AnimatedBuilder(
        animation: _followAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _followAnimation.value,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _isFollowing
                    ? Colors.white.withOpacity(0.25)
                    : Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(18),
                border: _isFollowing
                    ? Border.all(color: Colors.white.withOpacity(0.3), width: 1)
                    : null,
              ),
              child: _isFollowing
                  ? const Icon(
                      Icons.notifications,
                      color: Colors.white,
                      size: 18,
                    )
                  : const Center(
                      child: Text(
                        'дагах',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCollectionsSection() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Collections',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.storeData.collections.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final collection = widget.storeData.collections[index];
                return _buildCollectionCard(collection, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionCard(StoreCollection collection, int index) {
    return Container(
      width: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade900,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: collection.imageUrl.isNotEmpty
                ? Image.network(
                    collection.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade800,
                        child: const Icon(
                          Icons.collections,
                          color: Colors.grey,
                          size: 32,
                        ),
                      );
                    },
                  )
                : Container(
                    color: Colors.grey.shade800,
                    child: const Icon(
                      Icons.collections,
                      color: Colors.grey,
                      size: 32,
                    ),
                  ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
              child: Text(
                collection.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _getAvailableCategories().length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final category = _getAvailableCategories()[index];
                  final isSelected = _selectedCategory == category;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.black
                              : Colors.white.withOpacity(0.6),
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.tune,
              color: Colors.black,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsCount() {
    final filteredProducts = _getFilteredProducts();
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        '${filteredProducts.length} products',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildProductsGrid() {
    final filteredProducts = _getFilteredProducts();
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: filteredProducts.length,
        itemBuilder: (context, index) {
          final product = filteredProducts[index];
          return _buildProductCard(product);
        },
      ),
    );
  }

  List<StoreProduct> _getFilteredProducts() {
    if (_selectedCategory == 'All') {
      return widget.storeData.products;
    }

    return widget.storeData.products
        .where((product) => product.category == _selectedCategory)
        .toList();
  }

  List<String> _getAvailableCategories() {
    // Only show categories that have products assigned to them
    final categoriesWithProducts = <String>['All'];

    for (final category in widget.storeData.categories) {
      if (category == 'All') continue;

      final hasProducts = widget.storeData.products
          .any((product) => product.category == category);

      if (hasProducts) {
        categoriesWithProducts.add(category);
      }
    }

    return categoriesWithProducts;
  }

  Widget _buildProductCard(StoreProduct product) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductPage(
              product: ProductModel(
                id: product.id,
                storeId: widget.storeData.id,
                name: product.name,
                description: 'A great product from ${widget.storeData.name}',
                price: product.price,
                images: [product.imageUrl],
                category: product.category,
                stock: 10,
                variants: const [],
                isActive: true,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
              storeName: widget.storeData.name,
              storeLogoUrl: '',
              storeRating: widget.storeData.rating,
              storeRatingCount: int.tryParse(widget.storeData.reviewCount
                      .replaceAll(RegExp(r'[^0-9]'), '')) ??
                  0,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                child: product.imageUrl.isNotEmpty
                    ? Image.network(
                        product.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade800,
                            child: const Icon(
                              Icons.checkroom,
                              color: Colors.grey,
                              size: 32,
                            ),
                          );
                        },
                      )
                    : Container(
                        color: Colors.grey.shade800,
                        child: const Icon(
                          Icons.checkroom,
                          color: Colors.grey,
                          size: 32,
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${product.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Store data models
class StoreData {
  final String id;
  final String name;
  final String displayName;
  final String heroImageUrl;
  final Color backgroundColor;
  final double rating;
  final String reviewCount;
  final bool showFollowButton;
  final bool hasNotification;
  final List<StoreCollection> collections;
  final List<String> categories;
  final int productCount;
  final List<StoreProduct> products;

  StoreData({
    required this.id,
    required this.name,
    required this.displayName,
    required this.heroImageUrl,
    required this.backgroundColor,
    required this.rating,
    required this.reviewCount,
    this.showFollowButton = true,
    this.hasNotification = false,
    required this.collections,
    required this.categories,
    required this.productCount,
    required this.products,
  });
}

class StoreCollection {
  final String id;
  final String name;
  final String imageUrl;

  StoreCollection({
    required this.id,
    required this.name,
    required this.imageUrl,
  });
}

class StoreProduct {
  final String id;
  final String name;
  final String imageUrl;
  final double price;
  final int? discount;
  final String category;

  StoreProduct({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.price,
    this.discount,
    this.category = '',
  });
}
