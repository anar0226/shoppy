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

  // Search functionality
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

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

    _setupFollowStatusListener();
  }

  @override
  void dispose() {
    _followAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _setupFollowStatusListener() {
    // Listen to real-time follow status changes
    _followingService
        .followStatusStream(widget.storeData.id)
        .listen((isFollowing) {
      if (mounted) {
        setState(() {
          _isFollowing = isFollowing;
          _isLoading = false; // Stop loading when we get real data
        });
      }
    });
  }

  Future<void> _toggleFollow() async {
    if (_isLoading) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showPopupMessage('Дэлгүүрүүдийг дагахын тулд нэвтэрнэ үү',
          isError: true);
      return;
    }

    if (_isFollowing) {
      _showUnfollowConfirmation();
    } else {
      await _followStore();
    }
  }

  Future<void> _followStore() async {
    // Optimistic update
    setState(() {
      _isLoading = true;
    });

    // Trigger animation immediately for better UX
    _followAnimationController.forward().then((_) {
      _followAnimationController.reverse();
    });

    try {
      await _followingService.followStore(widget.storeData.id);
      // Success message will be shown after real-time listener updates
      _showPopupMessage('${widget.storeData.name}-г дагаж байна');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showPopupMessage('Дэлгүүрийг дагах явцад алдаа гарлаа', isError: true);
      }
    }
  }

  void _showUnfollowConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Дагахаа болих?'),
        content: Text('${widget.storeData.name} дагахаа болих уу?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFF4285F4)),
            child: const Text('Цуцлах'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _unfollowStore();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Дагахаа болих'),
          ),
        ],
      ),
    );
  }

  Future<void> _unfollowStore() async {
    // Optimistic update
    setState(() {
      _isLoading = true;
    });

    try {
      await _followingService.unfollowStore(widget.storeData.id);
      // Success message will be shown after real-time listener updates
      _showPopupMessage('${widget.storeData.name} дагахаа болилоо');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showPopupMessage('Дагахаа болих явцад алдаа гарлаа', isError: true);
      }
    }
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

  void _showSearchDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => _SearchDialog(
        controller: _searchController,
        onSearch: (query) {
          setState(() {
            _searchQuery = query.toLowerCase();
            _isSearching = query.isNotEmpty;
            _selectedCategory = 'All'; // Reset category filter when searching
          });
        },
        onClear: () {
          setState(() {
            _searchQuery = '';
            _isSearching = false;
            _searchController.clear();
          });
        },
        storeProducts: widget.storeData.products,
      ),
    );
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
    return SizedBox(
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
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.7),
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
                              color: Colors.white.withValues(alpha: 0.7),
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
                    _buildSearchIcon(),
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
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 18,
      ),
    );
  }

  Widget _buildSearchIcon() {
    return GestureDetector(
      onTap: _showSearchDialog,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _isSearching
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(
          _isSearching ? Icons.search_off : Icons.search,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildFollowButton() {
    if (_isLoading) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
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
                    ? Colors.white.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(18),
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
            'Коллекц',
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
                    Colors.black.withValues(alpha: 0.8),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.black
                        : Colors.white.withValues(alpha: 0.6),
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
    );
  }

  Widget _buildProductsCount() {
    final filteredProducts = _getFilteredProducts();
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Row(
        children: [
          Text(
            '${filteredProducts.length} бүтээгдэхүүн',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_isSearching) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.search,
                    color: Colors.white,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '"$_searchQuery"',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _searchQuery = '';
                        _isSearching = false;
                        _searchController.clear();
                      });
                    },
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductsGrid() {
    final filteredProducts = _getFilteredProducts();
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
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
    List<StoreProduct> filteredProducts = widget.storeData.products;

    // Filter by search query first
    if (_searchQuery.isNotEmpty) {
      filteredProducts = filteredProducts
          .where((product) => product.name.toLowerCase().contains(_searchQuery))
          .toList();
    }

    // Then filter by category
    if (_selectedCategory != 'All') {
      filteredProducts = filteredProducts
          .where((product) => product.category == _selectedCategory)
          .toList();
    }

    return filteredProducts;
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
              child: SizedBox(
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
                    '₮${product.price.toStringAsFixed(0)}',
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

class _SearchDialog extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSearch;
  final VoidCallback onClear;
  final List<StoreProduct> storeProducts;

  const _SearchDialog({
    required this.controller,
    required this.onSearch,
    required this.onClear,
    required this.storeProducts,
  });

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  List<StoreProduct> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _searchResults = widget.storeProducts;
  }

  void _performSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _searchResults = widget.storeProducts;
      } else {
        _searchResults = widget.storeProducts
            .where((product) =>
                product.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade800),
        ),
        child: Column(
          children: [
            // Search header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade800),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Бүтээгдэхүүн хайх...',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        prefixIcon:
                            Icon(Icons.search, color: Colors.grey.shade400),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade600),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade600),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade900,
                      ),
                      onChanged: (value) {
                        _performSearch(value);
                        widget.onSearch(value);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      widget.onClear();
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            // Search results count
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.centerLeft,
              child: Text(
                '${_searchResults.length} бүтээгдэхүүн олдлоо',
                style: TextStyle(
                  color: Colors.grey.shade300,
                  fontSize: 14,
                ),
              ),
            ),

            // Search results
            Expanded(
              child: _searchResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            color: Colors.grey.shade600,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Бүтээгдэхүүн олдсонгүй',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final product = _searchResults[index];
                        return _buildSearchResultItem(product);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultItem(StoreProduct product) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        // Navigate to product details
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductPage(
              product: ProductModel(
                id: product.id,
                storeId: '',
                name: product.name,
                description: 'A great product',
                price: product.price,
                images: [product.imageUrl],
                category: product.category,
                stock: 10,
                variants: const [],
                isActive: true,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
              storeName: '',
              storeLogoUrl: '',
              storeRating: 4.5,
              storeRatingCount: 100,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade800),
        ),
        child: Row(
          children: [
            // Product image
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade800,
              ),
              child: product.imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        product.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.checkroom,
                            color: Colors.grey,
                            size: 24,
                          );
                        },
                      ),
                    )
                  : const Icon(
                      Icons.checkroom,
                      color: Colors.grey,
                      size: 24,
                    ),
            ),

            const SizedBox(width: 12),

            // Product details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (product.category.isNotEmpty)
                    Text(
                      product.category,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    '₮${product.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey,
              size: 16,
            ),
          ],
        ),
      ),
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
                          color: Colors.black.withValues(alpha: 0.3),
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
