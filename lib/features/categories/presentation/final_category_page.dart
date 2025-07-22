import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:avii/features/home/presentation/main_scaffold.dart';
import 'package:avii/features/products/presentation/product_page.dart';
import 'package:avii/features/products/models/product_model.dart';
import 'package:avii/features/stores/models/store_model.dart';
import '../services/category_product_service.dart';

class FinalCategoryPage extends StatefulWidget {
  final String title;
  final String? mainCategory;
  final String? subCategory;

  const FinalCategoryPage({
    super.key,
    required this.title,
    this.mainCategory,
    this.subCategory,
  });

  @override
  State<FinalCategoryPage> createState() => _FinalCategoryPageState();
}

class _FinalCategoryPageState extends State<FinalCategoryPage> {
  String? _placeholderImage;
  static const String _lalarStoreId = 'TLLb3tqzvU2TZSsNPol9';
  StoreModel? _lalarStore;
  List<ProductModel> _featuredProducts = [];
  List<ProductModel> _categoryProducts = [];
  List<StoreModel> _allStores = [];
  bool _isLoadingFeatured = true;
  bool _isLoadingCategory = true;
  final CategoryProductService _categoryService = CategoryProductService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadPlaceholder();
    await _loadStore();
    await _loadAllStores();
    await Future.wait([
      _loadFeaturedProducts(),
      _loadCategoryProducts(),
    ]);
  }

  Future<void> _loadCategoryProducts() async {
    try {
      debugPrint('🔍 Loading category products for: ${widget.title}');

      // First try loading by exact category hierarchy
      List<ProductModel> products =
          await _categoryService.loadProductsByCategory(
        category: widget.mainCategory,
        subCategory: widget.subCategory,
        leafCategory: widget.title,
        limit: 20,
      );

      // If no products found, try broader searches
      if (products.isEmpty) {
        debugPrint(
            '🔄 No products found with hierarchy, trying term-based search');

        // Create search terms from the category information
        final searchTerms = <String>[];
        if (widget.title.isNotEmpty) searchTerms.add(widget.title);
        if (widget.subCategory != null && widget.subCategory!.isNotEmpty) {
          searchTerms.add(widget.subCategory!);
        }
        if (widget.mainCategory != null && widget.mainCategory!.isNotEmpty) {
          searchTerms.add(widget.mainCategory!);
        }

        if (searchTerms.isNotEmpty) {
          products = await _categoryService.loadProductsByTerms(
            searchTerms: searchTerms,
            limit: 20,
          );
        }
      }

      // Final fallback: load all active products
      if (products.isEmpty) {
        debugPrint(
            '🔄 No products found with terms, loading all active products');
        products = await _categoryService.loadAllActiveProducts(limit: 20);
      }

      if (mounted) {
        setState(() {
          _categoryProducts = products;
          _isLoadingCategory = false;
        });
      }

      debugPrint('✅ Loaded ${products.length} category products');
    } catch (e) {
      debugPrint('❌ Error loading category products: $e');
      if (mounted) {
        setState(() {
          _categoryProducts = [];
          _isLoadingCategory = false;
        });
      }
    }
  }

  Future<void> _loadAllStores() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('stores')
          .where('isActive', isEqualTo: true)
          .get();

      if (mounted) {
        setState(() {
          _allStores = snapshot.docs
              .map((doc) => StoreModel.fromFirestore(doc))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading stores: $e');
    }
  }

  Future<void> _loadFeaturedProducts() async {
    try {
      // Build path for super admin featured products
      String featuredPath = widget.mainCategory ?? '';
      if (widget.subCategory != null) {
        featuredPath += '_${widget.subCategory}';
      }
      featuredPath += '_${widget.title}';

      // Load featured products configuration from super admin
      final featuredDoc = await FirebaseFirestore.instance
          .doc('featured_products/$featuredPath')
          .get();

      if (featuredDoc.exists) {
        final data = featuredDoc.data() as Map<String, dynamic>;
        final productIds = List<String>.from(data['productIds'] ?? []);

        final allFeaturedProducts = <ProductModel>[];

        // Load the actual products using collectionGroup query
        for (final productId in productIds) {
          try {
            // First try the old structure (products/{productId})
            final productDoc = await FirebaseFirestore.instance
                .collection('products')
                .doc(productId)
                .get();

            if (productDoc.exists) {
              allFeaturedProducts.add(ProductModel.fromFirestore(productDoc));
            } else {
              // Fallback: search in collection group using a field query (not documentId)
              final productQuery = await FirebaseFirestore.instance
                  .collectionGroup('products')
                  .where('productId', isEqualTo: productId)
                  .limit(1)
                  .get();

              if (productQuery.docs.isNotEmpty) {
                allFeaturedProducts
                    .add(ProductModel.fromFirestore(productQuery.docs.first));
              }
            }
          } catch (e) {
            debugPrint('Error loading featured product $productId: $e');
          }
        }

        if (mounted) {
          setState(() {
            _featuredProducts = allFeaturedProducts;
            _isLoadingFeatured = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _featuredProducts = [];
            _isLoadingFeatured = false;
          });
        }
        debugPrint(
            'No featured products configuration found for: $featuredPath');
      }
    } catch (e) {
      debugPrint('Error loading featured products: $e');
      if (mounted) {
        setState(() {
          _featuredProducts = [];
          _isLoadingFeatured = false;
        });
      }
    }
  }

  Future<void> _loadPlaceholder() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc('ComingSoon')
          .get();
      final data = doc.data();
      if (data != null) {
        final images = List<String>.from(data['images'] ?? []);
        if (images.isNotEmpty) {
          if (mounted) {
            setState(() => _placeholderImage = images.first);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _loadStore() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('stores')
          .doc(_lalarStoreId)
          .get();
      if (doc.exists) {
        if (mounted) {
          setState(() => _lalarStore = StoreModel.fromFirestore(doc));
        }
      }
    } catch (_) {}
  }

  void _openProduct() {
    final product = ProductModel(
      id: 'placeholder',
      storeId: _lalarStoreId,
      name: 'Удахгүй',
      description: 'Удахгүй шинэ бүтээгдэхүүн гарах болно!',
      price: 0,
      images: _placeholderImage != null ? [_placeholderImage!] : [],
      category: widget.title,
      stock: 0,
      variants: const [],
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductPage(
          product: product,
          storeName: _lalarStore?.name ?? '',
          storeLogoUrl: _lalarStore?.logo ?? '',
          storeRating: 0,
          storeRatingCount: 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      currentIndex: 0,
      showBackButton: true,
      onBack: () => Navigator.of(context).maybePop(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _buildSearchBar(),
              const SizedBox(height: 12),
              Text(widget.title,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(child: _buildProductsGrid()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.grey.shade200,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none),
        ),
        onSubmitted: (value) {},
      ),
    );
  }

  Widget _buildProductsGrid() {
    if (_isLoadingFeatured || _isLoadingCategory) {
      return const Center(child: CircularProgressIndicator());
    }

    // Determine which products to show
    final hasFeatureProducts = _featuredProducts.isNotEmpty;
    final hasCategoryProducts = _categoryProducts.isNotEmpty;

    if (!hasFeatureProducts && !hasCategoryProducts) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Featured Products Section (if available)
        if (hasFeatureProducts) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Featured ${widget.title}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 280, // Fixed height for featured products
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              scrollDirection: Axis.horizontal,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: _featuredProducts.length,
              itemBuilder: (context, index) =>
                  _buildFeaturedProductCard(_featuredProducts[index]),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Category Products Section
        if (hasCategoryProducts) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Icon(Icons.category, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Text(
                  hasFeatureProducts
                      ? 'More ${widget.title}'
                      : 'All ${widget.title}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.6,
              ),
              itemCount: _categoryProducts.length,
              itemBuilder: (context, index) =>
                  _buildCategoryProductCard(_categoryProducts[index]),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '${widget.title} ангиллын бараа олдсонгүй',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Энэ ангиллын бараа олдсонгүй.\nДараа дахин шалгана уу!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Бусад ангилал үзэх'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedProductCard(ProductModel product) {
    // Find the store for this product
    final store = _allStores.firstWhere(
      (s) => s.id == product.storeId,
      orElse: () => StoreModel(
        id: product.storeId,
        name: 'Store',
        description: '',
        logo: '',
        banner: '',
        ownerId: '',
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        settings: {},
      ),
    );

    return GestureDetector(
      onTap: () => _openFeaturedProduct(product, store),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // image + favourite button
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: product.images.isNotEmpty
                      ? Image.network(
                          product.images.first,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.image,
                                  size: 50, color: Colors.grey),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.image,
                              size: 50, color: Colors.grey),
                        ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white70,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.favorite_border, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            store.name,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            product.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          const Row(
            children: [
              Icon(Icons.star, size: 14, color: Colors.amber),
              SizedBox(width: 2),
              Text('4.5', style: TextStyle(fontSize: 12)),
              SizedBox(width: 4),
              Text('(24)',
                  style: TextStyle(fontSize: 12, color: Colors.black45)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '\$${product.price.toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _openFeaturedProduct(ProductModel product, StoreModel store) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductPage(
          product: product,
          storeName: store.name,
          storeLogoUrl: store.logo,
          storeRating: 4.5,
          storeRatingCount: 24,
        ),
      ),
    );
  }

  Widget _buildCategoryProductCard(ProductModel product) {
    // Find the store for this product
    final store = _allStores.firstWhere(
      (s) => s.id == product.storeId,
      orElse: () => StoreModel(
        id: product.storeId,
        name: 'Store',
        description: '',
        logo: '',
        banner: '',
        ownerId: '',
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        settings: {},
      ),
    );

    return GestureDetector(
      onTap: () => _openCategoryProduct(product, store),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image + favourite button
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: product.images.isNotEmpty
                      ? Image.network(
                          product.images.first,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.image,
                                  size: 50, color: Colors.grey),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.image,
                              size: 50, color: Colors.grey),
                        ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white70,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.favorite_border, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            store.name,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            product.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          const Row(
            children: [
              Icon(Icons.star, size: 14, color: Colors.amber),
              SizedBox(width: 2),
              Text('4.5', style: TextStyle(fontSize: 12)),
              SizedBox(width: 4),
              Text('(24)',
                  style: TextStyle(fontSize: 12, color: Colors.black45)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '₮${product.price.toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _openCategoryProduct(ProductModel product, StoreModel store) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductPage(
          product: product,
          storeName: store.name,
          storeLogoUrl: store.logo,
          storeRating: 4.5,
          storeRatingCount: 24,
        ),
      ),
    );
  }

  // ignore: unused_element LATER USED
  Widget _productCard() {
    final storeName = _lalarStore?.name ?? 'Store';
    return GestureDetector(
      onTap: _openProduct,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // image + favourite button
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _placeholderImage != null
                      ? Image.network(_placeholderImage!, fit: BoxFit.cover)
                      : Container(color: Colors.grey.shade300),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white70,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.favorite_border, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(storeName,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 2),
          const Text(
            'Уучлаарай, уг ангилал одоогоор хоосон байна. :(',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          const Row(
            children: [
              Icon(Icons.star, size: 14, color: Colors.amber),
              SizedBox(width: 2),
              Text('0.0', style: TextStyle(fontSize: 12)),
              SizedBox(width: 4),
              Text('(0)',
                  style: TextStyle(fontSize: 12, color: Colors.black45)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            ' 24',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
