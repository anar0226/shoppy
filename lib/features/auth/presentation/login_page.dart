import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'signup_page.dart';
import 'package:avii/core/utils/validation_utils.dart';
import 'forgot_password_page.dart';
import 'enhanced_phone_auth_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  bool _passwordVisible = false;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Main content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 80),
                  const Text(
                    'Тавтай морил',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 60),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Email field
                        TextFormField(
                          style: const TextStyle(
                              color: Color(0xFF4285F4)), // Primary blue color
                          decoration: const InputDecoration(
                            labelText: 'имэйл',
                            labelStyle: TextStyle(color: Colors.grey),
                            border: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey),
                            ),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: Color(0xFF1F226C), width: 2),
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: ValidationUtils.validateEmail,
                          onSaved: (val) => _email = val!.trim(),
                        ),
                        const SizedBox(height: 24),

                        // Password field
                        TextFormField(
                          style: const TextStyle(
                              color: Color(0xFF4285F4)), // Primary blue color
                          decoration: InputDecoration(
                            labelText: 'нууц үг',
                            labelStyle: const TextStyle(color: Colors.grey),
                            border: const UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey),
                            ),
                            enabledBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: Color(0xFF1F226C), width: 2),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                  _passwordVisible
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey),
                              onPressed: () {
                                setState(() {
                                  _passwordVisible = !_passwordVisible;
                                });
                              },
                            ),
                          ),
                          obscureText: !_passwordVisible,
                          validator: ValidationUtils.validatePassword,
                          onSaved: (val) => _password = val!.trim(),
                        ),
                        const SizedBox(height: 8),

                        // Forgot password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const ForgotPasswordPage()),
                              );
                            },
                            child: const Text(
                              'Нууц үг мартсан уу?',
                              style: TextStyle(
                                color: Color(0xFF1F226C),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Login button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1F226C),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: auth.loading
                                ? null
                                : () async {
                                    if (_formKey.currentState?.validate() ??
                                        false) {
                                      _formKey.currentState!.save();
                                      try {
                                        await auth.signIn(_email, _password);
                                        if (context.mounted) {
                                          Navigator.of(context)
                                              .pushReplacementNamed('/home');
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                                  content: Text(e.toString())));
                                        }
                                      }
                                    }
                                  },
                            child: auth.loading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text('нэвтрэx'),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Signup text
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Шинэ хэрэглэгч болох ',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const SignUpPage())),
                              child: const Text(
                                'Бүртгүүлэх',
                                style: TextStyle(
                                  color: Color(0xFF1F226C),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                        _SocialButtons(auth: auth),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialButtons extends StatelessWidget {
  const _SocialButtons({required this.auth});
  final AuthProvider auth;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Divider with text
        Row(
          children: [
            const Expanded(
              child: Divider(
                color: Colors.grey,
                thickness: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Бусад нэвтрэх аргууд',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ),
            const Expanded(
              child: Divider(
                color: Colors.grey,
                thickness: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Circular social buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Google button
            GestureDetector(
              onTap: auth.loading
                  ? null
                  : () async {
                      try {
                        await auth.signInWithGoogle();
                        if (context.mounted) {
                          Navigator.of(context).pushReplacementNamed('/home');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())));
                        }
                      }
                    },
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: const Icon(
                  Icons.g_mobiledata,
                  color: Color(0xFF1F226C),
                  size: 32,
                ),
              ),
            ),

            // Apple button
            GestureDetector(
              onTap: auth.loading
                  ? null
                  : () async {
                      try {
                        await auth.signInWithApple();
                        if (context.mounted) {
                          Navigator.of(context).pushReplacementNamed('/home');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())));
                        }
                      }
                    },
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: const Icon(
                  Icons.apple,
                  color: Color(0xFF1F226C),
                  size: 32,
                ),
              ),
            ),

            // Phone button
            GestureDetector(
              onTap: auth.loading
                  ? null
                  : () async {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const EnhancedPhoneAuthPage(),
                        ),
                      );
                    },
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: const Icon(
                  Icons.phone,
                  color: Color(0xFF1F226C),
                  size: 32,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
