import 'package:flutter/material.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/stores/presentation/store_screen.dart';
import 'features/stores/data/sample_stores.dart';
import 'features/home/presentation/main_scaffold.dart';
import 'package:shoppy/features/Profile/profile_page.dart';
import 'package:provider/provider.dart';
import 'features/cart/providers/cart_provider.dart';
import 'package:shoppy/features/profile/providers/recently_viewed_provider.dart';
import 'package:shoppy/features/theme/theme_provider.dart';
import 'package:shoppy/features/addresses/providers/address_provider.dart';

void main() {
  runApp(const ShopUBApp());
}

class ShopUBApp extends StatelessWidget {
  const ShopUBApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => RecentlyViewedProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AddressProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (_, themeProvider, __) => MaterialApp(
          title: 'Shop UB',
          theme: ThemeData(
            primarySwatch: Colors.teal,
            fontFamily: 'Roboto',
          ),
          darkTheme: ThemeData.dark().copyWith(primaryColor: Colors.deepPurple),
          themeMode: themeProvider.mode,
          home: HomeScreen(),
          routes: {
            '/home': (_) => HomeScreen(),
            '/search': (_) => const SearchScreen(),
            '/orders': (_) => const OrdersScreen(),
            '/account': (_) => ProfilePage(),
          },
          onGenerateRoute: (settings) {
            if (settings.name != null && settings.name!.startsWith('/store/')) {
              final storeId = settings.name!.split('/')[2];
              final storeData = SampleStores.getStoreById(storeId);
              if (storeData != null) {
                return MaterialPageRoute(
                  builder: (context) => StoreScreen(storeData: storeData),
                );
              }
            }
            return null;
          },
        ),
      ),
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

  // Category data matching the screenshot
  final List<CategoryItem> categories = [
    CategoryItem(
      name: 'Women',
      imageUrl:
          'https://images.unsplash.com/photo-1594633312681-425c7b97ccd1?w=400',
      color: const Color(0xFF2D8A47),
    ),
    CategoryItem(
      name: 'Men',
      imageUrl:
          'https://images.unsplash.com/photo-1621072156002-e2fccdc0b176?w=400',
      color: const Color(0xFFD97841),
    ),
    CategoryItem(
      name: 'Beauty',
      imageUrl:
          'https://images.unsplash.com/photo-1596462502278-27bfdc403348?w=400',
      color: const Color(0xFF8B4513),
    ),
    CategoryItem(
      name: 'Food & drinks',
      imageUrl:
          'https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=400',
      color: const Color(0xFFB8A082),
    ),
    CategoryItem(
      name: 'Baby & toddler',
      imageUrl:
          'https://images.unsplash.com/photo-1515488042361-ee00e0ddd4e4?w=400',
      color: const Color(0xFFE8B5C8),
    ),
    CategoryItem(
      name: 'Home',
      imageUrl:
          'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=400',
      color: const Color(0xFF8B9B8A),
    ),
    CategoryItem(
      name: 'Fitness & nutrition',
      imageUrl:
          'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400',
      color: const Color(0xFF6B9BD1),
    ),
    CategoryItem(
      name: 'Accessories',
      imageUrl:
          'https://images.unsplash.com/photo-1511499767150-a48a237f0083?w=400',
      color: const Color(0xFF9ACD32),
    ),
    CategoryItem(
      name: 'Pet supplies',
      imageUrl:
          'https://images.unsplash.com/photo-1601758228041-f3b2795255f1?w=400',
      color: const Color(0xFFD2B48C),
    ),
    CategoryItem(
      name: 'Toys & games',
      imageUrl:
          'https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=400',
      color: const Color(0xFF6A5ACD),
    ),
    CategoryItem(
      name: 'Electronics',
      imageUrl:
          'https://images.unsplash.com/photo-1518655048521-f130df041f66?w=400',
      color: const Color(0xFF2F2F2F),
    ),
    CategoryItem(
      name: 'Arts & crafts',
      imageUrl:
          'https://images.unsplash.com/photo-1513475382585-d06e58bcb0e0?w=400',
      color: const Color(0xFFDEB887),
    ),
    CategoryItem(
      name: 'Luggage & bags',
      imageUrl:
          'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=400',
      color: const Color(0xFF808080),
    ),
    CategoryItem(
      name: 'Sporting goods',
      imageUrl:
          'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400',
      color: const Color(0xFF4682B4),
    ),
  ];

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

              // Categories Grid
              Expanded(
                child: _buildCategoriesGrid(),
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
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: const InputDecoration(
          hintText: 'Search',
          hintStyle: TextStyle(
            color: Colors.grey,
            fontSize: 16,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.grey,
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onChanged: (value) {
          // Handle search functionality
        },
      ),
    );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${category.name} category tapped!')),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
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
              child: Image.network(
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
                    category.color.withOpacity(0.3),
                    category.color.withOpacity(0.7),
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  // Buy again items
  final List<BuyAgainItem> buyAgainItems = const [
    BuyAgainItem(
      id: '1',
      imageUrl:
          'https://images.unsplash.com/photo-1556821840-3a63f95609a7?w=400',
      name: 'RIOT Hoodie',
    ),
    BuyAgainItem(
      id: '2',
      imageUrl:
          'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=400',
      name: 'Graphic Tee',
    ),
    BuyAgainItem(
      id: '3',
      imageUrl:
          'https://images.unsplash.com/photo-1503341504253-dff4815485f1?w=400',
      name: 'T-Shirt Mockup Pack',
    ),
    BuyAgainItem(
      id: '4',
      imageUrl:
          'https://images.unsplash.com/photo-1542272604-787c3835535d?w=400',
      name: 'Casual Wear',
    ),
  ];

  // Past orders data
  final List<PastOrder> pastOrders = const [
    PastOrder(
      id: '1',
      imageUrl:
          'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=200',
      status: 'Delivered',
      storeName: 'ETravelSim',
      itemCount: '1 item',
      price: '\$19.00',
    ),
    PastOrder(
      id: '2',
      imageUrl:
          'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=200',
      status: 'Delivered',
      storeName: 'Amazon',
      itemCount: '2 items',
    ),
    PastOrder(
      id: '3',
      imageUrl:
          'https://images.unsplash.com/photo-1434389677669-e08b4cac3105?w=200',
      status: 'In-store purchase',
      storeName: 'Alo Yoga',
      itemCount: '1 item',
      price: '\$95.90',
    ),
    PastOrder(
      id: '4',
      imageUrl:
          'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=200',
      status: 'Delivered',
      storeName: 'Amazon',
      itemCount: '2 items',
    ),
    PastOrder(
      id: '5',
      imageUrl:
          'https://images.unsplash.com/photo-1586717799252-bd134ad00e26?w=200',
      status: 'Delivered Apr 6',
      storeName: 'FedEx',
      itemCount: '',
    ),
    PastOrder(
      id: '6',
      imageUrl:
          'https://images.unsplash.com/photo-1527443224154-c4a3942d3acf?w=200',
      status: 'Ordered Apr 3',
      storeName: 'Macy\'s',
      itemCount: '1 item',
    ),
    PastOrder(
      id: '7',
      imageUrl:
          'https://images.unsplash.com/photo-1586953208448-b95a79798f07?w=200',
      status: 'Delivered',
      storeName: 'Amazon',
      itemCount: '2 items',
    ),
    PastOrder(
      id: '8',
      imageUrl:
          'https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=200',
      status: 'Delivered Mar 29',
      storeName: 'YZY',
      itemCount: '2 items',
      price: '\$58.10',
    ),
    PastOrder(
      id: '9',
      imageUrl:
          'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?w=200',
      status: 'Delivered',
      storeName: 'Amazon',
      itemCount: '2 items',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      currentIndex: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(context),

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      // Buy Again Section
                      _buildBuyAgainSection(context),

                      const SizedBox(height: 32),

                      // Past Orders Section
                      _buildPastOrdersSection(context),

                      const SizedBox(height: 80), // Space for bottom nav
                    ],
                  ),
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
            'Orders',
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Search orders tapped!')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.search,
                    size: 20,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('More options tapped!')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
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

  Widget _buildBuyAgainSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Text(
                'Buy again',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 20, color: Colors.black54),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: buyAgainItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = buyAgainItems[index];
              return _buildBuyAgainItem(context, item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBuyAgainItem(BuildContext context, BuyAgainItem item) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Buy again ${item.name} tapped!')),
        );
      },
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                item.imageUrl,
                width: 100,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 100,
                    height: 120,
                    color: Colors.grey[200],
                    child: const Icon(Icons.image, color: Colors.grey),
                  );
                },
              ),
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shopping_cart,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPastOrdersSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Text(
                'Past orders',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 20, color: Colors.black54),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: pastOrders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final order = pastOrders[index];
            return _buildPastOrderItem(context, order);
          },
        ),
      ],
    );
  }

  Widget _buildPastOrderItem(BuildContext context, PastOrder order) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order ${order.storeName} tapped!')),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Product Image
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  order.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.image, color: Colors.grey),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Order Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.status,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        order.storeName,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                      if (order.itemCount.isNotEmpty) ...[
                        const Text(
                          ' • ',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        Text(
                          order.itemCount,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                      if (order.price != null) ...[
                        const Text(
                          ' • ',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        Text(
                          order.price!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Data models for Orders screen
class BuyAgainItem {
  final String id;
  final String imageUrl;
  final String name;

  const BuyAgainItem({
    required this.id,
    required this.imageUrl,
    required this.name,
  });
}

class PastOrder {
  final String id;
  final String imageUrl;
  final String status;
  final String storeName;
  final String itemCount;
  final String? price;

  const PastOrder({
    required this.id,
    required this.imageUrl,
    required this.status,
    required this.storeName,
    required this.itemCount,
    this.price,
  });
}

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: const Center(child: Text('User Profile')),
    );
  }
}

class ShopUBBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final bool floating;
  const ShopUBBottomNavBar(
      {super.key, required this.currentIndex, this.floating = false});

  void _onTap(BuildContext context, int index) {
    const routes = ['/home', '/search', '/orders'];
    if (index != currentIndex) {
      Navigator.pushReplacementNamed(context, routes[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bar = Container(
      margin: floating
          ? const EdgeInsets.only(left: 24, right: 24, bottom: 16)
          : EdgeInsets.zero,
      decoration: floating
          ? BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            )
          : null,
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: floating ? Colors.transparent : Colors.white,
        elevation: floating ? 0 : 8,
        currentIndex: currentIndex,
        onTap: (i) => _onTap(context, i),
        selectedItemColor: const Color(0xFF7B61FF),
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Orders'),
        ],
      ),
    );
    return floating
        ? Stack(
            children: [
              const SizedBox(height: 70),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: bar,
              ),
            ],
          )
        : bar;
  }
}
