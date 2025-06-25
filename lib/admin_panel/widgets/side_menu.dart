import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../pages/orders_page.dart';
import '../pages/products_page.dart';
import '../pages/dashboard_page.dart';
import '../pages/users_page.dart';
import '../pages/analytics_page.dart';
import '../pages/collections_page.dart';
import '../pages/discounts_page.dart';
import '../pages/settings_page.dart';
import '../pages/storefront_page.dart';
import '../pages/categories_page.dart';
import '../pages/categorization_page.dart';
import '../../features/settings/themes/app_themes.dart';
import '../auth/auth_service.dart';

class SideMenu extends StatefulWidget {
  final String selected;

  const SideMenu({super.key, this.selected = 'Home'});

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> {
  String _storeName = 'My Store';
  String _storePlan = 'Basic plan';

  @override
  void initState() {
    super.initState();
    _loadStoreInfo();
  }

  Future<void> _loadStoreInfo() async {
    final ownerId = AuthService.instance.currentUser?.uid;
    if (ownerId == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('stores')
          .where('ownerId', isEqualTo: ownerId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final storeData = snapshot.docs.first.data();
        setState(() {
          _storeName = storeData['name'] ?? 'My Store';
          _storePlan = storeData['plan'] ?? 'Basic plan';
        });
      }
    } catch (e) {
      // Handle error silently, keep default values
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 240,
      color: AppThemes.getSurfaceColor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          _storeHeader(context),
          const SizedBox(height: 8),
          _navItem(context, Icons.home_outlined, 'Home',
              selected: widget.selected == 'Home', onTap: () {
            if (widget.selected != 'Home') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const DashboardPage()),
              );
            }
          }),
          _navItem(context, Icons.shopping_cart_outlined, 'Orders',
              selected: widget.selected == 'Orders', onTap: () {
            if (widget.selected != 'Orders') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const OrdersPage()),
              );
            }
          }),
          _navItem(context, Icons.inventory_2_outlined, 'Products',
              selected: widget.selected == 'Products', onTap: () {
            if (widget.selected != 'Products') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const ProductsPage()),
              );
            }
          }),
          _navItem(context, Icons.people_outline, 'Customers',
              selected: widget.selected == 'Users', onTap: () {
            if (widget.selected != 'Users') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const UsersPage()),
              );
            }
          }),
          _navItem(context, Icons.bar_chart_outlined, 'Analytics',
              selected: widget.selected == 'Analytics', onTap: () {
            if (widget.selected != 'Analytics') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const AnalyticsPage()),
              );
            }
          }),
          _navItem(context, Icons.local_offer_outlined, 'Discounts',
              selected: widget.selected == 'Discounts', onTap: () {
            if (widget.selected != 'Discounts') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const DiscountsPage()),
              );
            }
          }),
          _navItem(context, Icons.collections, 'Collections',
              selected: widget.selected == 'Collections', onTap: () {
            if (widget.selected != 'Collections') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const CollectionsPage()),
              );
            }
          }),
          _navItem(context, Icons.category, 'Categorization',
              selected: widget.selected == 'Categorization', onTap: () {
            if (widget.selected != 'Categorization') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const CategorizationPage()),
              );
            }
          }),
          _navItem(context, Icons.storefront, 'Storefront',
              selected: widget.selected == 'Storefront', onTap: () {
            if (widget.selected != 'Storefront') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const StorefrontPage()),
              );
            }
          }),
          const Spacer(),
          const Divider(height: 1),
          _navItem(context, Icons.settings_outlined, 'Settings',
              selected: widget.selected == 'Settings', onTap: () {
            if (widget.selected != 'Settings') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            }
          }),
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
            child: Text(
                _storeName.isNotEmpty ? _storeName[0].toUpperCase() : 'S',
                style: const TextStyle(color: Colors.white, fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_storeName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppThemes.getTextColor(context),
                    ),
                    overflow: TextOverflow.ellipsis),
                Text(_storePlan,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppThemes.getSecondaryTextColor(context),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, IconData icon, String label,
      {bool selected = false, String? badge, VoidCallback? onTap}) {
    final itemContent = Row(
      children: [
        Icon(icon,
            size: 20,
            color: selected
                ? AppThemes.primaryColor
                : AppThemes.getSecondaryTextColor(context)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected
                      ? AppThemes.primaryColor
                      : AppThemes.getTextColor(context))),
        ),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppThemes.primaryColor,
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
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppThemes.darkCard
                  : Colors.grey.shade200,
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
