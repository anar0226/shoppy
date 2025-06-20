import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1F226C), Color(0xFF3C42D2)],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  const Text('Тавтай',
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const Text('морил',
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 160),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'имэйл',
                            labelStyle: const TextStyle(color: Colors.white70),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide:
                                  const BorderSide(color: Colors.white70),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(
                                  color: Colors.white, width: 2),
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) =>
                              value != null && value.contains('@')
                                  ? null
                                  : 'бодит имэйл хаягаа оруулна уу',
                          onSaved: (val) => _email = val!.trim(),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'нууц үг',
                            labelStyle: const TextStyle(color: Colors.white70),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide:
                                  const BorderSide(color: Colors.white70),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(
                                  color: Colors.white, width: 2),
                            ),
                          ),
                          obscureText: true,
                          validator: (value) =>
                              value != null && value.length >= 6
                                  ? null
                                  : 'хамгийн багадаа 6 тэмдэгт оруулна уу',
                          onSaved: (val) => _password = val!.trim(),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {},
                            child: const Text('нууц үгээ мартсан уу?'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1F226C),
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
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content: Text(e.toString())));
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
                        _SocialButtons(auth: auth),
                        const SizedBox(height: 120), // space for footer
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom orange bar
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: const Color(0xFFFF8A32),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(".", style: TextStyle(color: Colors.white)),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SignUpPage())),
                    child: const Text('шинээр бүртгэл үүсгэх',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  )
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
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.g_mobiledata),
            label: const Text('Google хаягаар нэвтрэx'),
            onPressed: auth.loading
                ? null
                : () async {
                    await auth.signInWithGoogle();
                  },
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.apple),
            label: const Text('Apple хаягаар нэвтрэx'),
            onPressed: auth.loading
                ? null
                : () async {
                    await auth.signInWithApple();
                  },
          ),
        ),
      ],
    );
  }
}
