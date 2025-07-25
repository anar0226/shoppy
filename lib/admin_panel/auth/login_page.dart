import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'signup_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance
          .signIn(_emailCtrl.text.trim(), _passCtrl.text.trim());
    } on FirebaseAuthException catch (e) {
      // Handle Firebase Auth specific errors
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'Энэ и-мэйл хаягаар бүртгэгдээгүй байна';
          break;
        case 'wrong-password':
          errorMessage = 'Нууц үг буруу байна';
          break;
        case 'invalid-email':
          errorMessage = 'И-мэйл хаягийн хэлбэр буруу байна';
          break;
        case 'user-disabled':
          errorMessage = 'Энэ хэрэглэгчийн эрх хаагдсан байна';
          break;
        case 'too-many-requests':
          errorMessage =
              'Хэт олон удаа оролдлоо. Хэсэг хүлээгээд дахин оролдоно уу';
          break;
        case 'operation-not-allowed':
          errorMessage = 'И-мэйл/нууц үгээр нэвтрэх боломжгүй байна';
          break;
        default:
          errorMessage = e.message ?? 'Нэвтрэхэд алдаа гарлаа';
      }
      setState(() => _error = errorMessage);
    } catch (e) {
      setState(() => _error = 'Нэвтрэхэд алдаа гарлаа');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Avii.mn Admin',
                      style:
                          TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(labelText: 'И-мэйл хаяг'),
                    validator: (v) => v != null && v.contains('@')
                        ? null
                        : 'И-мэйл хаяг оруулна уу',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Нууц үг'),
                    validator: (v) => v != null && v.length >= 6
                        ? null
                        : '6-н тэмдэгтээс дээш нууц үг оруулна уу',
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () async {
                        if (_emailCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Эхлээд И-мэйл хаяг оруулна уу')));
                          return;
                        }
                        await AuthService.instance
                            .sendPasswordReset(_emailCtrl.text.trim());
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Нууц үг сэргээх и-мэйл илгээгдлээ')));
                        }
                      },
                      child: const Text('Нууц үг мартсан уу?'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _loading
                          ? const CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)
                          : const Text('Нэвтрэх'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const SignupPage()),
                            ),
                    child: const Text("Шинээр бүртгүүлэх"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
