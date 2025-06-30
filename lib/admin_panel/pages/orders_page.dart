import 'package:flutter/material.dart';
import '../widgets/top_nav_bar.dart';
import '../widgets/side_menu.dart';
import '../../features/settings/themes/app_themes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/auth_service.dart';
import '../../core/utils/type_utils.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  // Statistics variables
  int totalOrders = 0;
  double totalRevenue = 0.0;
  int uniqueCustomers = 0;

  void _calculateStatistics(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final newTotalOrders = docs.length;
    double newTotalRevenue = 0.0;
    Set<String> customerEmails = {};

    for (var doc in docs) {
      final data = doc.data();
      // Calculate total revenue
      final orderTotal =
          TypeUtils.safeCastDouble(data['total'], defaultValue: 0.0);
      newTotalRevenue += orderTotal;

      // Count unique customers
      final customerEmail = data['customerEmail'] as String? ??
          data['userEmail'] as String? ??
          data['customerId'] as String? ??
          '';
      if (customerEmail.isNotEmpty) {
        customerEmails.add(customerEmail);
      }
    }

    final newUniqueCustomers = customerEmails.length;

    // Only update state if values have actually changed
    if (totalOrders != newTotalOrders ||
        totalRevenue != newTotalRevenue ||
        uniqueCustomers != newUniqueCustomers) {
      totalOrders = newTotalOrders;
      totalRevenue = newTotalRevenue;
      uniqueCustomers = newUniqueCustomers;

      // Schedule state update for next frame to avoid rebuilding during build
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemes.getBackgroundColor(context),
      body: Row(
        children: [
          const SideMenu(selected: 'Захиалгууд'),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TopNavBar(title: 'Захиалгууд'),
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
                                Text('Захиалгууд',
                                    style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold)),
                                SizedBox(height: 4),
                                Text('Хэрэглэгчийн захиалгуудыг хянах'),
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
                              label: const Text('Захиалга үүсгэх'),
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
                                        hintText: 'Захиалга хайх...',
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
                                      value: 'бүх төлөв',
                                      items: const [
                                        DropdownMenuItem(
                                            value: 'бүх төлөв',
                                            child: Text('бүх төлөв')),
                                        DropdownMenuItem(
                                            value: 'захиалсан',
                                            child: Text('захиалсан')),
                                        DropdownMenuItem(
                                            value: 'хүргэгдсэн',
                                            child: Text('хүргэгдсэн')),
                                        DropdownMenuItem(
                                            value: 'цуцлагдсан',
                                            child: Text('цуцлагдсан')),
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
                              children: [
                                const Icon(Icons.shopping_cart_outlined,
                                    size: 16),
                                const SizedBox(width: 4),
                                Text('$totalOrders захиалга'),
                                const SizedBox(width: 16),
                                const Icon(Icons.attach_money, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                    '₮${totalRevenue.toStringAsFixed(0)} орлого'),
                                const SizedBox(width: 16),
                                const Icon(Icons.person_outline, size: 16),
                                const SizedBox(width: 4),
                                Text('$uniqueCustomers хэрэглэгч'),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text('Захиалгын хянах',
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
          .where('vendorId', isEqualTo: AuthService.instance.currentUser?.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Алдаа: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];

        // Calculate statistics when data changes
        _calculateStatistics(docs);

        List<DataRow> rows = docs.map((doc) {
          final data = doc.data();
          final id = doc.id;
          final email = data['customerEmail'] ?? data['userEmail'] ?? '';

          // Get customer name with fallback logic
          String customer = data['customerName'] ?? '';
          if (customer.isEmpty) {
            // Fallback to email username or placeholder
            customer =
                email.isNotEmpty ? email.split('@').first : 'Үл мэдэгдэх';
          }

          final date = (data['createdAt'] as Timestamp?)?.toDate() ??
              (data['date'] as Timestamp?)?.toDate() ??
              DateTime.now();
          final total =
              TypeUtils.safeCastDouble(data['total'], defaultValue: 0.0);
          final status = data['status'] ?? 'placed';

          // Translate status to Mongolian
          String getStatusText(String status) {
            switch (status.toLowerCase()) {
              case 'placed':
              case 'pending':
                return 'захиалсан';
              case 'paid':
                return 'төлөгдсөн';
              case 'shipped':
              case 'delivering':
                return 'хүргэж байна';
              case 'delivered':
                return 'хүргэгдсэн';
              case 'cancelled':
                return 'цуцлагдсан';
              default:
                return 'захиалсан';
            }
          }

          Color badgeColor(String status) {
            switch (status.toLowerCase()) {
              case 'paid':
              case 'delivered':
                return Colors.green.shade200;
              case 'placed':
              case 'pending':
                return Colors.orange.shade200;
              case 'shipped':
              case 'delivering':
                return Colors.blue.shade200;
              case 'cancelled':
                return Colors.red.shade200;
              default:
                return Colors.grey.shade200;
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
                  Text('#${id.substring(0, 8)}...',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('Захиалгын дугаар',
                      style: TextStyle(
                          color: AppThemes.getSecondaryTextColor(context),
                          fontSize: 12)),
                ],
              )
            ])),
            DataCell(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(customer),
                Text(email,
                    style: TextStyle(
                        color: AppThemes.getSecondaryTextColor(context),
                        fontSize: 12)),
              ],
            )),
            DataCell(Text('${date.year}/${date.month}/${date.day}')),
            DataCell(Text('₮${total.toStringAsFixed(0)}')),
            DataCell(Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor(status),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(getStatusText(status),
                  style: TextStyle(
                      fontSize: 12, color: AppThemes.getTextColor(context))),
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
            color: AppThemes.getCardColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppThemes.getBorderColor(context)),
          ),
          child: DataTable(
            columnSpacing: 24,
            headingRowHeight: 56,
            dataRowHeight: 64,
            headingTextStyle: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppThemes.getSecondaryTextColor(context)),
            columns: [
              DataColumn(
                  label: Text('Захиалга',
                      style: TextStyle(
                          color: AppThemes.getSecondaryTextColor(context)))),
              DataColumn(
                  label: Text('Хэрэглэгч',
                      style: TextStyle(
                          color: AppThemes.getSecondaryTextColor(context)))),
              DataColumn(
                  label: Text('Огноо',
                      style: TextStyle(
                          color: AppThemes.getSecondaryTextColor(context)))),
              DataColumn(
                  label: Text('Нийт дүн',
                      style: TextStyle(
                          color: AppThemes.getSecondaryTextColor(context)))),
              DataColumn(
                  label: Text('Төлөв',
                      style: TextStyle(
                          color: AppThemes.getSecondaryTextColor(context)))),
              DataColumn(
                  label: Text('Үйлдэл',
                      style: TextStyle(
                          color: AppThemes.getSecondaryTextColor(context)))),
            ],
            rows: rows,
          ),
        );
      },
    );
  }
}
