import 'package:flutter/material.dart';
import '../pages/orders_page.dart';
import '../pages/products_page.dart';
import '../pages/dashboard_page.dart';
import '../pages/customers_page.dart';
import '../pages/analytics_page.dart';
import '../pages/discounts_page.dart';

class SideMenu extends StatelessWidget {
  final String selected;

  const SideMenu({super.key, this.selected = 'Home'});

  @override
  Widget build(BuildContext context) {
    final labelStyle =
        Theme.of(context).textTheme.bodyMedium!.copyWith(color: Colors.black87);

    return Container(
      width: 240,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          _storeHeader(context),
          const SizedBox(height: 8),
          _navItem(Icons.home_outlined, 'Home', selected: selected == 'Home',
              onTap: () {
            if (selected != 'Home') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const DashboardPage()),
              );
            }
          }),
          _navItem(Icons.shopping_cart_outlined, 'Orders',
              badge: '3', selected: selected == 'Orders', onTap: () {
            if (selected != 'Orders') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const OrdersPage()),
              );
            }
          }),
          _navItem(Icons.inventory_2_outlined, 'Products',
              selected: selected == 'Products', onTap: () {
            if (selected != 'Products') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const ProductsPage()),
              );
            }
          }),
          _navItem(Icons.people_outline, 'Customers',
              selected: selected == 'Customers', onTap: () {
            if (selected != 'Customers') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const CustomersPage()),
              );
            }
          }),
          _navItem(Icons.bar_chart_outlined, 'Analytics',
              selected: selected == 'Analytics', onTap: () {
            if (selected != 'Analytics') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const AnalyticsPage()),
              );
            }
          }),
          _navItem(Icons.local_offer_outlined, 'Discounts',
              selected: selected == 'Discounts', onTap: () {
            if (selected != 'Discounts') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const DiscountsPage()),
              );
            }
          }),
          const Spacer(),
          const Divider(height: 1),
          _navItem(Icons.settings_outlined, 'Settings',
              selected: selected == 'Settings'),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _storeHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Text('S',
                style: TextStyle(color: Colors.white, fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('My Store', style: TextStyle(fontWeight: FontWeight.w600)),
              Text('Basic plan',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label,
      {bool selected = false, String? badge, VoidCallback? onTap}) {
    final itemContent = Row(
      children: [
        Icon(icon, size: 20, color: selected ? Colors.green : Colors.black45),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? Colors.green : Colors.black87)),
        ),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(badge,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
      ],
    );

    final navItem = Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: selected
          ? BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: itemContent,
      ),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: navItem,
    );
  }
}
