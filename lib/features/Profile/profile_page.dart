import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shoppy/features/home/presentation/main_scaffold.dart';
import 'package:shoppy/features/settings/settings_page.dart';
import 'package:shoppy/features/Profile/widgets/edit_profile_popup.dart';
import 'package:shoppy/features/payment/add_card_page.dart';

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
                SizedBox(
                  width: 185,
                  height: 108,
                  child: Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'Хадагласан Бараанууд',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 186,
                  height: 108,
                  child: Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'Дагдаг Дэлгүүрүүд',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
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
            SizedBox(
              height: 119,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _recentlyViewedCard(
                      'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=400'),
                  _recentlyViewedCard(
                      'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=400',
                      price: '\$57.00'),
                  _recentlyViewedCard(
                      'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=400'),
                ],
              ),
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

  Widget _recentlyViewedCard(String imageUrl, {String? price}) {
    return Container(
      width: 119,
      margin: EdgeInsets.only(right: 12),
      child: Stack(
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: EdgeInsets.all(8),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                height: 119,
                width: 119,
                fit: BoxFit.cover,
              ),
            ),
          ),
          if (price != null)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(price,
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }
}
