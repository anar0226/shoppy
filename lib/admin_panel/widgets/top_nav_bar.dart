import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/auth_service.dart';
import '../auth/login_page.dart';

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
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.center,
        height: preferredSize.height,
        child: Row(
          children: [
            Text(title,
                style: theme.textTheme.headlineSmall!
                    .copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            SizedBox(
              width: 360,
              height: 40,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
            const SizedBox(width: 24),
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_none_outlined),
                  onPressed: () {},
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(minWidth: 16),
                    child: const Text('2',
                        style: TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
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
                final user = FirebaseAuth.instance.currentUser;
                return [
                  PopupMenuItem<String>(
                    value: 'email',
                    enabled: false,
                    child: Text(user?.email ?? 'No email'),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'signout',
                    child: Text('Sign out'),
                  ),
                ];
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey.shade300,
                child: const Icon(Icons.person, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
