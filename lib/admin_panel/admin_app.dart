import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pages/dashboard_page.dart';
import 'auth/auth_service.dart';
import 'auth/login_page.dart';
import 'auth/verify_email_page.dart';
import 'widgets/store_setup_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminApp extends StatefulWidget {
  const AdminApp({super.key});

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shoppy Admin',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<User?>(
        stream: AuthService.instance.authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            final user = snapshot.data as User?;
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

                  return const DashboardPage();
                },
              );
            } else {
              return const VerifyEmailPage();
            }
          } else {
            return const LoginPage();
          }
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
        // Setup completed, rebuild to show dashboard
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
