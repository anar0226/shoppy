import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:avii/features/stores/models/store_model.dart';
import 'package:avii/features/stores/presentation/store_screen.dart'
    show StoreScreen, StoreData, StoreCollection, StoreProduct;
import 'package:avii/features/products/models/product_model.dart'
    show ProductModel, ProductVariant;
import 'package:avii/features/products/presentation/product_page.dart';
import 'package:avii/features/home/presentation/main_scaffold.dart';
import '../../../core/services/rating_service.dart';
import '../services/category_product_service.dart';

/// Model representing a tappable sub-category card.
class SubCategory {
  final String name;
  final String imageUrl;
  final Color color;
  final VoidCallback? onTap;

  const SubCategory({
    required this.name,
    required this.imageUrl,
    required this.color,
    this.onTap,
  });
}

/// A generic template page that can be reused for *any* high-level
/// category (Women, Men, Beauty, etc.).
///
/// Example usage:
/// ```dart
/// CategoryPage(
///   title: 'Women',
///   subCategories: [...],
///   featuredStoreIds: ['abc123', 'def456'],
///   sections: ['Tops', 'Shoes'],
/// );
/// ```
class CategoryPage extends StatefulWidget {
  /// Title displayed in the centered app-bar.
  final String title;

  /// Up to six sub-categories that will be rendered as tappable cards.
  final List<SubCategory> subCategories;

  /// The Firestore document-ids of stores to highlight in the *Featured brands* section.
  /// Provide between 1–4 ids. If less than four are supplied, the first one will be
  /// duplicated so that the UI still renders a 2 × 2 grid.
  final List<String> featuredStoreIds;

  /// Names of the sections that follow the *Featured brands* block. Each section will
  /// display four product placeholders in a 2 × 2 grid.
  final List<String> sections;

  const CategoryPage({
    super.key,
    required this.title,
    required this.subCategories,
    required this.featuredStoreIds,
    required this.sections,
  }) : assert(subCategories.length <= 6, '6-аас доош ангилал оруулна уу');

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  String? _placeholderImage;
  List<StoreData> _featuredStores = [];
  Map<String, List<ProductModel>> _sectionProducts = {};
  final CategoryProductService _categoryService = CategoryProductService();

  @override
  void initState() {
    super.initState();
    _loadPlaceholder();
    _loadFeaturedStores();
    _loadSectionProducts();
  }

  Future<void> _loadPlaceholder() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc('ComingSoon')
          .get();
      final data = doc.data();
      if (data == null) return;
      final images = List<String>.from(data['images'] ?? []);
      if (images.isNotEmpty) {
        setState(() => _placeholderImage = images.first);
      }
    } catch (_) {
      // Silently ignore – placeholder will just render grey box.
    }
  }

  Future<void> _loadFeaturedStores() async {
    if (widget.featuredStoreIds.isEmpty) return;

    final db = FirebaseFirestore.instance;
    final List<StoreData> loaded = [];

    for (final id in widget.featuredStoreIds) {
      try {
        final doc = await db.collection('stores').doc(id).get();
        if (!doc.exists) continue;
        final store = StoreModel.fromFirestore(doc);

        // Get actual store rating from reviews
        double storeRating = 0.0;
        String reviewCount = '0';

        try {
          final reviewsSnapshot = await FirebaseFirestore.instance
              .collection('stores')
              .doc(store.id)
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
            reviewCount = reviews.length > 1000
                ? '${(reviews.length / 1000).toStringAsFixed(1)}K'
                : reviews.length.toString();
          }
        } catch (reviewError) {
          print('⚠️ Error loading reviews for store ${store.id}: $reviewError');
          // Keep default values
        }

        loaded.add(
          StoreData(
            id: store.id,
            name: store.name,
            displayName: store.name.toUpperCase(),
            heroImageUrl: store.banner.isNotEmpty ? store.banner : store.logo,
            backgroundColor: const Color(0xFFFFFFFF),
            rating: double.parse(storeRating.toStringAsFixed(1)),
            reviewCount: reviewCount,
            collections: const <StoreCollection>[],
            categories: const <String>['All'],
            productCount: 0,
            products: const <StoreProduct>[],
            showFollowButton: true,
            hasNotification: false,
          ),
        );
      } catch (_) {
        // Ignore individual failures so that other stores can still load.
      }
    }

    // Ensure we always have 4 cards to satisfy the 2 × 2 grid.
    while (loaded.length < 4 && loaded.isNotEmpty) {
      loaded.add(loaded.first);
    }

    setState(() => _featuredStores = loaded);
  }

  Future<void> _loadSectionProducts() async {
    final Map<String, List<ProductModel>> sectionProducts = {};

    for (final section in widget.sections) {
      try {
        print('🔍 Loading products for section: $section');
        List<ProductModel> products = [];

        // Step 1: Try to load featured products from super admin
        try {
          String featuredPath = '${widget.title}_$section';
          final featuredDoc = await FirebaseFirestore.instance
              .doc('featured_products/$featuredPath')
              .get();

          if (featuredDoc.exists) {
            final data = featuredDoc.data() as Map<String, dynamic>;
            final productIds = List<String>.from(data['productIds'] ?? []);

            for (final productId in productIds.take(2)) {
              // Take 2 featured products
              try {
                // First try the old structure (products/{productId})
                final productDoc = await FirebaseFirestore.instance
                    .collection('products')
                    .doc(productId)
                    .get();

                if (productDoc.exists) {
                  products.add(ProductModel.fromFirestore(productDoc));
                } else {
                  // Fallback: search in collection group using a field query (not documentId)
                  final productQuery = await FirebaseFirestore.instance
                      .collectionGroup('products')
                      .where('productId', isEqualTo: productId)
                      .limit(1)
                      .get();

                  if (productQuery.docs.isNotEmpty) {
                    products.add(
                        ProductModel.fromFirestore(productQuery.docs.first));
                  }
                }
              } catch (e) {
                print('Error loading featured product $productId: $e');
              }
            }
          }
        } catch (e) {
          print('Error loading featured products for section $section: $e');
        }

        // Step 2: Fill remaining slots with actual category products
        final remainingSlots = 4 - products.length;
        if (remainingSlots > 0) {
          try {
            final categoryProducts =
                await _categoryService.loadProductsByCategory(
              category: widget.title,
              subCategory: section,
              limit: remainingSlots + 2, // Get a few extra for variety
            );

            // Filter out already added featured products
            final existingIds = products.map((p) => p.id).toSet();
            final newProducts = categoryProducts
                .where((p) => !existingIds.contains(p.id))
                .take(remainingSlots)
                .toList();

            products.addAll(newProducts);
          } catch (e) {
            print('Error loading category products for section $section: $e');
          }
        }

        // Step 3: If still not enough, try broader search
        if (products.length < 4) {
          try {
            final searchTerms = [section, widget.title];
            final broadProducts = await _categoryService.loadProductsByTerms(
              searchTerms: searchTerms,
              limit: 4 - products.length + 2,
            );

            final existingIds = products.map((p) => p.id).toSet();
            final newProducts = broadProducts
                .where((p) => !existingIds.contains(p.id))
                .take(4 - products.length)
                .toList();

            products.addAll(newProducts);
          } catch (e) {
            print('Error loading broad products for section $section: $e');
          }
        }

        sectionProducts[section] = products;
        print('✅ Loaded ${products.length} products for section $section');
      } catch (e) {
        print('❌ Error loading products for section $section: $e');
        sectionProducts[section] = [];
      }
    }

    setState(() {
      _sectionProducts = sectionProducts;
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
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false, // No back arrow
          centerTitle: true,
          title: Text(
            widget.title,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              _buildSubCategoryGrid(),
              const SizedBox(height: 24),
              _buildFeaturedBrandsSection(),
              const SizedBox(height: 24),
              ...widget.sections.expand((s) => [
                    _buildCategorySection(s),
                    const SizedBox(height: 24),
                  ])
            ],
          ),
        ),
      ),
    );
  }

  // ---------- UI BUILDERS ----------
  Widget _buildSubCategoryGrid() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: widget.subCategories.length,
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) => _subCatCard(widget.subCategories[index]),
    );
  }

  Widget _subCatCard(SubCategory cat) {
    return GestureDetector(
      onTap: cat.onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                cat.imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    cat.color.withOpacity(0.3),
                    cat.color.withOpacity(0.7),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              bottom: 16,
              child: Text(
                cat.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedBrandsSection() {
    if (_featuredStores.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Онцлоx Дэлгүүрүүд',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.8,
          children: _featuredStores.map(_brandCard).toList(),
        ),
      ],
    );
  }

  Widget _brandCard(StoreData store) {
    return GestureDetector(
      onTap: () => _openStore(context, store.id),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: store.heroImageUrl.startsWith('http')
                    ? Image.network(
                        store.heroImageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => Container(
                          color: Colors.grey.shade300,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image, size: 40),
                        ),
                      )
                    : Image.asset(store.heroImageUrl, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: store.heroImageUrl.startsWith('http')
                      ? Image.network(
                          store.heroImageUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) =>
                              const Icon(Icons.broken_image, size: 40),
                        )
                      : Image.asset(
                          store.heroImageUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            store.rating.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 1),
                          const Icon(Icons.star, size: 14, color: Colors.black),
                          const SizedBox(width: 3),
                          Text(
                            '(${store.reviewCount})',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(String title) {
    final products = _sectionProducts[title] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: 4,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.8,
          ),
          itemBuilder: (context, index) {
            if (index < products.length) {
              return _productCard(products[index]);
            } else {
              return _productPlaceholder();
            }
          },
        ),
      ],
    );
  }

  Widget _productCard(ProductModel product) {
    return GestureDetector(
      onTap: () async {
        // Load store information for the product
        try {
          final storeDoc = await FirebaseFirestore.instance
              .collection('stores')
              .doc(product.storeId)
              .get();

          String storeName = '';
          String storeLogoUrl = '';
          double storeRating = 0.0;
          int storeRatingCount = 0;

          if (storeDoc.exists) {
            final storeData = storeDoc.data()!;
            storeName = storeData['name'] ?? '';
            storeLogoUrl = storeData['logo'] ?? '';
            storeRating = (storeData['rating'] ?? 0.0).toDouble();
            storeRatingCount = storeData['ratingCount'] ?? 0;
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductPage(
                product: product,
                storeName: storeName,
                storeLogoUrl: storeLogoUrl,
                storeRating: storeRating,
                storeRatingCount: storeRatingCount,
              ),
            ),
          );
        } catch (e) {
          print('Error loading store info: $e');
          // Navigate anyway with empty store info
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductPage(
                product: product,
                storeName: '',
                storeLogoUrl: '',
                storeRating: 0,
                storeRatingCount: 0,
              ),
            ),
          );
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: product.images.isNotEmpty
                ? Image.network(
                    product.images.first,
                    width: double.infinity,
                    height: 160,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: double.infinity,
                      height: 160,
                      color: Colors.grey.shade300,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image, size: 40),
                    ),
                  )
                : Container(
                    width: double.infinity,
                    height: 160,
                    color: Colors.grey.shade300,
                    alignment: Alignment.center,
                    child: const Icon(Icons.inventory_2, size: 40),
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            product.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '₮${product.price.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _productPlaceholder() {
    return GestureDetector(
      onTap: () {
        final product = ProductModel(
          id: 'placeholder',
          storeId: '',
          name: 'Удахгүй',
          description: 'Stay tuned – great products on the way!',
          price: 0,
          images: _placeholderImage != null ? [_placeholderImage!] : [],
          category: '',
          stock: 0,
          variants: const <ProductVariant>[],
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductPage(
              product: product,
              storeName: '',
              storeLogoUrl: '',
              storeRating: 0,
              storeRatingCount: 0,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _placeholderImage != null
                ? Image.network(_placeholderImage!,
                    width: double.infinity, height: 160, fit: BoxFit.cover)
                : Container(
                    width: double.infinity,
                    height: 160,
                    color: Colors.grey.shade300,
                    alignment: Alignment.center,
                    child: const Text('Уучлаарай, одоогоор хоосон байна. :(',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
          ),
          const SizedBox(height: 8),
          const Text('Уучлаарай, одоогоор хоосон байна. :(',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _openStore(BuildContext context, String storeId) async {
    final db = FirebaseFirestore.instance;
    final storeDoc = await db.collection('stores').doc(storeId).get();
    if (!storeDoc.exists) return;
    final storeModel = StoreModel.fromFirestore(storeDoc);

    // Fetch up to 20 products
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

    // Get actual rating data instead of hardcoded values
    final ratingData = await RatingService().getStoreRating(storeId);

    final storeData = StoreData(
      id: storeModel.id,
      name: storeModel.name,
      displayName: storeModel.name.toUpperCase(),
      heroImageUrl:
          storeModel.banner.isNotEmpty ? storeModel.banner : storeModel.logo,
      backgroundColor: const Color(0xFF01BCE7),
      rating: ratingData.rating,
      reviewCount: ratingData.reviewCountDisplay,
      collections: const [],
      categories: const ['All'],
      productCount: products.length,
      products: products
          .map((p) => StoreProduct(
                id: p.id,
                name: p.name,
                imageUrl: p.images.isNotEmpty ? p.images.first : '',
                price: p.price,
              ))
          .toList(),
      showFollowButton: true,
      hasNotification: false,
    );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StoreScreen(storeData: storeData)),
    );
  }
}
