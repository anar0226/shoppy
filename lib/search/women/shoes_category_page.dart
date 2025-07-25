import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:avii/features/stores/presentation/store_screen.dart'
    show StoreScreen, StoreData, StoreCollection, StoreProduct;
import 'package:avii/features/stores/models/store_model.dart';
import 'package:avii/features/products/presentation/product_page.dart';
import 'package:avii/features/products/models/product_model.dart'
    show ProductModel, ProductVariant;
import '../../features/home/presentation/main_scaffold.dart';
import 'package:avii/features/categories/presentation/final_category_page.dart';
import '../../core/services/error_handler_service.dart';
import '../../core/services/rating_service.dart';

class ShoesCategoryPage extends StatefulWidget {
  const ShoesCategoryPage({super.key});

  @override
  State<ShoesCategoryPage> createState() => _ShoesCategoryPageState();
}

class _ShoesCategoryPageState extends State<ShoesCategoryPage> {
  String? _placeholderImage;

  // --- Featured brands (LalarStore) ---
  static const String _lalarStoreId = 'TLLb3tqzvU2TZSsNPol9';
  List<StoreData> _featuredStores = [];

  @override
  void initState() {
    super.initState();
    _loadPlaceholder();
    _loadFeaturedStore();
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
          setState(() => _placeholderImage = images.first);
        }
      }
    } catch (error, stackTrace) {
      if (mounted) {
        await ErrorHandlerService.instance.handleError(
          operation: 'load_placeholder_image',
          error: error,
          stackTrace: stackTrace,
          context: context,
          showUserMessage: false, // Silent failure for placeholder image
          additionalContext: {'categoryId': 'shoes'},
        );
      }
    }
  }

  Future<void> _loadFeaturedStore() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('stores')
          .doc(_lalarStoreId)
          .get();
      if (!doc.exists) return;
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
          final totalRating = reviews.fold<double>(0, (total, doc) {
            final data = doc.data();
            return total + ((data['rating'] as num?)?.toDouble() ?? 0);
          });
          storeRating = totalRating / reviews.length;
          reviewCount = reviews.length > 1000
              ? '${(reviews.length / 1000).toStringAsFixed(1)}K'
              : reviews.length.toString();
        }
      } catch (reviewError) {
        // Error loading reviews for store
        // Keep default values
      }

      final storeData = StoreData(
        id: store.id,
        name: store.name,
        displayName: store.name.toUpperCase(),
        heroImageUrl: store.banner.isNotEmpty ? store.banner : store.logo,
        backgroundColor: const Color(0xFFFFFFFF),
        rating: double.parse(storeRating.toStringAsFixed(1)),
        reviewCount: reviewCount,
        collections: const <StoreCollection>[],
        categories: const <String>["All"],
        productCount: 0,
        products: const <StoreProduct>[],
        showFollowButton: true,
        hasNotification: false,
      );
      setState(() {
        _featuredStores = List<StoreData>.filled(4, storeData);
      });
    } catch (error, stackTrace) {
      if (mounted) {
        await ErrorHandlerService.instance.handleError(
          operation: 'load_featured_store',
          error: error,
          stackTrace: stackTrace,
          context: context,
          showUserMessage: false, // Silent failure for featured stores
          additionalContext: {'categoryId': 'shoes'},
        );
      }
    }
  }

  static const List<String> _sections = [
    'Өндөр өсгийт',
    'Шаахай',
    'Пүүз',
    'Бусад',
  ];

  final List<_SubCat> _subCats = const [
    _SubCat('Өндөр өсгийт', 'assets/images/categories/Women/shoes/Heels.jpg',
        Color(0xFF8B4513)),
    _SubCat('Шаахай', 'assets/images/categories/Women/shoes/Slippers.jpg',
        Color(0xFFD97841)),
    _SubCat('Пүүз', 'assets/images/categories/Women/shoes/Sneakers.jpg',
        Color(0xFF6B9BD1)),
    _SubCat('Бусад', 'assets/images/categories/Women/shoes/Others.jpg',
        Color(0xFFB8A082)),
  ];

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
          title: const Text('Гутал', style: TextStyle(color: Colors.black)),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              _buildSubCategoryGrid(),
              const SizedBox(height: 24),
              _buildFeaturedBrandsSection(),
              const SizedBox(height: 24),
              ..._sections.expand((s) => [
                    _buildCategorySection(s),
                    const SizedBox(height: 24),
                  ])
            ],
          ),
        ),
      ),
    );
  }

  // ---------- UI Builders ----------
  Widget _buildSubCategoryGrid() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: _subCats.length,
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final cat = _subCats[index];
        return _subCatCard(cat);
      },
    );
  }

  Widget _subCatCard(_SubCat cat) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => FinalCategoryPage(title: cat.name)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
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
                    cat.color.withValues(alpha: 0.3),
                    cat.color.withValues(alpha: 0.7),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Онцлох брэндүүд',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.8,
          children: _featuredStores.map((s) => _brandCard(s)).toList(),
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
                    ? Image.network(store.heroImageUrl, fit: BoxFit.cover)
                    : Image.asset(store.heroImageUrl, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: store.heroImageUrl.startsWith('http')
                      ? Image.network(store.heroImageUrl,
                          width: 24, height: 24, fit: BoxFit.cover)
                      : Image.asset(store.heroImageUrl,
                          width: 24, height: 24, fit: BoxFit.cover),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    store.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.star, size: 14, color: Colors.black),
                const SizedBox(width: 4),
                Text(store.rating.toStringAsFixed(1)),
                const SizedBox(width: 4),
                Text('(${store.reviewCount})',
                    style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(String title) {
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
              childAspectRatio: 0.8),
          itemBuilder: (context, index) => _productPlaceholder(),
        ),
      ],
    );
  }

  Widget _productPlaceholder() {
    final product = ProductModel(
      id: 'placeholder',
      storeId: '',
      name: 'Удахгүй',
      description: 'Удахгүй шинэ бүтээгдэхүүн гарах болно!',
      price: 0,
      images: _placeholderImage != null ? [_placeholderImage!] : [],
      category: '',
      stock: 0,
      variants: const <ProductVariant>[],
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return GestureDetector(
      onTap: () => Navigator.push(
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
      ),
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
                    child: const Text('Удахгүй',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
          ),
          const SizedBox(height: 8),
          const Text('Удахгүй', style: TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ---------- Helper to navigate to full StoreScreen ----------
  Future<void> _openStore(BuildContext context, String storeId) async {
    final db = FirebaseFirestore.instance;
    final storeDoc = await db.collection('stores').doc(storeId).get();
    if (!storeDoc.exists) return;
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

    // Get actual rating data instead of hardcoded values
    final ratingData = await RatingService().getStoreRating(storeModel.id);

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

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => StoreScreen(storeData: storeData)),
      );
    }
  }
}

class _SubCat {
  final String name;
  final String imageUrl;
  final Color color;

  const _SubCat(this.name, this.imageUrl, this.color);
}
