import 'package:flutter/material.dart';
import '../domain/models.dart';
import 'widgets/seller_card.dart';
import 'widgets/offer_card.dart';
import '../../../../core/widgets/bottom_nav_bar.dart';

class HomeScreen extends StatelessWidget {
  final List<Store> followingStores = [
    Store(
      id: 'etravelsim',
      name: 'ETravelSim',
      imageUrl: 'https://i.ibb.co/6b8Qw8d/etravelsim.png',
    ),
    Store(
      id: 'unsalties',
      name: 'UNSALTIES',
      imageUrl: 'https://i.ibb.co/6wQw8dV/unsalties.png',
    ),
    Store(
      id: 'paintbrighter',
      name: 'Paint A Brighter Color',
      imageUrl: 'https://i.ibb.co/3kQw8dV/paint-brighter.png',
    ),
    Store(
      id: 'mrbeast',
      name: 'MRBEAST STORE',
      imageUrl: 'https://i.ibb.co/0jQw8dV/mrbeast.png',
    ),
    Store(
      id: 'uspolo',
      name: 'U.S. POLO ASSN.',
      imageUrl: 'https://i.ibb.co/4jQw8dV/uspolo.png',
    ),
  ];

  final List<Offer> offers = [
    Offer(
      id: 'dracoslides',
      imageUrl: 'https://i.ibb.co/6b8Qw8d/dracoslides-offer.jpg',
      discount: 'Save \$25',
      storeName: 'Dracoslides',
      rating: 4.6,
      reviews: '16K',
    ),
    Offer(
      id: 'purplebrand',
      imageUrl: 'https://i.ibb.co/6wQw8dV/purplebrand-offer.jpg',
      discount: 'Save \$50',
      storeName: 'PURPLE BRAND',
      rating: 4.8,
      reviews: '6.3K',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F8F8),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo
                  Text(
                    'shop',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF7B61FF),
                      fontFamily: 'Roboto',
                      letterSpacing: 1.5,
                    ),
                  ),
                  Row(
                    children: [
                      // Balance
                      GestureDetector(
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Balance tapped!')),
                        ),
                        child: Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '\u00000.00',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      // Notification
                      GestureDetector(
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Notifications tapped!')),
                        ),
                        child: Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(Icons.notifications_none, size: 24),
                        ),
                      ),
                      SizedBox(width: 10),
                      // Profile Avatar
                      GestureDetector(
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Profile tapped!')),
                        ),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.white,
                          backgroundImage: NetworkImage(
                            'https://randomuser.me/api/portraits/men/32.jpg',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Following Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Text(
                    'Following',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.circle, color: Colors.red, size: 10),
                        SizedBox(width: 4),
                        Text('${followingStores.length} Updates',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            Container(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 20),
                itemCount: followingStores.length,
                separatorBuilder: (_, __) => SizedBox(width: 14),
                itemBuilder: (context, i) {
                  final store = followingStores[i];
                  return GestureDetector(
                    onTap: () {
                      print('pressed on ${store.name}');
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => StorePage(store: store)),
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              store.imageUrl,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        SizedBox(height: 4),
                        Container(
                          width: 60,
                          child: Text(
                            store.name,
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Your Offers Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Text(
                    'Your offers',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.chevron_right, size: 24),
                ],
              ),
            ),
            Container(
              height: 210,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 20),
                itemCount: offers.length,
                separatorBuilder: (_, __) => SizedBox(width: 16),
                itemBuilder: (context, i) {
                  final offer = offers[i];
                  return GestureDetector(
                    onTap: () {
                      print('pressed on ${offer.storeName}');
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => OfferPage(offer: offer)),
                      );
                    },
                    child: OfferCard(
                      imageUrl: offer.imageUrl,
                      discount: offer.discount,
                      title: offer.storeName,
                      rating: offer.rating,
                      reviews: offer.reviews,
                    ),
                  );
                },
              ),
            ),
            // --- Show only loverockapparel SellerCard ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: SellerCard(
                sellerName: 'loverockapparel',
                profileLetter: 'L',
                rating: 4.6,
                reviews: 510,
                products: [
                  SellerProduct(
                    imageUrl:
                        'https://cdn.shopify.com/s/files/1/0580/8501/8996/products/IMG_9917_600x.jpg?v=1669162322',
                    price: '\$100.00',
                  ),
                  SellerProduct(
                    imageUrl:
                        'https://cdn.shopify.com/s/files/1/0580/8501/8996/products/IMG_9918_600x.jpg?v=1669162322',
                    price: '\$70.00',
                  ),
                  SellerProduct(
                    imageUrl:
                        'https://cdn.shopify.com/s/files/1/0580/8501/8996/products/IMG_9919_600x.jpg?v=1669162322',
                    price: '\$65.00',
                  ),
                  SellerProduct(
                    imageUrl:
                        'https://cdn.shopify.com/s/files/1/0580/8501/8996/products/IMG_9920_600x.jpg?v=1669162322',
                    price: '\$65.00',
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: ShopUBBottomNavBar(currentIndex: 0, floating: true),
    );
  }
}

// Dummy StorePage and OfferPage for navigation (to be moved to their own files)
class StorePage extends StatelessWidget {
  final Store store;
  const StorePage({required this.store});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(store.name)),
      body:
          Center(child: Text('Store page for \\${store.name} coming soon...')),
    );
  }
}

class OfferPage extends StatelessWidget {
  final Offer offer;
  const OfferPage({required this.offer});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(offer.storeName)),
      body: Center(
          child: Text('Offer page for \\${offer.storeName} coming soon...')),
    );
  }
}
