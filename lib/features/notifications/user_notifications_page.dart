import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';
import '../../core/utils/type_utils.dart';

class UserNotificationsPage extends StatefulWidget {
  const UserNotificationsPage({super.key});

  @override
  State<UserNotificationsPage> createState() => _UserNotificationsPageState();
}

class _UserNotificationsPageState extends State<UserNotificationsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<QuerySnapshot>? _notificationsStream;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  void _initializeNotifications() {
    final user = _auth.currentUser;
    if (user != null) {
      _notificationsStream = NotificationService.getUserNotifications(user.uid);
      _getUnreadCount();
    }
  }

  Future<void> _getUnreadCount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('read', isEqualTo: false)
          .get();

      setState(() {
        _unreadCount = snapshot.docs.length;
      });
    } catch (e) {
      print('Error getting unread count: $e');
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await NotificationService.markNotificationAsRead(notificationId);
      _getUnreadCount(); // Refresh count
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final unreadNotifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('read', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in unreadNotifications.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();

      _getUnreadCount(); // Refresh count

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Бүх мэдэгдэл уншигдсан'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error marking all as read: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Бүх мэдэгдэл уншигдсан үед алдаа гарлаа'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: Row(
          children: [
            const Text(
              'Мэдэгдэл',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                'Бүх мэдэгдэл уншигдсан',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
      body: _auth.currentUser == null
          ? const Center(
              child: Text(
                'Мэдэгдэл харахын тулд нэвтрэх',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: _notificationsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 64, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        const Text(
                          'Мэдэгдэл оруулах үед алдаа гарлаа',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          style: const TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final notifications = snapshot.data?.docs ?? [];

                if (notifications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Мэдэгдэл оруулаагүй байна',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Таныг захиалга, үнэлгээ, мэдэгдэл, болон бусад мэдэгдэлүүдээр мэдэгдэх болно',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final doc = notifications[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildNotificationCard(doc.id, data);
                  },
                );
              },
            ),
    );
  }

  Widget _buildNotificationCard(
      String notificationId, Map<String, dynamic> data) {
    final title = data['title'] ?? 'Notification';
    final message = data['message'] ?? '';
    final type = data['type'] ?? 'general';
    final isRead = data['read'] ?? false;
    final createdAt = data['createdAt'] as Timestamp?;
    final notificationData = data['data'] as Map<String, dynamic>? ?? {};

    final icon = _getNotificationIcon(type);
    final color = _getNotificationColor(type);
    final timeAgo = _getTimeAgo(createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRead ? Colors.grey[200]! : Colors.blue[200]!,
          width: isRead ? 1 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (!isRead) {
            _markAsRead(notificationId);
          }
          _handleNotificationTap(type, notificationData);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  isRead ? FontWeight.w500 : FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'orderTracking':
        return Icons.local_shipping;
      case 'offers':
        return Icons.local_offer;
      case 'priceDrops':
        return Icons.trending_down;
      case 'newDrops':
        return Icons.new_releases;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'orderTracking':
        return Colors.green;
      case 'offers':
        return Colors.orange;
      case 'priceDrops':
        return Colors.red;
      case 'newDrops':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getTimeAgo(Timestamp? createdAt) {
    if (createdAt == null) return 'Одоо';

    final now = DateTime.now();
    final time = createdAt.toDate();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'Одоо';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} минутын өмнө';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} цагын өмнө';
    } else if (diff.inDays < 30) {
      return '${diff.inDays} хоногын өмнө';
    } else {
      return '${(diff.inDays / 30).floor()} сарын өмнө';
    }
  }

  void _handleNotificationTap(String type, Map<String, dynamic> data) {
    // Handle navigation based on notification type
    switch (type) {
      case 'orderTracking':
        final orderId = data['orderId'] as String?;
        if (orderId != null) {
          // Navigator.pushNamed(context, '/order-details', arguments: orderId);
          print('Захиалгын дэлгэцэнд шилжих: $orderId');
        }
        break;
      case 'priceDrops':
      case 'newDrops':
        final productId = data['productId'] as String?;
        final storeId = TypeUtils.extractStoreId(data['storeId']);
        if (productId != null) {
          // Navigator.pushNamed(context, '/product-details', arguments: {
          //   'productId': productId,
          //   'storeId': storeId,
          // });
          print('Бүтээгдэхүүний дэлгэцэнд шилжих: $productId в $storeId');
        }
        break;
      case 'offers':
        final offerId = data['offerId'] as String?;
        if (offerId != null) {
          // Navigator.pushNamed(context, '/offers');
          print('Үнэлгээний дэлгэцэнд шилжих: $offerId');
        }
        break;
      default:
        print('Мэдэгдэл дарсан: $type');
    }
  }
}
