import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'pages/admin_panel_layout.dart';
import 'auth/auth_service.dart';
import 'auth/unified_auth_page.dart';
import 'auth/verify_email_page.dart';
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
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppSettingsProvider(),
      child: Consumer<AppSettingsProvider>(
        builder: (context, settings, child) {
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
                      future: _checkStoreSetup(user.uid),
                      builder: (context, storeSnapshot) {
                        if (storeSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Scaffold(
                              body: Center(child: CircularProgressIndicator()));
                        }

                        final needsSetup = storeSnapshot.data ?? false;
                        if (needsSetup) {
                          return _StoreSetupWrapper(userId: user.uid);
                        }

                        return const AdminPanelLayout();
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

  Future<bool> _checkStoreSetup(String userId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('stores')
          .where('ownerId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return true; // No store exists

      final storeData = snap.docs.first.data();
      final status = storeData['status'] ?? '';
      final name = storeData['name'] ?? '';

      return status == 'setup_pending' || name.isEmpty;
    } catch (e) {
      return false; // On error, proceed to dashboard
    }
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
    // Get store ID
    final snap = await FirebaseFirestore.instance
        .collection('stores')
        .where('ownerId', isEqualTo: widget.userId)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty && mounted) {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => StoreSetupDialog(storeId: snap.docs.first.id),
      );

      if (result == true && mounted) {
        // Mark setup as completed so that build shows dashboard immediately
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
