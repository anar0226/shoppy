import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/colors.dart';
import 'unified_auth_page.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;
  String? _error;
  String? _emailForCode; // Email associated with the reset code
  String? _oobCode;
  bool _isLoading = true;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _initFromUrl();
  }

  Future<void> _initFromUrl() async {
    final uri = Uri.base;
    final mode = uri.queryParameters['mode'];
    final oobCode = uri.queryParameters['oobCode'];

    if (mode != 'resetPassword' || oobCode == null || oobCode.isEmpty) {
      setState(() {
        _error = 'Буруу холбоос байна. Дахин хүсэлт илгээнэ үү.';
        _isLoading = false;
      });
      return;
    }

    try {
      final email =
          await FirebaseAuth.instance.verifyPasswordResetCode(oobCode);
      setState(() {
        _oobCode = oobCode;
        _emailForCode = email;
        _isLoading = false;
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = _mapAuthErrorToMongolian(e);
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Холбоос хүчинтэй биш эсвэл хугацаа дууссан байж магадгүй.';
        _isLoading = false;
      });
    }
  }

  String _mapAuthErrorToMongolian(FirebaseAuthException e) {
    switch (e.code) {
      case 'expired-action-code':
        return 'Холбоосын хугацаа дууссан байна. Дахин хүсэлт илгээнэ үү.';
      case 'invalid-action-code':
        return 'Холбоос хүчинтэй биш байна. Дахин хүсэлт илгээнэ үү.';
      case 'user-not-found':
        return 'Ийм хэрэглэгч олдсонгүй.';
      default:
        return e.message ?? 'Алдаа гарлаа. Дараа дахин оролдоно уу.';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_oobCode == null) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.confirmPasswordReset(
        code: _oobCode!,
        newPassword: _passwordController.text.trim(),
      );

      setState(() {
        _completed = true;
        _isSubmitting = false;
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = _mapAuthErrorToMongolian(e);
        _isSubmitting = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Нууц үг шинэчлэхэд алдаа гарлаа. Дараа дахин оролдоно уу.';
        _isSubmitting = false;
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _isLoading
                ? const CircularProgressIndicator()
                : _completed
                    ? _buildSuccess(context)
                    : _buildForm(context),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              const Icon(Icons.check_circle,
                  color: AppColors.success, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Нууц үг амжилттай шинэчлэгдлээ',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Одоо шинэ нууц үгээрээ нэвтэрч болно.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (_) => const UnifiedAuthPage()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Нэвтрэх хуудас руу очих'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: AppColors.brandBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_reset,
                      color: Colors.white, size: 40),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Нууц үг шинэчлэх',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _emailForCode == null
                    ? 'Шинэ нууц үгээ оруулна уу.'
                    : 'Дараах хаягийн нууц үгийг шинэчилнэ: $_emailForCode',
                style: const TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                Container(
                  width: double.infinity,
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
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Шинэ нууц үг',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
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
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: _obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Нууц үг давтах',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm),
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
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text('Шинэчлэх'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                              builder: (_) => const UnifiedAuthPage()),
                        );
                      },
                      child: const Text('Нэвтрэх хуудас руу буцах'),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
