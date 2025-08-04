import 'package:flutter/material.dart';
import 'package:avii/features/home/presentation/floating_nav_bar.dart';
import 'package:provider/provider.dart';
import 'package:avii/features/addresses/presentation/manage_addresses_page.dart';
import 'package:avii/features/auth/providers/auth_provider.dart';
import 'package:avii/features/auth/presentation/login_page.dart';
import 'package:avii/features/settings/notifications_page.dart';
import 'package:avii/legal/terms_and_conditions_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<_SettingsItem> items = [
      _SettingsItem(Icons.location_on, "Хүргэлтийн хаяг"),
      _SettingsItem(Icons.notifications, "Мэдэгдэл"),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              children: [
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    "Тохиргоо",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.4,
                  children: items.asMap().entries.map((entry) {
                    int index = entry.key;
                    _SettingsItem item = entry.value;
                    return GestureDetector(
                      onTap: () {
                        switch (index) {
                          case 0: // Хүргэлтийн хаяг (Addresses)
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ManageAddressesPage(),
                              ),
                            );
                            break;
                          case 1: // Мэдэгдэл (Notifications)
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const NotificationsPage(),
                              ),
                            );
                            break;
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4285F4).withValues(
                                  alpha: 0.07), // Primary blue color
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(item.icon,
                                size: 28,
                                color: const Color(
                                    0xFF4285F4)), // Primary blue color
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                item.label,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 40),
                Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      await context.read<AuthProvider>().signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                          (_) => false,
                        );
                      }
                    },
                    icon: const Icon(Icons.logout,
                        color: Color(0xFF4285F4)), // Primary blue color
                    label: const Text(
                      "Гарах",
                      style: TextStyle(
                        color: Color(0xFF4285F4), // Primary blue color
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          const Color(0xFF4285F4), // Primary blue color
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    "1.0.0",
                    style: TextStyle(
                      color: Color(0xFF4285F4), // Primary blue color
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Wrap(
                    spacing: 24,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const TermsAndConditionsPage(),
                            ),
                          );
                        },
                        child: const Text(
                          "Ерөнхий нөхцлүүд",
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            color: Color(0xFF4285F4), // Primary blue color
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text(
                          "Лиценз",
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            color: Color(0xFF4285F4), // Primary blue color
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
            // Floating nav bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FloatingNavBar(
                currentIndex: -1,
                onTap: (index) {
                  const routes = ['/home', '/search', '/orders'];
                  Navigator.pushReplacementNamed(context, routes[index]);
                },
              ),
            ),
            // Back button
            Positioned(
              left: 24,
              bottom: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4285F4)
                            .withValues(alpha: 0.1), // Primary blue color
                        blurRadius: 10,
                      )
                    ],
                  ),
                  child: const Icon(Icons.arrow_back,
                      color: Color(0xFF4285F4)), // Primary blue color
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String label;
  _SettingsItem(this.icon, this.label);
}
