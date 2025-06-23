import 'package:flutter/material.dart';
import '../widgets/side_menu.dart';
import '../widgets/top_nav_bar.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          const SideMenu(selected: 'Customers'),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TopNavBar(title: 'Customers'),
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
                                Text('Customers',
                                    style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold)),
                                SizedBox(height: 4),
                                Text('Manage your customer relationships'),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add customer'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            SizedBox(
                              width: 260,
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Search customers...',
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
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
                                      borderRadius: BorderRadius.circular(8)),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Row(
                              children: const [
                                Icon(Icons.person_outline, size: 16),
                                SizedBox(width: 4),
                                Text('4 customers'),
                                SizedBox(width: 16),
                                Icon(Icons.attach_money, size: 16),
                                SizedBox(width: 4),
                                Text('\$4,863.95 revenue'),
                                SizedBox(width: 16),
                                Icon(Icons.shopping_cart_outlined, size: 16),
                                SizedBox(width: 4),
                                Text('18 orders'),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text('Customer Database',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        _customerTable(),
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

  Widget _customerTable() {
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
        headingTextStyle:
            const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54),
        columns: const [
          DataColumn(label: Text('Customer')),
          DataColumn(label: Text('Location')),
          DataColumn(label: Text('Orders')),
          DataColumn(label: Text('Total Spent')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Actions')),
        ],
        rows: _rows(),
      ),
    );
  }

  List<DataRow> _rows() {
    final data = [
      {
        'name': 'Sarah Johnson',
        'email': 'sarah.johnson@example.com',
        'city': 'Toronto',
        'country': 'Canada',
        'orders': 3,
        'spent': 892.25,
        'status': 'active'
      },
      {
        'name': 'John Smith',
        'email': 'john.smith@example.com',
        'city': 'New York',
        'country': 'United States',
        'orders': 5,
        'spent': 1247.50,
        'status': 'active'
      },
      {
        'name': 'Mike Davis',
        'email': 'mike.davis@example.com',
        'city': 'Los Angeles',
        'country': 'United States',
        'orders': 8,
        'spent': 2156.80,
        'status': 'active'
      },
      {
        'name': 'Emma Wilson',
        'email': 'emma.wilson@example.com',
        'city': 'London',
        'country': 'United Kingdom',
        'orders': 2,
        'spent': 567.40,
        'status': 'inactive'
      },
    ];

    Color badgeColor(String status) =>
        status == 'active' ? Colors.green.shade200 : Colors.grey.shade300;

    return data.map((raw) {
      final item = raw as Map<String, dynamic>;
      final name = item['name'] as String;
      final email = item['email'] as String;
      final city = item['city'] as String;
      final country = item['country'] as String;
      final orders = item['orders'] as int;
      final spent = item['spent'] as double;
      final status = item['status'] as String;

      final initials = name.split(' ').map((e) => e[0]).take(2).join();
      return DataRow(cells: [
        // Customer
        DataCell(Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.blue.shade200,
            child: Text(initials,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(email,
                  style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          )
        ])),
        // Location
        DataCell(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(city),
            Text(country,
                style: const TextStyle(color: Colors.black54, fontSize: 12)),
          ],
        )),
        // Orders
        DataCell(Text(orders.toString())),
        // Total Spent
        DataCell(Text('\$${spent.toStringAsFixed(2)}')),
        // Status
        DataCell(Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor(status),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(status,
              style: const TextStyle(fontSize: 12, color: Colors.black87)),
        )),
        // Actions
        DataCell(Row(children: const [
          Icon(Icons.edit, size: 18),
          SizedBox(width: 16),
          Icon(Icons.delete_outline, size: 18, color: Colors.red),
        ])),
      ]);
    }).toList();
  }
}
