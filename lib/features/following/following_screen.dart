import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shoppy/features/auth/providers/auth_provider.dart';
import 'package:shoppy/features/stores/models/store_model.dart';
import 'package:shoppy/features/products/models/product_model.dart';
import 'package:shoppy/features/home/domain/models.dart' show SellerProduct;
import 'package:shoppy/features/home/presentation/widgets/seller_card.dart';
import 'package:shoppy/features/home/presentation/main_scaffold.dart';
import 'package:shoppy/features/home/presentation/home_screen.dart'
    show SellerData;
import 'package:shoppy/features/stores/presentation/store_screen.dart';
import 'package:shoppy/features/stores/presentation/store_screen.dart'
    show StoreData, StoreProduct;

class FollowingScreen extends StatelessWidget {
  const FollowingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return MainScaffold(
      currentIndex: 0,
      showBackButton: true,
      onBack: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: auth.user == null
              ? const Center(child: Text('Sign in to view followed stores'))
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
          const Text('No followed stores yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Tap the follow button on any store',
              style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
            child: const Text('Go discover',
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
                price: '\$${p.price.toStringAsFixed(2)}',
              ))
          .toList();
      result.add(SellerData(
        name: store.name,
        storeId: store.id,
        profileLetter:
            store.name.isNotEmpty ? store.name[0].toUpperCase() : '?',
        rating: 4.9,
        reviews: 0,
        products: sellerProducts,
        backgroundImageUrl: store.banner,
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

    // Build StoreData
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

  @override
  Widget build(BuildContext context) {
    return SellerCard(
      sellerName: seller.name,
      profileLetter: seller.profileLetter,
      rating: seller.rating,
      reviews: seller.reviews,
      products: seller.products,
      onShopAllTap: () => _openStore(context, seller.storeId),
    );
  }
}
