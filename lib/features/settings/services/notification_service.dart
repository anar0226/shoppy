import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:avii/core/services/error_handler_service.dart';

class NotificationService {
  static const String _notificationsCollection = 'notifications';
  static const String _usersCollection = 'users';

  // Check if a specific notification type is enabled for the user
  static Future<bool> isNotificationEnabled(String notificationType) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final doc = await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final notifications =
            data['notificationSettings'] as Map<String, dynamic>? ?? {};
        return notifications[notificationType] ?? true;
      }
    } catch (e) {
      await ErrorHandlerService.instance.handleError(
        operation: 'notification_service_error',
        error: e,
        showUserMessage: false,
        logError: true,
        fallbackValue: null,
      );
    }
    return true; // Default to enabled
  }

  // Send order tracking notification
  static Future<void> sendOrderTrackingNotification({
    required String userId,
    required String orderId,
    required String status,
    required String title,
    required String message,
  }) async {
    if (await isNotificationEnabled('orderTracking')) {
      await _createNotification(
        userId: userId,
        type: 'orderTracking',
        title: title,
        message: message,
        data: {
          'orderId': orderId,
          'status': status,
        },
      );
    }
  }

  // Send offer notification
  static Future<void> sendOfferNotification({
    required String userId,
    required String offerId,
    required String title,
    required String message,
  }) async {
    if (await isNotificationEnabled('offers')) {
      await _createNotification(
        userId: userId,
        type: 'offers',
        title: title,
        message: message,
        data: {
          'offerId': offerId,
        },
      );
    }
  }

  // Send price drop notification
  static Future<void> sendPriceDropNotification({
    required String userId,
    required String productId,
    required String storeId,
    required String title,
    required String message,
    required double oldPrice,
    required double newPrice,
  }) async {
    if (await isNotificationEnabled('priceDrops')) {
      await _createNotification(
        userId: userId,
        type: 'priceDrops',
        title: title,
        message: message,
        data: {
          'productId': productId,
          'storeId': storeId,
          'oldPrice': oldPrice,
          'newPrice': newPrice,
        },
      );
    }
  }

  // Send new drop notification
  static Future<void> sendNewDropNotification({
    required String userId,
    required String productId,
    required String storeId,
    required String title,
    required String message,
  }) async {
    if (await isNotificationEnabled('newDrops')) {
      await _createNotification(
        userId: userId,
        type: 'newDrops',
        title: title,
        message: message,
        data: {
          'productId': productId,
          'storeId': storeId,
        },
      );
    }
  }

  // Create notification in Firestore
  static Future<void> _createNotification({
    required String userId,
    required String type,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection(_notificationsCollection)
          .add({
        'userId': userId,
        'type': type,
        'title': title,
        'message': message,
        'data': data ?? {},
        'read': false,
        'isRead': false, // Include both read and isRead for compatibility
        'createdAt': Timestamp
            .now(), // Use explicit timestamp instead of server timestamp
      });
    } catch (e) {
      await ErrorHandlerService.instance.handleError(
        operation: 'notification_service_error',
        error: e,
        showUserMessage: false,
        logError: true,
        fallbackValue: null,
      );
    }
  }

  // Get notifications for user
  static Stream<QuerySnapshot> getUserNotifications(String userId) {
    return FirebaseFirestore.instance
        .collection(_notificationsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Mark notification as read
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection(_notificationsCollection)
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      await ErrorHandlerService.instance.handleError(
        operation: 'notification_service_error',
        error: e,
        showUserMessage: false,
        logError: true,
        fallbackValue: null,
      );
    }
  }

  // Check for price drops in followed stores
  static Future<void> checkPriceDropsForUser(String userId) async {
    try {
      // Get user's followed stores
      final userDoc = await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(userId)
          .get();

      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>;
      final followedStoreIds =
          List<String>.from(userData['followerStoreIds'] ?? []);

      if (followedStoreIds.isEmpty) return;

      // Check for discounted products in followed stores
      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('storeId', whereIn: followedStoreIds)
          .where('discountPercentage', isGreaterThan: 0)
          .get();

      for (final productDoc in productsSnapshot.docs) {
        final productData = productDoc.data();
        final discountPercentage = productData['discountPercentage'] ?? 0;

        if (discountPercentage > 0) {
          final originalPrice = productData['price']?.toDouble() ?? 0.0;
          final discountedPrice =
              originalPrice * (1 - discountPercentage / 100);

          await sendPriceDropNotification(
            userId: userId,
            productId: productDoc.id,
            storeId: productData['storeId'],
            title: 'Price Drop Alert!',
            message:
                '${productData['name']} is now ${discountPercentage.toInt()}% off!',
            oldPrice: originalPrice,
            newPrice: discountedPrice,
          );
        }
      }
    } catch (e) {
      await ErrorHandlerService.instance.handleError(
        operation: 'notification_service_error',
        error: e,
        showUserMessage: false,
        logError: true,
        fallbackValue: null,
      );
    }
  }

  // Check for new products in followed stores
  static Future<void> checkNewProductsForUser(String userId) async {
    try {
      // Get user's followed stores
      final userDoc = await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(userId)
          .get();

      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>;
      final followedStoreIds =
          List<String>.from(userData['followerStoreIds'] ?? []);

      if (followedStoreIds.isEmpty) return;

      // Check for new products (added in last 24 hours) in followed stores
      final yesterday = DateTime.now().subtract(const Duration(days: 1));

      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('storeId', whereIn: followedStoreIds)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(yesterday))
          .get();

      for (final productDoc in productsSnapshot.docs) {
        final productData = productDoc.data();

        await sendNewDropNotification(
          userId: userId,
          productId: productDoc.id,
          storeId: productData['storeId'],
          title: 'New Drop Alert!',
          message:
              'Check out the new ${productData['name']} from your followed store!',
        );
      }
    } catch (e) {
      await ErrorHandlerService.instance.handleError(
        operation: 'notification_service_error',
        error: e,
        showUserMessage: false,
        logError: true,
        fallbackValue: null,
      );
    }
  }

  // Initialize notification listeners for user
  static Future<void> initializeNotificationListeners(String userId) async {
    // These would typically be called by Cloud Functions or background tasks
    // For now, we provide the methods to be called when needed

    // Check for price drops and new products periodically
    await checkPriceDropsForUser(userId);
    await checkNewProductsForUser(userId);
  }
}
