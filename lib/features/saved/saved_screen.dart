import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:avii/features/auth/providers/auth_provider.dart';
import 'package:avii/features/products/models/product_model.dart';
import 'package:avii/features/products/presentation/product_page.dart';
import 'package:avii/features/home/presentation/main_scaffold.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return MainScaffold(
      currentIndex: 3,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              const _Header(),
              Expanded(
                child: auth.user == null
                    ? const Center(
                        child: Text(
                            'Та аккаунт үүсгэсний хадгаласан бараанууд харагдана'))
                    : StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(auth.user!.uid)
                            .snapshots(),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          final data =
                              snap.data?.data() as Map<String, dynamic>?;
                          final ids =
                              List<String>.from(data?['savedProductIds'] ?? []);
                          if (ids.isEmpty) return const _EmptyState();
                          return _SavedGrid(ids: ids);
                        },
                      ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: Text('Хадгалсан бараанууд',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black26),
            ),
            child: const Icon(Icons.favorite_border,
                size: 40, color: Colors.black45),
          ),
          const SizedBox(height: 24),
          const Text('Хадгалсан бараа алга',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Таны хадгаласан бараанууд энд харагдана',
              style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
            child: const Text('нүүр хуудаслүү буцах',
                style: TextStyle(color: Color(0xFF6A5AE0))),
          )
        ],
      ),
    );
  }
}

class _SavedGrid extends StatelessWidget {
  final List<String> ids;
  const _SavedGrid({required this.ids});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('products')
          .where(FieldPath.documentId, whereIn: ids)
          .get(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final products =
            snap.data!.docs.map((d) => ProductModel.fromFirestore(d)).toList();
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.65,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            return _SavedCard(product: products[index]);
          },
        );
      },
    );
  }
}

class _SavedCard extends StatelessWidget {
  final ProductModel product;
  const _SavedCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
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
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: product.images.isNotEmpty
                      ? Image.network(product.images.first,
                          width: double.infinity, fit: BoxFit.cover)
                      : Container(color: Colors.grey[300]),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: product.isDiscounted && product.discountPercent > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                              '${product.discountPercent.toStringAsFixed(0)}% off',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12)),
                        )
                      : const SizedBox.shrink(),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    decoration: const BoxDecoration(
                        color: Color(0xFF6A5AE0), shape: BoxShape.circle),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(Icons.favorite,
                        color: Colors.white, size: 18),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('₮${product.price.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
