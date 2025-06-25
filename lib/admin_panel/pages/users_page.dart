import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/top_nav_bar.dart';
import '../widgets/side_menu.dart';
import '../../features/admin/users/models/user_model.dart';
import '../../features/admin/users/services/user_service.dart';
import '../../features/settings/themes/app_themes.dart';
import '../widgets/users/add_user_dialog.dart';
import '../widgets/users/user_detail_dialog.dart';
import '../widgets/users/edit_user_dialog.dart';
import '../auth/auth_service.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final UserService _userService = UserService();

  // Search and filter state
  final _searchController = TextEditingController();
  String _statusFilter = 'All Status';
  String _userTypeFilter = 'All Types';
  DateTime? _fromDate;
  DateTime? _toDate;

  // Pagination state
  List<UserModel> _users = [];
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool _isLoading = false;

  // Analytics data
  Map<String, dynamic>? _analytics;
  bool _analyticsLoading = true;

  // Store ID for checking following status
  String? _currentStoreId;

  @override
  void initState() {
    super.initState();
    _loadStoreId();
    _loadAnalytics();
    _loadUsers();
  }

  Future<void> _loadStoreId() async {
    final ownerId = AuthService.instance.currentUser?.uid;
    if (ownerId == null) {
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('stores')
          .where('ownerId', isEqualTo: ownerId)
          .limit(1)
          .get();

      setState(() {
        if (snap.docs.isNotEmpty) {
          _currentStoreId = snap.docs.first.id;
        }
      });
    } catch (e) {
      // Handle error silently
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    try {
      final analytics = await _userService.getUserAnalytics();
      setState(() {
        _analytics = analytics;
        _analyticsLoading = false;
      });
    } catch (e) {
      setState(() => _analyticsLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load analytics: $e')),
        );
      }
    }
  }

  Future<void> _loadUsers({bool refresh = false}) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      if (refresh) {
        _users.clear();
        _lastDocument = null;
        _hasMore = true;
      }

      final stream = _userService.getUsersStream(
        statusFilter: _statusFilter,
        userTypeFilter: _userTypeFilter,
        fromDate: _fromDate,
        toDate: _toDate,
        lastDocument: _lastDocument,
      );

      stream.listen((snapshot) {
        if (mounted) {
          final allUsers = snapshot.docs
              .map((doc) =>
                  UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();

          // Filter to only show users following this specific store
          final followingUsers = _currentStoreId != null
              ? allUsers
                  .where((user) => user.isFollowingStore(_currentStoreId!))
                  .toList()
              : <UserModel>[];

          setState(() {
            if (refresh) {
              _users = followingUsers;
            } else {
              _users.addAll(followingUsers);
            }

            _lastDocument =
                snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
            _hasMore = snapshot.docs.length >= 50; // Based on limit in service
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load users: $e')),
        );
      }
    }
  }

  Future<void> _searchUsers() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _loadUsers(refresh: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final allResults = await _userService.searchUsers(query);
      // Filter search results to only show users following this store
      final followingResults = _currentStoreId != null
          ? allResults
              .where((user) => user.isFollowingStore(_currentStoreId!))
              .toList()
          : <UserModel>[];

      setState(() {
        _users = followingResults;
        _hasMore = false; // Search results don't support pagination
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    _loadUsers(refresh: true);
  }

  void _clearFilters() {
    setState(() {
      _statusFilter = 'All Status';
      _userTypeFilter = 'All Types';
      _fromDate = null;
      _toDate = null;
      _searchController.clear();
    });
    _loadUsers(refresh: true);
  }

  Future<void> _toggleUserStatus(UserModel user) async {
    try {
      await _userService.toggleUserStatus(user.id, !user.isActive);
      _loadUsers(refresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'User ${user.isActive ? 'deactivated' : 'activated'} successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update user status: $e')),
        );
      }
    }
  }

  Future<void> _deleteUser(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
            'Are you sure you want to delete ${user.displayNameOrEmail}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _userService.deleteUser(user.id);
        _loadUsers(refresh: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete user: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemes.getBackgroundColor(context),
      body: Row(
        children: [
          const SideMenu(selected: 'Users'),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TopNavBar(title: 'Users'),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Customers',
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Manage customers who are following your store'),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const AddUserDialog(),
                  ).then((_) => _loadUsers(refresh: true));
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add User'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Analytics Cards
          if (_analyticsLoading)
            const Center(child: CircularProgressIndicator())
          else if (_analytics != null)
            _buildAnalyticsCards(),

          const SizedBox(height: 24),

          // Search and Filters
          _buildSearchAndFilters(),

          const SizedBox(height: 24),

          // Users Table
          _buildUsersTable(),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCards() {
    return Row(
      children: [
        Expanded(
            child: _buildAnalyticsCard(
          'Total Users',
          _analytics!['totalUsers'].toString(),
          Icons.people,
          Colors.blue,
        )),
        const SizedBox(width: 16),
        Expanded(
            child: _buildAnalyticsCard(
          'New This Month',
          _analytics!['newThisMonth'].toString(),
          Icons.person_add,
          Colors.green,
        )),
        const SizedBox(width: 16),
        Expanded(
            child: _buildAnalyticsCard(
          'Active Users',
          _analytics!['activeUsers'].toString(),
          Icons.verified_user,
          Colors.orange,
        )),
        const SizedBox(width: 16),
        Expanded(
            child: _buildAnalyticsCard(
          'Avg. Lifetime Value',
          '\$${_analytics!['avgLifetimeValue'].toStringAsFixed(2)}',
          Icons.attach_money,
          Colors.purple,
        )),
      ],
    );
  }

  Widget _buildAnalyticsCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          // Search Row
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _searchUsers(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _searchUsers,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                child: const Text('Search'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Filters Row
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _statusFilter,
                  items: const [
                    DropdownMenuItem(
                        value: 'All Status', child: Text('All Status')),
                    DropdownMenuItem(value: 'Active', child: Text('Active')),
                    DropdownMenuItem(
                        value: 'Inactive', child: Text('Inactive')),
                  ],
                  onChanged: (value) {
                    setState(() => _statusFilter = value!);
                    _applyFilters();
                  },
                  decoration: InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _userTypeFilter,
                  items: const [
                    DropdownMenuItem(
                        value: 'All Types', child: Text('All Types')),
                    DropdownMenuItem(
                        value: 'customer', child: Text('Customer')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (value) {
                    setState(() => _userTypeFilter = value!);
                    _applyFilters();
                  },
                  decoration: InputDecoration(
                    labelText: 'User Type',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _clearFilters,
                child: const Text('Clear Filters'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Users (${_users.length})',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),

          // Table Content
          if (_users.isEmpty && !_isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Text(
                'No users found',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _users.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _users.length) {
                  // Load more button
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () => _loadUsers(),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Load More'),
                      ),
                    ),
                  );
                }

                final user = _users[index];
                return _buildUserRow(user, index);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildUserRow(UserModel user, int index) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: index == _users.length - 1
                ? Colors.transparent
                : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.blue.shade100,
            backgroundImage: user.photoURL?.isNotEmpty == true
                ? NetworkImage(user.photoURL!)
                : null,
            child: user.photoURL?.isEmpty != false
                ? Icon(Icons.person, color: Colors.blue.shade700)
                : null,
          ),

          const SizedBox(width: 16),

          // User Info
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName?.isNotEmpty == true
                      ? user.displayName!
                      : 'Customer',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'ID: ${user.id.substring(0, 8)}...',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),

          // Status
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color:
                    user.isActive ? Colors.green.shade100 : Colors.red.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                user.statusText,
                style: TextStyle(
                  color: user.isActive
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Orders
          Expanded(
            child: Text(
              '${user.stats.totalOrders} orders',
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),

          // Total Spent
          Expanded(
            child: Text(
              user.formattedTotalSpent,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),

          // Registered
          Expanded(
            child: Text(
              user.formattedCreatedAt,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),

          // Actions
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'view':
                  showDialog(
                    context: context,
                    builder: (_) => UserDetailDialog(userId: user.id),
                  );
                  break;
                case 'edit':
                  showDialog(
                    context: context,
                    builder: (_) => EditUserDialog(user: user),
                  ).then((_) => _loadUsers(refresh: true));
                  break;
                case 'toggle':
                  _toggleUserStatus(user);
                  break;
                case 'delete':
                  _deleteUser(user);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'view',
                child: Row(
                  children: [
                    Icon(Icons.visibility, size: 16),
                    SizedBox(width: 8),
                    Text('View Details'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 16),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'toggle',
                child: Row(
                  children: [
                    Icon(
                      user.isActive ? Icons.block : Icons.check_circle,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(user.isActive ? 'Deactivate' : 'Activate'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
