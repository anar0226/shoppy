import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// OrdersPage for Super Admin – view all marketplace orders and payout details.
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _ordersStream;

  @override
  void initState() {
    super.initState();
    // Listen to all orders in real-time. Adjust the collection/path if needed.
    _ordersStream = FirebaseFirestore.instance
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Orders',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _ordersStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                        child: Text('Error loading orders: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final orders = snapshot.data!.docs;
                  if (orders.isEmpty) {
                    return const Center(child: Text('No orders found'));
                  }

                  return PaginatedDataTable(
                    header: const Text('Recent Orders'),
                    rowsPerPage: 10,
                    columns: const [
                      DataColumn(label: Text('Order #')),
                      DataColumn(label: Text('Customer')),
                      DataColumn(label: Text('Store')),
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Total')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Actions')),
                    ],
                    source: _OrdersDataSource(context, orders),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersDataSource extends DataTableSource {
  final BuildContext context;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> orders;

  _OrdersDataSource(this.context, this.orders);

  @override
  DataRow? getRow(int index) {
    if (index >= orders.length) return null;
    final doc = orders[index];
    final data = doc.data();
    final orderId = doc.id;
    final customerName = data['customerName'] ?? 'N/A';
    final storeId = data['storeId'] ?? 'N/A';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final total = data['total'] ?? 0;
    final status = data['status'] ?? 'N/A';

    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(Text(orderId.substring(0, 8))),
        DataCell(Text(customerName)),
        DataCell(Text(storeId)),
        DataCell(Text(createdAt != null ? _formatDate(createdAt) : 'Unknown')),
        DataCell(Text('₮${total.toStringAsFixed(2)}')),
        DataCell(_buildStatusChip(status)),
        DataCell(
          IconButton(
            icon: const Icon(Icons.visibility),
            tooltip: 'View details',
            onPressed: () => _showOrderDetails(context, doc),
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => orders.length;
  @override
  int get selectedRowCount => 0;

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'paid':
        color = Colors.green;
        break;
      case 'pending':
        color = Colors.orange;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Chip(
        label: Text(status), backgroundColor: color.withValues(alpha: 0.15));
  }

  Future<void> _showOrderDetails(BuildContext context,
      QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    final products = List<Map<String, dynamic>>.from(data['products'] ?? []);

    // Fetch store bank details
    final storeId = data['storeId'];
    Map<String, dynamic>? bankInfo;
    if (storeId != null) {
      final storeSnap = await FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .get();
      if (storeSnap.exists) {
        bankInfo = storeSnap.data()?['bankDetails'];
      }
    }

    // Show bottom sheet with all the information
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Order #${doc.id}',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _infoRow('Customer', data['customerName'] ?? 'N/A'),
                  _infoRow(
                      'Date',
                      _formatDate((data['createdAt'] as Timestamp?)?.toDate() ??
                          DateTime.now())),
                  _infoRow(
                      'Total', '₮${(data['total'] ?? 0).toStringAsFixed(2)}'),
                  _infoRow('Status', data['status'] ?? 'N/A'),
                  const SizedBox(height: 16),
                  const Text('Products',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ...products.map((p) => Text('- ${p['name']} x${p['qty']}')),
                  const SizedBox(height: 24),
                  const Text('Store Bank Details',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (bankInfo != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoRow('Bank', bankInfo['bankName'] ?? 'N/A'),
                        _infoRow(
                            'Account Name', bankInfo['accountName'] ?? 'N/A'),
                        _infoRow(
                            'Account No.', bankInfo['accountNumber'] ?? 'N/A'),
                      ],
                    )
                  else
                    const Text('Bank details not found'),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(width: 150, child: Text(title)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
