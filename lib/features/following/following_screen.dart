import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:avii/features/auth/providers/auth_provider.dart';
import 'package:avii/features/stores/models/store_model.dart';
import 'package:avii/features/products/models/product_model.dart';
import 'package:avii/features/home/domain/models.dart' show SellerProduct;
import 'package:avii/features/home/presentation/widgets/seller_card.dart';
import 'package:avii/features/home/presentation/main_scaffold.dart';
import 'package:avii/features/home/presentation/home_screen.dart'
    show SellerData;
import 'package:avii/features/stores/presentation/store_screen.dart';
import 'services/following_service.dart';
import '../../core/services/rating_service.dart';

class FollowingScreen extends StatefulWidget {
  const FollowingScreen({super.key});

  @override
  State<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  final FollowingService _followingService = FollowingService();

  void _showUnfollowAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Бүх дэлгүүрийг дагахаа больx'),
        content:
            const Text('Бүх дэлгүүрийг дагахаа больxдоо итгэлтэй байна уу?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Цуцлах'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _unfollowAllStores();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Бүх дэлгүүрийг дагахаа больx'),
          ),
        ],
      ),
    );
  }

  Future<void> _unfollowAllStores() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(auth.user!.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        final storeIds = List<String>.from(data['followerStoreIds'] ?? []);

        for (final storeId in storeIds) {
          await _followingService.unfollowStore(storeId);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Амжилттай!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Алдаа гарлаа: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return MainScaffold(
      currentIndex: 0,
      showBackButton: true,
      onBack: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: const Text(
            'Таны дагадаг дэлгүүрүүд',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.black),
              onSelected: (value) {
                if (value == 'unfollow_all') {
                  _showUnfollowAllDialog();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'unfollow_all',
                  child: Row(
                    children: [
                      Icon(Icons.remove_circle_outline, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Бүх дэлгүүрийг дагахаа больx'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: auth.user == null
              ? const Center(child: Text('Бүртгүүлэх'))
              : StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(auth.user!.uid)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final data = snap.data?.data() as Map<String, dynamic>?;
                    final storeIds =
                        List<String>.from(data?['followerStoreIds'] ?? []);
                    if (storeIds.isEmpty) {
                      return const _EmptyFollowing();
                    }
                    return _FollowedStoresGrid(ids: storeIds);
                  },
                ),
        ),
      ),
    );
  }
}

class _EmptyFollowing extends StatelessWidget {
  const _EmptyFollowing();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Та одоогоор ямар ч дэлгүүр дагаагүй байна',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Та ямар ч дэлгүүрийг дагаx боломжтой!',
              style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
            child: const Text('нүүр хуудаслуу буцах',
                style: TextStyle(color: Color(0xFF6A5AE0))),
          )
        ],
      ),
    );
  }
}

class _FollowedStoresGrid extends StatelessWidget {
  final List<String> ids;
  const _FollowedStoresGrid({required this.ids});

  Future<List<SellerData>> _buildSellerData() async {
    final db = FirebaseFirestore.instance;
    final storeSnap = await db
        .collection('stores')
        .where(FieldPath.documentId, whereIn: ids)
        .get();
    List<SellerData> result = [];
    for (final doc in storeSnap.docs) {
      final store = StoreModel.fromFirestore(doc);
      final prodSnap = await db
          .collection('products')
          .where('storeId', isEqualTo: store.id)
          .limit(4)
          .get();
      final products =
          prodSnap.docs.map((d) => ProductModel.fromFirestore(d)).toList();
      final sellerProducts = products
          .map((p) => SellerProduct(
                id: p.id,
                imageUrl: p.images.isNotEmpty ? p.images.first : '',
                price: '₮${p.price.toStringAsFixed(2)}',
              ))
          .toList();

      // Get actual rating data instead of hardcoded values
      final ratingData = await RatingService().getStoreRating(store.id);

      result.add(SellerData(
        name: store.name,
        storeId: store.id,
        profileLetter:
            store.name.isNotEmpty ? store.name[0].toUpperCase() : '?',
        rating: ratingData.rating,
        reviews: ratingData.reviewCount,
        products: sellerProducts,
        backgroundImageUrl: store.banner,
        storeLogoUrl: store.logo, // Add store logo URL
        isAssetBg: false,
      ));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SellerData>>(
      future: _buildSellerData(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final sellers = snap.data!;
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          separatorBuilder: (_, __) => const SizedBox(height: 24),
          itemCount: sellers.length,
          itemBuilder: (context, index) {
            final s = sellers[index];
            return _SellerCardWithNav(seller: s);
          },
        );
      },
    );
  }
}

class _SellerCardWithNav extends StatelessWidget {
  final SellerData seller;
  const _SellerCardWithNav({required this.seller});

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

    // Build StoreData
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoreScreen(storeData: storeData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SellerCard(
      sellerName: seller.name,
      profileLetter: seller.profileLetter,
      rating: seller.rating,
      reviews: seller.reviews,
      products: seller.products,
      storeId: seller.storeId,
      storeLogoUrl: seller.storeLogoUrl, // Pass store logo URL
      onShopAllTap: () => _openStore(context, seller.storeId),
    );
  }
}
