import 'package:flutter/material.dart';
import '../widgets/top_nav_bar.dart';
import '../widgets/side_menu.dart';
import '../widgets/add_product_dialog.dart';

class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          const SideMenu(selected: 'Products'),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TopNavBar(title: 'Products'),
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
                                Text('Products',
                                    style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold)),
                                SizedBox(height: 4),
                                Text('Manage your product catalog'),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => const AddProductDialog(),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add product'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Row(
                                children: const [],
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            SizedBox(
                              width: 260,
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Search products...',
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: const [
                                  Icon(Icons.inventory_2_outlined, size: 16),
                                  SizedBox(width: 4),
                                  Text('3 products'),
                                  SizedBox(width: 16),
                                  Icon(Icons.attach_money, size: 16),
                                  SizedBox(width: 4),
                                  Text('\$11,100.00 inventory value'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text('Product Catalog',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        _productTable(),
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

  Widget _productTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      width: double.infinity,
      child: DataTable(
        columnSpacing: 24,
        headingRowHeight: 56,
        dataRowHeight: 64,
        headingTextStyle:
            const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54),
        columns: const [
          DataColumn(label: Text('Product')),
          DataColumn(label: Text('SKU')),
          DataColumn(label: Text('Price')),
          DataColumn(label: Text('Inventory')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Actions')),
        ],
        rows: _rows(),
      ),
    );
  }

  List<DataRow> _rows() {
    List<Map<String, dynamic>> data = [
      {
        'name': 'Wireless Headphones',
        'sku': 'WH-001',
        'price': 100.0,
        'inventory': 45,
        'status': 'active'
      },
      {
        'name': 'Smartphone Case',
        'sku': 'SC-003',
        'price': 30.0,
        'inventory': 120,
        'status': 'active'
      },
      {
        'name': 'USB Cable',
        'sku': 'UC-002',
        'price': 15.0,
        'inventory': 200,
        'status': 'active'
      },
    ];

    Color badgeColor(String status) {
      switch (status) {
        case 'active':
          return Colors.green.shade200;
        case 'draft':
          return Colors.grey.shade300;
        default:
          return Colors.grey;
      }
    }

    return data.map((item) {
      return DataRow(cells: [
        DataCell(Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(item['name'].toString()[0],
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(item['name'],
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const Text('Created 6/22/2025',
                  style: TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          )
        ])),
        DataCell(Text(item['sku'])),
        DataCell(Text('\$${item['price'].toStringAsFixed(2)}')),
        DataCell(Text(item['inventory'].toString())),
        DataCell(Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor(item['status']),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(item['status'],
              style: const TextStyle(fontSize: 12, color: Colors.black87)),
        )),
        DataCell(Row(children: const [
          Icon(Icons.edit, size: 18),
          SizedBox(width: 16),
          Icon(Icons.delete_outline, size: 18, color: Colors.red),
        ])),
      ]);
    }).toList();
  }
}
