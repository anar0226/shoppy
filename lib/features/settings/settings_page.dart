import 'package:flutter/material.dart';
import 'package:shoppy/features/home/presentation/floating_nav_bar.dart';
import 'package:provider/provider.dart';
import 'package:shoppy/features/theme/theme_provider.dart';
import 'package:shoppy/features/addresses/presentation/manage_addresses_page.dart';
import 'package:shoppy/features/auth/providers/auth_provider.dart';
import 'package:shoppy/features/auth/presentation/login_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<_SettingsItem> items = [
      _SettingsItem(Icons.location_on, "Addresses"),
      _SettingsItem(Icons.notifications, "Notifications"),
      _SettingsItem(Icons.verified_user, "Data and privacy"),
      _SettingsItem(Icons.language, "Language"),
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
                    "Settings",
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
                  children: items.map((item) {
                    return GestureDetector(
                      onTap: () {
                        if (item.label == 'Addresses') {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ManageAddressesPage(),
                            ),
                          );
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.07),
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
                            Icon(item.icon, size: 28, color: Colors.black),
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
                // Dark mode toggle
                Consumer<ThemeProvider>(
                  builder: (_, themeProv, __) => SwitchListTile(
                    value: themeProv.mode == ThemeMode.dark,
                    onChanged: (_) => themeProv.toggle(),
                    title: const Text('Dark mode',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w500)),
                  ),
                ),
                const SizedBox(height: 20),
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
                    icon: const Icon(Icons.logout, color: Colors.black),
                    label: const Text(
                      "Sign out",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    "Version 2.204.0-release.93253",
                    style: TextStyle(
                      color: Colors.black54,
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
                        onPressed: () {},
                        child: const Text(
                          "Terms and conditions",
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text(
                          "Licenses",
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            color: Colors.black87,
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
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                      )
                    ],
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.black),
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
