import 'package:flutter/material.dart';
import '../widgets/side_menu.dart';
import '../widgets/top_nav_bar.dart';
import '../../features/settings/themes/app_themes.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemes.getBackgroundColor(context),
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
                              children: [
                                Text('Customers',
                                    style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            AppThemes.getTextColor(context))),
                                const SizedBox(height: 4),
                                Text('Manage your customer relationships',
                                    style: TextStyle(
                                        color: AppThemes.getSecondaryTextColor(
                                            context))),
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
                                style: TextStyle(
                                    color: AppThemes.getTextColor(context)),
                                decoration: InputDecoration(
                                  hintText: 'Search customers...',
                                  hintStyle: TextStyle(
                                      color: AppThemes.getSecondaryTextColor(
                                          context)),
                                  prefixIcon: Icon(Icons.search,
                                      color: AppThemes.getSecondaryTextColor(
                                          context)),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                          color: AppThemes.getBorderColor(
                                              context))),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                          color: AppThemes.getBorderColor(
                                              context))),
                                  fillColor: AppThemes.getCardColor(context),
                                  filled: true,
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
                              children: [
                                Icon(Icons.person_outline,
                                    size: 16,
                                    color: AppThemes.getSecondaryTextColor(
                                        context)),
                                const SizedBox(width: 4),
                                Text('4 customers',
                                    style: TextStyle(
                                        color:
                                            AppThemes.getTextColor(context))),
                                const SizedBox(width: 16),
                                Icon(Icons.attach_money,
                                    size: 16,
                                    color: AppThemes.getSecondaryTextColor(
                                        context)),
                                const SizedBox(width: 4),
                                Text('\$4,863.95 revenue',
                                    style: TextStyle(
                                        color:
                                            AppThemes.getTextColor(context))),
                                const SizedBox(width: 16),
                                Icon(Icons.shopping_cart_outlined,
                                    size: 16,
                                    color: AppThemes.getSecondaryTextColor(
                                        context)),
                                const SizedBox(width: 4),
                                Text('18 orders',
                                    style: TextStyle(
                                        color:
                                            AppThemes.getTextColor(context))),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text('Customer Database',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppThemes.getTextColor(context))),
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
              label: Text('Customer',
                  style: TextStyle(
                      color: AppThemes.getSecondaryTextColor(context)))),
          DataColumn(
              label: Text('Location',
                  style: TextStyle(
                      color: AppThemes.getSecondaryTextColor(context)))),
          DataColumn(
              label: Text('Orders',
                  style: TextStyle(
                      color: AppThemes.getSecondaryTextColor(context)))),
          DataColumn(
              label: Text('Total Spent',
                  style: TextStyle(
                      color: AppThemes.getSecondaryTextColor(context)))),
          DataColumn(
              label: Text('Status',
                  style: TextStyle(
                      color: AppThemes.getSecondaryTextColor(context)))),
          DataColumn(
              label: Text('Actions',
                  style: TextStyle(
                      color: AppThemes.getSecondaryTextColor(context)))),
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
              Text(name,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppThemes.getTextColor(context))),
              Text(email,
                  style: TextStyle(
                      color: AppThemes.getSecondaryTextColor(context),
                      fontSize: 12)),
            ],
          )
        ])),
        // Location
        DataCell(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(city,
                style: TextStyle(color: AppThemes.getTextColor(context))),
            Text(country,
                style: TextStyle(
                    color: AppThemes.getSecondaryTextColor(context),
                    fontSize: 12)),
          ],
        )),
        // Orders
        DataCell(Text(orders.toString(),
            style: TextStyle(color: AppThemes.getTextColor(context)))),
        // Total Spent
        DataCell(Text('\$${spent.toStringAsFixed(2)}',
            style: TextStyle(color: AppThemes.getTextColor(context)))),
        // Status
        DataCell(Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor(status),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(status,
              style: TextStyle(
                  fontSize: 12, color: AppThemes.getTextColor(context))),
        )),
        // Actions
        DataCell(Row(children: [
          Icon(Icons.edit, size: 18, color: AppThemes.getTextColor(context)),
          const SizedBox(width: 16),
          Icon(Icons.delete_outline, size: 18, color: Colors.red),
        ])),
      ]);
    }).toList();
  }
}
