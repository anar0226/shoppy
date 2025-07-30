import 'package:flutter/material.dart';
import 'features/home/presentation/home_screen.dart' as front_home;
import 'features/stores/presentation/store_screen.dart';
import 'features/home/presentation/main_scaffold.dart';
import 'package:avii/features/Profile/profile_page.dart';
import 'package:provider/provider.dart';
import 'features/cart/providers/cart_provider.dart';
import 'package:avii/features/profile/providers/recently_viewed_provider.dart';
import 'package:avii/features/theme/theme_provider.dart';
import 'package:avii/features/addresses/providers/address_provider.dart';
import 'package:avii/features/auth/providers/auth_provider.dart';
import 'package:avii/features/auth/presentation/splash_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:avii/features/products/models/product_model.dart';
import 'package:avii/features/stores/models/store_model.dart';
import 'features/saved/saved_screen.dart';
import 'features/orders/presentation/order_tracking_page.dart';
import 'search/women/women_category_page.dart';
import 'search/men/men_category_page.dart';
import 'features/categories/presentation/accessories_category_page.dart';
import 'features/categories/presentation/beauty_category_page.dart';

import 'features/notifications/fcm_service.dart';
import 'features/products/presentation/product_page.dart';
import 'core/utils/type_utils.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'features/reviews/widgets/review_submission_dialog.dart';

import 'core/utils/popup_utils.dart';
import 'features/auth/presentation/profile_completion_page.dart';
import 'features/support/support_contact_page.dart';
import 'bootstrap.dart' as boot;
import 'core/widgets/paginated_firestore_list.dart';
import 'core/providers/connectivity_provider.dart';
import 'core/services/error_handler_service.dart';

void main() => boot.bootstrap();

class ShopUBApp extends StatefulWidget {
  const ShopUBApp({super.key});

  @override
  State<ShopUBApp> createState() => _ShopUBAppState();
}

class _ShopUBAppState extends State<ShopUBApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initializeFCM();
  }

  Future<void> _initializeFCM() async {
    await FCMService().initialize(
      onNotificationTap: _handleNotificationNavigation,
    );
  }

  void _handleNotificationNavigation(
      String route, Map<String, dynamic>? arguments) {
    final context = _navigatorKey.currentContext;
    if (context == null) return;

    switch (route) {
      case '/product':
        final productId = arguments?['productId'] as String?;
        if (productId != null) {
          _navigateToProduct(context, productId);
        }
        break;
      case '/orders':
        Navigator.pushNamed(context, '/orders');
        break;
      case '/offers':
        // Navigate to offers page when implemented
        Navigator.pushNamed(context, '/home');
        break;
      default:
        Navigator.pushNamed(context, '/home');
    }
  }

  Future<void> _navigateToProduct(
      BuildContext context, String productId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get();

      if (doc.exists) {
        final product = ProductModel.fromFirestore(doc);
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductPage(
                product: product,
                storeName: 'Store',
                storeLogoUrl: '',
                storeRating: 5.0,
                storeRatingCount: 0,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        await ErrorHandlerService.instance.handleError(
          operation: 'navigate_to_product',
          error: e,
          showUserMessage: true,
          fallbackValue: null,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RecentlyViewedProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AddressProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (_, themeProvider, __) => MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'Avii.mn',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            primaryColor: const Color(0xFF0053A3),
            fontFamily: 'Roboto',
          ),
          darkTheme:
              ThemeData.dark().copyWith(primaryColor: const Color(0xFF0053A3)),
          themeMode: themeProvider.mode,
          home: const SplashRouter(),
          routes: {
            '/home': (_) => const front_home.HomeScreen(),
            '/search': (_) => const SearchScreen(),
            '/orders': (_) => const OrdersScreen(),
            '/account': (_) => const ProfilePage(),
            '/saved': (_) => const SavedScreen(),
            '/profile-completion': (_) => const ProfileCompletionPage(),
            '/support': (_) => const SupportContactPage(),
          },
          onGenerateRoute: (settings) {
            // Handle store routes
            if (settings.name != null && settings.name!.startsWith('/store/')) {
              // Store routes now handled by Firestore data in the app
              // This fallback should not be needed in production
              return MaterialPageRoute(
                builder: (context) => Scaffold(
                  appBar: AppBar(title: const Text('Store not found')),
                  body: const Center(
                    child: Text('Store route handling moved to Firestore'),
                  ),
                ),
              );
            }

            // Handle product routes
            if (settings.name != null &&
                settings.name!.startsWith('/product/')) {
              final productId = settings.name!.split('/')[2];
              return MaterialPageRoute(
                builder: (context) =>
                    _ProductRouteHandler(productId: productId),
              );
            }

            return null;
          },
        ),
      ),
    );
  }
}

class _ProductRouteHandler extends StatelessWidget {
  final String productId;

  const _ProductRouteHandler({required this.productId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('Бүтээгдэхүүн олдсонгүй')),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Бүтээгдэхүүн олдсонгүй',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Таньд хайж байгаа бүтээгдэхүүн олдсонгүй.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        try {
          final product = ProductModel.fromFirestore(snapshot.data!);
          return ProductPage(
            product: product,
            storeName: 'Store',
            storeLogoUrl: '',
            storeRating: 5.0,
            storeRatingCount: 0,
          );
        } catch (e) {
          return Scaffold(
            appBar: AppBar(title: const Text('Алдаа')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Бүтээгдэхүүнийг олох явцад алдаа гарлаа',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Алдаа: ${e.toString()}',
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'Бүгд'; // All

  // Search filters
  final List<String> _filters = ['Бүгд', 'Бүтээгдэхүүн', 'Дэлгүүр'];

  // Category data matching the screenshot
  final List<CategoryItem> categories = [
    CategoryItem(
      name: 'Эмэгтэй',
      imageUrl: 'assets/images/categories/Women/women.jpg',
      color: const Color(0xFF2D8A47),
    ),
    CategoryItem(
      name: 'Эрэгтэй',
      imageUrl: 'assets/images/categories/Men/men.jpg',
      color: const Color(0xFFD97841),
    ),
    CategoryItem(
      name: 'Гоо сайхан',
      imageUrl: 'assets/images/categories/Beauty/makeup.jpg',
      color: const Color(0xFFFF69B4),
    ),
    CategoryItem(
      name: 'Хоол хүнс, ундаа',
      imageUrl:
          'https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=400',
      color: const Color(0xFFB8A082),
    ),
    CategoryItem(
      name: 'Гэр аxуй',
      imageUrl:
          'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=400',
      color: const Color(0xFF8B9B8A),
    ),
    CategoryItem(
      name: 'Фитнесс',
      imageUrl:
          'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400',
      color: const Color(0xFF6B9BD1),
    ),
    CategoryItem(
      name: 'Аксессуары',
      imageUrl: 'assets/images/categories/Accessories/accessories.jpg',
      color: const Color.fromARGB(255, 0, 255, 81),
    ),
    CategoryItem(
      name: 'Амьтдын бүтээгдэхүүн',
      imageUrl:
          'https://images.unsplash.com/photo-1601758228041-f3b2795255f1?w=400',
      color: const Color(0xFFD2B48C),
    ),
    CategoryItem(
      name: 'Тоглоомнууд',
      imageUrl: 'assets/images/categories/Toys&games/toys and games.jpg',
      color: const Color(0xFF6A5ACD),
    ),
    CategoryItem(
      name: 'Цахилгаан бараа',
      imageUrl: 'assets/images/categories/electronics/electronics.jpg',
      color: const Color(0xFF2F2F2F),
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // === Search helpers for paginator ===
  bool _matchesProductSearch(ProductModel p) {
    final term = _searchQuery.toLowerCase();
    if (term.isEmpty) return false;
    return p.name.toLowerCase().contains(term) ||
        p.category.toLowerCase().contains(term);
  }

  bool _matchesStoreSearch(StoreModel s) {
    final term = _searchQuery.toLowerCase();
    if (term.isEmpty) return false;
    return s.name.toLowerCase().contains(term) ||
        s.description.toLowerCase().contains(term);
  }

  // Lightweight search: just update query; paginator handles fetching.
  void _performSearch(String query) {
    setState(() {
      _searchQuery = query.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      currentIndex: 1,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: SafeArea(
          child: Column(
            children: [
              // Search Bar
              _buildSearchBar(),

              // Search Filters (only show when searching)
              if (_searchQuery.isNotEmpty) _buildSearchFilters(),

              // Content - either search results or categories
              Expanded(
                child: _searchQuery.isEmpty
                    ? _buildCategoriesGrid()
                    : _buildSearchResults(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Бүтээгдэхүүн, дэлгүүр хайх...',
          hintStyle: const TextStyle(
            color: Colors.grey,
            fontSize: 16,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: Colors.grey,
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    _performSearch('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onChanged: (value) {
          _performSearch(value);
        },
        onSubmitted: (value) {
          _performSearch(value);
        },
      ),
    );
  }

  Widget _buildSearchFilters() {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = filter;
              });
              _performSearch(_searchQuery);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.black : Colors.grey.shade300,
                ),
              ),
              child: Center(
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchQuery.isEmpty) {
      return const SizedBox.shrink();
    }

    Widget empty() => Center(
          child: Text('"$_searchQuery" хайлтаар илэрц олдсонгүй'),
        );

    if (_selectedFilter == 'Дэлгүүр') {
      return PaginatedFirestoreList<DocumentSnapshot>(
        query: FirebaseFirestore.instance
            .collection('stores')
            .where('status', isEqualTo: 'active')
            .orderBy('createdAt', descending: true),
        pageSize: 20,
        fromDoc: (doc) => doc,
        emptyBuilder: (_) => empty(),
        itemBuilder: (ctx, doc) {
          final store = StoreModel.fromFirestore(doc);
          if (!_matchesStoreSearch(store)) return const SizedBox.shrink();
          final result = SearchResult(
            id: store.id,
            title: store.name,
            subtitle:
                'Дэлгүүр • ${store.description.isNotEmpty ? store.description : 'Онлайн дэлгүүр'}',
            imageUrl: store.logo.isNotEmpty ? store.logo : store.banner,
            type: SearchResultType.store,
            data: store,
          );
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: _buildSearchResultCard(result),
          );
        },
      );
    }

    // Products (default)
    return PaginatedFirestoreList<DocumentSnapshot>(
      query: FirebaseFirestore.instance
          .collection('products')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true),
      pageSize: 20,
      fromDoc: (doc) => doc,
      emptyBuilder: (_) => empty(),
      itemBuilder: (ctx, doc) {
        final product = ProductModel.fromFirestore(doc);
        if (!_matchesProductSearch(product)) return const SizedBox.shrink();
        final result = SearchResult(
          id: product.id,
          title: product.name,
          subtitle: 'Бүтээгдэхүүн • ₮${product.price.toStringAsFixed(0)}',
          imageUrl: product.images.isNotEmpty ? product.images.first : '',
          type: SearchResultType.product,
          data: product,
        );
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: _buildSearchResultCard(result),
        );
      },
    );
  }

  Widget _buildSearchResultCard(SearchResult result) {
    return GestureDetector(
      onTap: () => _handleSearchResultTap(result),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 60,
                height: 60,
                child: result.imageUrl.isNotEmpty
                    ? Image.network(
                        result.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade200,
                            child: Icon(
                              result.type == SearchResultType.product
                                  ? Icons.inventory_2
                                  : Icons.store,
                              color: Colors.grey,
                            ),
                          );
                        },
                      )
                    : Container(
                        color: Colors.grey.shade200,
                        child: Icon(
                          result.type == SearchResultType.product
                              ? Icons.inventory_2
                              : Icons.store,
                          color: Colors.grey,
                        ),
                      ),
              ),
            ),

            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result.subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Arrow
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  void _handleSearchResultTap(SearchResult result) {
    if (result.type == SearchResultType.product) {
      final product = result.data as ProductModel;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductPage(
            product: product,
            storeName: 'Store',
            storeLogoUrl: '',
            storeRating: 5.0,
            storeRatingCount: 0,
          ),
        ),
      );
    } else if (result.type == SearchResultType.store) {
      final store = result.data as StoreModel;
      _navigateToStore(store);
    }
  }

  Future<void> _navigateToStore(StoreModel store) async {
    try {
      final db = FirebaseFirestore.instance;

      // Fetch products for this store
      final productsQuery = await db
          .collection('products')
          .where('storeId', isEqualTo: store.id)
          .where('isActive', isEqualTo: true)
          .limit(20)
          .get();

      final products = productsQuery.docs
          .map((doc) => ProductModel.fromFirestore(doc))
          .toList();

      // Navigate to store page
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StoreScreen(
              storeData: StoreData(
                id: store.id,
                name: store.name,
                displayName: store.name.toUpperCase(),
                heroImageUrl:
                    store.banner.isNotEmpty ? store.banner : store.logo,
                backgroundColor: const Color(0xFF01BCE7),
                rating: 4.9,
                reviewCount: '25',
                collections: const [],
                categories: const ['All'],
                productCount: products.length,
                products: products
                    .map((p) => StoreProduct(
                          id: p.id,
                          name: p.name,
                          imageUrl: p.images.isNotEmpty ? p.images.first : '',
                          price: p.price,
                        ))
                    .toList(),
                showFollowButton: true,
                hasNotification: false,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        PopupUtils.showError(
          context: context,
          message: 'Дэлгүүр нээхэд алдаа гарлаа: $e',
        );
      }
    }
  }

  Widget _buildCategoriesGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.8,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          return _buildCategoryCard(categories[index]);
        },
      ),
    );
  }

  Widget _buildCategoryCard(CategoryItem category) {
    return GestureDetector(
      onTap: () {
        if (category.name == 'Эмэгтэй') {
          // Women in Mongolian
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WomenCategoryPage()),
          );
        } else if (category.name == 'Эрэгтэй') {
          // Men in Mongolian
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MenCategoryPage()),
          );
        } else if (category.name == 'Аксессуары') {
          // Accessories in Mongolian
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AccessoriesCategoryPage()),
          );
        } else if (category.name == 'Гоо сайхан') {
          // Beauty in Mongolian
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BeautyCategoryPage()),
          );
        } else {
          PopupUtils.showInfo(
            context: context,
            message: '${category.name} удахгүй!',
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background Image
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: category.imageUrl.startsWith('assets/')
                  ? Image.asset(
                      category.imageUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: category.color,
                          width: double.infinity,
                          height: double.infinity,
                        );
                      },
                    )
                  : Image.network(
                      category.imageUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: category.color,
                          width: double.infinity,
                          height: double.infinity,
                        );
                      },
                    ),
            ),

            // Overlay
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    category.color.withValues(alpha: 0.3),
                    category.color.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),

            // Category Name
            Positioned(
              left: 16,
              bottom: 16,
              child: Text(
                category.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Category data model
class CategoryItem {
  final String name;
  final String imageUrl;
  final Color color;

  CategoryItem({
    required this.name,
    required this.imageUrl,
    required this.color,
  });
}

// Search result models
enum SearchResultType {
  product,
  store,
}

class SearchResult {
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final SearchResultType type;
  final dynamic data;

  SearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.type,
    required this.data,
  });
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  // Helper: check if an order matches current search query
  bool _matchesSearch(QueryDocumentSnapshot doc) {
    if (_searchQuery.isEmpty) return true;
    final data = doc.data() as Map<String, dynamic>;
    final orderId = doc.id.toLowerCase();
    final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
    final searchLower = _searchQuery.toLowerCase();
    if (orderId.contains(searchLower)) return true;
    for (final item in items) {
      final productName = (item['name'] ?? '').toString().toLowerCase();
      if (productName.contains(searchLower)) return true;
    }
    return false;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return MainScaffold(
      currentIndex: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              if (_isSearching) _buildSearchBar(),
              Expanded(
                child: auth.user == null
                    ? const Center(
                        child: Text('Нэвтэрч орж захиалгын жагсаалтыг үзэх'))
                    : PaginatedFirestoreList<QueryDocumentSnapshot>(
                        query: FirebaseFirestore.instance
                            .collection('users')
                            .doc(auth.user!.uid)
                            .collection('orders')
                            .orderBy('createdAt', descending: true),
                        pageSize: 20,
                        fromDoc: (doc) => doc as QueryDocumentSnapshot,
                        emptyBuilder: (ctx) => _searchQuery.isEmpty
                            ? _buildEmptyState()
                            : _buildNoSearchResults(),
                        itemBuilder: (ctx, order) {
                          if (!_matchesSearch(order)) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(
                                left: 16, right: 16, bottom: 16),
                            child: _buildOrderCard(ctx, order),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 40), // Spacer for centering
          const Text(
            'Миний захиалга',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _searchController.clear();
                      _searchQuery = '';
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isSearching ? Colors.blue.shade50 : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isSearching ? Icons.close : Icons.search,
                    size: 20,
                    color: _isSearching ? Colors.blue.shade700 : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  PopupUtils.showInfo(
                    context: context,
                    message: 'Нэмэлт сонголт!',
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.more_horiz,
                    size: 20,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: const InputDecoration(
          hintText: 'Захиалга хайх (дугаар, бүтээгдэхүүний нэр)...',
          prefixIcon: Icon(Icons.search, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        autofocus: true,
      ),
    );
  }

  Widget _buildNoSearchResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'Хайлтад тохирох захиалга олдсонгүй',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Өөр түлхүүр үг ашиглан дахин оролдоно уу',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 80,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Захиалга байхгүй байна',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Таны захиалсан бараанууд энд харагдана',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, QueryDocumentSnapshot order) {
    final data = order.data() as Map<String, dynamic>;
    final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
    final storeId = TypeUtils.extractStoreId(data['storeId']);
    final status = data['status'] as String? ?? 'placed';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Store header with status
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('stores')
                .doc(storeId)
                .get(),
            builder: (context, storeSnap) {
              String storeName = 'Дэлгүүр';
              String storeImage = '';

              if (storeSnap.hasData && storeSnap.data!.exists) {
                final storeData =
                    storeSnap.data!.data() as Map<String, dynamic>;
                storeName = storeData['name'] ?? 'Дэлгүүр';
                storeImage = storeData['logo'] ?? storeData['banner'] ?? '';
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFF0F0F0)),
                  ),
                ),
                child: Row(
                  children: [
                    // Store profile picture (square format)
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey.shade200,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: storeImage.isNotEmpty
                            ? Image.network(
                                storeImage,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.store,
                                    color: Colors.grey.shade600,
                                    size: 20,
                                  );
                                },
                              )
                            : Icon(
                                Icons.store,
                                color: Colors.grey.shade600,
                                size: 20,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Store name and order info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            storeName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${items.length} зүйл • ${_getStatusText(status)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // More options
                    GestureDetector(
                      onTap: () => _showOrderOptions(context, order, storeName),
                      child: const Icon(
                        Icons.more_horiz,
                        color: Colors.grey,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Products list
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              color: Color(0xFFF0F0F0),
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildProductItem(context, item, order.id, storeId, order);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem(BuildContext context, Map<String, dynamic> item,
      String orderId, String storeId, QueryDocumentSnapshot order) {
    final productName = item['name'] ?? 'Бүтээгдэхүүн';
    final price = TypeUtils.safeCastDouble(item['price'], defaultValue: 0.0);
    final quantity = TypeUtils.safeCastInt(item['quantity'], defaultValue: 1);
    final variant = item['variant'] ?? '';
    final imageUrl = item['imageUrl'] ?? '';
    final productId = item['productId'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade100,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.inventory_2,
                          color: Colors.grey,
                          size: 30,
                        );
                      },
                    )
                  : const Icon(
                      Icons.inventory_2,
                      color: Colors.grey,
                      size: 30,
                    ),
            ),
          ),

          const SizedBox(width: 16),

          // Product details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Price and variant on same line
                Row(
                  children: [
                    Text(
                      '₮${price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    if (variant.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      const Text('•', style: TextStyle(color: Colors.grey)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          variant,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),

                if (quantity > 1) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Тоо ширхэг: $quantity',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                const SizedBox(height: 8),

                // Action buttons
                Row(
                  children: [
                    // Track Order button
                    GestureDetector(
                      onTap: () => _navigateToOrderTracking(context, order),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.track_changes,
                              size: 16,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Хянах',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Review button
                    GestureDetector(
                      onTap: () => _navigateToReview(
                          context, productId, orderId, storeId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Үнэлгээ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderOptions(
      BuildContext context, QueryDocumentSnapshot order, String storeName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Refund policy option
            ListTile(
              leading: const Icon(Icons.policy, color: Colors.black87),
              title: const Text('Буцаалт, Солилт'),
              onTap: () {
                Navigator.pop(context);
                _showRefundPolicy(context, order);
              },
            ),

            // Report issue option
            ListTile(
              leading: const Icon(Icons.report_problem, color: Colors.orange),
              title: const Text('Асуудал мэдэгдэх'),
              onTap: () {
                Navigator.pop(context);
                _showReportIssue(context, order);
              },
            ),

            // Delete order option
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Захиалга устгах'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteOrderConfirmation(context, order);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToOrderTracking(
      BuildContext context, QueryDocumentSnapshot order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderTrackingPage(order: order),
      ),
    );
  }

  void _showRefundPolicy(BuildContext context,
      [QueryDocumentSnapshot? order]) async {
    String? storeId;

    // Get store ID from order if provided, otherwise use a recent order
    if (order != null) {
      final orderData = order.data() as Map<String, dynamic>;
      storeId = orderData['storeId'] as String?;
    } else {
      // Get the store ID from a recent order
      final auth = context.read<AuthProvider>();
      if (auth.user != null) {
        try {
          final orderSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(auth.user!.uid)
              .collection('orders')
              .orderBy('createdAt', descending: true)
              .limit(1)
              .get();

          // Check if widget is still mounted after async operation
          if (!mounted) return;

          if (orderSnapshot.docs.isNotEmpty) {
            final orderData = orderSnapshot.docs.first.data();
            storeId = TypeUtils.extractStoreId(orderData['storeId']);
          }
        } catch (e) {
          // Fallback to generic policy
          if (!mounted) return;
        }
      }
    }

    if (storeId == null || storeId.isEmpty) {
      if (!context.mounted) return;
      _showGenericRefundPolicy(context);
      return;
    }

    try {
      // Fetch store's refund policy
      final storeDoc = await FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .get();

      // Check if widget is still mounted after async operation
      if (!context.mounted) return;

      if (!storeDoc.exists) {
        if (context.mounted) {
          _showGenericRefundPolicy(context);
        }
        return;
      }

      final storeData = storeDoc.data() as Map<String, dynamic>;
      final storeName = storeData['name'] as String? ?? 'Дэлгүүр';
      final refundPolicy = storeData['refundPolicy'] as String? ?? '';

      if (refundPolicy.isEmpty) {
        if (context.mounted) {
          _showGenericRefundPolicy(context);
        }
        return;
      }

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('$storeName-ийн буцаалт, солилт'),
            content: SingleChildScrollView(
              child: Text(
                refundPolicy,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Ойлголоо'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      _showGenericRefundPolicy(context);
    }
  }

  void _showGenericRefundPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Буцаах бодлого'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ерөнхий буцаах бодлого:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text(
                  '• Захиалга хүлээн авснаас хойш 7 хоногийн дотор буцаах боломжтой'),
              SizedBox(height: 8),
              Text(
                  '• Бараа эх байдлаараа байх ёстой (хэрэглээгүй, хуванцар боолттой)'),
              SizedBox(height: 8),
              Text(
                  '• Хувийн хэрэглээний бараа (гоо сайхны бүтээгдэхүүн) буцаах боломжгүй'),
              SizedBox(height: 8),
              Text('• Буцаах зардлыг худалдан авагч хариуцна'),
              SizedBox(height: 8),
              Text('• Мөнгийг 3-5 ажлын өдрийн дотор буцаан олгоно'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ойлголоо'),
          ),
        ],
      ),
    );
  }

  void _showReportIssue(BuildContext context, QueryDocumentSnapshot order) {
    final TextEditingController issueController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Асуудал мэдэгдэх'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Захиалгатай холбоотой асуудлаа бичээд илгээнэ үү:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: issueController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Асуудлын дэлгэрэнгүй тайлбар...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Цуцлах'),
          ),
          ElevatedButton(
            onPressed: () {
              if (issueController.text.trim().isNotEmpty) {
                // Here you would typically send the issue to your support system
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Таны асуудал амжилттай илгээгдлээ. Удахгүй хариу өгөх болно.'),
                    duration: Duration(seconds: 3),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Асуудлын тайлбар оруулна уу'),
                  ),
                );
              }
              issueController.dispose();
            },
            child: const Text('Илгээх'),
          ),
        ],
      ),
    );
  }

  void _showDeleteOrderConfirmation(
      BuildContext context, QueryDocumentSnapshot order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Захиалга устгах'),
        content: const Text(
          'Та энэ захиалгыг устгахдаа итгэлтэй байна уу? Энэ үйлдлийг буцаах боломжгүй.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Цуцлах'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                // Delete the order from user's orders collection
                final user = auth.FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('orders')
                      .doc(order.id)
                      .delete();

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Захиалга амжилттай устгагдлаа'),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Захиалга устгахад алдаа гарлаа'),
                    ),
                  );
                }
              }
            },
            child: const Text('Устгах'),
          ),
        ],
      ),
    );
  }

  void _navigateToReview(
      BuildContext context, String productId, String orderId, String storeId) {
    if (productId.isEmpty || storeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Бүтээгдэхүүний мэдээлэл олдсонгүй')),
      );
      return;
    }

    // Use existing review functionality
    showDialog(
      context: context,
      builder: (context) => ReviewSubmissionDialog(
        storeId: storeId,
        storeName: 'Дэлгүүр', // Will be loaded from store data
        orderId: orderId,
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'placed':
        return 'Захиалсан';
      case 'confirmed':
        return 'Баталгаажсан';
      case 'shipped':
        return 'Илгээсэн';
      case 'delivered':
        return 'Хүргэгдсэн';
      case 'cancelled':
        return 'Цуцалсан';
      default:
        return 'Захиалсан';
    }
  }
}

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('профайл')),
      body: const Center(child: Text('профайл')),
    );
  }
}

class ShopUBBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final bool floating;
  const ShopUBBottomNavBar(
      {super.key, required this.currentIndex, this.floating = false});

  void _onTap(BuildContext context, int index) {
    const routes = ['/home', '/search', '/orders', '/saved'];
    if (index != currentIndex) {
      Navigator.pushReplacementNamed(context, routes[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => _onTap(context, index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey.shade600,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Нүүр'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Хайх'),
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag), label: 'Захиалга'),
          BottomNavigationBarItem(
              icon: Icon(Icons.bookmark), label: 'Хадгалсан'),
        ],
      ),
    );
  }
}

class ReceiptPage extends StatelessWidget {
  final QueryDocumentSnapshot order;

  const ReceiptPage({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final data = order.data() as Map<String, dynamic>;
    final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
    final totalAmount =
        TypeUtils.safeCastDouble(data['total'], defaultValue: 0.0);
    final createdAt = (data['createdAt'] ?? Timestamp.now()) as Timestamp;

    // Extract payment and address information
    final String paymentMethod = data['paymentMethod'] as String? ?? 'Карт';
    final String paymentIntentId = (data['paymentIntentId'] as String?) ?? '';
    final String customerEmail = (data['customerEmail'] as String?) ??
        (data['userEmail'] as String?) ??
        '';
    final Map<String, dynamic> deliveryAddress =
        (data['deliveryAddress'] as Map<String, dynamic>?) ?? {};
    final String shippingAddress = (data['shippingAddress'] as String?) ?? '';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Баримт',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                const Center(
                  child: Text(
                    'Баримт',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Order info - using truncated order number
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Захиалгын дугаар #${order.id.substring(0, 8).toUpperCase()}...',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(createdAt.toDate()),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Items list
                ...items.map((item) => _buildReceiptItem(item)),

                const SizedBox(height: 24),

                // Divider
                Container(
                  height: 1,
                  color: Colors.grey.shade300,
                ),

                const SizedBox(height: 16),

                // Subtotal
                _buildReceiptRow(
                    'Үнийн дүн', '₮${totalAmount.toStringAsFixed(0)}'),
                const SizedBox(height: 8),

                // Shipping
                _buildReceiptRow('Хүргэлт', 'Үнэгүй'),

                const SizedBox(height: 16),

                // Another divider
                Container(
                  height: 2,
                  color: Colors.black,
                ),

                const SizedBox(height: 16),

                // Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Нийт дүн',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      '₮${totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Payment method - using actual payment data
                const Text(
                  'Төлбөрийн хэрэгсэл',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Text(
                      _getPaymentMethodDisplay(paymentMethod),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      paymentIntentId.isNotEmpty
                          ? '•••• ${paymentIntentId.substring(paymentIntentId.length - 4)}'
                          : 'QPay төлбөр',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Payment details
                _buildPaymentDetails(paymentMethod, paymentIntentId),

                const SizedBox(height: 32),

                // Billing address - using actual address data
                _buildBillingAddressSection(
                    customerEmail, deliveryAddress, shippingAddress),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentDetails(String paymentMethod, String paymentIntentId) {
    if (paymentMethod.toLowerCase() == 'qpay') {
      return Row(
        children: [
          Container(
            width: 32,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(
              child: Text(
                'QPay',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              paymentIntentId.isNotEmpty
                  ? '•••• ${paymentIntentId.substring(paymentIntentId.length - 4)}'
                  : 'QPay төлбөр',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black,
              ),
            ),
          ),
          Icon(
            Icons.info_outline,
            size: 16,
            color: Colors.grey.shade600,
          ),
        ],
      );
    } else {
      // Default card display
      return Row(
        children: [
          Container(
            width: 24,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(2),
            ),
            child: const Center(
              child: Text(
                'VISA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '•••• •••• •••• 1099',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.info_outline,
            size: 16,
            color: Colors.grey.shade600,
          ),
        ],
      );
    }
  }

  Widget _buildBillingAddressSection(String customerEmail,
      Map<String, dynamic> deliveryAddress, String shippingAddress) {
    return FutureBuilder<Map<String, String>>(
      future:
          _getReceiptUserInfo(deliveryAddress, shippingAddress, customerEmail),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Төлбөрийн хаяг',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 12),
              CircularProgressIndicator(),
            ],
          );
        }

        final userInfo = snapshot.data ?? {};
        final recipientName = userInfo['name'] ?? 'Хэрэглэгч';
        final fullAddress = userInfo['address'] ?? 'Улаанbaatar, Монгол улс';
        final phone = userInfo['phone'] ?? '+976 9999 9999';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Төлбөрийн хаяг',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              recipientName,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              fullAddress,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              phone,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black,
              ),
            ),
            if (customerEmail.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                customerEmail,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  // Helper method to get user info for receipt
  Future<Map<String, String>> _getReceiptUserInfo(
      Map<String, dynamic> deliveryAddress,
      String shippingAddress,
      String customerEmail) async {
    try {
      // Try to get current user info if available
      final currentUser = auth.FirebaseAuth.instance.currentUser;
      String userName = 'Хэрэглэгч';
      String userPhone = '+976 9999 9999';

      if (currentUser != null) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();

          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            userName = userData['displayName'] as String? ??
                userData['firstName'] as String? ??
                userData['name'] as String? ??
                currentUser.displayName ??
                'Хэрэглэгч';
            userPhone = userData['phoneNumber'] as String? ??
                userData['phone'] as String? ??
                currentUser.phoneNumber ??
                '+976 9999 9999';
          }
        } catch (e) {
          // Error fetching user data for receipt
        }
      }

      // Get address information
      String finalAddress = 'Улаанbaatar, Монгол улс';
      String phone = userPhone;

      if (deliveryAddress.isNotEmpty) {
        finalAddress = deliveryAddress['fullAddress'] as String? ??
            deliveryAddress['address'] as String? ??
            deliveryAddress['line1'] as String? ??
            shippingAddress;

        phone = deliveryAddress['phone'] as String? ??
            deliveryAddress['contactPhone'] as String? ??
            userPhone;

        // Override name if delivery address has name info
        final firstName = deliveryAddress['firstName'] as String? ?? '';
        final lastName = deliveryAddress['lastName'] as String? ?? '';
        if (firstName.isNotEmpty || lastName.isNotEmpty) {
          userName = '$firstName $lastName'.trim();
        }
      } else if (shippingAddress.isNotEmpty) {
        finalAddress = shippingAddress;
      }

      return {
        'name': userName,
        'address': finalAddress,
        'phone': phone,
      };
    } catch (e) {
      // Error getting receipt user info
      return {
        'name': 'Хэрэглэгч',
        'address': 'Улаанbaatar, Монгол улс',
        'phone': '+976 9999 9999',
      };
    }
  }

  String _getPaymentMethodDisplay(String paymentMethod) {
    switch (paymentMethod.toLowerCase()) {
      case 'qpay':
        return 'QPay';
      case 'card':
      case 'visa':
      case 'mastercard':
        return 'Карт';
      case 'cash':
        return 'Бэлэн мөнгө';
      default:
        return 'Карт';
    }
  }

  Widget _buildReceiptItem(Map<String, dynamic> item) {
    final name = item['name'] ?? 'Бүтээгдэхүүн';
    final price = TypeUtils.safeCastDouble(item['price'], defaultValue: 0.0);
    final quantity = TypeUtils.safeCastInt(item['quantity'], defaultValue: 1);
    final variant = item['variant'] ?? '';
    final imageUrl = item['imageUrl'] ?? '';

    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          // Product image
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade100,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.inventory_2,
                          color: Colors.grey,
                          size: 24,
                        );
                      },
                    )
                  : const Icon(
                      Icons.inventory_2,
                      color: Colors.grey,
                      size: 24,
                    ),
            ),
          ),

          const SizedBox(width: 12),

          // Product details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (variant.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    variant,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                if (quantity > 1) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Тоо ширхэг: $quantity',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Price
          Text(
            '₮${(price * quantity).toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      '1 сарын',
      '2 сарын',
      '3 сарын',
      '4 сарын',
      '5 сарын',
      '6 сарын',
      '7 сарын',
      '8 сарын',
      '9 сарын',
      '10 сарын',
      '11 сарын',
      '12 сарын'
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
