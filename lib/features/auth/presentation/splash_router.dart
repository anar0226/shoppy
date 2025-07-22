import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import 'login_page.dart';
import '../../home/presentation/home_screen.dart';

class SplashRouter extends StatefulWidget {
  const SplashRouter({Key? key}) : super(key: key);

  @override
  State<SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<SplashRouter> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    final auth = context.read<AuthProvider>();
    // We allow 1 second splash
    await Future.delayed(const Duration(milliseconds: 800));
    final prefs = await SharedPreferences.getInstance();
    final bool? seenOnboarding = prefs.getBool('seen_onboarding');

    if (auth.user != null) {
      // Check if authenticated user needs profile completion
      if (auth.needsProfileCompletion) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/profile-completion');
        }
      } else {
        if (mounted) {
          Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
      }
    } else if (seenOnboarding == true) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginPage()));
      }
    } else {
      // For now, navigate to login and set flag
      await prefs.setBool('seen_onboarding', true);
      if (mounted) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginPage()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: FlutterLogo(size: 64),
      ),
    );
  }
}
