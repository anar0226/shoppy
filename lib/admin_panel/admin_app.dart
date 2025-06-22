import 'package:flutter/material.dart';
import 'pages/dashboard_page.dart';
import 'auth/auth_service.dart';
import 'auth/login_page.dart';
import 'auth/verify_email_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shoppy Admin',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: StreamBuilder(
        stream: AuthService.instance.authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            final user = snapshot.data as User?;
            if (user != null && user.emailVerified) {
              return const DashboardPage();
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
}
