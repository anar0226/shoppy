import 'package:flutter/material.dart';
import 'auth_service.dart';
import '../pages/dashboard_page.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool _sent = false;
  bool _checking = false;
  String? _msg;

  Future<void> _send() async {
    await AuthService.instance.sendEmailVerification();
    setState(() {
      _sent = true;
      _msg = 'Имэйл баталгаажуулах холбоосыг илгээсэн';
    });
  }

  Future<void> _refresh() async {
    setState(() => _checking = true);
    await AuthService.instance.reloadUser();

    // Check if email is now verified
    final user = AuthService.instance.currentUser;
    if (user != null && user.emailVerified) {
      // Navigate to dashboard
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardPage()),
        );
      }
    } else {
      setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Имэйлээ баталгаажуулна уу',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text(
                    'Бид баталгаажуулах холбоосыг таны имэйлд илгээсэн. Та имэйлээ баталгаажуулаад дахин оролдоно уу.'),
                if (_msg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_msg!,
                        style: const TextStyle(color: Colors.green)),
                  ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _sent ? null : _send,
                  child: const Text('Имэйл дахин илгээх'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _checking ? null : _refresh,
                  child: _checking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Имэйл баталгаажуулсан'),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () async {
                    await AuthService.instance.signOut();
                  },
                  child: const Text('Гарах'),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
