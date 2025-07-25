import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../stores/models/store_model.dart';
import '../models/payment_model.dart';

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Constants
  static const double monthlyFee = 100.0; // 100 MNT
  static const int gracePeriodDays = 7; // 7 days grace period
  static const String subscriptionCollection = 'subscriptions';
  static const String paymentsCollection = 'payments';

  /// Create a new subscription for a store
  Future<void> createSubscription(String userId, String storeId) async {
    try {
      final now = DateTime.now();
      final nextPaymentDate = DateTime(now.year, now.month + 1, now.day);

      await _firestore.collection('stores').doc(storeId).update({
        'subscriptionStatus': SubscriptionStatus.pending.name,
        'subscriptionStartDate': Timestamp.fromDate(now),
        'nextPaymentDate': Timestamp.fromDate(nextPaymentDate),
        'updatedAt': Timestamp.fromDate(now),
      });
    } catch (e) {
      throw Exception('Failed to create subscription: $e');
    }
  }

  /// Process a successful payment and activate subscription
  Future<void> processPayment(PaymentModel payment) async {
    try {
      final now = DateTime.now();
      final nextPaymentDate = DateTime(now.year, now.month + 1, now.day);
      final subscriptionEndDate = DateTime(now.year, now.month + 1, now.day);

      // Update store subscription status
      await _firestore.collection('stores').doc(payment.storeId).update({
        'subscriptionStatus': SubscriptionStatus.active.name,
        'lastPaymentDate': Timestamp.fromDate(now),
        'nextPaymentDate': Timestamp.fromDate(nextPaymentDate),
        'subscriptionEndDate': Timestamp.fromDate(subscriptionEndDate),
        'updatedAt': Timestamp.fromDate(now),
      });

      // Add payment to history
      await _addPaymentToHistory(payment.storeId, payment.toMap());

      // Save payment record
      await _firestore.collection(paymentsCollection).add(payment.toMap());
    } catch (e) {
      throw Exception('Failed to process payment: $e');
    }
  }

  /// Check subscription status for a store
  Future<SubscriptionStatus> checkSubscriptionStatus(String storeId) async {
    try {
      final doc = await _firestore.collection('stores').doc(storeId).get();
      if (!doc.exists) {
        throw Exception('Store not found');
      }

      final data = doc.data() as Map<String, dynamic>;
      final status = SubscriptionStatus.values.firstWhere(
        (s) => s.name == data['subscriptionStatus'],
        orElse: () => SubscriptionStatus.pending,
      );

      // Check if subscription is expired and needs to be updated
      if (status == SubscriptionStatus.active) {
        final endDate = data['subscriptionEndDate'] as Timestamp?;
        if (endDate != null && endDate.toDate().isBefore(DateTime.now())) {
          await _updateExpiredSubscription(storeId);
          return SubscriptionStatus.expired;
        }
      }

      return status;
    } catch (e) {
      throw Exception('Failed to check subscription status: $e');
    }
  }

  /// Get next payment date for a store
  Future<DateTime?> getNextPaymentDate(String storeId) async {
    try {
      final doc = await _firestore.collection('stores').doc(storeId).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;
      final nextPaymentTimestamp = data['nextPaymentDate'] as Timestamp?;
      return nextPaymentTimestamp?.toDate();
    } catch (e) {
      throw Exception('Failed to get next payment date: $e');
    }
  }

  /// Cancel subscription for a store
  Future<void> cancelSubscription(String storeId) async {
    try {
      final now = DateTime.now();
      await _firestore.collection('stores').doc(storeId).update({
        'subscriptionStatus': SubscriptionStatus.cancelled.name,
        'updatedAt': Timestamp.fromDate(now),
      });
    } catch (e) {
      throw Exception('Failed to cancel subscription: $e');
    }
  }

  /// Renew subscription for a store
  Future<void> renewSubscription(String storeId) async {
    try {
      final now = DateTime.now();
      final nextPaymentDate = DateTime(now.year, now.month + 1, now.day);
      final subscriptionEndDate = DateTime(now.year, now.month + 1, now.day);

      await _firestore.collection('stores').doc(storeId).update({
        'subscriptionStatus': SubscriptionStatus.active.name,
        'lastPaymentDate': Timestamp.fromDate(now),
        'nextPaymentDate': Timestamp.fromDate(nextPaymentDate),
        'subscriptionEndDate': Timestamp.fromDate(subscriptionEndDate),
        'updatedAt': Timestamp.fromDate(now),
      });
    } catch (e) {
      throw Exception('Failed to renew subscription: $e');
    }
  }

  /// Get payment history for a store
  Future<List<PaymentModel>> getPaymentHistory(String storeId) async {
    try {
      final querySnapshot = await _firestore
          .collection(paymentsCollection)
          .where('storeId', isEqualTo: storeId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => PaymentModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get payment history: $e');
    }
  }

  /// Check if store can access admin panel (has active subscription)
  Future<bool> canAccessAdminPanel(String storeId) async {
    try {
      final status = await checkSubscriptionStatus(storeId);
      return status == SubscriptionStatus.active ||
          status == SubscriptionStatus.gracePeriod;
    } catch (e) {
      return false;
    }
  }

  /// Get subscription details for a store
  Future<Map<String, dynamic>> getSubscriptionDetails(String storeId) async {
    try {
      final doc = await _firestore.collection('stores').doc(storeId).get();
      if (!doc.exists) {
        throw Exception('Store not found');
      }

      final data = doc.data() as Map<String, dynamic>;
      final status = SubscriptionStatus.values.firstWhere(
        (s) => s.name == data['subscriptionStatus'],
        orElse: () => SubscriptionStatus.pending,
      );

      final nextPaymentDate = data['nextPaymentDate'] as Timestamp?;
      final lastPaymentDate = data['lastPaymentDate'] as Timestamp?;
      final subscriptionEndDate = data['subscriptionEndDate'] as Timestamp?;

      return {
        'status': status,
        'nextPaymentDate': nextPaymentDate?.toDate(),
        'lastPaymentDate': lastPaymentDate?.toDate(),
        'subscriptionEndDate': subscriptionEndDate?.toDate(),
        'monthlyFee': monthlyFee,
        'daysUntilExpiry':
            subscriptionEndDate?.toDate().difference(DateTime.now()).inDays,
      };
    } catch (e) {
      throw Exception('Failed to get subscription details: $e');
    }
  }

  /// Update expired subscription status
  Future<void> _updateExpiredSubscription(String storeId) async {
    try {
      final now = DateTime.now();
      final endDate = await _getSubscriptionEndDate(storeId);

      if (endDate != null && endDate.isBefore(now)) {
        final daysSinceExpiry = now.difference(endDate).inDays;

        SubscriptionStatus newStatus;
        if (daysSinceExpiry <= gracePeriodDays) {
          newStatus = SubscriptionStatus.gracePeriod;
        } else {
          newStatus = SubscriptionStatus.expired;
        }

        await _firestore.collection('stores').doc(storeId).update({
          'subscriptionStatus': newStatus.name,
          'updatedAt': Timestamp.fromDate(now),
        });
      }
    } catch (e) {
      throw Exception('Failed to update expired subscription: $e');
    }
  }

  /// Get subscription end date
  Future<DateTime?> _getSubscriptionEndDate(String storeId) async {
    try {
      final doc = await _firestore.collection('stores').doc(storeId).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;
      final endDate = data['subscriptionEndDate'] as Timestamp?;
      return endDate?.toDate();
    } catch (e) {
      return null;
    }
  }

  /// Add payment to store's payment history
  Future<void> _addPaymentToHistory(
      String storeId, Map<String, dynamic> paymentData) async {
    try {
      await _firestore.collection('stores').doc(storeId).update({
        'paymentHistory': FieldValue.arrayUnion([paymentData]),
      });
    } catch (e) {
      throw Exception('Failed to add payment to history: $e');
    }
  }

  /// Get current user's store subscription status
  Future<SubscriptionStatus?> getCurrentUserSubscriptionStatus() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final querySnapshot = await _firestore
          .collection('stores')
          .where('ownerId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) return null;

      final storeId = querySnapshot.docs.first.id;
      return await checkSubscriptionStatus(storeId);
    } catch (e) {
      return null;
    }
  }

  /// Get current user's store ID
  Future<String?> getCurrentUserStoreId() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final querySnapshot = await _firestore
          .collection('stores')
          .where('ownerId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) return null;

      return querySnapshot.docs.first.id;
    } catch (e) {
      return null;
    }
  }
}
