import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../auth/auth_service.dart';

enum NotificationType {
  order,
  product,
  customer,
  system,
}

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? data;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.data,
  });

  factory NotificationModel.fromMap(String id, Map<String, dynamic> map) {
    return NotificationModel(
      id: id,
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => NotificationType.system,
      ),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      isRead: map['isRead'] ?? false,
      data: map['data'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'type': type.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'data': data,
    };
  }

  IconData get icon {
    switch (type) {
      case NotificationType.order:
        return Icons.shopping_cart;
      case NotificationType.product:
        return Icons.inventory;
      case NotificationType.customer:
        return Icons.person;
      case NotificationType.system:
        return Icons.info;
    }
  }

  Color get color {
    switch (type) {
      case NotificationType.order:
        return Colors.green;
      case NotificationType.product:
        return Colors.blue;
      case NotificationType.customer:
        return Colors.purple;
      case NotificationType.system:
        return Colors.orange;
    }
  }

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 30) {
      return '${diff.inDays}d ago';
    } else {
      return '${(diff.inDays / 30).floor()}mo ago';
    }
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get notifications for current store owner
  Stream<List<NotificationModel>> getNotifications() {
    final ownerId = AuthService.instance.currentUser?.uid;
    if (ownerId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('notifications')
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  // Get unread notification count
  Stream<int> getUnreadCount() {
    final ownerId = AuthService.instance.currentUser?.uid;
    if (ownerId == null) {
      return Stream.value(0);
    }

    return _firestore
        .collection('notifications')
        .where('ownerId', isEqualTo: ownerId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    final ownerId = AuthService.instance.currentUser?.uid;
    if (ownerId == null) return;

    try {
      final unreadDocs = await _firestore
          .collection('notifications')
          .where('ownerId', isEqualTo: ownerId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in unreadDocs.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  // Delete all notifications for current store owner
  Future<void> clearAllNotifications() async {
    final ownerId = AuthService.instance.currentUser?.uid;
    if (ownerId == null) return;

    try {
      final allDocs = await _firestore
          .collection('notifications')
          .where('ownerId', isEqualTo: ownerId)
          .get();

      final batch = _firestore.batch();
      for (final doc in allDocs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      debugPrint('All notifications cleared successfully');
    } catch (e) {
      debugPrint('Error clearing all notifications: $e');
    }
  }

  // Create a notification (for system use)
  Future<void> createNotification({
    required String storeId,
    required String ownerId,
    required String title,
    required String message,
    required NotificationType type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final notification = NotificationModel(
        id: '',
        title: title,
        message: message,
        type: type,
        createdAt: DateTime.now(),
        data: data,
      );

      await _firestore.collection('notifications').add({
        ...notification.toMap(),
        'storeId': storeId,
        'ownerId': ownerId,
        'read': false, // Include both read and isRead for compatibility
      });
    } catch (e) {
      debugPrint('Error creating notification: $e');
    }
  }

  // Auto-generate notifications from orders (call this when orders are created)
  Future<void> notifyNewOrder({
    required String storeId,
    required String ownerId,
    required String orderId,
    required String customerEmail,
    required double total,
  }) async {
    await createNotification(
      storeId: storeId,
      ownerId: ownerId,
      title: 'New Order Received',
      message:
          'Order #${orderId.substring(0, 6)} from $customerEmail (₮${total.toStringAsFixed(2)})',
      type: NotificationType.order,
      data: {'orderId': orderId, 'total': total},
    );
  }

  // Enhanced method to send notifications with SMS support
  static Future<void> notifyStoreOwnerNewOrder({
    required String storeId,
    required String ownerId,
    required String orderId,
    required String customerEmail,
    required double total,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      // Create in-app notification
      final notificationService = NotificationService();
      await notificationService.notifyNewOrder(
        storeId: storeId,
        ownerId: ownerId,
        orderId: orderId,
        customerEmail: customerEmail,
        total: total,
      );

      // Send FCM push notification to store owner
      final itemNames = items
          .map((item) => item['name'] ?? 'Бүтээгдэхүүн')
          .take(2)
          .join(', ');
      final moreItems = items.length > 2 ? ' +${items.length - 2} бусад' : '';

      await _sendPushNotificationToOwner(
        ownerId: ownerId,
        title: 'Шинэ захиалга ирлээ! 🛍️',
        message: '$itemNames$moreItems - ₮${total.toStringAsFixed(0)}',
        data: {
          'type': 'new_order',
          'orderId': orderId,
          'storeId': storeId,
        },
      );

      // Send SMS notification if phone number is available
      await _sendSMSNotificationToOwner(
        ownerId: ownerId,
        orderId: orderId,
        total: total,
        itemCount: items.length,
      );
    } catch (e) {
      debugPrint('Error sending new order notification: $e');
    }
  }

  // Send push notification to store owner
  static Future<void> _sendPushNotificationToOwner({
    required String ownerId,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get store owner's FCM token
      final ownerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerId)
          .get();

      if (ownerDoc.exists) {
        final ownerData = ownerDoc.data() as Map<String, dynamic>;
        final fcmToken = ownerData['fcmToken'] as String?;

        if (fcmToken != null && fcmToken.isNotEmpty) {
          // Send push notification via Firebase Cloud Functions
          await FirebaseFirestore.instance
              .collection('notification_queue')
              .add({
            'userId': ownerId,
            'payload': {
              'notification': {
                'title': title,
                'body': message,
              },
              'data': data ?? {},
              'token': fcmToken,
            },
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      debugPrint('Error sending push notification to owner: $e');
    }
  }

  // Send SMS notification to store owner
  static Future<void> _sendSMSNotificationToOwner({
    required String ownerId,
    required String orderId,
    required double total,
    required int itemCount,
  }) async {
    try {
      // Get store owner's phone number
      final ownerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerId)
          .get();

      if (ownerDoc.exists) {
        final ownerData = ownerDoc.data() as Map<String, dynamic>;
        final phoneNumber = ownerData['phoneNumber'] as String?;

        if (phoneNumber != null && phoneNumber.isNotEmpty) {
          // Queue SMS notification for Cloud Functions to process
          await FirebaseFirestore.instance.collection('sms_queue').add({
            'phoneNumber': phoneNumber,
            'message':
                'Shoppy: Шинэ захиалга #${orderId.substring(0, 6)}. $itemCount бүтээгдэхүүн, ₮${total.toStringAsFixed(0)}. Админ панелээс харна уу.',
            'type': 'new_order',
            'ownerId': ownerId,
            'orderId': orderId,
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      debugPrint('Error queuing SMS notification: $e');
    }
  }

  // Notify low stock
  Future<void> notifyLowStock({
    required String storeId,
    required String ownerId,
    required String productName,
    required int currentStock,
  }) async {
    await createNotification(
      storeId: storeId,
      ownerId: ownerId,
      title: 'Low Stock Alert',
      message: '$productName is running low (${currentStock} remaining)',
      type: NotificationType.product,
      data: {'productName': productName, 'stock': currentStock},
    );
  }

  // Notify new customer
  Future<void> notifyNewCustomer({
    required String storeId,
    required String ownerId,
    required String customerEmail,
  }) async {
    await createNotification(
      storeId: storeId,
      ownerId: ownerId,
      title: 'New Customer',
      message: '$customerEmail has registered',
      type: NotificationType.customer,
      data: {'customerEmail': customerEmail},
    );
  }
}
