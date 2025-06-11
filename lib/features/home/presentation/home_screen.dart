import 'package:flutter/material.dart';
import '../domain/models.dart';

class HomeScreen extends StatelessWidget {
  HomeScreen({super.key});

  // Following stores data
  final List<Store> followingStores = [
    Store(
      id: 'etravelsim',
      name: 'ETravelSim',
      imageUrl:
          'https://images.unsplash.com/photo-1563013544-824ae1b704d3?w=400',
    ),
    Store(
      id: 'unsalties',
      name: 'UNSALTIES',
      imageUrl:
          'https://images.unsplash.com/photo-1572635196237-6f3c6a5b8d5c?w=400',
    ),
    Store(
      id: 'paintbrighter',
      name: 'Paint A Brighter Color',
      imageUrl:
          'https://images.unsplash.com/photo-1541961017774-22349e4a1262?w=400',
    ),
    Store(
      id: 'mrbeast',
      name: 'MRBEAST STORE',
      imageUrl:
          'https://images.unsplash.com/photo-1559827260-dc66d52bef19?w=400',
    ),
    Store(
      id: 'uspolo',
      name: 'U.S. POLO ASSN.',
      imageUrl:
          'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=400',
    ),
  ];

  // Your offers data
  final List<Offer> offers = [
    Offer(
      id: 'dracoslides',
      imageUrl:
          'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=400',
      discount: 'Save \$25',
      storeName: 'Dracoslides',
      rating: 4.6,
      reviews: '16K',
      title: 'SPRING SALE',
    ),
    Offer(
      id: 'purplebrand',
      imageUrl:
          'https://images.unsplash.com/photo-1506629905587-4b8b653337f0?w=400',
      discount: 'Save \$50',
      storeName: 'PURPLE BRAND',
      rating: 4.8,
      reviews: '6.3K',
      title: 'PURPLE',
    ),
  ];

  // Sample seller data
  final List<SellerData> sellers = [
    SellerData(
      name: 'SLF',
      profileLetter: 'S',
      rating: 4.6,
      reviews: 510,
      products: [
        SellerProduct(
          imageUrl:
              'https://images.unsplash.com/photo-1542272604-787c3835535d?w=400',
          price: '\$10.00',
        ),
        SellerProduct(
          imageUrl:
              'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=400',
          price: '\$5.00',
        ),
        SellerProduct(
          imageUrl:
              'https://images.unsplash.com/photo-1503341504253-dff4815485f1?w=400',
          price: '\$15.00',
        ),
        SellerProduct(
          imageUrl:
              'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=400',
          price: '\$15.00',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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

                    // Following Section
                    _buildFollowingSection(context),

                    const SizedBox(height: 24),

                    // Your Offers Section
                    _buildYourOffersSection(context),

                    const SizedBox(height: 24),

                    // Seller Cards
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: sellers
                            .map((seller) => Padding(
                                  padding: const EdgeInsets.only(bottom: 24),
                                  child: _buildSellerCard(context, seller),
                                ))
                            .toList(),
                      ),
                    ),

                    const SizedBox(height: 80), // Space for bottom nav
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // Bottom Navigation
      bottomNavigationBar: _buildBottomNavigation(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          const Text(
            'shop',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Color(0xFF7B61FF),
              letterSpacing: 1.2,
            ),
          ),

          // Right side actions
          Row(
            children: [
              // Balance
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Balance tapped!')),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    '\$0.00',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Notification
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notifications tapped!')),
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
                    Icons.notifications_outlined,
                    size: 20,
                    color: Colors.black87,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Profile
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/account');
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const CircleAvatar(
                    backgroundImage: NetworkImage(
                      'https://images.unsplash.com/photo-1494790108755-2616b5d10c39?w=200',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFollowingSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Following header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Text(
                'Following',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: Colors.red, size: 8),
                    SizedBox(width: 4),
                    Text(
                      '17 Updates',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 20, color: Colors.black54),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Horizontal scrolling stores - 65x65 pixels with 7px gaps
        SizedBox(
          height: 85, // 65px + space for text below
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: followingStores.length,
            separatorBuilder: (_, __) => const SizedBox(width: 7), // 7px gap
            itemBuilder: (context, index) {
              final store = followingStores[index];
              return GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${store.name} tapped!')),
                  );
                },
                child: Column(
                  children: [
                    Container(
                      width: 65, // Exact 65px width
                      height: 65, // Exact 65px height
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          store.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child:
                                  const Icon(Icons.store, color: Colors.grey),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 65,
                      child: Text(
                        store.name,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildYourOffersSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Your offers header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Text(
                'Your offers',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 20, color: Colors.black54),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Horizontal scrolling offers - 185x191 pixels
        SizedBox(
          height: 191, // Exact 191px height
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: offers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final offer = offers[index];
              return GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${offer.storeName} offer tapped!')),
                  );
                },
                child: Container(
                  width: 185, // Exact 185px width
                  height: 191, // Exact 191px height
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
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
                      // Background image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          offer.imageUrl,
                          width: 185,
                          height: 191,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 185,
                              height: 191,
                              color: Colors.grey[300],
                              child: const Icon(Icons.image,
                                  size: 50, color: Colors.grey),
                            );
                          },
                        ),
                      ),

                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                      ),

                      // Discount badge
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7B61FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            offer.discount,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),

                      // Bottom content
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (offer.title != null) ...[
                              Text(
                                offer.title!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                            Text(
                              offer.storeName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  offer.rating.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(Icons.star,
                                    color: Colors.amber, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  '(${offer.reviews})',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSellerCard(BuildContext context, SellerData seller) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Seller Info
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.black87,
                child: Text(
                  seller.profileLetter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      seller.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          seller.rating.toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.star, color: Colors.black87, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '(${seller.reviews})',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${seller.name} options tapped!')),
                  );
                },
                child: const Icon(
                  Icons.more_horiz,
                  color: Colors.black54,
                  size: 24,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Products Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1,
            ),
            itemCount: seller.products.length,
            itemBuilder: (context, index) {
              return _buildProductCard(context, seller.products[index]);
            },
          ),

          const SizedBox(height: 20),

          // Shop All Button
          Row(
            children: [
              const Text(
                'Shop all',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Shop all ${seller.name} tapped!')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0F0F0),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
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

  Widget _buildProductCard(BuildContext context, SellerProduct product) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Product ${product.price} tapped!')),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            // Product Image
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                product.imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child:
                        const Icon(Icons.image, size: 50, color: Colors.grey),
                  );
                },
              ),
            ),

            // Price Tag
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  product.price,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),

            // Heart Icon
            Positioned(
              bottom: 8,
              right: 8,
              child: GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Added to favorites!')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_border,
                    size: 16,
                    color: Colors.black54,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(context, Icons.home, 0, true),
          _buildNavItem(context, Icons.search, 1, false),
          _buildNavItem(context, Icons.bookmark_border, 2, false),
        ],
      ),
    );
  }

  Widget _buildNavItem(
      BuildContext context, IconData icon, int index, bool isActive) {
    return GestureDetector(
      onTap: () {
        switch (index) {
          case 0:
            // Already on home
            break;
          case 1:
            Navigator.pushNamed(context, '/search');
            break;
          case 2:
            Navigator.pushNamed(context, '/orders');
            break;
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF7B61FF) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : Colors.black54,
          size: 22,
        ),
      ),
    );
  }
}

// Data models
class SellerData {
  final String name;
  final String profileLetter;
  final double rating;
  final int reviews;
  final List<SellerProduct> products;

  SellerData({
    required this.name,
    required this.profileLetter,
    required this.rating,
    required this.reviews,
    required this.products,
  });
}
