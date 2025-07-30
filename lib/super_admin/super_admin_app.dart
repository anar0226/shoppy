import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/theme/theme_provider.dart';
import 'auth/super_admin_auth_service.dart';
import 'auth/super_admin_login_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/stores_management_page.dart';
import 'pages/featured_stores_page.dart';
import 'pages/featured_products_page.dart';
import 'pages/featured_brands_page.dart';
import 'pages/payment_management_page.dart';
import 'pages/backup_management_page.dart';
import 'pages/settings_page.dart';
import 'widgets/side_menu.dart';
import 'widgets/top_nav_bar.dart';
import '../core/services/error_handler_service.dart';

class SuperAdminApp extends StatelessWidget {
  const SuperAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('SuperAdmin: Building SuperAdminApp');

    try {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: Consumer<ThemeProvider>(
          builder: (_, themeProvider, __) {
            debugPrint('SuperAdmin: Building MaterialApp');
            return MaterialApp(
              title: 'Avii.mn Super Admin',
              theme: ThemeData(
                primarySwatch: Colors.blue,
                primaryColor: const Color(0xFF0053A3),
                fontFamily: 'Inter',
                visualDensity: VisualDensity.adaptivePlatformDensity,
              ),
              darkTheme: ThemeData.dark().copyWith(
                primaryColor: const Color(0xFF0053A3),
              ),
              themeMode: themeProvider.mode,
              home: const SuperAdminRoot(),
              debugShowCheckedModeBanner: false,
            );
          },
        ),
      );
    } catch (e) {
      debugPrint('SuperAdmin: Error building SuperAdminApp: $e');
      return MaterialApp(
        title: 'Avii.mn Super Admin - Error',
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error initializing Super Admin: $e',
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    debugPrint('SuperAdmin: Initializing...');
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    try {
      debugPrint('SuperAdmin: Checking authentication...');
      final isAuth = await SuperAdminAuthService.instance.isAuthenticated();
      debugPrint('SuperAdmin: Authentication result: $isAuth');

      if (mounted) {
        setState(() {
          _isAuthenticated = isAuth;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('SuperAdmin: Authentication error: $e');
      await ErrorHandlerService.instance.handleError(
        operation: 'super_admin_authentication_check',
        error: e,
        showUserMessage: false,
        logError: true,
        fallbackValue: null,
      );
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _isLoading = false;
          _errorMessage = 'Authentication check failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        'SuperAdmin: Building root widget. Loading: $_isLoading, Authenticated: $_isAuthenticated');

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading Super Admin...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error: $_errorMessage',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _checkAuthentication();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isAuthenticated) {
      debugPrint('SuperAdmin: Showing login page');
      return SuperAdminLoginPage(
        onLoginSuccess: () {
          debugPrint('SuperAdmin: Login successful');
          setState(() {
            _isAuthenticated = true;
          });
        },
      );
    }

    debugPrint('SuperAdmin: Showing main screen');
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
    'Stores': const StoresManagementPage(),
    'FeaturedStores': const FeaturedStoresPage(),
    'FeaturedProducts': const FeaturedProductsPage(),
    'FeaturedBrands': const FeaturedBrandsPage(),
    'Payment': const PaymentManagementPage(),
    'Backup Management': const BackupManagementPage(),
    'Settings': const SettingsPage(),
  };

  @override
  void initState() {
    super.initState();
    debugPrint('SuperAdmin: Main screen initialized');
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('SuperAdmin: Building main screen with page: $_currentPage');

    try {
      return Scaffold(
        body: Row(
          children: [
            // Side Menu
            SuperAdminSideMenu(
              currentPage: _currentPage,
              onPageSelected: (page) {
                debugPrint('SuperAdmin: Page selected: $page');
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
    } catch (e) {
      debugPrint('SuperAdmin: Error building main screen: $e');
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading Super Admin: $e',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
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
    };
  }

  // Helper getters for UI display
  String get formattedRevenue => '₮${totalRevenue.toStringAsFixed(2)}';
  String get formattedCommission => '₮${platformCommission.toStringAsFixed(2)}';
  String get successRatePercent =>
      '${notificationSuccessRate.toStringAsFixed(1)}%';

  double get storeGrowthRate {
    if (totalStores == 0) return 0;
    return (activeStores / totalStores) * 100;
  }

  double get userEngagementRate {
    if (totalUsers == 0) return 0;
    return (activeUsers / totalUsers) * 100;
  }
}
