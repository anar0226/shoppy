import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/product_model.dart';

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _collection = 'products';

  // Create a new product
  Future<String> createProduct(ProductModel product) async {
    DocumentReference docRef =
        await _firestore.collection(_collection).add(product.toMap());
    return docRef.id;
  }

  // Upload product images
  Future<List<String>> uploadProductImages(
      String storeId, List<File> images) async {
    List<String> imageUrls = [];

    for (var image in images) {
      String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${image.path.split('/').last}';
      Reference ref =
          _storage.ref().child('stores/$storeId/products/$fileName');

      await ref.putFile(image);
      String downloadUrl = await ref.getDownloadURL();
      imageUrls.add(downloadUrl);
    }

    return imageUrls;
  }

  // Get a product by ID
  Future<ProductModel?> getProduct(String productId) async {
    DocumentSnapshot doc =
        await _firestore.collection(_collection).doc(productId).get();
    if (doc.exists) {
      return ProductModel.fromFirestore(doc);
    }
    return null;
  }

  // Get all products for a store
  Stream<List<ProductModel>> getStoreProducts(String storeId) {
    return _firestore
        .collection(_collection)
        .where('storeId', isEqualTo: storeId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ProductModel.fromFirestore(doc))
            .toList());
  }

  // Update a product
  Future<void> updateProduct(String productId, ProductModel product) async {
    await _firestore
        .collection(_collection)
        .doc(productId)
        .update(product.toMap());
  }

  // Delete a product
  Future<void> deleteProduct(String productId) async {
    await _firestore.collection(_collection).doc(productId).delete();
  }

  // Search products in a store
  Stream<List<ProductModel>> searchStoreProducts(String storeId, String query) {
    return _firestore
        .collection(_collection)
        .where('storeId', isEqualTo: storeId)
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: '$query\uf8ff')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ProductModel.fromFirestore(doc))
            .toList());
  }

  // Get products by category
  Stream<List<ProductModel>> getProductsByCategory(
      String storeId, String category) {
    return _firestore
        .collection(_collection)
        .where('storeId', isEqualTo: storeId)
        .where('category', isEqualTo: category)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ProductModel.fromFirestore(doc))
            .toList());
  }
}
