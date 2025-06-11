import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/store_model.dart';

class StoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'stores';

  // Create a new store
  Future<String> createStore(StoreModel store) async {
    DocumentReference docRef =
        await _firestore.collection(_collection).add(store.toMap());
    return docRef.id;
  }

  // Get a store by ID
  Future<StoreModel?> getStore(String storeId) async {
    DocumentSnapshot doc =
        await _firestore.collection(_collection).doc(storeId).get();
    if (doc.exists) {
      return StoreModel.fromFirestore(doc);
    }
    return null;
  }

  // Get all stores
  Stream<List<StoreModel>> getAllStores() {
    return _firestore.collection(_collection).snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => StoreModel.fromFirestore(doc)).toList());
  }

  // Get stores by owner
  Stream<List<StoreModel>> getStoresByOwner(String ownerId) {
    return _firestore
        .collection(_collection)
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => StoreModel.fromFirestore(doc)).toList());
  }

  // Update a store
  Future<void> updateStore(String storeId, StoreModel store) async {
    await _firestore.collection(_collection).doc(storeId).update(store.toMap());
  }

  // Delete a store
  Future<void> deleteStore(String storeId) async {
    await _firestore.collection(_collection).doc(storeId).delete();
  }

  // Search stores
  Stream<List<StoreModel>> searchStores(String query) {
    return _firestore
        .collection(_collection)
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: '$query\uf8ff')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => StoreModel.fromFirestore(doc)).toList());
  }
}
