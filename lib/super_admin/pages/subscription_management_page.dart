import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SubscriptionManagementPage extends StatefulWidget {
  const SubscriptionManagementPage({super.key});

  @override
  State<SubscriptionManagementPage> createState() =>
      _SubscriptionManagementPageState();
}

class _SubscriptionManagementPageState
    extends State<SubscriptionManagementPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _subscriptions = [];
  String _filterStatus = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get all stores with subscription information
      final storesSnapshot = await FirebaseFirestore.instance
          .collection('stores')
          .where('subscriptionStatus', isNotEqualTo: null)
          .get();

      List<Map<String, dynamic>> subscriptions = [];

      for (final storeDoc in storesSnapshot.docs) {
        final storeData = storeDoc.data();
        final subscriptionStatus = storeData['subscriptionStatus'];
        final kycStatus = storeData['kycStatus'] ?? 'pending';
        final subscriptionPayment = storeData['subscriptionPayment'];

        // Get payment records if they exist
        List<Map<String, dynamic>> paymentRecords = [];
        if (subscriptionPayment != null) {
          final paymentsSnapshot = await FirebaseFirestore.instance
              .collection('subscription_payments')
              .where('storeId', isEqualTo: storeDoc.id)
              .orderBy('createdAt', descending: true)
              .get();

          for (final paymentDoc in paymentsSnapshot.docs) {
            paymentRecords.add({
              'id': paymentDoc.id,
              ...paymentDoc.data(),
            });
          }
        }

        subscriptions.add({
          'storeId': storeDoc.id,
          'storeData': storeData,
          'subscriptionStatus': subscriptionStatus,
          'kycStatus': kycStatus,
          'paymentRecords': paymentRecords,
        });
      }

      // Sort by creation date (newest first)
      subscriptions.sort((a, b) {
        final aDate = a['storeData']['createdAt'] as Timestamp?;
        final bDate = b['storeData']['createdAt'] as Timestamp?;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

      setState(() {
        _subscriptions = subscriptions;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading subscriptions: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyKYC(String storeId) async {
    try {
      await FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .update({
        'kycStatus': 'verified',
        'kycVerifiedAt': FieldValue.serverTimestamp(),
        'kycVerifiedBy': 'super_admin',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('KYC verification successful'),
          backgroundColor: Colors.green,
        ),
      );

      _loadSubscriptions();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error verifying KYC: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _activateStore(String storeId) async {
    try {
      await FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .update({
        'subscriptionStatus': 'active',
        'activatedAt': FieldValue.serverTimestamp(),
        'activatedBy': 'super_admin',
        'isActive': true,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Store activated successfully'),
          backgroundColor: Colors.green,
        ),
      );

      _loadSubscriptions();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error activating store: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectKYC(String storeId) async {
    try {
      await FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .update({
        'kycStatus': 'rejected',
        'kycRejectedAt': FieldValue.serverTimestamp(),
        'kycRejectedBy': 'super_admin',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('KYC rejected'),
          backgroundColor: Colors.orange,
        ),
      );

      _loadSubscriptions();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error rejecting KYC: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredSubscriptions {
    List<Map<String, dynamic>> filtered = _subscriptions;

    // Apply status filter
    if (_filterStatus != 'all') {
      filtered = filtered.where((sub) {
        if (_filterStatus == 'pending_payment') {
          return sub['subscriptionStatus'] == 'pending_payment';
        } else if (_filterStatus == 'pending_kyc') {
          return sub['kycStatus'] == 'pending';
        } else if (_filterStatus == 'active') {
          return sub['subscriptionStatus'] == 'active';
        }
        return true;
      }).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((sub) {
        final storeData = sub['storeData'];
        final storeName = storeData['name']?.toString().toLowerCase() ?? '';
        final ownerName =
            storeData['ownerName']?.toString().toLowerCase() ?? '';
        final phone = storeData['phone']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();

        return storeName.contains(query) ||
            ownerName.contains(query) ||
            phone.contains(query);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Subscription Management',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Manage store subscriptions, KYC verification, and activation',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _loadSubscriptions,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Filters and Search
            Row(
              children: [
                // Status Filter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: _filterStatus,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Status')),
                      DropdownMenuItem(
                          value: 'pending_payment',
                          child: Text('Pending Payment')),
                      DropdownMenuItem(
                          value: 'pending_kyc', child: Text('Pending KYC')),
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filterStatus = value!;
                      });
                    },
                  ),
                ),

                const SizedBox(width: 16),

                // Search
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search stores...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Statistics Cards
            Row(
              children: [
                _buildStatCard(
                  'Total Subscriptions',
                  _subscriptions.length.toString(),
                  Icons.subscriptions,
                  Colors.blue,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Pending Payment',
                  _subscriptions
                      .where(
                          (s) => s['subscriptionStatus'] == 'pending_payment')
                      .length
                      .toString(),
                  Icons.payment,
                  Colors.orange,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Pending KYC',
                  _subscriptions
                      .where((s) => s['kycStatus'] == 'pending')
                      .length
                      .toString(),
                  Icons.verified_user,
                  Colors.red,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Active',
                  _subscriptions
                      .where((s) => s['subscriptionStatus'] == 'active')
                      .length
                      .toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Subscriptions List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredSubscriptions.isEmpty
                      ? const Center(
                          child: Text(
                            'No subscriptions found',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredSubscriptions.length,
                          itemBuilder: (context, index) {
                            final subscription = _filteredSubscriptions[index];
                            return _buildSubscriptionCard(subscription);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(Map<String, dynamic> subscription) {
    final storeData = subscription['storeData'];
    final storeId = subscription['storeId'];
    final subscriptionStatus = subscription['subscriptionStatus'];
    final kycStatus = subscription['kycStatus'];
    final paymentRecords = subscription['paymentRecords'] as List;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store Info
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    (storeData['name'] ?? 'S').substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        storeData['name'] ?? 'Unknown Store',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Owner: ${storeData['ownerName'] ?? 'Unknown'} | Phone: ${storeData['phone'] ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildStatusChip(subscriptionStatus, 'Subscription'),
                    const SizedBox(height: 8),
                    _buildStatusChip(kycStatus, 'KYC'),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Payment Records
            if (paymentRecords.isNotEmpty) ...[
              const Text(
                'Payment Records',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...paymentRecords
                  .map((payment) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              payment['status'] == 'verified'
                                  ? Icons.check_circle
                                  : Icons.pending,
                              color: payment['status'] == 'verified'
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Amount: ₮${payment['amount']?.toString() ?? 'N/A'}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    'Date: ${payment['createdAt'] != null ? DateFormat('MMM dd, yyyy HH:mm').format((payment['createdAt'] as Timestamp).toDate()) : 'N/A'}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              payment['status'] ?? 'pending',
                              style: TextStyle(
                                color: payment['status'] == 'verified'
                                    ? Colors.green
                                    : Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ],

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                if (kycStatus == 'pending') ...[
                  ElevatedButton.icon(
                    onPressed: () => _verifyKYC(storeId),
                    icon: const Icon(Icons.verified_user),
                    label: const Text('Verify KYC'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => _rejectKYC(storeId),
                    icon: const Icon(Icons.cancel),
                    label: const Text('Reject KYC'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.shade300),
                    ),
                  ),
                ],
                if (kycStatus == 'verified' &&
                    subscriptionStatus == 'pending_payment') ...[
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => _activateStore(storeId),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Activate Store'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, String type) {
    Color color;
    IconData icon;

    if (type == 'Subscription') {
      switch (status) {
        case 'active':
          color = Colors.green;
          icon = Icons.check_circle;
          break;
        case 'pending_payment':
          color = Colors.orange;
          icon = Icons.payment;
          break;
        default:
          color = Colors.grey;
          icon = Icons.pending;
      }
    } else {
      // KYC
      switch (status) {
        case 'verified':
          color = Colors.green;
          icon = Icons.verified_user;
          break;
        case 'rejected':
          color = Colors.red;
          icon = Icons.cancel;
          break;
        default:
          color = Colors.orange;
          icon = Icons.pending;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
