import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:avii/core/utils/validation_utils.dart';
import 'package:avii/legal/terms_and_conditions_page.dart';
import 'dart:math';

class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _name = '';
  String _email = '';
  String _password = '';
  String _confirmPassword = '';
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _agreeToTerms = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<bool> _showGmailConfirmationDialog(String email) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Имэйл баталгаажуулах'),
            content: Text('$_email хаяг руу баталгаажуулах имэйл илгээх үү?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Үгүй'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Тийм'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _requireEmailVerified(AuthProvider auth) async {
    if (auth.user == null) return;
    await auth.user!.sendEmailVerification();
    bool verified = false;
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Имэйл баталгаажуулах'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Танд баталгаажуулах имэйл илгээгдлээ. Линк дээр дарж имэйлээ баталгаажуулаад "Баталгаажуулсан" товч дээр дарна уу.'),
              const SizedBox(height: 12),
              Text(
                auth.user!.email ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await auth.user!.reload();
                verified = auth.user!.emailVerified;
                if (verified) {
                  Navigator.of(context).pop();
                } else {
                  setState(() {});
                }
              },
              child: const Text('Баталгаажуулсан'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1F226C)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 80),
              const Text(
                'Шинээр бүртгүүлэx',
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
                    // Name field
                    TextFormField(
                      style: const TextStyle(color: Colors.black),
                      decoration: const InputDecoration(
                        labelText: 'нэр',
                        labelStyle: TextStyle(color: Colors.grey),
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide:
                              BorderSide(color: Color(0xFF1F226C), width: 2),
                        ),
                      ),
                      validator: ValidationUtils.validateName,
                      onSaved: (val) => _name = val!.trim(),
                    ),
                    const SizedBox(height: 24),

                    // Email field
                    TextFormField(
                      style: const TextStyle(color: Colors.black),
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
                          borderSide:
                              BorderSide(color: Color(0xFF1F226C), width: 2),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: ValidationUtils.validateEmail,
                      onSaved: (val) => _email = val!.trim(),
                    ),
                    const SizedBox(height: 24),

                    // Password field
                    TextFormField(
                      controller: _passwordController,
                      style: const TextStyle(color: Colors.black),
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
                          borderSide:
                              BorderSide(color: Color(0xFF1F226C), width: 2),
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
                    const SizedBox(height: 24),

                    // Confirm password field
                    TextFormField(
                      controller: _confirmPasswordController,
                      style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        labelText: 'нууц үг давтах',
                        labelStyle: const TextStyle(color: Colors.grey),
                        border: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide:
                              BorderSide(color: Color(0xFF1F226C), width: 2),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                              _confirmPasswordVisible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey),
                          onPressed: () {
                            setState(() {
                              _confirmPasswordVisible =
                                  !_confirmPasswordVisible;
                            });
                          },
                        ),
                      ),
                      obscureText: !_confirmPasswordVisible,
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'нууц үг таарахгүй байна';
                        }
                        return null;
                      },
                      onSaved: (val) => _confirmPassword = val!.trim(),
                    ),
                    const SizedBox(height: 24),

                    // Terms and conditions agreement
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _agreeToTerms,
                          onChanged: (value) {
                            setState(() {
                              _agreeToTerms = value ?? false;
                            });
                          },
                          activeColor: const Color(0xFF1F226C),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _agreeToTerms = !_agreeToTerms;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                  children: [
                                    const TextSpan(text: 'Би '),
                                    WidgetSpan(
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const TermsAndConditionsPage(),
                                            ),
                                          );
                                        },
                                        child: const Text(
                                          'Үйлчилгээний нөхцөл',
                                          style: TextStyle(
                                            color: Color(0xFF1F226C),
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const TextSpan(
                                        text: '-тэй танилцаж, зөвшөөрч байна.'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Sign up button
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
                        onPressed: auth.loading || !_agreeToTerms
                            ? null
                            : () async {
                                if (_formKey.currentState?.validate() ??
                                    false) {
                                  _formKey.currentState!.save();
                                  try {
                                    // Gmail confirmation
                                    bool proceed = true;
                                    if (_email
                                        .toLowerCase()
                                        .endsWith('@gmail.com')) {
                                      proceed =
                                          await _showGmailConfirmationDialog(
                                              _email);
                                    }
                                    if (!proceed) return;

                                    await auth.signUp(_name, _email, _password);

                                    if (auth.user != null &&
                                        !auth.user!.emailVerified &&
                                        _email
                                            .toLowerCase()
                                            .endsWith('@gmail.com')) {
                                      await _requireEmailVerified(auth);
                                    }

                                    if (auth.user != null &&
                                        auth.user!.emailVerified) {
                                      if (context.mounted) {
                                        Navigator.of(context)
                                            .pushReplacementNamed('/home');
                                      }
                                    } else {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text(
                                                    'Имэйл баталгаажаагүй тул нэвтрэх боломжгүй.')));
                                      }
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(e.toString())));
                                  }
                                }
                              },
                        child: auth.loading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('бүртгүүлэx'),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Login link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Хэрэглэгч байгаа юу? ',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Нэвтрэх',
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
