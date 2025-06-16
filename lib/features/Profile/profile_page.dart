import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shoppy/features/home/presentation/main_scaffold.dart';
import 'package:shoppy/features/settings/settings_page.dart';
import 'package:shoppy/features/Profile/widgets/edit_profile_popup.dart';
import 'package:shoppy/features/payment/add_card_page.dart';
import 'package:shoppy/features/products/presentation/product_page.dart';
import 'package:provider/provider.dart';
import 'package:shoppy/features/profile/providers/recently_viewed_provider.dart';

class ProfilePage extends StatelessWidget {
  // Replace with your user data
  final String userName = 'ASAP';
  final String userEmail = 'anar0226@gmail.com';
  final String userAvatarUrl = 'assets/images/placeholders/ASAP.jpg';

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      currentIndex: 3, // no icon highlighted in the bottom bar
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black,
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
                              color: Colors.black, size: 14),
                          label: Text('Тохиргоо',
                              style:
                                  TextStyle(color: Colors.black, fontSize: 10)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[200],
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            fixedSize: Size(90, 30),
                            padding: EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                        SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            showEditProfilePopup(
                                context, userName, userAvatarUrl);
                          },
                          icon:
                              Icon(Icons.person, color: Colors.black, size: 14),
                          label: Text('Профайл',
                              style:
                                  TextStyle(color: Colors.black, fontSize: 10)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[200],
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4)),
                            fixedSize: Size(90, 30),
                            padding: EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                CircleAvatar(
                  radius: 45,
                  backgroundImage: AssetImage(userAvatarUrl),
                ),
              ],
            ),
            SizedBox(height: 24),
            // Saved & Following Cards
            Row(
              children: [
                _iconCard(context, title: 'Saved', icons: []),
                const SizedBox(width: 8),
                _iconCard(context, title: 'Following', icons: []),
              ],
            ),
            SizedBox(height: 24),
            // Recently Viewed
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
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
                  return const Text('No recently viewed items');
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Төлбөрийн аргууд',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ElevatedButton(
                  onPressed: () {},
                  child: Text('+', style: TextStyle(color: Colors.black)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    elevation: 0,
                    shape: StadiumBorder(),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            // Card placeholder with Add Card button
            Container(
              height: 240,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                image: const DecorationImage(
                  image: AssetImage('assets/images/icons/creditcard.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddCardPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                    minimumSize: const Size(20, 10),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'Add Card',
                    style: TextStyle(fontSize: 10, color: Colors.black),
                  ),
                ),
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
    return SizedBox(
      width: 185,
      height: 108,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children:
                      (icons.isNotEmpty ? icons : ['']).take(4).map((url) {
                    if (url.isEmpty) {
                      return const SizedBox(width: 40, height: 40);
                    }
                    return Padding(
                      padding: const EdgeInsets.only(right: 4.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: url.isEmpty
                            ? Container(
                                color: Colors.grey.shade200,
                                width: 40,
                                height: 40)
                            : (url.startsWith('http')
                                ? FadeInImage.assetNetwork(
                                    placeholder:
                                        'assets/images/placeholders/1px.png',
                                    image: url,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    imageCacheWidth: 80,
                                    fadeInDuration:
                                        const Duration(milliseconds: 200),
                                    fadeInCurve: Curves.easeIn,
                                  )
                                : Image.asset(url,
                                    width: 40, height: 40, fit: BoxFit.cover)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
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

  Widget _smartImage(String url,
      {required double height, required double width}) {
    if (url.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: url,
        height: height,
        width: width,
        fit: BoxFit.cover,
      );
    } else if (url.isNotEmpty) {
      return Image.asset(
        url,
        height: height,
        width: width,
        fit: BoxFit.cover,
      );
    } else {
      return Container(
        color: Colors.grey.shade200,
        height: height,
        width: width,
      );
    }
  }
}
