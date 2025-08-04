import 'package:flutter/material.dart';
import '../auth/super_admin_auth_service.dart';

// Simple wrapper for compatibility with existing backup management page
class SideMenu extends StatelessWidget {
  final String selected;

  const SideMenu({super.key, required this.selected});

  @override
  Widget build(BuildContext context) {
    return SuperAdminSideMenu(
      currentPage: selected,
      onPageSelected: (page) {
        // Simple navigation - you can enhance this later
        // Navigation to $page
      },
    );
  }
}

class SuperAdminSideMenu extends StatelessWidget {
  final String currentPage;
  final Function(String) onPageSelected;

  const SuperAdminSideMenu({
    super.key,
    required this.currentPage,
    required this.onPageSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          right: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  color: Colors.white,
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'Super Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildMenuItem(
                  'Dashboard',
                  Icons.dashboard,
                  'Dashboard',
                ),
                _buildMenuItem(
                  'Orders',
                  Icons.receipt_long,
                  'Orders',
                ),
                _buildMenuItem(
                  'Featured',
                  Icons.star,
                  'Featured',
                ),
                _buildMenuItem(
                  'Subscriptions',
                  Icons.subscriptions,
                  'Subscriptions',
                ),
                _buildMenuItem(
                  'KYC Verification',
                  Icons.verified_user,
                  'KYC Verification',
                ),
                _buildMenuItem(
                  'Payment Management',
                  Icons.payment,
                  'Payment',
                ),
                _buildMenuItem(
                  'Backup Management',
                  Icons.backup,
                  'Backup Management',
                ),
                const Divider(height: 32),
                _buildMenuItem(
                  'Settings',
                  Icons.settings,
                  'Settings',
                ),
              ],
            ),
          ),

          // Logout Button
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final shouldLogout = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );

                  if (shouldLogout == true) {
                    await SuperAdminAuthService.instance.logout();
                    // The app will automatically redirect to login
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red.shade300),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(String title, IconData icon, String pageKey) {
    final isSelected = currentPage == pageKey;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Colors.blue.shade600 : Colors.grey.shade600,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.blue.shade600 : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        selectedTileColor: Colors.blue.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        onTap: () => onPageSelected(pageKey),
      ),
    );
  }
}
