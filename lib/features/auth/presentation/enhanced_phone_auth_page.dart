import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../../../core/services/auth_security_service.dart';
import '../../../core/utils/popup_utils.dart';

class EnhancedPhoneAuthPage extends StatefulWidget {
  const EnhancedPhoneAuthPage({super.key});

  @override
  State<EnhancedPhoneAuthPage> createState() => _EnhancedPhoneAuthPageState();
}

class _EnhancedPhoneAuthPageState extends State<EnhancedPhoneAuthPage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _authSecurity = AuthSecurityService();

  bool _codeSent = false;
  bool _isLoading = false;
  int _resendCountdown = 0;
  String? _errorMessage;
  int _attemptCount = 0;
  static const int _maxAttempts = 3;
  static const int _resendCooldown = 60; // seconds

  @override
  void initState() {
    super.initState();
    _authSecurity.startSession();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _authSecurity.dispose();
    super.dispose();
  }

  Future<void> _sendVerificationCode() async {
    if (_isLoading) return;

    // Validate phone number
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check security constraints
      final securityResult = await _authSecurity.validateUserSecurity(
        operation: 'phone_verification',
        requireEmailVerification: false,
        requireActiveAccount: false,
        requireAuthentication: false, // Don't require auth for phone auth
      );

      if (!securityResult.success) {
        throw Exception(securityResult.message);
      }

      final auth = Provider.of<AuthProvider>(context, listen: false);
      final phoneNumber = '+976${_phoneController.text.trim()}';

      // Validate phone number format
      if (!_isValidMongolianPhone(_phoneController.text.trim())) {
        throw Exception('Утасны дугаарын формат буруу байна');
      }

      await auth.sendPhoneVerificationCode(phoneNumber);

      setState(() {
        _codeSent = true;
        _resendCountdown = _resendCooldown;
      });

      _startResendCountdown();

      if (mounted) {
        PopupUtils.showSuccess(
          context: context,
          message: 'Баталгаажуулах код илгээгдлээ',
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _attemptCount++;
      });

      // Log failed attempt for security
      if (mounted) {
        final currentUser =
            Provider.of<AuthProvider>(context, listen: false).user;
        if (currentUser != null) {
          await _authSecurity.recordFailedAttempt(
              currentUser.uid, 'phone_verification');
        }
      }

      // Block further attempts if max reached
      if (_attemptCount >= _maxAttempts) {
        setState(() {
          _errorMessage =
              'Хэт олон оролдлого хийлээ. 15 минутын дараа дахин оролдоно уу.';
        });
        _disableForCooldown();
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyCode() async {
    if (_isLoading || _codeController.text.trim().length != 6) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final user = await auth.verifyPhoneCode(_codeController.text.trim());

      if (user != null) {
        // Clear failed attempts on success
        await _authSecurity.clearFailedAttempts(user.uid);

        if (mounted) {
          if (auth.needsProfileCompletion) {
            Navigator.of(context).pushReplacementNamed('/profile-completion');
          } else {
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/home', (route) => false);
          }
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _attemptCount++;
      });

      // Clear the code field on error
      _codeController.clear();

      // Block further attempts if max reached
      if (_attemptCount >= _maxAttempts) {
        setState(() {
          _errorMessage =
              'Хэт олон буруу код оруулсан байна. Дахин код илгээх хэрэгтэй.';
          _codeSent = false;
        });
        _resetForm();
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startResendCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _resendCountdown--;
        });
        return _resendCountdown > 0;
      }
      return false;
    });
  }

  void _resetForm() {
    setState(() {
      _codeSent = false;
      _codeController.clear();
      _errorMessage = null;
      _attemptCount = 0;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    auth.clearPhoneVerification();
  }

  void _disableForCooldown() {
    Timer(const Duration(minutes: 15), () {
      if (mounted) {
        setState(() {
          _attemptCount = 0;
          _errorMessage = null;
        });
      }
    });
  }

  bool _isValidMongolianPhone(String phone) {
    // Mongolian mobile numbers are 8 digits starting with 8, 9, or 7
    final phoneRegex = RegExp(r'^[89]\d{7}$');
    return phoneRegex.hasMatch(phone);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Утасны дугаараар нэвтрэх'),
        backgroundColor: const Color(0xFF1F226C),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1F226C), Color(0xFF3C42D2)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),

                  // Icon and title
                  Icon(
                    Icons.phone_android,
                    size: 80,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    _codeSent
                        ? 'Баталгаажуулах код оруулна уу'
                        : 'Утасны дугаараа оруулна уу',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  Text(
                    _codeSent
                        ? '+976${_phoneController.text} дугаарт илгээсэн 6 оронтой кодыг оруулна уу'
                        : 'Танд SMS-ээр 6 оронтой код илгээх болно',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Error message display
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.red.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: Colors.red[300], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                  color: Colors.red[300], fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Input fields
                  if (!_codeSent) ...[
                    // Phone number input
                    TextFormField(
                      controller: _phoneController,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: InputDecoration(
                        labelText: 'Утасны дугаар',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixText: '+976 ',
                        prefixStyle:
                            const TextStyle(color: Colors.white, fontSize: 18),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Colors.white70, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.white, width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.red, width: 1.5),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.red, width: 2),
                        ),
                        counterText: '',
                      ),
                      keyboardType: TextInputType.phone,
                      maxLength: 8,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Утасны дугаараа оруулна уу';
                        }
                        if (value.length != 8) {
                          return '8 оронтой утасны дугаар оруулна уу';
                        }
                        if (!_isValidMongolianPhone(value)) {
                          return 'Буруу утасны дугаар (8, 9-өөр эхлэх ёстой)';
                        }
                        return null;
                      },
                    ),
                  ] else ...[
                    // Verification code input
                    TextFormField(
                      controller: _codeController,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 24, letterSpacing: 4),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        labelText: 'Баталгаажуулах код',
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: '••••••',
                        hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 24),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Colors.white70, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.white, width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.red, width: 1.5),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.red, width: 2),
                        ),
                        counterText: '',
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Баталгаажуулах кодыг оруулна уу';
                        }
                        if (value.length != 6) {
                          return '6 оронтой код оруулна уу';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        if (value.length == 6) {
                          _verifyCode();
                        }
                      },
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Main action button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8A32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    onPressed: (_isLoading || _attemptCount >= _maxAttempts)
                        ? null
                        : () async {
                            if (!_codeSent) {
                              await _sendVerificationCode();
                            } else {
                              await _verifyCode();
                            }
                          },
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _codeSent ? 'Баталгаажуулах' : 'Код илгээх',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),

                  // Additional actions
                  if (_codeSent) ...[
                    const SizedBox(height: 16),

                    // Resend code button
                    TextButton(
                      onPressed: _resendCountdown > 0 || _isLoading
                          ? null
                          : () {
                              _resetForm();
                            },
                      child: Text(
                        _resendCountdown > 0
                            ? 'Дахин код илгээх ($_resendCountdown с)'
                            : 'Дахин код илгээх',
                        style: TextStyle(
                          color: _resendCountdown > 0
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.white70,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Change phone number button
                    TextButton(
                      onPressed: _isLoading ? null : _resetForm,
                      child: const Text(
                        'Өөр дугаар ашиглах',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Security notice
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.security,
                            color: Colors.white.withValues(alpha: 0.7),
                            size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Таны утасны дугаар аюулгүй байдлын зорилгоор хамгаалагдана.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
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
