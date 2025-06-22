import 'package:flutter/material.dart';
import '../widgets/top_nav_bar.dart';
import '../widgets/side_menu.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/auth_service.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          const SideMenu(selected: 'Orders'),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TopNavBar(title: 'Orders'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('Orders',
                                    style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold)),
                                SizedBox(height: 4),
                                Text('Manage your customer orders'),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Create order'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 260,
                                    child: TextField(
                                      decoration: InputDecoration(
                                        hintText: 'Search orders…',
                                        prefixIcon: const Icon(Icons.search),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 180,
                                    child: DropdownButtonFormField<String>(
                                      value: 'All Status',
                                      items: const [
                                        DropdownMenuItem(
                                            value: 'All Status',
                                            child: Text('All Status')),
                                      ],
                                      onChanged: (_) {},
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: const [
                                Icon(Icons.shopping_cart_outlined, size: 16),
                                SizedBox(width: 4),
                                Text('3 orders'),
                                SizedBox(width: 16),
                                Icon(Icons.attach_money, size: 16),
                                SizedBox(width: 4),
                                Text('\$483.49 revenue'),
                                SizedBox(width: 16),
                                Icon(Icons.person_outline, size: 16),
                                SizedBox(width: 4),
                                Text('3 customers'),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text('Order Management',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        _ordersStreamTable(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ordersStreamTable() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('ownerId', isEqualTo: AuthService.instance.currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: \\${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];

        List<DataRow> rows = docs.map((doc) {
          final data = doc.data();
          final id = doc.id;
          final customer = data['customerName'] ?? 'Unknown';
          final email = data['customerEmail'] ?? '';
          final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
          final total = data['total'] ?? 0;
          final status = data['status'] ?? 'Pending';

          Color badgeColor(String status) {
            switch (status) {
              case 'Paid':
                return Colors.green.shade200;
              case 'Pending':
                return Colors.yellow.shade600;
              case 'Shipped':
                return Colors.blue.shade300;
              default:
                return Colors.grey;
            }
          }

          return DataRow(cells: [
            DataCell(Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shopping_cart_outlined,
                    size: 20, color: Colors.black),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('#$id',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('Order ID: $id'),
                ],
              )
            ])),
            DataCell(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(customer),
                Text(email,
                    style: TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            )),
            DataCell(Text('${date.month}/${date.day}/${date.year}')),
            DataCell(Text('\$${total.toStringAsFixed(2)}')),
            DataCell(Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor(status),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(status,
                  style: const TextStyle(fontSize: 12, color: Colors.black87)),
            )),
            DataCell(Row(children: const [
              Icon(Icons.edit, size: 18),
              SizedBox(width: 16),
              Icon(Icons.delete_outline, size: 18, color: Colors.red),
            ])),
          ]);
        }).toList();

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DataTable(
            columnSpacing: 24,
            headingRowHeight: 56,
            dataRowHeight: 64,
            headingTextStyle: const TextStyle(
                fontWeight: FontWeight.w600, color: Colors.black54),
            columns: const [
              DataColumn(label: Text('Order')),
              DataColumn(label: Text('Customer')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Total')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: rows,
          ),
        );
      },
    );
  }
}
