import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shoppy/features/stores/models/store_model.dart';
import 'package:shoppy/features/products/models/product_model.dart';

class FirestoreStoreScreen extends StatelessWidget {
  final String storeId;
  const FirestoreStoreScreen({super.key, required this.storeId});

  Future<StoreModel?> _loadStore() async {
    final doc = await FirebaseFirestore.instance
        .collection('stores')
        .doc(storeId)
        .get();
    if (!doc.exists) return null;
    return StoreModel.fromFirestore(doc);
  }

  Future<List<ProductModel>> _loadProducts() async {
    final db = FirebaseFirestore.instance.collection('products');

    // Attempt 1: lowercase 'storeId'
    final lowerSnap = await db.where('storeId', isEqualTo: storeId).get();
    if (lowerSnap.docs.isNotEmpty) {
      return lowerSnap.docs.map((d) => ProductModel.fromFirestore(d)).toList();
    }

    // Attempt 2: uppercase 'StoreId'
    final upperSnap = await db.where('StoreId', isEqualTo: storeId).get();
    if (upperSnap.docs.isNotEmpty) {
      return upperSnap.docs.map((d) => ProductModel.fromFirestore(d)).toList();
    }

    // No products found
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StoreModel?>(
      future: _loadStore(),
      builder: (context, storeSnap) {
        if (!storeSnap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final store = storeSnap.data;
        if (store == null) {
          return const Scaffold(body: Center(child: Text('Store not found')));
        }
        return Scaffold(
          appBar: AppBar(title: Text(store.name)),
          body: FutureBuilder<List<ProductModel>>(
            future: _loadProducts(),
            builder: (context, prodSnap) {
              if (!prodSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final products = prodSnap.data!;
              if (products.isEmpty) {
                return const Center(child: Text('No products'));
              }
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.8,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final p = products[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: p.images.isNotEmpty
                              ? Image.network(p.images.first, fit: BoxFit.cover)
                              : Container(color: Colors.grey[300]),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(p.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('\$${p.price.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
