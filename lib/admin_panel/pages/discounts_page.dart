import 'package:flutter/material.dart';
import '../widgets/top_nav_bar.dart';
import '../widgets/side_menu.dart';

class DiscountsPage extends StatelessWidget {
  const DiscountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          const SideMenu(selected: 'Discounts'),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TopNavBar(title: 'Discounts'),
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
                                Text('Discounts',
                                    style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold)),
                                SizedBox(height: 4),
                                Text('Create and manage promotional offers'),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Create discount'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // filter row
                        Row(
                          children: [
                            SizedBox(
                              width: 260,
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Search discounts...',
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 140,
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
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 140,
                              child: DropdownButtonFormField<String>(
                                value: 'All Types',
                                items: const [
                                  DropdownMenuItem(
                                      value: 'All Types',
                                      child: Text('All Types')),
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
                                Icon(Icons.local_offer_outlined, size: 16),
                                SizedBox(width: 4),
                                Text('3 discounts'),
                                SizedBox(width: 16),
                                Icon(Icons.calendar_today_outlined, size: 16),
                                SizedBox(width: 4),
                                Text('3 active'),
                                SizedBox(width: 16),
                                Icon(Icons.person_outline, size: 16),
                                SizedBox(width: 4),
                                Text('224 uses'),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text('Discount Codes',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        _discountTable(),
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

  Widget _discountTable() {
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
          DataColumn(label: Text('Discount')),
          DataColumn(label: Text('Code')),
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Value')),
          DataColumn(label: Text('Uses')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Actions')),
        ],
        rows: _rows(),
      ),
    );
  }

  List<DataRow> _rows() {
    final discounts = [
      {
        'icon': Icons.local_offer_outlined,
        'name': 'Free Shipping Promotion',
        'created': '6/17/2025',
        'code': 'FREESHIP',
        'type': 'Free Shipping',
        'value': 'Free Shipping',
        'uses': '156 / 200',
        'status': 'active'
      },
      {
        'icon': Icons.percent,
        'name': 'Summer Sale 2024',
        'created': '6/12/2025',
        'code': 'SUMMER20',
        'type': 'Percentage',
        'value': '20.00%',
        'uses': '23 / 100',
        'status': 'active'
      },
      {
        'icon': Icons.attach_money,
        'name': 'New Customer Welcome',
        'created': '5/23/2025',
        'code': 'WELCOME10',
        'type': 'Fixed Amount',
        'value': '\$10.00',
        'uses': '45',
        'status': 'active'
      },
    ];

    Color badgeColor(String status) =>
        status == 'active' ? Colors.green.shade200 : Colors.grey.shade300;

    return discounts.map((d) {
      return DataRow(cells: [
        // Discount cell
        DataCell(Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.purple.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(d['icon'] as IconData, color: Colors.purple),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(d['name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('Created ${d['created']}',
                  style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          ),
        ])),
        DataCell(Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(d['code'] as String,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        )),
        DataCell(Text(d['type'] as String)),
        DataCell(Text(d['value'] as String,
            style: const TextStyle(fontWeight: FontWeight.w600))),
        DataCell(Text(d['uses'] as String)),
        DataCell(Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor(d['status'] as String),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(d['status'] as String,
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
