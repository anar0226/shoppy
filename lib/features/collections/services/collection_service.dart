import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/collection_model.dart';

class CollectionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'collections';

  // Create a new collection
  Future<String> createCollection(CollectionModel collection) async {
    DocumentReference docRef =
        await _firestore.collection(_collection).add(collection.toMap());
    return docRef.id;
  }

  // Get a collection by ID
  Future<CollectionModel?> getCollection(String collectionId) async {
    DocumentSnapshot doc =
        await _firestore.collection(_collection).doc(collectionId).get();
    if (doc.exists) {
      return CollectionModel.fromFirestore(doc);
    }
    return null;
  }

  // Get all collections for a store
  Stream<List<CollectionModel>> getStoreCollections(String storeId) {
    return _firestore
        .collection(_collection)
        .where('storeId', isEqualTo: storeId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CollectionModel.fromFirestore(doc))
            .toList());
  }

  // Update a collection
  Future<void> updateCollection(
      String collectionId, CollectionModel collection) async {
    await _firestore
        .collection(_collection)
        .doc(collectionId)
        .update(collection.toMap());
  }

  // Delete a collection (soft delete)
  Future<void> deleteCollection(String collectionId) async {
    await _firestore.collection(_collection).doc(collectionId).update({
      'isActive': false,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // Hard delete a collection
  Future<void> hardDeleteCollection(String collectionId) async {
    await _firestore.collection(_collection).doc(collectionId).delete();
  }

  // Get collection count for a store
  Future<int> getCollectionCount(String storeId) async {
    QuerySnapshot snapshot = await _firestore
        .collection(_collection)
        .where('storeId', isEqualTo: storeId)
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs.length;
  }

  // Search collections by name
  Stream<List<CollectionModel>> searchCollections(
      String storeId, String query) {
    return _firestore
        .collection(_collection)
        .where('storeId', isEqualTo: storeId)
        .where('isActive', isEqualTo: true)
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: '$query\uf8ff')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CollectionModel.fromFirestore(doc))
            .toList());
  }
}
