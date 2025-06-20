import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shoppy/features/auth/providers/auth_provider.dart';
import 'package:shoppy/features/stores/models/store_model.dart';
import 'package:shoppy/features/products/models/product_model.dart';
import '../domain/models.dart';
import 'floating_nav_bar.dart';
import 'main_scaffold.dart';
import 'firestore_store_screen.dart';
import 'package:shoppy/features/stores/presentation/store_screen.dart';
import 'package:shoppy/features/stores/presentation/store_screen.dart'
    show StoreData, StoreProduct;
import 'package:shoppy/features/products/presentation/product_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  late Future<List<SellerData>> _sellersFuture;
  Future<List<Store>>? _followingFuture;

  @override
  void initState() {
    super.initState();
    _sellersFuture = _loadSellers();

    // Load followed stores for current user (logos + names)
    final auth = context.read<AuthProvider>();
    if (auth.user != null) {
      _followingFuture = _loadFollowingStores(auth.user!.uid);
    } else {
      _followingFuture = Future.value([]);
    }
  }

  Future<List<Store>> _loadFollowingStores(String uid) async {
    final userDoc = await _db.collection('users').doc(uid).get();
    final List<dynamic> ids = userDoc.data()?['followerStoreIds'] ?? [];
    if (ids.isEmpty) return [];
    final snap = await _db
        .collection('stores')
        .where(FieldPath.documentId, whereIn: ids)
        .get();
    return snap.docs
        .map(StoreModel.fromFirestore)
        .map((s) => Store(id: s.id, name: s.name, imageUrl: s.logo))
        .toList();
  }

  Future<List<SellerData>> _loadSellers() async {
    // Fetch all stores; you can add filters like status=='active' once data is consistent
    final storeSnap = await _db.collection('stores').get();

    final List<SellerData> result = [];
    for (final doc in storeSnap.docs) {
      final storeModel = StoreModel.fromFirestore(doc);
      final products = await _fetchProducts(storeModel.id);

      final sellerProducts = products
          .map((p) => SellerProduct(
                id: p.id,
                imageUrl: p.images.isNotEmpty ? p.images.first : '',
                price: '\$${p.price.toStringAsFixed(2)}',
              ))
          .toList();

      result.add(SellerData(
        name: storeModel.name,
        storeId: storeModel.id,
        profileLetter:
            storeModel.name.isNotEmpty ? storeModel.name[0].toUpperCase() : '?',
        rating: 4.9,
        reviews: 25,
        products: sellerProducts,
        backgroundImageUrl: storeModel.banner,
        isAssetBg: false,
      ));
    }
    return result;
  }

  Future<List<ProductModel>> _fetchProducts(String storeId,
      {int limit = 4}) async {
    final lower = await _db
        .collection('products')
        .where('storeId', isEqualTo: storeId)
        .limit(limit)
        .get();
    if (lower.docs.isNotEmpty) {
      return lower.docs.map((d) => ProductModel.fromFirestore(d)).toList();
    }
    final upper = await _db
        .collection('products')
        .where('StoreId', isEqualTo: storeId)
        .limit(limit)
        .get();
    return upper.docs.map((d) => ProductModel.fromFirestore(d)).toList();
  }

  // Your offers data
  final List<Offer> offers = [
    Offer(
      id: 'dracoslides',
      imageUrl:
          'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=400',
      discount: 'Save \$25',
      storeName: 'DRACOSLIDES',
      rating: 4.6,
      reviews: '16K',
      title: 'SPRING SALE',
    ),
    Offer(
      id: 'purplebrand',
      imageUrl:
          'https://i.pinimg.com/236x/3b/de/66/3bde66eb4a2eb105e1e8e5f0f341a925.jpg',
      discount: 'Save \$50',
      storeName: 'PURPLE BRAND',
      rating: 4.8,
      reviews: '6.3K',
      title: 'PURPLE',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      currentIndex: 0,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(context),

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      // Following Section
                      FutureBuilder<List<Store>>(
                        future: _followingFuture,
                        builder: (context, snap) {
                          if (!snap.hasData) {
                            return const SizedBox(
                                height: 100,
                                child:
                                    Center(child: CircularProgressIndicator()));
                          }
                          return _buildFollowingSection(context, snap.data!);
                        },
                      ),

                      const SizedBox(height: 24),

                      // Your Offers Section
                      _buildYourOffersSection(context),

                      const SizedBox(height: 24),

                      // Seller Cards (dynamic)
                      FutureBuilder<List<SellerData>>(
                        future: _sellersFuture,
                        builder: (context, snap) {
                          if (!snap.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          final data = snap.data!;
                          if (data.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text('No active stores yet'),
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: data
                                  .map((seller) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 24),
                                        child:
                                            _buildSellerCard(context, seller),
                                      ))
                                  .toList(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 80), // Space for bottom nav
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          const Text(
            'shop',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Color.fromARGB(255, 22, 14, 179),
              letterSpacing: 0.5,
            ),
          ),

          // Right side actions
          Row(
            children: [
              // Balance
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Balance tapped!')),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    '\$0.00',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Notification
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notifications tapped!')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.notifications_outlined,
                    size: 20,
                    color: Colors.black87,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Profile
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/account');
                },
                child: const CircleAvatar(
                  radius: 20,
                  backgroundImage: AssetImage(
                    'assets/images/placeholders/ASAP.jpg',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFollowingSection(
      BuildContext context, List<Store> followingStores) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Following header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Text(
                'Таны дагадаг дэлгүүрүүд',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 20, color: Colors.black54),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Horizontal scrolling stores - 65x65 pixels with 7px gaps
        SizedBox(
          height: 85, // 65px + space for text below
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: followingStores.isNotEmpty ? followingStores.length : 1,
            separatorBuilder: (_, __) => const SizedBox(width: 7), // 7px gap
            itemBuilder: (context, index) {
              if (followingStores.isEmpty) {
                // show placeholder text
                return const Center(
                    child: Text("You don't follow any stores at the moment"));
              }
              final store = followingStores[index];
              return GestureDetector(
                onTap: () {
                  _openStore(context, store.id);
                },
                child: Column(
                  children: [
                    Container(
                      width: 65, // Exact 65px width
                      height: 65, // Exact 65px height
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          store.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child:
                                  const Icon(Icons.store, color: Colors.grey),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 65,
                      child: Text(
                        store.name,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildYourOffersSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Your offers header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Text(
                'Xямдралтай бараа',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 20, color: Colors.black54),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Horizontal scrolling offers - 185x191 pixels
        SizedBox(
          height: 191, // Exact 191px height
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: offers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final offer = offers[index];
              return GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${offer.storeName} offer tapped!')),
                  );
                },
                child: Container(
                  width: 185, // Exact 185px width
                  height: 191, // Exact 191px height
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
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
                      // Background image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          offer.imageUrl,
                          width: 185,
                          height: 191,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 185,
                              height: 191,
                              color: Colors.grey[300],
                              child: const Icon(Icons.image,
                                  size: 50, color: Colors.grey),
                            );
                          },
                        ),
                      ),

                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                      ),

                      // Bottom content
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              offer.storeName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  offer.rating.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(Icons.star,
                                    color: Colors.amber, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  '(${offer.reviews})',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSellerCard(BuildContext context, SellerData seller) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        image: seller.backgroundImageUrl != null
            ? DecorationImage(
                image: seller.isAssetBg
                    ? AssetImage(seller.backgroundImageUrl!)
                    : NetworkImage(seller.backgroundImageUrl!) as ImageProvider,
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.white.withOpacity(0.7),
                  BlendMode.lighten,
                ),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Seller Info
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.black87,
                child: Text(
                  seller.profileLetter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      seller.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          seller.rating.toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.star, color: Colors.black87, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '(${seller.reviews})',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${seller.name} options tapped!')),
                  );
                },
                child: const Icon(
                  Icons.more_horiz,
                  color: Colors.black54,
                  size: 24,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Products Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1,
            ),
            itemCount: seller.products.length,
            itemBuilder: (context, index) {
              return _buildProductCard(context, seller.products[index], seller);
            },
          ),

          const SizedBox(height: 20),

          // Shop All Button
          Row(
            children: [
              const Text(
                'Shop all',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _openStore(context, seller.storeId),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0F0F0),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    size: 20,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(
      BuildContext context, SellerProduct product, SellerData seller) {
    return GestureDetector(
      onTap: () async {
        final doc = await FirebaseFirestore.instance
            .collection('products')
            .doc(product.id)
            .get();
        if (!doc.exists) return;
        final prodModel = ProductModel.fromFirestore(doc);
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductPage(
              product: prodModel,
              storeName: seller.name,
              storeLogoUrl: '',
              storeRating: seller.rating,
              storeRatingCount: seller.reviews,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            // Product Image
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                product.imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child:
                        const Icon(Icons.image, size: 50, color: Colors.grey),
                  );
                },
              ),
            ),

            // Price Tag
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  product.price,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),

            // Heart Icon
            Positioned(
              bottom: 8,
              right: 8,
              child: GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Added to favorites!')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_border,
                    size: 16,
                    color: Colors.black54,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openStore(BuildContext context, String storeId) async {
    final storeDoc = await FirebaseFirestore.instance
        .collection('stores')
        .doc(storeId)
        .get();
    if (!storeDoc.exists) return;
    final storeModel = StoreModel.fromFirestore(storeDoc);

    final products = await _fetchProducts(storeModel.id, limit: 20);

    // Build StoreData for legacy StoreScreen
    final storeData = StoreData(
      id: storeModel.id,
      name: storeModel.name,
      displayName: storeModel.name.toUpperCase(),
      heroImageUrl:
          storeModel.banner.isNotEmpty ? storeModel.banner : storeModel.logo,
      backgroundColor: const Color(0xFF01BCE7),
      rating: 4.9,
      reviewCount: '25',
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoreScreen(storeData: storeData),
      ),
    );
  }
}

// Data models
class SellerData {
  final String name;
  final String storeId;
  final String profileLetter;
  final double rating;
  final int reviews;
  final List<SellerProduct> products;
  final String? backgroundImageUrl;
  final bool isAssetBg;

  SellerData({
    required this.name,
    required this.storeId,
    required this.profileLetter,
    required this.rating,
    required this.reviews,
    required this.products,
    this.backgroundImageUrl,
    this.isAssetBg = false,
  });
}
