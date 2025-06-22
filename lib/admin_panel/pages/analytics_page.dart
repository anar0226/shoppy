import 'package:flutter/material.dart';
import '../widgets/side_menu.dart';
import '../widgets/top_nav_bar.dart';
import '../widgets/stat_card.dart';
import '../widgets/simple_chart_placeholder.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          const SideMenu(selected: 'Analytics'),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TopNavBar(title: 'Analytics'),
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
                                Text('Analytics',
                                    style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold)),
                                SizedBox(height: 4),
                                Text(
                                    'Track your store performance and insights'),
                              ],
                            ),
                            Row(
                              children: [
                                SizedBox(
                                  width: 140,
                                  child: DropdownButtonFormField<String>(
                                    value: 'Last 30 days',
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'Last 30 days',
                                          child: Text('Last 30 days')),
                                      DropdownMenuItem(
                                          value: 'Last 7 days',
                                          child: Text('Last 7 days')),
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
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  onPressed: () {},
                                  icon: const Icon(Icons.download_outlined,
                                      size: 18),
                                  label: const Text('Export'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 14),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // stats cards
                        Wrap(
                          spacing: 24,
                          runSpacing: 24,
                          children: const [
                            StatCard(
                              title: 'Total Revenue',
                              value: '\$67,000.00',
                              delta: '+22.5%',
                              deltaUp: true,
                              icon: Icons.attach_money,
                              iconBg: Colors.green,
                              periodLabel: 'This month',
                              comparisonLabel: 'vs yesterday',
                            ),
                            StatCard(
                              title: 'Orders',
                              value: '267',
                              delta: '+18.7%',
                              deltaUp: true,
                              icon: Icons.shopping_cart_outlined,
                              iconBg: Colors.blue,
                              periodLabel: 'This month',
                              comparisonLabel: 'vs yesterday',
                            ),
                            StatCard(
                              title: 'Customers',
                              value: '189',
                              delta: '+12.3%',
                              deltaUp: true,
                              icon: Icons.person_outline,
                              iconBg: Colors.purple,
                              periodLabel: 'This month',
                              comparisonLabel: 'vs yesterday',
                            ),
                            StatCard(
                              title: 'Conversion Rate',
                              value: '4.2%',
                              delta: '+0.5%',
                              deltaUp: true,
                              icon: Icons.bar_chart,
                              iconBg: Colors.orange,
                              periodLabel: 'This month',
                              comparisonLabel: 'vs last month',
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Revenue trend card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text('Revenue Trend',
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                  SizedBox(
                                    width: 120,
                                    child: DropdownButtonFormField<String>(
                                      value: 'Sales',
                                      items: const [
                                        DropdownMenuItem(
                                            value: 'Sales',
                                            child: Text('Sales')),
                                        DropdownMenuItem(
                                            value: 'Orders',
                                            child: Text('Orders')),
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
                              const SizedBox(height: 12),
                              const SimpleChartPlaceholder(height: 280),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Top products & customer segments
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top products list
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Top Products',
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 16),
                                    _topProductRow('1', 'Wireless Headphones',
                                        '142 sold', '\$14,200.00'),
                                    const SizedBox(height: 12),
                                    _topProductRow('2', 'Smartphone Case',
                                        '98 sold', '\$2,940.00'),
                                    const SizedBox(height: 12),
                                    _topProductRow('3', 'USB Cable', '87 sold',
                                        '\$1,305.00'),
                                    const SizedBox(height: 12),
                                    _topProductRow('4', 'Phone Charger',
                                        '65 sold', '\$1,950.00'),
                                    const SizedBox(height: 12),
                                    _topProductRow('5', 'Screen Protector',
                                        '34 sold', '\$510.00'),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            // Customer segments
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text('Customer Segments',
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700)),
                                    SizedBox(height: 16),
                                    SimpleChartPlaceholder(height: 240),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Traffic & Conversion funnel
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text('Traffic Sources',
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700)),
                                    SizedBox(
                                        height: 150,
                                        child: Center(child: Text('List'))),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text('Conversion Funnel',
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700)),
                                    SizedBox(
                                        height: 150,
                                        child: Center(child: Text('Funnel'))),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
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

  Widget _topProductRow(
      String rank, String name, String subtitle, String amount) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child:
              Text(rank, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(amount, style: const TextStyle(fontWeight: FontWeight.w600)),
            Container(
              width: 120,
              height: 6,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: int.parse(rank) / 5,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
