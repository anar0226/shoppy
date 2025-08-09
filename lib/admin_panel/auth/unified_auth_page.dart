import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;
import 'auth_service.dart';

import '../pages/admin_panel_layout.dart';

class UnifiedAuthPage extends StatefulWidget {
  const UnifiedAuthPage({super.key});

  @override
  State<UnifiedAuthPage> createState() => _UnifiedAuthPageState();
}

class _UnifiedAuthPageState extends State<UnifiedAuthPage> {
  bool _isLoginMode = true;
  bool _isLoading = false;
  String? _error;
  String? _successMessage;

  // Form controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Password visibility
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Terms acceptance
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isLoginMode = !_isLoginMode;
      _error = null;
      _successMessage = null;
      // Clear form when switching modes
      if (_isLoginMode) {
        _firstNameController.clear();
        _lastNameController.clear();
        _confirmPasswordController.clear();
        _acceptedTerms = false;
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    // Additional validation for signup
    if (!_isLoginMode && !_acceptedTerms) {
      setState(() {
        _error =
            'Үйлчилгээний нөхцөл болон Нууцлалын бодлогыг хүлээн зөвшөөрнө үү';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      if (_isLoginMode) {
        await _handleLogin();
      } else {
        await _handleSignup();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogin() async {
    try {
      await AuthService.instance.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      // Login successful - user will be redirected by auth state listener
    } on FirebaseAuthException catch (e) {
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
        default:
          errorMessage = e.message ?? 'Нэвтрэхэд алдаа гарлаа';
      }
      throw Exception(errorMessage);
    }
  }

  Future<void> _handleSignup() async {
    UserCredential? userCredential;
    String? storeId;

    try {
      // Step 1: Create user in Firebase Authentication
      userCredential = await AuthService.instance.signUp(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (userCredential.user == null) {
        throw Exception('Failed to create user account');
      }

      // Step 2: Create store document in Firestore
      storeId = FirebaseFirestore.instance.collection('stores').doc().id;
      await FirebaseFirestore.instance.collection('stores').doc(storeId).set({
        'name':
            '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
        'description': '',
        'logo': '',
        'banner': '',
        'ownerId': userCredential.user!.uid,
        'status': 'setup_pending',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'settings': {},
        'phone': '',
        'facebook': '',
        'instagram': '',
        'refundPolicy': '',
        // Initialize payout fields
        'selectedBank': null,
        'bankAccountNumber': '',
        'bankAccountHolderName': '',
        'preferredPayoutMethod': 'bankTransfer',
        'payoutFrequency': 'weekly',
        'minimumPayoutAmount': 50000,
        'autoPayoutEnabled': true,
        'idCardFrontImage': '',
        'idCardBackImage': '',
        'kycStatus': 'notSubmitted',
        'kycRejectionReason': '',
        'kycSubmittedAt': null,
        'kycApprovedAt': null,
        'payoutSetupCompleted': false,
        'payoutSetupCompletedAt': null,
        'payoutSetupNotes': '',
        // Initialize subscription fields
        'subscriptionStatus': 'pending',
        'subscriptionStartDate': null,
        'subscriptionEndDate': null,
        'lastPaymentDate': null,
        'nextPaymentDate': null,
        'paymentHistory': [],
      });

      // Step 3: Navigate to main admin panel
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) =>
                const AdminPanelLayout(initialPage: 'Нүүр хуудас')));
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'Нууц үг хэтэрхий хялбар байна';
          break;
        case 'email-already-in-use':
          errorMessage = 'Энэ и-мэйл хаяг аль хэдийн бүртгэгдсэн байна';
          break;
        case 'invalid-email':
          errorMessage = 'И-мэйл хаягийн хэлбэр буруу байна';
          break;
        default:
          errorMessage = e.message ?? 'Бүртгүүлэхэд алдаа гарлаа';
      }
      throw Exception(errorMessage);
    } catch (e) {
      // Handle other errors (likely Firestore errors)
      developer.log('Signup error: $e', name: 'UnifiedAuthPage');

      // If user was created but Firestore failed, we need to clean up
      if (userCredential?.user != null) {
        try {
          await userCredential?.user?.delete();
          throw Exception('Бүртгүүлэхэд алдаа гарлаа. Дахин оролдоно уу.');
        } catch (deleteError) {
          developer.log(
              'Failed to delete user after signup error: $deleteError',
              name: 'UnifiedAuthPage');
          throw Exception(
              'Бүртгүүлэх явцад алдаа гарлаа. Та нэвтрэх оролдоод үзээрэй.');
        }
      } else {
        throw Exception('Бүртгүүлэхэд алдаа гарлаа');
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _error = 'Эхлээд И-мэйл хаяг оруулна уу';
      });
      return;
    }

    try {
      await AuthService.instance
          .sendPasswordReset(_emailController.text.trim());
      setState(() {
        _successMessage = 'Нууц үг сэргээх и-мэйл илгээгдлээ';
      });
    } catch (e) {
      setState(() {
        _error = 'Нууц үг сэргээх и-мэйл илгээхэд алдаа гарлаа';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 900;
    return Scaffold(
      body: SafeArea(
        child: isCompact
            ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: _buildRightPanel(isCompact: true),
                  ),
                ),
              )
            : Row(
                children: [
                  // Left side - Branding and Features (desktop/tablet only)
                  Expanded(
                    flex: 1,
                    child: _buildLeftPanel(),
                  ),
                  // Right side - Authentication Form
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(48.0),
                      child: _buildRightPanel(),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildLeftPanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF4285F4), // Brand blue
            Color(0xFF4FC3F7), // Light blue
          ],
        ),
      ),
      child: Stack(
        children: [
          // Decorative circle in top-left
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Main content
          Padding(
            padding: const EdgeInsets.all(48.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Spacer to push content down slightly
                const SizedBox(height: 40),

                // Logo and Brand
                const Text(
                  'Avii.mn',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Монголын шилдэг онлайн худалдааны платформ',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 80),

                // Feature highlights
                _buildFeatureItem(
                  icon: Icons.storefront,
                  title: 'Өөрийн дэлгүүрээ үнэ төлбөргүй нээгээрэй',
                  description: 'Хэдхэн минутын дотор онлайн дэлгүүр үүсгээрэй',
                ),
                const SizedBox(height: 40),
                _buildFeatureItem(
                  icon: Icons.trending_up,
                  title: 'Борлуулалтаа нэмэгдүүлээрэй',
                  description:
                      'Та бидний шилдэг борлуулалтын хэрэгсэл ашиглах боломжтой',
                ),
                const SizedBox(height: 40),
                _buildFeatureItem(
                  icon: Icons.security,
                  title: 'Найдвартай төлбөр',
                  description: 'Аюулгүй, хурдан төлбөрийн систем',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanel({bool isCompact = false}) {
    return Container(
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 0 : 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Navigation Tabs
            Row(
              children: [
                Expanded(
                  child: _buildTab(
                    title: 'Нэвтрэх',
                    isActive: _isLoginMode,
                    onTap: () {
                      if (!_isLoginMode) _toggleMode();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTab(
                    title: 'Бүртгүүлэх',
                    isActive: !_isLoginMode,
                    onTap: () {
                      if (_isLoginMode) _toggleMode();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Form Title
            Text(
              _isLoginMode ? 'Тавтай морилно уу' : 'Бүртгэл үүсгэх',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isLoginMode
                  ? 'Өөрийн акаунтаа нэвтэрнэ үү'
                  : 'Өөрийн онлайн дэлгүүрээ эхлүүлээрэй',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 24),

            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Name fields (only for signup)
                      if (!_isLoginMode) ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _firstNameController,
                                decoration: InputDecoration(
                                  labelText: 'Нэр',
                                  labelStyle:
                                      const TextStyle(color: Colors.black54),
                                  border: OutlineInputBorder(
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade400),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade400),
                                  ),
                                  focusedBorder: const OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: Color(0xFF4285F4), width: 2),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Нэр оруулна уу';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _lastNameController,
                                decoration: InputDecoration(
                                  labelText: 'Овог',
                                  labelStyle:
                                      const TextStyle(color: Colors.black54),
                                  border: OutlineInputBorder(
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade400),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade400),
                                  ),
                                  focusedBorder: const OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: Color(0xFF4285F4), width: 2),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Овог оруулна уу';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Email field
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'И-мэйл хаяг',
                          labelStyle: const TextStyle(color: Colors.black54),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey.shade400),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey.shade400),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide:
                                BorderSide(color: Color(0xFF4285F4), width: 2),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'И-мэйл хаяг оруулна уу';
                          }
                          if (!value.contains('@')) {
                            return 'И-мэйл хаягийн хэлбэр буруу байна';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Нууц үг',
                          labelStyle: const TextStyle(color: Colors.black54),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey.shade400),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey.shade400),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide:
                                BorderSide(color: Color(0xFF4285F4), width: 2),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.grey.shade600,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Нууц үг оруулна уу';
                          }
                          if (value.length < 6) {
                            return 'Нууц үг хамгийн багадаа 6 тэмдэгт байх ёстой';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Confirm password field (only for signup)
                      if (!_isLoginMode) ...[
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'Нууц үг давтах',
                            labelStyle: const TextStyle(color: Colors.black54),
                            border: OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Colors.grey.shade400),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Colors.grey.shade400),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: Color(0xFF4285F4), width: 2),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.grey.shade600,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Нууц үг давтах';
                            }
                            if (value != _passwordController.text) {
                              return 'Нууц үг таарахгүй байна';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Remember me and forgot password (only for login)
                      if (_isLoginMode) ...[
                        Row(
                          children: [
                            Checkbox(
                              value: false, // You can add state for this
                              onChanged: (value) {
                                // Handle remember me
                              },
                            ),
                            const Flexible(
                              child: Text(
                                'Нууц үг, Нэвтрэх нэрийг хадгалах.',
                                style: TextStyle(color: Colors.black87),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: _handleForgotPassword,
                              child: const Text(
                                'Нууц үгээ мартсан уу?',
                                style: TextStyle(color: Color(0xFF4285F4)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Terms and conditions (only for signup)
                      if (!_isLoginMode) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _acceptedTerms,
                              onChanged: (value) {
                                setState(() {
                                  _acceptedTerms = value ?? false;
                                });
                              },
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _acceptedTerms = !_acceptedTerms;
                                  });
                                },
                                child: const Text(
                                  'Би Үйлчилгээний нөхцөл болон Нууцлалын бодлогыг хүлээн зөвшөөрч байна',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Error/Success messages
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            _error!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      if (_successMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Text(
                            _successMessage!,
                            style: TextStyle(color: Colors.green.shade700),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Submit button
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4285F4),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFF4285F4)),
                                  ),
                                )
                              : Text(
                                  _isLoginMode ? 'Нэвтрэх' : 'Бүртгүүлэх',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab({
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.black : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }
}
