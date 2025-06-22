import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/top_nav_bar.dart';
import '../widgets/side_menu.dart';
import '../widgets/stat_card.dart';
import '../widgets/simple_chart_placeholder.dart';
import '../widgets/store_setup_dialog.dart';
import '../auth/auth_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    _checkStoreSetup();
  }

  Future<void> _checkStoreSetup() async {
    final ownerId = AuthService.instance.currentUser?.uid;
    if (ownerId == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('stores')
        .where('ownerId', isEqualTo: ownerId)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      final storeData = snap.docs.first.data();
      final status = storeData['status'] ?? '';

      if (status == 'setup_pending' && mounted) {
        // Show setup dialog
        final result = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => StoreSetupDialog(storeId: snap.docs.first.id),
        );

        // If setup was completed, refresh the page
        if (result == true && mounted) {
          setState(() {});
        }
      }
    }
  }

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
