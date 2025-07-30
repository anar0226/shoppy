import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PaymentManagementPage extends StatefulWidget {
  const PaymentManagementPage({super.key});

  @override
  State<PaymentManagementPage> createState() => _PaymentManagementPageState();
}

class _PaymentManagementPageState extends State<PaymentManagementPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _transactions = [];
  String _filterStatus = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get all orders with payment information - simplified query to avoid permission issues
      final ordersSnapshot =
          await FirebaseFirestore.instance.collection('orders').get();

      List<Map<String, dynamic>> transactions = [];

      for (final orderDoc in ordersSnapshot.docs) {
        final orderData = orderDoc.data();

        // Only process completed payments
        final paymentStatus = orderData['paymentStatus'];
        if (paymentStatus != 'completed') continue;

        // Get store information
        final storeId = orderData['storeId'];
        DocumentSnapshot? storeDoc;
        if (storeId != null) {
          storeDoc = await FirebaseFirestore.instance
              .collection('stores')
              .doc(storeId)
              .get();
        }

        // Get user information
        final userId = orderData['userId'];
        DocumentSnapshot? userDoc;
        if (userId != null) {
          userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
        }

        // Calculate store earnings (total - platform commission)
        final total = (orderData['total'] ?? 0).toDouble();
        final platformCommission =
            (orderData['platformCommission'] ?? 0).toDouble();
        final storeEarnings = total - platformCommission;

        // Check if payment has been processed
        final paymentProcessed = orderData['paymentProcessed'] ?? false;
        final paymentProcessedAt = orderData['paymentProcessedAt'];
        final paymentProcessedBy = orderData['paymentProcessedBy'];

        transactions.add({
          'orderId': orderDoc.id,
          'orderData': orderData,
          'storeData': storeDoc?.data(),
          'userData': userDoc?.data(),
          'storeEarnings': storeEarnings,
          'paymentProcessed': paymentProcessed,
          'paymentProcessedAt': paymentProcessedAt,
          'paymentProcessedBy': paymentProcessedBy,
        });
      }

      // Sort transactions by creation date (newest first)
      transactions.sort((a, b) {
        final aDate = a['orderData']['createdAt'] as Timestamp?;
        final bDate = b['orderData']['createdAt'] as Timestamp?;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading transactions: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredTransactions {
    return _transactions.where((transaction) {
      // Filter by status
      if (_filterStatus != 'all') {
        final paymentProcessed = transaction['paymentProcessed'] ?? false;
        if (_filterStatus == 'pending' && paymentProcessed) return false;
        if (_filterStatus == 'processed' && !paymentProcessed) return false;
      }

      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final orderId = transaction['orderId']?.toString().toLowerCase() ?? '';
        final storeName =
            transaction['storeData']?['name']?.toString().toLowerCase() ?? '';
        final userName =
            transaction['userData']?['name']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();

        if (!orderId.contains(query) &&
            !storeName.contains(query) &&
            !userName.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  double get _totalPendingAmount {
    return _filteredTransactions
        .where((t) => !(t['paymentProcessed'] ?? false))
        .fold(0.0, (total, t) => total + (t['storeEarnings'] ?? 0));
  }

  Future<void> _markAsPaid(String orderId) async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
        'paymentProcessed': true,
        'paymentProcessedAt': FieldValue.serverTimestamp(),
        'paymentProcessedBy': 'super_admin',
      });

      // Reload transactions
      await _loadTransactions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment marked as processed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error marking payment as processed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Payment Management',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _loadTransactions,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Total Pending',
                    '₮${_totalPendingAmount.toStringAsFixed(2)}',
                    Colors.orange,
                    Icons.pending,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    'Total Transactions',
                    _filteredTransactions.length.toString(),
                    Colors.blue,
                    Icons.receipt,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    'Pending Payments',
                    _filteredTransactions
                        .where((t) => !(t['paymentProcessed'] ?? false))
                        .length
                        .toString(),
                    Colors.red,
                    Icons.payment,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Filters
            Row(
              children: [
                // Status Filter
                DropdownButton<String>(
                  value: _filterStatus,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Status')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(
                        value: 'processed', child: Text('Processed')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _filterStatus = value!;
                    });
                  },
                ),
                const SizedBox(width: 16),

                // Search
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText:
                          'Search by order ID, store name, or customer name...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
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

            // Transactions Table
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredTransactions.isEmpty
                      ? const Center(
                          child: Text(
                            'No transactions found',
                            style: TextStyle(fontSize: 18),
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Order ID')),
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Store')),
                              DataColumn(label: Text('Customer')),
                              DataColumn(label: Text('Total')),
                              DataColumn(label: Text('Store Earnings')),
                              DataColumn(label: Text('Bank Details')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: _filteredTransactions.map((transaction) {
                              final orderData = transaction['orderData'];
                              final storeData = transaction['storeData'];
                              final userData = transaction['userData'];
                              final paymentProcessed =
                                  transaction['paymentProcessed'] ?? false;

                              return DataRow(
                                cells: [
                                  DataCell(Text(orderData['orderId'] ?? 'N/A')),
                                  DataCell(Text(
                                    orderData['createdAt'] != null
                                        ? DateFormat('MMM dd, yyyy HH:mm')
                                            .format((orderData['createdAt']
                                                    as Timestamp)
                                                .toDate())
                                        : 'N/A',
                                  )),
                                  DataCell(Text(storeData?['name'] ?? 'N/A')),
                                  DataCell(Text(userData?['name'] ?? 'N/A')),
                                  DataCell(Text(
                                      '₮${(orderData['total'] ?? 0).toStringAsFixed(2)}')),
                                  DataCell(Text(
                                      '₮${transaction['storeEarnings'].toStringAsFixed(2)}')),
                                  DataCell(
                                    storeData?['bankDetails'] != null
                                        ? _buildBankDetailsWidget(
                                            storeData!['bankDetails'])
                                        : const Text('No bank details'),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: paymentProcessed
                                            ? Colors.green
                                            : Colors.orange,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        paymentProcessed
                                            ? 'Processed'
                                            : 'Pending',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    paymentProcessed
                                        ? const Text('Already processed')
                                        : ElevatedButton(
                                            onPressed: () => _markAsPaid(
                                                orderData['orderId']),
                                            child: const Text('Mark as Paid'),
                                          ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
      String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBankDetailsWidget(Map<String, dynamic> bankDetails) {
    return PopupMenuButton<String>(
      child: const Text('View Details'),
      itemBuilder: (context) => [
        PopupMenuItem(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bank: ${bankDetails['bankName'] ?? 'N/A'}'),
              Text('Account: ${bankDetails['accountNumber'] ?? 'N/A'}'),
              Text('Name: ${bankDetails['accountName'] ?? 'N/A'}'),
            ],
          ),
        ),
      ],
    );
  }
}
