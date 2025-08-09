import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/side_menu.dart';
import '../widgets/top_nav_bar.dart';
import '../auth/auth_service.dart';
import 'dashboard_page.dart';
import 'orders_page.dart';
import 'products_page.dart';
import 'customers_page.dart';
import 'analytics_page.dart';

import 'discounts_page.dart';
import 'collections_page.dart';
import 'categorization_page.dart';
import 'storefront_page.dart';
import 'order_cleanup_page.dart';
import 'settings_page.dart';
import 'store_payout_settings_page.dart';

class AdminPanelLayout extends StatefulWidget {
  final String initialPage;

  const AdminPanelLayout({
    super.key,
    this.initialPage = 'Нүүр хуудас',
  });

  @override
  State<AdminPanelLayout> createState() => _AdminPanelLayoutState();
}

class _AdminPanelLayoutState extends State<AdminPanelLayout> {
  String _currentPage = 'Нүүр хуудас';
  String? _storeId;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _loadStoreId();
  }

  Future<void> _loadStoreId() async {
    try {
      final ownerId = AuthService.instance.currentUser?.uid;
      if (ownerId == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('stores')
          .where('ownerId', isEqualTo: ownerId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          _storeId = snapshot.docs.first.id;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  void _navigateToPage(String page) {
    setState(() {
      _currentPage = page;
    });
  }

  Widget _getCurrentPage() {
    switch (_currentPage) {
      case 'Нүүр хуудас':
        return const DashboardPage();
      case 'захиалгууд':
        return const OrdersPage();
      case 'Бүтээгдэхүүнүүд':
        return const ProductsPage();
      case 'Үйлчлүүлэгчид':
        return const CustomersPage();
      case 'Аналитик':
        return const AnalyticsPage();

      case 'Хөнгөлөлтийн код':
        return const DiscountsPage();
      case 'Коллекц':
        return const CollectionsPage();
      case 'Бүтээгдэхүүний ангилал':
        return const CategorizationPage();
      case 'Дэлгүүр':
        return const StorefrontPage();
      case 'Захиалгын цэвэрлэлт':
        return const OrderCleanupPage();
      case 'Төлбөрийн тохиргоо':
        return _buildPayoutSettingsPage();
      case 'Тохиргоо':
        return const SettingsPage();
      default:
        return const DashboardPage();
    }
  }

  Widget _buildPayoutSettingsPage() {
    if (_storeId == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    return StorePayoutSettingsPage(storeId: _storeId!);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 1100;

    // Check if the current page needs navigation wrapper
    if (_needsNavigationWrapper(_currentPage)) {
      // Return the page directly (it has its own navigation)
      return _getCurrentPage();
    } else {
      // Apply navigation wrapper for pages that don't have it
      if (!isCompact) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: Row(
            children: [
              SideMenu(
                selected: _currentPage,
                onPageSelected: _navigateToPage,
              ),
              Expanded(
                child: Column(
                  children: [
                    TopNavBar(title: _currentPage),
                    Expanded(
                      child: _getCurrentPage(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      } else {
        // Compact layout: use Drawer
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: const Color(0xFF4285F4),
            elevation: 0,
            title: Text(
              _currentPage,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          drawer: Drawer(
            width: 280,
            child: SafeArea(
              child: SideMenu(
                selected: _currentPage,
                onPageSelected: (p) {
                  Navigator.of(context).pop();
                  _navigateToPage(p);
                },
              ),
            ),
          ),
          body: _getCurrentPage(),
        );
      }
    }
  }

  bool _needsNavigationWrapper(String pageName) {
    // Pages that already have their own navigation structure
    const pagesWithNavigation = [
      'Нүүр хуудас',
      'захиалгууд',
      'Бүтээгдэхүүнүүд',
      'Үйлчлүүлэгчид',
      'Аналитик',
      'Хөнгөлөлтийн код',
      'Коллекц',
      'Бүтээгдэхүүний ангилал',
      'Дэлгүүр',
      'Захиалгын цэвэрлэлт',
      'Тохиргоо',
    ];

    return pagesWithNavigation.contains(pageName);
  }
}
