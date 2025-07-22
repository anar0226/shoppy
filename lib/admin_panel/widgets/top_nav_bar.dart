import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../auth/auth_service.dart';
import '../auth/login_page.dart';
import '../services/notification_service.dart';
import '../../features/settings/providers/app_settings_provider.dart';
import '../../features/settings/themes/app_themes.dart';

class TopNavBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  const TopNavBar({super.key, this.title = 'Home'});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 0,
      color: AppThemes.getSurfaceColor(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.center,
        height: preferredSize.height,
        child: Row(
          children: [
            Text(title,
                style: theme.textTheme.headlineSmall!.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppThemes.getTextColor(context),
                )),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 360),
                height: 40,
                child: TextField(
                  style: TextStyle(color: AppThemes.getTextColor(context)),
                  decoration: InputDecoration(
                    hintText: 'Search',
                    hintStyle: TextStyle(
                        color: AppThemes.getSecondaryTextColor(context)),
                    prefixIcon: Icon(Icons.search,
                        color: AppThemes.getSecondaryTextColor(context)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: AppThemes.getBorderColor(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: AppThemes.getBorderColor(context)),
                    ),
                    fillColor: AppThemes.getCardColor(context),
                    filled: true,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),
            StreamBuilder<int>(
              stream: NotificationService().getUnreadCount(),
              builder: (context, snapshot) {
                final unreadCount = snapshot.data ?? 0;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: Icon(Icons.notifications_none_outlined,
                          color: AppThemes.getTextColor(context)),
                      onPressed: () => _showNotificationsDropdown(context),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          constraints: const BoxConstraints(minWidth: 16),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(width: 8),

            // Settings dropdown
            PopupMenuButton<String>(
              icon:
                  Icon(Icons.settings, color: AppThemes.getTextColor(context)),
              tooltip: 'Settings',
              offset: const Offset(0, 40),
              onSelected: (value) {
                final settings =
                    Provider.of<AppSettingsProvider>(context, listen: false);
                switch (value) {
                  case 'toggle_theme':
                    settings.toggleTheme();
                    break;
                  case 'toggle_language':
                    settings.toggleLanguage();
                    break;
                }
              },
              itemBuilder: (context) {
                final settings =
                    Provider.of<AppSettingsProvider>(context, listen: false);
                return [
                  PopupMenuItem<String>(
                    value: 'toggle_theme',
                    child: Row(
                      children: [
                        Icon(
                          settings.isDarkMode
                              ? Icons.light_mode
                              : Icons.dark_mode,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(settings.isDarkMode ? 'Light Mode' : 'Dark Mode'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'toggle_language',
                    child: Row(
                      children: [
                        const Icon(Icons.language, size: 20),
                        const SizedBox(width: 12),
                        Text(settings.languageCode == 'en'
                            ? 'Mongolian'
                            : 'English'),
                      ],
                    ),
                  ),
                ];
              },
            ),

            const SizedBox(width: 8),
            // Display user name if available
            Builder(builder: (_) {
              final user = FirebaseAuth.instance.currentUser;
              final name = user?.displayName ?? user?.email ?? 'User';
              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: Text(name,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppThemes.getTextColor(context),
                    )),
              );
            }),
            PopupMenuButton<String>(
              offset: const Offset(0, 40),
              tooltip: 'Account',
              onSelected: (value) async {
                if (value == 'signout') {
                  await AuthService.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                      (route) => false,
                    );
                  }
                }
              },
              itemBuilder: (context) {
                return [
                  PopupMenuItem<String>(
                    value: 'email',
                    enabled: false,
                    child: Text(
                        FirebaseAuth.instance.currentUser?.email ?? 'No email'),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'signout',
                    child: Text('Гарах'),
                  ),
                ];
              },
              child: Builder(builder: (_) {
                final user = FirebaseAuth.instance.currentUser;
                final photoUrl = user?.photoURL;
                return CircleAvatar(
                  radius: 18,
                  backgroundColor: photoUrl == null || photoUrl.isEmpty
                      ? Colors.grey.shade300
                      : Colors.transparent,
                  backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                      ? NetworkImage(photoUrl)
                      : null,
                  child: (photoUrl == null || photoUrl.isEmpty)
                      ? const Icon(Icons.person, color: Colors.black)
                      : null,
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationsDropdown(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const NotificationsDialog(),
    );
  }
}

class NotificationsDialog extends StatelessWidget {
  const NotificationsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: 400,
        height: 500,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Мэдэгдэл',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () async {
                        await NotificationService().markAllAsRead();
                      },
                      tooltip: 'Уншсан гэж тэмдэглэх',
                      icon: const Icon(Icons.done_all),
                    ),
                    IconButton(
                      onPressed: () async {
                        // Show confirmation dialog
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Устгах'),
                            content: const Text(
                              'Бүх мэдэгдэл устгах уу?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('Цуцалгах'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('Бүгдийг устгах'),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true) {
                          await NotificationService().clearAllNotifications();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Бүх мэдэгдэл устгагдлаа')),
                            );
                          }
                        }
                      },
                      tooltip: 'Бүгдийг устгах',
                      icon: const Icon(Icons.delete_sweep, color: Colors.red),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Хаах',
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: StreamBuilder<List<NotificationModel>>(
                stream: NotificationService().getNotifications(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final notifications = snapshot.data ?? [];

                  if (notifications.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Мэдэгдэл байхгүй',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return _buildNotificationItem(context, notification);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(
      BuildContext context, NotificationModel notification) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: notification.isRead
            ? Colors.transparent
            : Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: notification.isRead
              ? Colors.grey.shade200
              : Colors.blue.withValues(alpha: 0.2),
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: notification.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            notification.icon,
            color: notification.color,
            size: 20,
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight:
                notification.isRead ? FontWeight.normal : FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.message,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              notification.timeAgo,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        onTap: () async {
          if (!notification.isRead) {
            await NotificationService().markAsRead(notification.id);
          }
          // Handle notification tap based on type
          if (notification.type == NotificationType.order) {
            // Navigate to order details
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          }
        },
        trailing: !notification.isRead
            ? Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              )
            : null,
      ),
    );
  }
}
