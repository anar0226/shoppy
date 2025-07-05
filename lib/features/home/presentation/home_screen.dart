import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as FirebaseAuth;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:avii/features/auth/providers/auth_provider.dart';
import 'package:avii/features/stores/models/store_model.dart';
import 'package:avii/features/products/models/product_model.dart';
import '../../notifications/notifications_inbox_page.dart';
import '../domain/models.dart';
import 'main_scaffold.dart';
import 'package:avii/features/stores/presentation/store_screen.dart';
import 'package:avii/features/products/presentation/product_page.dart';
import 'widgets/seller_card.dart';
import '../../../core/services/rating_service.dart';
import '../../recommendations/services/simple_recommendation_service.dart';
import '../../recommendations/presentation/preferences_dialog.dart';
import '../../../core/widgets/paginated_firestore_list.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SimpleRecommendationService _recommendationService =
      SimpleRecommendationService();

  late Future<List<SellerData>> _sellersFuture;
  Future<List<Store>>? _followingFuture;

  // Pagination variables
  int _currentPage = 0;
  static const int _storesPerPage = 30;
  final List<String> _loadedStoreIds = [];

  @override
  void initState() {
    super.initState();
    _sellersFuture = _loadSellers();

    // Load followed stores for current user (logos + names)
    final auth = context.read<AuthProvider>();
    if (auth.user != null) {
      _followingFuture = _loadFollowingStores(auth.user!.uid);
      // Check if user needs to set preferences
      _checkAndShowPreferencesDialog();
    } else {
      _followingFuture = Future.value([]);
    }
  }

  // Check if user has preferences, if not show dialog
  Future<void> _checkAndShowPreferencesDialog() async {
    try {
      final preferences = await _recommendationService.getUserPreferences();
      // Checking user preferences

      if (preferences == null) {
        // Check if we've already shown the dialog this session using SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final hasShownDialog = prefs.getBool(
                'preferences_dialog_shown_${FirebaseAuth.FirebaseAuth.instance.currentUser?.uid}') ??
            false;

        if (!hasShownDialog) {
          // Wait a bit for the UI to settle, then show dialog
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(milliseconds: 500), () {
              _showPreferencesDialog();
            });
          });
        }
      }
    } catch (e) {
      // Error checking user preferences
    }
  }

  // Show preferences dialog
  Future<void> _showPreferencesDialog() async {
    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PreferencesDialog(),
    );

    if (result == true) {
      // Preferences were saved, reload stores to show recommendations
      setState(() {
        _currentPage = 0; // Reset to first page
        _loadedStoreIds.clear(); // Clear loaded stores
        _sellersFuture = _loadSellers();
      });
    }

    // Mark that we've shown the preferences dialog for this user
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = FirebaseAuth.FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await prefs.setBool('preferences_dialog_shown_$userId', true);
      }
    } catch (e) {
      // Error saving dialog shown flag
    }
  }

  Future<List<Store>> _loadFollowingStores(String uid) async {
    final userDoc = await _db.collection('users').doc(uid).get();
    final List<dynamic> ids = userDoc.data()?['followerStoreIds'] ?? [];
    if (ids.isEmpty) return [];
    final snap = await _db
        .collection('stores')
        .where(FieldPath.documentId, whereIn: ids)
        .get();
    return snap.docs
        .map(StoreModel.fromFirestore)
        .map((s) => Store(id: s.id, name: s.name, imageUrl: s.logo))
        .toList();
  }

  Future<List<SellerData>> _loadSellers() async {
    try {
      // Loading sellers
      final List<SellerData> result = [];

      // Step 1: Load recommended stores (only on first page)
      if (_currentPage == 0) {
        try {
          final recommendedStores =
              await _recommendationService.getRecommendedStores(limit: 10);
          print('📋 Found ${recommendedStores.length} recommended stores');

          for (final storeModel in recommendedStores) {
            if (result.length >= _storesPerPage) break;

            final sellerData = await _convertStoreToSellerData(storeModel,
                isRecommended: true);
            if (sellerData != null) {
              result.add(sellerData);
              _loadedStoreIds.add(storeModel.id);
            }
          }
        } catch (e) {
          print('⚠️ Error loading recommended stores: $e');
        }
      }

      // Step 2: Fill remaining slots with other active stores
      final int remainingSlots = _storesPerPage - result.length;
      if (remainingSlots > 0) {
        try {
          // Get user's not interested stores to exclude them
          final notInterestedStores = await _getNotInterestedStores();

          // Calculate how many stores to skip based on current page and already loaded stores
          final int skipCount = (_currentPage * _storesPerPage) - result.length;

          final storesSnapshot = await _db
              .collection('stores')
              .where('status', isEqualTo: 'active')
              .limit(remainingSlots +
                  skipCount +
                  50) // Get extra to account for filtering
              .get();

          print(
              '📋 Found ${storesSnapshot.docs.length} active stores from Firestore');

          int addedCount = 0;
          int skippedCount = 0;

          for (final doc in storesSnapshot.docs) {
            if (addedCount >= remainingSlots) break;

            final storeModel = StoreModel.fromFirestore(doc);

            // Skip if already loaded
            if (_loadedStoreIds.contains(storeModel.id)) {
              continue;
            }

            // Skip if user marked as not interested
            if (notInterestedStores.contains(storeModel.id)) {
              continue;
            }

            // Skip the first few stores if this is not the first page
            if (skippedCount < skipCount) {
              skippedCount++;
              continue;
            }

            final sellerData = await _convertStoreToSellerData(storeModel,
                isRecommended: false);
            if (sellerData != null) {
              result.add(sellerData);
              _loadedStoreIds.add(storeModel.id);
              addedCount++;
            }
          }

          print('✅ Added $addedCount additional stores');
        } catch (e) {
          print('⚠️ Error loading additional stores: $e');
        }
      }

      print('🎯 Total sellers loaded: ${result.length}');
      return result;
    } catch (e) {
      print('💥 Fatal error loading sellers: $e');
      return [];
    }
  }

  // Helper method to convert StoreModel to SellerData
  Future<SellerData?> _convertStoreToSellerData(StoreModel storeModel,
      {required bool isRecommended}) async {
    try {
      // Load seller card settings
      final sellerCardDoc =
          await _db.collection('seller_cards').doc(storeModel.id).get();

      List<String> featuredProductIds = [];
      String? customBackgroundUrl;

      if (sellerCardDoc.exists) {
        final cardData = sellerCardDoc.data()!;
        featuredProductIds =
            List<String>.from(cardData['featuredProductIds'] ?? []);
        customBackgroundUrl = cardData['backgroundImageUrl'];
      }

      // Load products - either featured products or default products
      List<ProductModel> products;

      if (featuredProductIds.isNotEmpty) {
        // Load the specific featured products
        products = [];
        for (final productId in featuredProductIds.take(4)) {
          try {
            final productDoc =
                await _db.collection('products').doc(productId).get();
            if (productDoc.exists) {
              products.add(ProductModel.fromFirestore(productDoc));
            }
          } catch (e) {
            print('Error loading featured product $productId: $e');
          }
        }
      } else {
        // Load default products if no featured products are set
        products = await _fetchProducts(storeModel.id);
      }

      // Allow even if no products

      if (products.isEmpty) return null;

      final sellerProducts = products
          .map((p) => SellerProduct(
                id: p.id,
                imageUrl: p.images.isNotEmpty ? p.images.first : '',
                price: '₮${p.price.toStringAsFixed(2)}',
              ))
          .toList();

      // Load real ratings from reviews
      double storeRating = 0.0;
      int reviewCount = 0;

      try {
        final reviewsSnapshot = await _db
            .collection('stores')
            .doc(storeModel.id)
            .collection('reviews')
            .where('status', isEqualTo: 'active')
            .get();

        if (reviewsSnapshot.docs.isNotEmpty) {
          final reviews = reviewsSnapshot.docs;
          final totalRating = reviews.fold<double>(0, (sum, doc) {
            final data = doc.data();
            return sum + ((data['rating'] as num?)?.toDouble() ?? 0);
          });
          storeRating = totalRating / reviews.length;
          reviewCount = reviews.length;
        }
      } catch (reviewError) {
        print('⚠️ Error loading reviews for ${storeModel.name}: $reviewError');
      }

      return SellerData(
        name: storeModel.name,
        storeId: storeModel.id,
        profileLetter:
            storeModel.name.isNotEmpty ? storeModel.name[0].toUpperCase() : '?',
        rating: double.parse(storeRating.toStringAsFixed(1)),
        reviews: reviewCount,
        products: sellerProducts,
        backgroundImageUrl: customBackgroundUrl ?? storeModel.banner,
        storeLogoUrl: storeModel.logo,
        isAssetBg: false,
        isRecommended: isRecommended,
      );
    } catch (e) {
      print('Error converting store ${storeModel.id} to seller data: $e');
      return null;
    }
  }

  Future<List<ProductModel>> _fetchProducts(String storeId,
      {int limit = 4}) async {
    final lower = await _db
        .collection('products')
        .where('storeId', isEqualTo: storeId)
        .limit(limit)
        .get();
    if (lower.docs.isNotEmpty) {
      return lower.docs.map((d) => ProductModel.fromFirestore(d)).toList();
    }
    final upper = await _db
        .collection('products')
        .where('StoreId', isEqualTo: storeId)
        .limit(limit)
        .get();
    return upper.docs.map((d) => ProductModel.fromFirestore(d)).toList();
  }

  // Get user's not interested stores
  Future<List<String>> _getNotInterestedStores() async {
    try {
      final userId = FirebaseAuth.FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return [];

      final userDoc = await _db.collection('users').doc(userId).get();
      if (!userDoc.exists) return [];

      final userData = userDoc.data() as Map<String, dynamic>;
      return List<String>.from(userData['notInterestedStoreIds'] ?? []);
    } catch (e) {
      print('Error getting not interested stores: $e');
      return [];
    }
  }

  // Refresh method to load next page of stores
  Future<void> _refreshStores() async {
    setState(() {
      _currentPage++;
    });

    try {
      final newSellers = await _loadSellers();
      if (newSellers.isNotEmpty) {
        setState(() {
          _sellersFuture = Future.value(newSellers);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${newSellers.length} шинэ дэлгүүр ачаалагдлаа'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // No more stores available, revert page counter
        setState(() {
          _currentPage--;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Илүү дэлгүүр байхгүй байна'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Error occurred, revert page counter
      setState(() {
        _currentPage--;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Дэлгүүр ачаалахад алдаа гарлаа: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Load featured offers dynamically from real stores
  Future<List<Offer>> _loadFeaturedOffers() async {
    print('🔍 Loading featured offers - Starting...');

    try {
      final List<Offer> dynamicOffers = [];

      // Use the same featured store IDs for consistency
      final featuredStoreIds = [
        'TLLb3tqzvU2TZSsNPol9',
        'store_rbA5yLk0vadvSWarOpzYW1bRRUz1'
      ];

      print('🔍 Loading stores: $featuredStoreIds');

      for (final storeId in featuredStoreIds) {
        try {
          print('🔍 Loading store: $storeId');
          final storeDoc = await _db.collection('stores').doc(storeId).get();

          if (!storeDoc.exists) {
            print('❌ Store $storeId does not exist');
            continue;
          }

          final storeData = storeDoc.data()!;
          final storeName = storeData['name'] ?? 'Unknown Store';
          final storeImage = storeData['banner'] ?? storeData['logo'] ?? '';

          print('✅ Store loaded: $storeName, image: $storeImage');

          // Get store reviews to calculate real rating
          double rating = 0.0; // Default rating changed from 4.5 to 0.0
          String reviewCount = '0';

          try {
            final reviewsSnapshot = await _db
                .collection('stores')
                .doc(storeId)
                .collection('reviews')
                .where('status', isEqualTo: 'active')
                .get();

            if (reviewsSnapshot.docs.isNotEmpty) {
              final reviews = reviewsSnapshot.docs;
              final totalRating = reviews.fold<double>(0, (sum, doc) {
                final data = doc.data();
                return sum + ((data['rating'] as num?)?.toDouble() ?? 0);
              });
              rating = totalRating / reviews.length;
              reviewCount = reviews.length > 1000
                  ? '${(reviews.length / 1000).toStringAsFixed(1)}K'
                  : reviews.length.toString();
              print('📊 Reviews loaded: $reviewCount reviews, rating: $rating');
            } else {
              print('📊 No reviews found for $storeName');
            }
          } catch (reviewError) {
            print('⚠️ Error loading reviews for $storeId: $reviewError');
          }

          final offer = Offer(
            id: storeId,
            imageUrl: storeImage.isNotEmpty
                ? storeImage
                : 'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=400',
            discount:
                dynamicOffers.isEmpty ? 'Featured Store' : 'Special Offer',
            storeName: storeName.toUpperCase(),
            rating: double.parse(rating.toStringAsFixed(1)),
            reviews: reviewCount,
            title: dynamicOffers.isEmpty ? 'FEATURED' : 'SPECIAL',
          );

          dynamicOffers.add(offer);
          print('✅ Offer created for: ${offer.storeName}');
        } catch (e) {
          print('❌ Error loading offer for store $storeId: $e');
        }
      }

      print('🎯 Total offers loaded: ${dynamicOffers.length}');
      return dynamicOffers;
    } catch (e) {
      print('💥 Fatal error loading featured offers: $e');
      rethrow; // Re-throw to show in UI
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      currentIndex: 0,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(context),

              // Scrollable Content (refactored with pagination)
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshStores,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: const SizedBox(height: 16)),

                      // Following Section
                      SliverToBoxAdapter(
                        child: FutureBuilder<List<Store>>(
                          future: _followingFuture,
                          builder: (context, snap) {
                            if (!snap.hasData) {
                              return const SizedBox(
                                  height: 100,
                                  child: Center(
                                      child: CircularProgressIndicator()));
                            }
                            return _buildFollowingSection(context, snap.data!);
                          },
                        ),
                      ),

                      SliverToBoxAdapter(child: const SizedBox(height: 24)),

                      // Your Offers Section
                      SliverToBoxAdapter(
                          child: _buildYourOffersSection(context)),

                      SliverToBoxAdapter(child: const SizedBox(height: 24)),

                      // Seller Cards with pagination
                      SliverFillRemaining(
                        hasScrollBody: true,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: PaginatedFirestoreList<DocumentSnapshot>(
                            query: FirebaseFirestore.instance
                                .collection('stores')
                                .where('status', isEqualTo: 'active')
                                .orderBy('createdAt', descending: true),
                            pageSize: 10,
                            fromDoc: (doc) => doc,
                            emptyBuilder: (ctx) => const Center(
                                child: Text(
                                    'Одоогоор идэвхтэй дэлгүүр байхгүй байна')),
                            itemBuilder: (ctx, doc) {
                              return FutureBuilder<SellerData?>(
                                future: _storeDocToSellerData(doc),
                                builder: (context, snap) {
                                  if (!snap.hasData) {
                                    return const SizedBox.shrink();
                                  }
                                  final seller = snap.data!;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 24),
                                    child: _buildSellerCard(context, seller),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
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
          // Logo
          const Text(
            'Avii.mn',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Color.fromARGB(255, 22, 14, 179),
              letterSpacing: 0.5,
            ),
          ),

          // Right side actions
          Row(
            children: [
              // Balance
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Авий оноо')),
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
                    '₮0.00',
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsInboxPage(),
                    ),
                  );
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
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
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseAuth.FirebaseAuth.instance.currentUser !=
                              null
                          ? FirebaseFirestore.instance
                              .collection('notifications')
                              .where('userId',
                                  isEqualTo: FirebaseAuth
                                      .FirebaseAuth.instance.currentUser!.uid)
                              .where('read', isEqualTo: false)
                              .snapshots()
                          : null,
                      builder: (context, snapshot) {
                        final unreadCount = snapshot.data?.docs.length ?? 0;

                        if (unreadCount == 0) return const SizedBox.shrink();

                        return Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                                minWidth: 16, minHeight: 16),
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Profile
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/account');
                },
                child: const CircleAvatar(
                  radius: 20,
                  backgroundImage: AssetImage(
                    'assets/images/placeholders/ASAP.jpg',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFollowingSection(
      BuildContext context, List<Store> followingStores) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Following header
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                'Таны дагадаг дэлгүүрүүд',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.black87,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 20, color: Colors.black54),
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
            itemCount: followingStores.isNotEmpty ? followingStores.length : 1,
            separatorBuilder: (_, __) => const SizedBox(width: 7), // 7px gap
            itemBuilder: (context, index) {
              if (followingStores.isEmpty) {
                // show placeholder text
                return const Center(
                    child: Text("Та одоогоор ямар ч дэлгүүр дагаагүй байна"));
              }
              final store = followingStores[index];
              return GestureDetector(
                onTap: () {
                  _openStore(context, store.id);
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
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                'Онцлоx Дэлгүүрүүд:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.black87,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 20, color: Colors.black54),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Dynamic loading of offers
        FutureBuilder<List<Offer>>(
          future: _loadFeaturedOffers(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 191,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              print('Featured offers error: ${snapshot.error}');
              return SizedBox(
                height: 191,
                child: Center(
                  child: Text('Ачаалахад алдаа гарлаа: ${snapshot.error}'),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox(
                height: 191,
                child: Center(child: Text('Онцлоx дэлгүүрүүд байхгүй байна')),
              );
            }

            final offers = snapshot.data!;

            return SizedBox(
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
                      // Navigate to the actual store
                      _openStore(context, offer.id);
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
                          // Background image with 70% opacity
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Stack(
                              children: [
                                Image.network(
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
                                // 70% opacity overlay
                                Container(
                                  width: 185,
                                  height: 191,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    color: Colors.black.withOpacity(
                                        0.3), // 70% opacity = 30% overlay
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Content overlay
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 12,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
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
            );
          },
        ),
      ],
    );
  }

  Widget _buildSellerCard(BuildContext context, SellerData seller) {
    return SellerCard(
      sellerName: seller.name,
      profileLetter: seller.profileLetter,
      rating: seller.rating,
      reviews: seller.reviews,
      products: seller.products,
      storeId: seller.storeId,
      backgroundImageUrl: seller.backgroundImageUrl,
      storeLogoUrl: seller.storeLogoUrl, // Pass the store logo URL
      isRecommended: seller.isRecommended, // Pass the recommended flag
      onShopAllTap: () => _openStore(context, seller.storeId),
    );
  }

  Widget _buildProductCard(
      BuildContext context, SellerProduct product, SellerData seller) {
    return GestureDetector(
      onTap: () async {
        final doc = await FirebaseFirestore.instance
            .collection('products')
            .doc(product.id)
            .get();
        if (!doc.exists) return;
        final prodModel = ProductModel.fromFirestore(doc);
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductPage(
              product: prodModel,
              storeName: seller.name,
              storeLogoUrl: '',
              storeRating: seller.rating,
              storeRatingCount: seller.reviews,
            ),
          ),
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
                    const SnackBar(content: Text('Таалагдлаа!')),
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

  void _openStore(BuildContext context, String storeId) async {
    final storeDoc = await FirebaseFirestore.instance
        .collection('stores')
        .doc(storeId)
        .get();
    if (!storeDoc.exists) return;
    final storeModel = StoreModel.fromFirestore(storeDoc);

    final products = await _fetchProducts(storeModel.id, limit: 20);

    // Load collections for this store
    final collectionsSnapshot = await FirebaseFirestore.instance
        .collection('collections')
        .where('storeId', isEqualTo: storeModel.id)
        .where('isActive', isEqualTo: true)
        .get();

    final collections = collectionsSnapshot.docs
        .map((doc) => StoreCollection(
              id: doc.id,
              name: doc.data()['name'] ?? '',
              imageUrl: doc.data()['backgroundImage'] ?? '',
            ))
        .toList();

    // Load managed categories for this store
    final categoriesSnapshot = await FirebaseFirestore.instance
        .collection('store_categories')
        .where('storeId', isEqualTo: storeModel.id)
        .where('isActive', isEqualTo: true)
        .orderBy('sortOrder', descending: false)
        .orderBy('createdAt', descending: false)
        .get();

    final categoryNames = <String>['All'];
    categoryNames.addAll(
      categoriesSnapshot.docs
          .map((doc) => doc.data()['name'] as String? ?? '')
          .where((name) => name.isNotEmpty),
    );

    // Get actual rating data instead of hardcoded values
    final ratingData = await RatingService().getStoreRating(storeId);

    // Build StoreData for legacy StoreScreen
    final storeData = StoreData(
      id: storeModel.id,
      name: storeModel.name,
      displayName: storeModel.name.toUpperCase(),
      heroImageUrl:
          storeModel.banner.isNotEmpty ? storeModel.banner : storeModel.logo,
      backgroundColor: const Color(0xFF01BCE7),
      rating: ratingData.rating,
      reviewCount: ratingData.reviewCountDisplay,
      collections: collections,
      categories: categoryNames,
      productCount: products.length,
      products: products
          .map((p) => StoreProduct(
                id: p.id,
                name: p.name,
                imageUrl: p.images.isNotEmpty ? p.images.first : '',
                price: p.price,
                category: _getProductCategory(p.id, categoriesSnapshot.docs),
              ))
          .toList(),
      showFollowButton: true,
      hasNotification: false,
    );

    // Use Hours template for all stores (or add logic to choose template)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoreScreen(storeData: storeData),
      ),
    );
  }

  String _getProductCategory(
      String productId, List<QueryDocumentSnapshot> categoryDocs) {
    for (final doc in categoryDocs) {
      final data = doc.data() as Map<String, dynamic>?;
      final productIds = List<String>.from(data?['productIds'] ?? []);
      if (productIds.contains(productId)) {
        return data?['name'] as String? ?? '';
      }
    }
    return ''; // Product not in any category
  }

  // Convert store firestore doc to SellerData for paginator
  Future<SellerData?> _storeDocToSellerData(DocumentSnapshot doc) {
    final storeModel = StoreModel.fromFirestore(doc);
    return _convertStoreToSellerData(storeModel, isRecommended: false);
  }
}

// Data models
class SellerData {
  final String name;
  final String storeId;
  final String profileLetter;
  final double rating;
  final int reviews;
  final List<SellerProduct> products;
  final String? backgroundImageUrl;
  final String? storeLogoUrl; // Added store logo URL field
  final bool isAssetBg;
  final bool isRecommended; // Added recommended flag

  SellerData({
    required this.name,
    required this.storeId,
    required this.profileLetter,
    required this.rating,
    required this.reviews,
    required this.products,
    this.backgroundImageUrl,
    this.storeLogoUrl, // Added store logo URL parameter
    this.isAssetBg = false,
    this.isRecommended = false, // Default to false
  });
}
