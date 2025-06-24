import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/discount_model.dart';

class DiscountService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'discounts';

  // Create a new discount
  Future<String> createDiscount(DiscountModel discount) async {
    DocumentReference docRef =
        await _firestore.collection(_collection).add(discount.toMap());
    return docRef.id;
  }

  // Get a discount by ID
  Future<DiscountModel?> getDiscount(String discountId) async {
    DocumentSnapshot doc =
        await _firestore.collection(_collection).doc(discountId).get();
    if (doc.exists) {
      return DiscountModel.fromFirestore(doc);
    }
    return null;
  }

  // Get all discounts for a store
  Stream<List<DiscountModel>> getStoreDiscounts(String storeId) {
    return _firestore
        .collection(_collection)
        .where('storeId', isEqualTo: storeId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DiscountModel.fromFirestore(doc))
            .toList());
  }

  // Update a discount
  Future<void> updateDiscount(String discountId, DiscountModel discount) async {
    await _firestore
        .collection(_collection)
        .doc(discountId)
        .update(discount.toMap());
  }

  // Delete a discount
  Future<void> deleteDiscount(String discountId) async {
    await _firestore.collection(_collection).doc(discountId).delete();
  }

  // Search discounts in a store
  Stream<List<DiscountModel>> searchStoreDiscounts(
      String storeId, String query) {
    return _firestore
        .collection(_collection)
        .where('storeId', isEqualTo: storeId)
        .where('code', isGreaterThanOrEqualTo: query.toUpperCase())
        .where('code', isLessThanOrEqualTo: '${query.toUpperCase()}\uf8ff')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DiscountModel.fromFirestore(doc))
            .toList());
  }

  // Check if discount code already exists for a store
  Future<bool> isCodeUnique(String storeId, String code,
      [String? excludeDiscountId]) async {
    Query query = _firestore
        .collection(_collection)
        .where('storeId', isEqualTo: storeId)
        .where('code', isEqualTo: code.toUpperCase());

    final snapshot = await query.get();

    // If no discount ID to exclude, just check if any exist
    if (excludeDiscountId == null) {
      return snapshot.docs.isEmpty;
    }

    // If excluding a discount ID (for updates), check if any others exist
    return snapshot.docs.where((doc) => doc.id != excludeDiscountId).isEmpty;
  }

  // Increment usage count for a discount
  Future<void> incrementUsageCount(String discountId) async {
    await _firestore.collection(_collection).doc(discountId).update({
      'currentUseCount': FieldValue.increment(1),
    });
  }
}
