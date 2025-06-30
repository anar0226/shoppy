import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/theme/theme_provider.dart';
import 'auth/super_admin_auth_service.dart';
import 'auth/super_admin_login_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/stores_management_page.dart';
import 'pages/users_management_page.dart';
import 'pages/analytics_page.dart';
import 'pages/notifications_page.dart';
import 'pages/commission_management_page.dart';
import 'pages/settings_page.dart';
import 'pages/featured_stores_page.dart';
import 'pages/featured_products_page.dart';
import 'widgets/side_menu.dart';
import 'widgets/top_nav_bar.dart';

class SuperAdminApp extends StatelessWidget {
  const SuperAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (_, themeProvider, __) => MaterialApp(
          title: 'Shoppy Super Admin',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            fontFamily: 'Inter',
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          darkTheme: ThemeData.dark().copyWith(
            primaryColor: Colors.blue,
          ),
          themeMode: themeProvider.mode,
          home: const SuperAdminRoot(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}

class SuperAdminRoot extends StatefulWidget {
  const SuperAdminRoot({super.key});

  @override
  State<SuperAdminRoot> createState() => _SuperAdminRootState();
}

class _SuperAdminRootState extends State<SuperAdminRoot> {
  bool _isAuthenticated = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    try {
      final isAuth = await SuperAdminAuthService.instance.isAuthenticated();
      if (mounted) {
        setState(() {
          _isAuthenticated = isAuth;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isAuthenticated) {
      return SuperAdminLoginPage(
        onLoginSuccess: () {
          setState(() {
            _isAuthenticated = true;
          });
        },
      );
    }

    return const SuperAdminMainScreen();
  }
}

class SuperAdminMainScreen extends StatefulWidget {
  const SuperAdminMainScreen({super.key});

  @override
  State<SuperAdminMainScreen> createState() => _SuperAdminMainScreenState();
}

class _SuperAdminMainScreenState extends State<SuperAdminMainScreen> {
  String _currentPage = 'Dashboard';

  final Map<String, Widget> _pages = {
    'Dashboard': const DashboardPage(),
    'Analytics': const AnalyticsPage(),
    'Stores': const StoresManagementPage(),
    'FeaturedStores': const FeaturedStoresPage(),
    'FeaturedProducts': const FeaturedProductsPage(),
    'Users': const UsersManagementPage(),
    'Notifications': const NotificationsPage(),
    'Commission': const CommissionManagementPage(),
    'Settings': const SettingsPage(),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Side Menu
          SuperAdminSideMenu(
            currentPage: _currentPage,
            onPageSelected: (page) {
              setState(() {
                _currentPage = page;
              });
            },
          ),

          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top Navigation
                SuperAdminTopNavBar(title: _currentPage),

                // Page Content
                Expanded(
                  child: _pages[_currentPage] ?? const DashboardPage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Platform-wide statistics model
class PlatformStats {
  final int totalStores;
  final int activeStores;
  final int totalUsers;
  final int activeUsers;
  final int totalOrders;
  final double totalRevenue;
  final double platformCommission;
  final int notificationsSent;
  final double notificationSuccessRate;
  final Map<String, dynamic> topPerformingStores;
  final Map<String, dynamic> recentActivity;

  // New commission-specific fields
  final double pendingCommissions;
  final double paidCommissions;
  final int totalCommissionTransactions;
  final int pendingCommissionTransactions;
  final double averageCommissionPerTransaction;
  final List<Map<String, dynamic>> topEarningStores;

  PlatformStats({
    this.totalStores = 0,
    this.activeStores = 0,
    this.totalUsers = 0,
    this.activeUsers = 0,
    this.totalOrders = 0,
    this.totalRevenue = 0.0,
    this.platformCommission = 0.0,
    this.notificationsSent = 0,
    this.notificationSuccessRate = 0.0,
    this.topPerformingStores = const {},
    this.recentActivity = const {},
    // Commission fields
    this.pendingCommissions = 0.0,
    this.paidCommissions = 0.0,
    this.totalCommissionTransactions = 0,
    this.pendingCommissionTransactions = 0,
    this.averageCommissionPerTransaction = 0.0,
    this.topEarningStores = const [],
  });

  factory PlatformStats.fromMap(Map<String, dynamic> map) {
    return PlatformStats(
      totalStores: map['totalStores'] ?? 0,
      activeStores: map['activeStores'] ?? 0,
      totalUsers: map['totalUsers'] ?? 0,
      activeUsers: map['activeUsers'] ?? 0,
      totalOrders: map['totalOrders'] ?? 0,
      totalRevenue: (map['totalRevenue'] ?? 0).toDouble(),
      platformCommission: (map['platformCommission'] ?? 0).toDouble(),
      notificationsSent: map['notificationsSent'] ?? 0,
      notificationSuccessRate: (map['notificationSuccessRate'] ?? 0).toDouble(),
      topPerformingStores:
          Map<String, dynamic>.from(map['topPerformingStores'] ?? {}),
      recentActivity: Map<String, dynamic>.from(map['recentActivity'] ?? {}),
      // Commission fields
      pendingCommissions: (map['pendingCommissions'] ?? 0).toDouble(),
      paidCommissions: (map['paidCommissions'] ?? 0).toDouble(),
      totalCommissionTransactions: map['totalCommissionTransactions'] ?? 0,
      pendingCommissionTransactions: map['pendingCommissionTransactions'] ?? 0,
      averageCommissionPerTransaction:
          (map['averageCommissionPerTransaction'] ?? 0).toDouble(),
      topEarningStores:
          List<Map<String, dynamic>>.from(map['topEarningStores'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalStores': totalStores,
      'activeStores': activeStores,
      'totalUsers': totalUsers,
      'activeUsers': activeUsers,
      'totalOrders': totalOrders,
      'totalRevenue': totalRevenue,
      'platformCommission': platformCommission,
      'notificationsSent': notificationsSent,
      'notificationSuccessRate': notificationSuccessRate,
      'topPerformingStores': topPerformingStores,
      'recentActivity': recentActivity,
      // Commission fields
      'pendingCommissions': pendingCommissions,
      'paidCommissions': paidCommissions,
      'totalCommissionTransactions': totalCommissionTransactions,
      'pendingCommissionTransactions': pendingCommissionTransactions,
      'averageCommissionPerTransaction': averageCommissionPerTransaction,
      'topEarningStores': topEarningStores,
    };
  }

  // Helper getters for UI display
  String get formattedRevenue => '₮${totalRevenue.toStringAsFixed(2)}';
  String get formattedCommission => '₮${platformCommission.toStringAsFixed(2)}';
  String get successRatePercent =>
      '${notificationSuccessRate.toStringAsFixed(1)}%';

  // New commission helper getters
  String get formattedPendingCommissions =>
      '₮${pendingCommissions.toStringAsFixed(2)}';
  String get formattedPaidCommissions =>
      '₮${paidCommissions.toStringAsFixed(2)}';
  String get formattedAverageCommission =>
      '₮${averageCommissionPerTransaction.toStringAsFixed(2)}';
  double get commissionCollectionRate {
    if (totalCommissionTransactions == 0) return 0;
    return ((totalCommissionTransactions - pendingCommissionTransactions) /
            totalCommissionTransactions) *
        100;
  }

  String get collectionRatePercent =>
      '${commissionCollectionRate.toStringAsFixed(1)}%';

  double get storeGrowthRate {
    if (totalStores == 0) return 0;
    return (activeStores / totalStores) * 100;
  }

  double get userEngagementRate {
    if (totalUsers == 0) return 0;
    return (activeUsers / totalUsers) * 100;
  }
}
