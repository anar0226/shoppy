import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../notifications/widgets/notification_permission_widget.dart';
import '../notifications/fcm_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _orderTracking = true;
  bool _offers = true;
  bool _priceDrops = true;
  bool _newDrops = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final notifications =
              data['notificationSettings'] as Map<String, dynamic>? ?? {};

          setState(() {
            _orderTracking = notifications['orderTracking'] ?? true;
            _offers = notifications['offers'] ?? true;
            _priceDrops = notifications['priceDrops'] ?? true;
            _newDrops = notifications['newDrops'] ?? true;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateNotificationSetting(String key, bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'notificationSettings.$key': value,
        });
      } catch (e) {
        // Handle error
        print('Error updating notification setting: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text(
          'Мэдэгдэл',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Мэдэгдэл тохируулалт',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),

                // Push Notification Status
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.smartphone, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          const Text(
                            'Push мэдэгдэл',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          const NotificationStatusIndicator(),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Push мэдэгдэлээр мэдэгдэх боломжтой',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<bool>(
                        future: FCMService().isNotificationPermissionGranted(),
                        builder: (context, snapshot) {
                          final isGranted = snapshot.data ?? false;
                          if (!isGranted) {
                            return const NotificationPermissionWidget(
                              showAsCard: false,
                              customTitle:
                                  'Push мэдэгдэлээр мэдэгдэх боломжтой',
                              customDescription:
                                  'Tap to enable instant notifications on your device',
                            );
                          }
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle,
                                    color: Colors.green.shade600, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Push мэдэгдэлээр мэдэгдэх боломжтой',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Мэдэгдэл төрөл',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                _buildNotificationTile(
                  title: 'Захиалгын төлөв',
                  subtitle: 'Захиалгын талаарx мэдэглэл аваx',
                  icon: Icons.local_shipping,
                  value: _orderTracking,
                  onChanged: (value) {
                    setState(() {
                      _orderTracking = value;
                    });
                    _updateNotificationSetting('orderTracking', value);
                  },
                ),
                _buildNotificationTile(
                  title: 'Үнэлгээ',
                  subtitle: 'Үнэлгээний талаар мэдэглэл авах',
                  icon: Icons.local_offer,
                  value: _offers,
                  onChanged: (value) {
                    setState(() {
                      _offers = value;
                    });
                    _updateNotificationSetting('offers', value);
                  },
                ),
                _buildNotificationTile(
                  title: 'Xямдрал',
                  subtitle: 'Хямдралтай бүтээгдэхүүний талаар мэдэглэл авах',
                  icon: Icons.trending_down,
                  value: _priceDrops,
                  onChanged: (value) {
                    setState(() {
                      _priceDrops = value;
                    });
                    _updateNotificationSetting('priceDrops', value);
                  },
                ),
                _buildNotificationTile(
                  title: 'Шинэ бүтээгдэхүүн',
                  subtitle: 'Шинэ бүтээгдэхүүн талаар мэдэглэл авах',
                  icon: Icons.new_releases,
                  value: _newDrops,
                  onChanged: (value) {
                    setState(() {
                      _newDrops = value;
                    });
                    _updateNotificationSetting('newDrops', value);
                  },
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Мэдэгдэл',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Таны мэдэгдэлээ эндээс хянах боломжтой. Өөрчлөлтүүд автоматаар хадгалагдана.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildNotificationTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: Row(
          children: [
            Icon(
              icon,
              color: Colors.black,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(left: 36),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        activeColor: Colors.black,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}
