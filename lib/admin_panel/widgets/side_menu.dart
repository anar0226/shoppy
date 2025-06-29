import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../pages/orders_page.dart';
import '../pages/products_page.dart';
import '../pages/dashboard_page.dart';
import '../pages/customers_page.dart';
import '../pages/analytics_page.dart';
import '../pages/collections_page.dart';
import '../pages/discounts_page.dart';
import '../pages/settings_page.dart';
import '../pages/storefront_page.dart';
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
          _navItem(context, Icons.home_outlined, 'Нүүр хуудас',
              selected: widget.selected == 'Нүүр хуудас', onTap: () {
            if (widget.selected != 'Нүүр хуудас') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const DashboardPage()),
              );
            }
          }),
          _navItem(context, Icons.shopping_cart_outlined, 'захиалгууд',
              selected: widget.selected == 'захиалгууд', onTap: () {
            if (widget.selected != 'захиалгууд') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const OrdersPage()),
              );
            }
          }),
          _navItem(context, Icons.inventory_2_outlined, 'Бүтээгдэхүүнүүд',
              selected: widget.selected == 'Бүтээгдэхүүнүүд', onTap: () {
            if (widget.selected != 'Бүтээгдэхүүнүүд') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const ProductsPage()),
              );
            }
          }),
          _navItem(context, Icons.people_outline, 'Үйлчлүүлэгчид',
              selected: widget.selected == 'Үйлчлүүлэгчид', onTap: () {
            if (widget.selected != 'Үйлчлүүлэгчид') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const CustomersPage()),
              );
            }
          }),
          _navItem(context, Icons.bar_chart_outlined, 'Аналитик',
              selected: widget.selected == 'Аналитик', onTap: () {
            if (widget.selected != 'Аналитик') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const AnalyticsPage()),
              );
            }
          }),
          _navItem(context, Icons.local_offer_outlined, 'Хөнгөлөлтийн код',
              selected: widget.selected == 'Хөнгөлөлтийн код', onTap: () {
            if (widget.selected != 'Хөнгөлөлтийн код') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const DiscountsPage()),
              );
            }
          }),
          _navItem(context, Icons.collections, 'Коллекц',
              selected: widget.selected == 'Коллекц', onTap: () {
            if (widget.selected != 'Коллекц') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const CollectionsPage()),
              );
            }
          }),
          _navItem(context, Icons.category, 'Бүтээгдэхүүний ангилал',
              selected: widget.selected == 'Бүтээгдэхүүний ангилал', onTap: () {
            if (widget.selected != 'Бүтээгдэхүүний ангилал') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const CategorizationPage()),
              );
            }
          }),
          _navItem(context, Icons.storefront, 'Дэлгүүр',
              selected: widget.selected == 'Дэлгүүр', onTap: () {
            if (widget.selected != 'Дэлгүүр') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const StorefrontPage()),
              );
            }
          }),
          const Spacer(),
          const Divider(height: 1),
          _navItem(context, Icons.settings_outlined, 'Тохиргоо',
              selected: widget.selected == 'Тохиргоо', onTap: () {
            if (widget.selected != 'Тохиргоо') {
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
