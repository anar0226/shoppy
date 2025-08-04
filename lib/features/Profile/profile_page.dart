// ignore_for_file: prefer_const_constructors

import 'dart:io';
import 'package:flutter/material.dart';

import 'package:avii/features/home/presentation/main_scaffold.dart';
import 'package:avii/features/settings/settings_page.dart';
import 'package:avii/features/saved/saved_screen.dart';
import 'package:avii/features/Profile/widgets/edit_profile_popup.dart';
import 'package:avii/features/products/presentation/product_page.dart';
import 'package:provider/provider.dart';
import 'package:avii/features/profile/providers/recently_viewed_provider.dart';
import 'package:avii/features/auth/providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:avii/features/stores/models/store_model.dart';
import 'package:avii/features/following/following_screen.dart';
import 'package:avii/core/constants/assets.dart';
import '../../core/services/error_handler_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Future<List<String>>? _followedStoresFuture;
  Future<List<String>>? _savedFuture;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    if (auth.user != null) {
      _followedStoresFuture = _getFollowedStores(auth.user!.uid);
      _savedFuture = _getSavedImages(auth.user!.uid);
    }
  }

  Future<List<String>> _getFollowedStores(String uid) async {
    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final List<dynamic> storeIds = userDoc.data()?['followerStoreIds'] ?? [];

      if (storeIds.isEmpty) return [];

      final storesSnapshot = await FirebaseFirestore.instance
          .collection('stores')
          .where(FieldPath.documentId, whereIn: storeIds)
          .get();

      return storesSnapshot.docs
          .map((doc) => StoreModel.fromFirestore(doc).logo)
          .toList();
    } catch (e) {
      await ErrorHandlerService.instance.handleError(
        operation: 'get_followed_stores',
        error: e,
        showUserMessage: false,
        logError: true,
        fallbackValue: <String>[],
      );
      return [];
    }
  }

  Future<List<String>> _getSavedImages(String uid) async {
    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final List<dynamic> productIds = userDoc.data()?['savedProductIds'] ?? [];
      if (productIds.isEmpty) return [];
      final prodSnap = await FirebaseFirestore.instance
          .collection('products')
          .where(FieldPath.documentId, whereIn: productIds)
          .get();
      return prodSnap.docs.map((d) {
        final images = List<String>.from(d.data()['images'] ?? []);
        return images.isNotEmpty ? images.first : '';
      }).toList();
    } catch (e) {
      await ErrorHandlerService.instance.handleError(
        operation: 'get_saved_images',
        error: e,
        showUserMessage: false,
        logError: true,
        fallbackValue: <String>[],
      );
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final String userName = user?.displayName ?? 'Guest';
    final String userEmail = user?.email ?? '';
    final String? userAvatarUrl = user?.photoURL;

    return MainScaffold(
      currentIndex: 3, // no icon highlighted in the bottom bar
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Color(0xFF4285F4), // Primary blue color
          title: const Text('Профайл'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          children: [
            SizedBox(height: 15),
            // Top Row: User Info, Buttons, and Avatar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userName,
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold)),
                    Text(userEmail,
                        style:
                            TextStyle(fontSize: 16, color: Colors.grey[600])),
                    SizedBox(height: 6),
                    // Settings & Profile Buttons
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SettingsPage()),
                            );
                          },
                          icon: Icon(Icons.settings,
                              color: Color(0xFF4285F4),
                              size: 14), // Primary blue color
                          label: Text('Тохиргоо',
                              style: TextStyle(
                                  color: Color(0xFF4285F4),
                                  fontSize: 10)), // Primary blue color
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.grey.shade50, // Light grey background
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                    color: Color(0xFF4285F4),
                                    width: 1)), // Blue outline
                            fixedSize: Size(90, 30),
                            padding: EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                        SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            showEditProfilePopup(
                                context, userName, userAvatarUrl ?? '');
                          },
                          icon: Icon(Icons.person,
                              color: Color(0xFF4285F4),
                              size: 14), // Primary blue color
                          label: Text('Профайл',
                              style: TextStyle(
                                  color: Color(0xFF4285F4),
                                  fontSize: 10)), // Primary blue color
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.grey.shade50, // Light grey background
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                                side: BorderSide(
                                    color: Color(0xFF4285F4),
                                    width: 1)), // Blue outline
                            fixedSize: Size(90, 30),
                            padding: EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => showEditProfilePopup(
                      context, userName, userAvatarUrl ?? ''),
                  child: CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: (userAvatarUrl != null &&
                            userAvatarUrl.isNotEmpty)
                        ? (userAvatarUrl.startsWith('http')
                            ? NetworkImage(userAvatarUrl)
                            : FileImage(File(userAvatarUrl))) as ImageProvider
                        : const AssetImage(AppAssets.defaultProfilePicture),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            // Saved & Following Cards
            Row(
              children: [
                FutureBuilder<List<String>>(
                  future: _savedFuture,
                  builder: (context, snap) {
                    final icons = snap.data ?? [];
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SavedScreen()),
                      ),
                      child: _iconCard(context, title: 'Saved', icons: icons),
                    );
                  },
                ),
                const SizedBox(width: 8),
                FutureBuilder<List<String>>(
                  future: _followedStoresFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }
                    final icons = snapshot.data ?? [];
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const FollowingScreen()),
                      ),
                      child:
                          _iconCard(context, title: 'Following', icons: icons),
                    );
                  },
                ),
              ],
            ),
            SizedBox(height: 24),
            // Recently Viewed
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: const [
                Text('Үзсэн Бараанууд',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios, size: 16),
              ],
            ),
            SizedBox(height: 12),
            Consumer<RecentlyViewedProvider>(
              builder: (_, recent, __) {
                if (recent.items.isEmpty) {
                  return Text('Үзсэн бараа байхгүй байна',
                      style: TextStyle(color: Colors.grey[600]));
                }
                return SizedBox(
                  height: 119,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: recent.items.length,
                    itemBuilder: (context, index) {
                      final product = recent.items[index];
                      return GestureDetector(
                        onTap: () {
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
                        },
                        child: _recentlyViewedCard(product.images.isNotEmpty
                            ? product.images.first
                            : ''),
                      );
                    },
                  ),
                );
              },
            ),
            SizedBox(height: 24),
            // Payment Methods
            Text('Төлбөрийн аргууд',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            // QPay and StorePay Icons
            Row(
              children: [
                Expanded(
                  child: _paymentMethodCard(
                    title: 'QPay',
                    subtitle: 'Цахим төлбөр',
                    backgroundColor:
                        Colors.grey.shade50, // Light grey background
                    iconColor: const Color(0xFF4285F4),
                    iconWidget: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/images/logos/QPAY.png',
                          width: 50,
                          height: 50,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4285F4),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Text(
                                  'QPay',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _paymentMethodCard(
                    title: 'StorePay',
                    subtitle: 'Тун удахгүй',
                    backgroundColor:
                        Colors.grey.shade50, // Light grey background
                    iconColor: const Color(0xFF4285F4),
                    iconWidget: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/images/logos/STOREPAY.png',
                          width: 50,
                          height: 50,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4285F4),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Text(
                                  'Store\nPay',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 32),

            // Support Section
            SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Тусламж',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/support');
                      },
                      icon: const Icon(Icons.support_agent, size: 20),
                      label: const Text('Холбоо барих'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.grey.shade50, // Light grey background
                        foregroundColor:
                            Color(0xFF4285F4), // Primary blue color
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                              color: Color(0xFF4285F4),
                              width: 1), // Blue outline
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _iconCard(BuildContext context,
      {required String title, required List<String> icons}) {
    // Calculate how many icons can fit in the card width
    // Card width is 185, with 12 padding on each side = 161 available width
    // Each icon is 40 wide + 4 padding between = 44 per icon except last one
    const cardWidth = 185.0;
    const horizontalPadding = 24.0; // 12 on each side
    const iconWidth = 40.0;
    const iconSpacing = 4.0;

    const availableWidth = cardWidth - horizontalPadding;
    final maxIcons =
        ((availableWidth + iconSpacing) / (iconWidth + iconSpacing)).floor();
    final displayIcons = icons.take(maxIcons).toList();

    return SizedBox(
      width: cardWidth,
      height: 108,
      child: Card(
        color: Colors.grey.shade50, // Light grey background
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Color(0xFF4285F4), width: 1), // Blue outline
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: displayIcons.isEmpty
                      ? [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              title == 'Saved'
                                  ? Icons.bookmark_border
                                  : Icons.store_outlined,
                              color: Colors.grey.shade400,
                              size: 20,
                            ),
                          )
                        ]
                      : displayIcons.asMap().entries.map((entry) {
                          final index = entry.key;
                          final url = entry.value;

                          return Padding(
                            padding: EdgeInsets.only(
                              right: index < displayIcons.length - 1
                                  ? iconSpacing
                                  : 0,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: url.isEmpty
                                  ? Container(
                                      color: Colors.grey.shade200,
                                      width: iconWidth,
                                      height: 40,
                                    )
                                  : (url.startsWith('http')
                                      ? FadeInImage.assetNetwork(
                                          placeholder:
                                              'assets/images/placeholders/1px.png',
                                          image: url,
                                          width: iconWidth,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          imageCacheWidth: 80,
                                          fadeInDuration:
                                              const Duration(milliseconds: 200),
                                          fadeInCurve: Curves.easeIn,
                                        )
                                      : Image.asset(url,
                                          width: iconWidth,
                                          height: 40,
                                          fit: BoxFit.cover)),
                            ),
                          );
                        }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  if (icons.length > maxIcons)
                    Text(
                      '+${icons.length - maxIcons}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recentlyViewedCard(String url) {
    Widget thumb;
    if (url.startsWith('http')) {
      thumb = FadeInImage.assetNetwork(
        placeholder:
            'assets/images/placeholders/1px.png', // 1×1 transparent png
        image: url,
        width: 119,
        height: 119,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.none,
        imageCacheWidth: 120,
      );
    } else if (url.isNotEmpty) {
      thumb = Image.asset(url,
          width: 119,
          height: 119,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.none);
    } else {
      thumb = Container(color: Colors.grey.shade200);
    }

    return SizedBox(
      width: 119,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: thumb,
      ),
    );
  }

  Widget _paymentMethodCard({
    required String title,
    required String subtitle,
    required Color backgroundColor,
    required Color iconColor,
    required Widget iconWidget,
  }) {
    return Container(
      height: 130,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color(0xFF4285F4), // Blue outline
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          iconWidget,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: iconColor.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
