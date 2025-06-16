import 'package:flutter/material.dart';
import '../../../core/constants/assets.dart';
import 'package:shoppy/features/home/presentation/main_scaffold.dart';
import 'package:shoppy/features/products/models/product_model.dart';
import 'package:shoppy/features/products/presentation/product_page.dart';

class StoreScreen extends StatefulWidget {
  final StoreData storeData;

  const StoreScreen({
    super.key,
    required this.storeData,
  });

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  String selectedCategory = 'All';
  bool isFollowing = false;
  final ScrollController _scrollController = ScrollController();
  bool _showAppBarTitle = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.offset > 200 && !_showAppBarTitle) {
      setState(() {
        _showAppBarTitle = true;
      });
    } else if (_scrollController.offset <= 200 && _showAppBarTitle) {
      setState(() {
        _showAppBarTitle = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use a cyan color that matches the MrBeast store in the screenshot
    final storeColor = widget.storeData.name.toLowerCase().contains('beast')
        ? const Color(0xFF00C8E0)
        : widget.storeData.backgroundColor;

    return MainScaffold(
      currentIndex: 0,
      showBackButton: true,
      onBack: () => Navigator.of(context).maybePop(),
      child: Scaffold(
        backgroundColor: storeColor,
        // Remove the AppBar completely to avoid overlays on banner
        body: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Store header with banner (full width, no overlays)
            SliverToBoxAdapter(
              child: _buildStoreHeader(),
            ),

            // Store information section (handle, actions, rating)
            SliverToBoxAdapter(
              child: _buildStoreInfoSection(storeColor),
            ),

            // Collections section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: _buildCollectionsSection(),
              ),
            ),

            // Category filters
            SliverToBoxAdapter(
              child: _buildCategoryFilters(),
            ),

            // Products count
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 16.0),
                child: Text(
                  '${widget.storeData.productCount} products',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),

            // Products grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: _buildProductsGrid(),
            ),

            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 80),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreHeader() {
    return Container(
      height: 200,
      width: double.infinity,
      child: widget.storeData.name.toLowerCase().contains('beast')
          ? Image.asset(
              AppAssets.mrBeastBanner,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) {
                // Fallback if asset fails to load
                return Container(
                  color: const Color(0xFF00C8E0),
                  child: const Center(
                    child: Text(
                      'MRBEAST\n.STORE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            )
          : Image.network(
              widget.storeData.heroImageUrl,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: widget.storeData.backgroundColor,
                  child: Center(
                    child: Text(
                      widget.storeData.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildStoreInfoSection(Color backgroundColor) {
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  widget.storeData.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      isFollowing
                          ? Icons.notifications
                          : Icons.notifications_none,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        isFollowing = !isFollowing;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isFollowing
                              ? 'Now following ${widget.storeData.name}!'
                              : 'Unfollowed ${widget.storeData.name}'),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.white),
                    onPressed: _showSearchDialog,
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz, color: Colors.white),
                    onPressed: () => _showSettingsPopup(context),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                widget.storeData.rating.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.star, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                '(${widget.storeData.reviewCount})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionsSection() {
    if (widget.storeData.collections.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        for (var collection in widget.storeData.collections)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: _buildCollectionCard(collection),
          ),
      ],
    );
  }

  Widget _buildCollectionCard(StoreCollection collection) {
    // Full width card with rounded corners
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${collection.name} collection tapped!')),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Collection image
                Image.network(
                  collection.imageUrl,
                  fit: BoxFit.cover,
                ),
                // Text overlay
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          collection.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return Container(
      height: 50,
      padding: const EdgeInsets.only(left: 16.0),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widget.storeData.categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final category = widget.storeData.categories[index];
          final isSelected = selectedCategory == category;

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedCategory = category;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.center,
              child: Text(
                category,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 16,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  SliverGrid _buildProductsGrid() {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final product = widget.storeData.products[index];
          return _buildProductCard(product);
        },
        childCount: widget.storeData.products.length,
      ),
    );
  }

  Widget _buildProductCard(StoreProduct product) {
    return GestureDetector(
      onTap: () {
        // Navigate to the ProductPage template using placeholder data.
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) {
              // Convert StoreProduct to ProductModel with placeholder fields.
              final productModel = ProductModel(
                id: product.id,
                storeId: widget.storeData.id,
                name: product.name,
                description: 'Exclusive item from MrBeast.Store',
                price: product.price,
                images: [product.imageUrl],
                category: 'Merch',
                stock: 100,
                variants: [],
                isActive: true,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );

              // Parse rating count from string like "6.6K".
              int ratingCount = 0;
              final countStr = widget.storeData.reviewCount.toLowerCase();
              if (countStr.endsWith('k')) {
                ratingCount =
                    ((double.tryParse(countStr.replaceAll('k', '')) ?? 0) *
                            1000)
                        .toInt();
              } else {
                ratingCount = int.tryParse(countStr) ?? 0;
              }

              return ProductPage(
                product: productModel,
                storeName: widget.storeData.displayName,
                storeLogoUrl: widget.storeData.heroImageUrl,
                storeRating: widget.storeData.rating,
                storeRatingCount: ratingCount,
              );
            },
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            Expanded(
              child: product.imageUrl.startsWith('http')
                  ? Image.network(
                      product.imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image,
                              color: Colors.grey),
                        );
                      },
                    )
                  : Image.asset(
                      product.imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
            ),

            // Price tag - similar to the screenshot
            Container(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                '\$${product.price.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Search in ${widget.storeData.name}'),
          content: TextField(
            decoration: const InputDecoration(
              hintText: 'Enter product name...',
              prefixIcon: Icon(Icons.search),
            ),
            onSubmitted: (value) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'Searching for "$value" in ${widget.storeData.name}')),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showSettingsPopup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Store Settings',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Notifications'),
                trailing: Switch(
                  value: isFollowing,
                  onChanged: (value) {
                    setState(() {
                      isFollowing = value;
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
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

  StoreProduct({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.price,
    this.discount,
  });
}
