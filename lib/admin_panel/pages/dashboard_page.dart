import 'package:flutter/material.dart';
import '../widgets/side_menu.dart';
import '../widgets/stat_card.dart';
import '../widgets/top_nav_bar.dart';
import '../widgets/simple_chart_placeholder.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const SideMenu(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TopNavBar(title: 'Home'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add product'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 16),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _whiteButton(Icons.list, 'View all orders'),
                            const SizedBox(width: 12),
                            _whiteButton(
                                Icons.widgets_outlined, 'Manage inventory'),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // summary cards row
                        Wrap(
                          spacing: 24,
                          runSpacing: 24,
                          children: [
                            const StatCard(
                              title: 'Total sales',
                              value: '\$ 2,832.40',
                              delta: '+12.5%',
                              deltaUp: true,
                              icon: Icons.attach_money,
                              iconBg: Colors.green,
                            ),
                            const StatCard(
                              title: 'Orders',
                              value: '23',
                              delta: '+8.2%',
                              deltaUp: true,
                              icon: Icons.shopping_cart_outlined,
                              iconBg: Colors.blue,
                            ),
                            const StatCard(
                              title: 'Store sessions',
                              value: '1,247',
                              delta: '-3.1%',
                              deltaUp: false,
                              icon: Icons.people_outline,
                              iconBg: Colors.purple,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // chart and top products row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Expanded(
                                child: SimpleChartPlaceholder(height: 280)),
                            SizedBox(width: 24),
                            Expanded(
                                child: StatCard(
                              title: 'Top products',
                              value: '',
                              delta: '',
                              deltaUp: true,
                              icon: Icons.star_border,
                              iconBg: Colors.orange,
                            )),
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

  Widget _whiteButton(IconData icon, String label) {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: Icon(icon, color: Colors.black54, size: 18),
      label: Text(label, style: const TextStyle(color: Colors.black87)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }
}
