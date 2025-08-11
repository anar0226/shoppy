import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'pages/admin_panel_layout.dart';
import 'auth/auth_service.dart';
import 'auth/unified_auth_page.dart';
import 'auth/verify_email_page.dart';
import 'auth/reset_password_page.dart';
import 'widgets/store_setup_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../features/settings/providers/app_settings_provider.dart';
import '../features/settings/themes/app_themes.dart';
// import '../l10n/generated/app_localizations.dart'; // Will be generated after build

class AdminApp extends StatefulWidget {
  const AdminApp({super.key});

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  Future<bool> _isSuperAdmin(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('super_admins')
          .doc(uid)
          .get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _hasStore(String uid) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('stores')
          .where('ownerId', isEqualTo: uid)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _hasAdminAccess(String uid) async {
    final isAdmin = await _isSuperAdmin(uid);
    if (isAdmin) return true;
    return _hasStore(uid);
  }

  Future<bool> _needsStoreSetup(String uid) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('stores')
          .where('ownerId', isEqualTo: uid)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return false; // no store -> not applicable here

      final storeData = snap.docs.first.data();
      final status = storeData['status'] ?? '';
      final name = storeData['name'] ?? '';

      return status == 'setup_pending' || name.isEmpty;
    } catch (e) {
      return false; // On error, proceed to dashboard
    }
  }

  Widget _accessDenied() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline,
                  size: 48, color: Color(0xFF4285F4)),
              const SizedBox(height: 16),
              const Text(
                'Админы хэсэг зөвхөн дэлгүүрийн эзэмшигч болон супер админуудад зориулагдсан.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Та мобайл хэрэглэгчийн эрхээр нэвтэрсэн байж магадгүй. Супер админтай холбогдоно уу.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  await AuthService.instance.signOut();
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4285F4)),
                child: const Text('Гарах'),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppSettingsProvider(),
      child: Consumer<AppSettingsProvider>(
        builder: (context, settings, child) {
          // Handle Firebase action links (e.g., reset password) on web
          final uri = Uri.base;
          final mode = uri.queryParameters['mode'];
          if (mode == 'resetPassword') {
            return const MaterialApp(
              debugShowCheckedModeBanner: false,
              home: ResetPasswordPage(),
            );
          }

          return MaterialApp(
            title: 'Avii.mn Admin',
            theme: AppThemes.lightTheme,
            darkTheme: AppThemes.darkTheme,
            themeMode: settings.themeMode,
            debugShowCheckedModeBanner: false,

            // Internationalization (temporarily disabled until generated)
            locale: settings.locale,
            localizationsDelegates: const [
              // AppLocalizations.delegate, // Will be enabled after generation
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppSettingsProvider.supportedLocales,
            home: StreamBuilder<User?>(
              stream: AuthService.instance.authStateChanges,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                      body: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasData) {
                  final user = snapshot.data;
                  if (user != null && user.emailVerified) {
                    return FutureBuilder<bool>(
                      future: _hasAdminAccess(user.uid),
                      builder: (context, accessSnapshot) {
                        if (accessSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Scaffold(
                              body: Center(child: CircularProgressIndicator()));
                        }

                        final hasAccess = accessSnapshot.data ?? false;
                        if (!hasAccess) {
                          return _accessDenied();
                        }

                        return FutureBuilder<bool>(
                          future: _needsStoreSetup(user.uid),
                          builder: (context, setupSnapshot) {
                            if (setupSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Scaffold(
                                  body: Center(
                                      child: CircularProgressIndicator()));
                            }

                            final needsSetup = setupSnapshot.data ?? false;
                            if (needsSetup) {
                              return _StoreSetupWrapper(userId: user.uid);
                            }

                            return const AdminPanelLayout();
                          },
                        );
                      },
                    );
                  } else {
                    return const VerifyEmailPage();
                  }
                } else {
                  return const UnifiedAuthPage();
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class _StoreSetupWrapper extends StatefulWidget {
  final String userId;

  const _StoreSetupWrapper({required this.userId});

  @override
  State<_StoreSetupWrapper> createState() => _StoreSetupWrapperState();
}

class _StoreSetupWrapperState extends State<_StoreSetupWrapper> {
  bool _setupCompleted = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showSetupDialog());
  }

  Future<void> _showSetupDialog() async {
    // Get store ID (assume exists due to access gate)
    final snap = await FirebaseFirestore.instance
        .collection('stores')
        .where('ownerId', isEqualTo: widget.userId)
        .limit(1)
        .get();

    if (mounted) {
      if (snap.docs.isEmpty) {
        // Nothing to setup
        setState(() {
          _setupCompleted = true;
        });
        return;
      }
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => StoreSetupDialog(storeId: snap.docs.first.id),
      );

      if (result == true && mounted) {
        setState(() {
          _setupCompleted = true;
        });
      } else if (mounted) {
        setState(() {
          _setupCompleted = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_setupCompleted) {
      return const AdminPanelLayout();
    }

    // Still waiting for setup completion
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
