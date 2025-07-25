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
import '../pages/order_cleanup_page.dart';
import '../pages/subscription_page.dart';
import '../pages/store_payout_settings_page.dart';
import '../../features/settings/themes/app_themes.dart';
import '../auth/auth_service.dart';

class SideMenu extends StatefulWidget {
  final String selected;
  final Function(String)? onPageSelected;

  const SideMenu({
    super.key,
    this.selected = 'Home',
    this.onPageSelected,
  });

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> {
  String _storeName = 'My Store';
  String _storePlan = 'Avii.mn';

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
          _storePlan = storeData['plan'] ?? 'Avii.mn';
        });
      }
    } catch (e) {
      // Handle error silently, keep default values
    }
  }

  Future<void> _navigateToPayoutSettings(BuildContext context) async {
    final ownerId = AuthService.instance.currentUser?.uid;
    if (ownerId == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('stores')
          .where('ownerId', isEqualTo: ownerId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final storeId = snapshot.docs.first.id;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => StorePayoutSettingsPage(storeId: storeId),
          ),
        );
      }
    } catch (e) {
      // Handle error silently
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 240,
      color: Colors.white, // Pure white background
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          _storeHeader(context),
          const SizedBox(height: 8),
          _navItem(context, Icons.home_outlined, 'Нүүр хуудас',
              selected: widget.selected == 'Нүүр хуудас', onTap: () {
            if (widget.selected != 'Нүүр хуудас') {
              if (widget.onPageSelected != null) {
                widget.onPageSelected!('Нүүр хуудас');
              } else {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const DashboardPage()),
                );
              }
            }
          }),
          _navItem(context, Icons.shopping_cart_outlined, 'захиалгууд',
              selected: widget.selected == 'захиалгууд', onTap: () {
            if (widget.selected != 'захиалгууд') {
              if (widget.onPageSelected != null) {
                widget.onPageSelected!('захиалгууд');
              } else {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const OrdersPage()),
                );
              }
            }
          }),
          _navItem(context, Icons.inventory_2_outlined, 'Бүтээгдэхүүнүүд',
              selected: widget.selected == 'Бүтээгдэхүүнүүд', onTap: () {
            if (widget.selected != 'Бүтээгдэхүүнүүд') {
              if (widget.onPageSelected != null) {
                widget.onPageSelected!('Бүтээгдэхүүнүүд');
              } else {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const ProductsPage()),
                );
              }
            }
          }),
          _navItem(context, Icons.people_outline, 'Үйлчлүүлэгчид',
              selected: widget.selected == 'Үйлчлүүлэгчид', onTap: () {
            if (widget.selected != 'Үйлчлүүлэгчид') {
              if (widget.onPageSelected != null) {
                widget.onPageSelected!('Үйлчлүүлэгчид');
              } else {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const CustomersPage()),
                );
              }
            }
          }),
          _navItem(context, Icons.bar_chart_outlined, 'Аналитик',
              selected: widget.selected == 'Аналитик', onTap: () {
            if (widget.selected != 'Аналитик') {
              if (widget.onPageSelected != null) {
                widget.onPageSelected!('Аналитик');
              } else {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const AnalyticsPage()),
                );
              }
            }
          }),
          _navItem(context, Icons.payment, 'Төлбөр',
              selected: widget.selected == 'Төлбөр', onTap: () {
            if (widget.selected != 'Төлбөр') {
              if (widget.onPageSelected != null) {
                widget.onPageSelected!('Төлбөр');
              } else {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const SubscriptionPage()),
                );
              }
            }
          }),
          _navItem(context, Icons.account_balance_wallet, 'Төлбөрийн тохиргоо',
              selected: widget.selected == 'Төлбөрийн тохиргоо', onTap: () {
            if (widget.selected != 'Төлбөрийн тохиргоо') {
              if (widget.onPageSelected != null) {
                widget.onPageSelected!('Төлбөрийн тохиргоо');
              } else {
                _navigateToPayoutSettings(context);
              }
            }
          }),
          _navItem(context, Icons.local_offer_outlined, 'Хөнгөлөлтийн код',
              selected: widget.selected == 'Хөнгөлөлтийн код', onTap: () {
            if (widget.selected != 'Хөнгөлөлтийн код') {
              if (widget.onPageSelected != null) {
                widget.onPageSelected!('Хөнгөлөлтийн код');
              } else {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const DiscountsPage()),
                );
              }
            }
          }),
          _navItem(context, Icons.collections, 'Коллекц',
              selected: widget.selected == 'Коллекц', onTap: () {
            if (widget.selected != 'Коллекц') {
              if (widget.onPageSelected != null) {
                widget.onPageSelected!('Коллекц');
              } else {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const CollectionsPage()),
                );
              }
            }
          }),
          _navItem(context, Icons.category, 'Бүтээгдэхүүний ангилал',
              selected: widget.selected == 'Бүтээгдэхүүний ангилал', onTap: () {
            if (widget.selected != 'Бүтээгдэхүүний ангилал') {
              if (widget.onPageSelected != null) {
                widget.onPageSelected!('Бүтээгдэхүүний ангилал');
              } else {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const CategorizationPage()),
                );
              }
            }
          }),
          _navItem(context, Icons.storefront, 'Дэлгүүр',
              selected: widget.selected == 'Дэлгүүр', onTap: () {
            if (widget.selected != 'Дэлгүүр') {
              if (widget.onPageSelected != null) {
                widget.onPageSelected!('Дэлгүүр');
              } else {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const StorefrontPage()),
                );
              }
            }
          }),
          _navItem(context, Icons.cleaning_services, 'Захиалгын цэвэрлэлт',
              selected: widget.selected == 'Захиалгын цэвэрлэлт', onTap: () {
            if (widget.selected != 'Захиалгын цэвэрлэлт') {
              if (widget.onPageSelected != null) {
                widget.onPageSelected!('Захиалгын цэвэрлэлт');
              } else {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const OrderCleanupPage()),
                );
              }
            }
          }),
          const Spacer(),
          const Divider(height: 1),
          _navItem(context, Icons.settings_outlined, 'Тохиргоо',
              selected: widget.selected == 'Тохиргоо', onTap: () {
            if (widget.selected != 'Тохиргоо') {
              if (widget.onPageSelected != null) {
                widget.onPageSelected!('Тохиргоо');
              } else {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              }
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
