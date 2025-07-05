import 'package:flutter/material.dart';
import '../../../features/admin/users/models/user_model.dart';
import '../../../features/admin/users/services/user_service.dart';

class UserDetailDialog extends StatefulWidget {
  final String userId;

  const UserDetailDialog({super.key, required this.userId});

  @override
  State<UserDetailDialog> createState() => _UserDetailDialogState();
}

class _UserDetailDialogState extends State<UserDetailDialog>
    with SingleTickerProviderStateMixin {
  final _userService = UserService();
  UserModel? _user;
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    try {
      final user = await _userService.getUserById(widget.userId);
      setState(() {
        _user = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load user: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 800,
        height: 600,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  if (_user != null) ...[
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.blue.shade100,
                      backgroundImage: _user!.photoURL?.isNotEmpty == true
                          ? NetworkImage(_user!.photoURL!)
                          : null,
                      child: _user!.photoURL?.isEmpty != false
                          ? Icon(Icons.person,
                              color: Colors.blue.shade700, size: 30)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _user!.displayNameOrEmail,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _user!.email,
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _user!.isActive
                                  ? Colors.green.shade100
                                  : Colors.red.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _user!.statusText,
                              style: TextStyle(
                                color: _user!.isActive
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (_isLoading) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(width: 16),
                    const Text('Loading user...'),
                  ] else ...[
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 16),
                    const Text('User not found'),
                  ],
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Tabs
            if (_user != null) ...[
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Profile'),
                  Tab(text: 'Orders'),
                  Tab(text: 'Addresses'),
                  Tab(text: 'Activity'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildProfileTab(),
                    _buildOrdersTab(),
                    _buildAddressesTab(),
                    _buildActivityTab(),
                  ],
                ),
              ),
            ] else ...[
              const Expanded(
                child: Center(
                  child: Text('Unable to load user details'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'User Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Email', _user!.email),
          _buildInfoRow('Display Name', _user!.displayName ?? 'Not set'),
          _buildInfoRow('Phone Number', _user!.phoneNumber ?? 'Not set'),
          _buildInfoRow('User Type', _user!.userType.toUpperCase()),
          _buildInfoRow('Member Since', _user!.formattedCreatedAt),
          _buildInfoRow(
              'Last Login', _user!.lastLoginAt?.toString() ?? 'Never'),
          const SizedBox(height: 24),
          const Text(
            'Statistics',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _buildStatCard(
                'Total Orders',
                _user!.stats.totalOrders.toString(),
                Icons.shopping_bag,
                Colors.blue,
              )),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildStatCard(
                'Total Spent',
                _user!.formattedTotalSpent,
                Icons.attach_money,
                Colors.green,
              )),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildStatCard(
                'Reviews',
                _user!.stats.reviewsCount.toString(),
                Icons.star,
                Colors.orange,
              )),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildStatCard(
                'Saved Items',
                _user!.stats.savedItems.toString(),
                Icons.favorite,
                Colors.red,
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersTab() {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(
        child: Text(
          'Order history will be displayed here',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildAddressesTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Saved Addresses',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (_user!.addresses.isEmpty)
            const Center(
              child: Text(
                'No saved addresses',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _user!.addresses.length,
                itemBuilder: (context, index) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.location_on),
                      title: Text('Address ${index + 1}'),
                      subtitle: Text(_user!.addresses[index]),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityTab() {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(
        child: Text(
          'User activity history will be displayed here',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
