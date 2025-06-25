import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category_model.dart';

class CategoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'store_categories';

  // Create a new category
  Future<String> createCategory(CategoryModel category) async {
    DocumentReference docRef =
        await _firestore.collection(_collection).add(category.toMap());
    return docRef.id;
  }

  // Get a category by ID
  Future<CategoryModel?> getCategory(String categoryId) async {
    DocumentSnapshot doc =
        await _firestore.collection(_collection).doc(categoryId).get();
    if (doc.exists) {
      return CategoryModel.fromFirestore(doc);
    }
    return null;
  }

  // Get all categories for a store
  Stream<List<CategoryModel>> getStoreCategories(String storeId) {
    return _firestore
        .collection(_collection)
        .where('storeId', isEqualTo: storeId)
        .where('isActive', isEqualTo: true)
        .orderBy('sortOrder', descending: false)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CategoryModel.fromFirestore(doc))
            .toList());
  }

  // Update a category
  Future<void> updateCategory(String categoryId, CategoryModel category) async {
    await _firestore
        .collection(_collection)
        .doc(categoryId)
        .update(category.toMap());
  }

  // Delete a category (soft delete)
  Future<void> deleteCategory(String categoryId) async {
    await _firestore.collection(_collection).doc(categoryId).update({
      'isActive': false,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // Hard delete a category
  Future<void> hardDeleteCategory(String categoryId) async {
    await _firestore.collection(_collection).doc(categoryId).delete();
  }

  // Add product to category
  Future<void> addProductToCategory(String categoryId, String productId) async {
    await _firestore.collection(_collection).doc(categoryId).update({
      'productIds': FieldValue.arrayUnion([productId]),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // Remove product from category
  Future<void> removeProductFromCategory(
      String categoryId, String productId) async {
    await _firestore.collection(_collection).doc(categoryId).update({
      'productIds': FieldValue.arrayRemove([productId]),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // Get categories count for a store
  Future<int> getCategoryCount(String storeId) async {
    QuerySnapshot snapshot = await _firestore
        .collection(_collection)
        .where('storeId', isEqualTo: storeId)
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs.length;
  }

  // Search categories by name
  Stream<List<CategoryModel>> searchCategories(String storeId, String query) {
    return _firestore
        .collection(_collection)
        .where('storeId', isEqualTo: storeId)
        .where('isActive', isEqualTo: true)
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: '$query\uf8ff')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CategoryModel.fromFirestore(doc))
            .toList());
  }

  // Update category sort order
  Future<void> updateCategorySortOrder(String categoryId, int newOrder) async {
    await _firestore.collection(_collection).doc(categoryId).update({
      'sortOrder': newOrder,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
