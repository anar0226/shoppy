import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/notifications/fcm_service.dart';
import '../auth/auth_service.dart';

class SendNotificationDialog extends StatefulWidget {
  const SendNotificationDialog({super.key});

  @override
  State<SendNotificationDialog> createState() => _SendNotificationDialogState();
}

class _SendNotificationDialogState extends State<SendNotificationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  String _selectedTarget = 'all_customers';
  String _notificationType = 'promotion';
  bool _isSending = false;

  final List<Map<String, dynamic>> _targetOptions = [
    {'value': 'all_customers', 'label': 'All Customers', 'icon': Icons.group},
    {
      'value': 'recent_customers',
      'label': 'Recent Customers (30 days)',
      'icon': Icons.schedule
    },
    {
      'value': 'high_value',
      'label': 'High Value Customers',
      'icon': Icons.star
    },
    {
      'value': 'cart_abandoners',
      'label': 'Cart Abandoners',
      'icon': Icons.shopping_cart_outlined
    },
  ];

  final List<Map<String, dynamic>> _notificationTypes = [
    {'value': 'promotion', 'label': 'Promotion', 'icon': Icons.local_offer},
    {'value': 'announcement', 'label': 'Announcement', 'icon': Icons.campaign},
    {
      'value': 'product_alert',
      'label': 'Product Alert',
      'icon': Icons.inventory
    },
    {'value': 'event', 'label': 'Event', 'icon': Icons.event},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSending = true;
    });

    try {
      final storeOwnerId = AuthService.instance.currentUser?.uid;
      if (storeOwnerId == null) {
        throw Exception('User not authenticated');
      }

      // Get store ID
      final storeQuery = await FirebaseFirestore.instance
          .collection('stores')
          .where('ownerId', isEqualTo: storeOwnerId)
          .limit(1)
          .get();

      if (storeQuery.docs.isEmpty) {
        throw Exception('Store not found');
      }

      final storeId = storeQuery.docs.first.id;
      final storeName = storeQuery.docs.first.data()['name'] as String;

      // Get target users - simplified for initial implementation
      final targetUsers = await _getTargetUsers(storeId);

      if (targetUsers.isEmpty) {
        throw Exception('No users found for the selected target');
      }

      // Create notification data
      final notificationData = {
        'type': _notificationType,
        'storeId': storeId,
        'storeName': storeName,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Send notifications
      await FCMService.sendPushNotificationToUsers(
        userIds: targetUsers,
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        data: notificationData,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notification sent to ${targetUsers.length} users'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<List<String>> _getTargetUsers(String storeId) async {
    // Simplified user targeting - get users who follow the store
    final followersQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('followerStoreIds', arrayContains: storeId)
        .limit(100)
        .get();

    return followersQuery.docs.map((doc) => doc.id).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.send, color: Colors.blue.shade600, size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'Send Push Notification',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                'Title',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter notification title',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
                maxLength: 50,
              ),
              const SizedBox(height: 16),

              // Body
              const Text(
                'Message',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _bodyController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter notification message',
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a message';
                  }
                  return null;
                },
                maxLength: 150,
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isSending ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSending ? null : _sendNotification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                      ),
                      child: _isSending
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Send Notification'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
