import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_security_service.dart';
import '../../features/auth/providers/enhanced_auth_provider.dart';
import '../utils/popup_utils.dart';

/// Security middleware that wraps critical operations with authentication and verification checks
class SecurityMiddleware {
  static final SecurityMiddleware _instance = SecurityMiddleware._internal();
  factory SecurityMiddleware() => _instance;
  SecurityMiddleware._internal();

  /// Wrapper for functions that require authenticated and verified users
  static Future<T?> withSecurityCheck<T>({
    required BuildContext context,
    required String operation,
    required Future<T> Function() action,
    bool requireEmailVerification = true,
    bool requireActiveAccount = true,
    bool showErrorDialog = true,
    VoidCallback? onSecurityFailure,
  }) async {
    try {
      final authProvider =
          Provider.of<EnhancedAuthProvider>(context, listen: false);

      // Check security constraints
      final securityResult = await authProvider.checkSecurity(
        operation: operation,
        requireEmailVerification: requireEmailVerification,
        requireActiveAccount: requireActiveAccount,
      );

      if (!securityResult.success) {
        if (context.mounted) {
          await _handleSecurityFailure(
            context: context,
            result: securityResult,
            showErrorDialog: showErrorDialog,
            onFailure: onSecurityFailure,
          );
        }
        return null;
      }

      // Security check passed, execute the action
      return await action();
    } catch (e) {
      if (showErrorDialog && context.mounted) {
        PopupUtils.showError(
          context: context,
          message: 'Алдаа гарлаа: ${e.toString()}',
        );
      }
      return null;
    }
  }

  /// Handle security check failures with appropriate user feedback
  static Future<void> _handleSecurityFailure({
    required BuildContext context,
    required AuthSecurityResult result,
    bool showErrorDialog = true,
    VoidCallback? onFailure,
  }) async {
    if (!showErrorDialog) {
      onFailure?.call();
      return;
    }

    switch (result.code) {
      case AuthSecurityCode.emailNotVerified:
        await _showEmailVerificationDialog(context);
        break;
      case AuthSecurityCode.accountLocked:
        await _showAccountLockedDialog(context, result.message!);
        break;
      case AuthSecurityCode.accountDisabled:
        await _showAccountDisabledDialog(context, result.message!);
        break;
      case AuthSecurityCode.rateLimitExceeded:
        PopupUtils.showWarning(
          context: context,
          message:
              result.message ?? 'Хэт олон оролдлого хийлээ. Түр хүлээнэ үү.',
        );
        break;
      case AuthSecurityCode.notAuthenticated:
        await _showLoginRequiredDialog(context);
        break;
      default:
        PopupUtils.showError(
          context: context,
          message: result.message ?? 'Нэвтрэхэд алдаа гарлаа',
        );
    }

    onFailure?.call();
  }

  /// Show email verification required dialog
  static Future<void> _showEmailVerificationDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.email_outlined, color: Colors.orange[600]),
            const SizedBox(width: 12),
            const Text('Имэйл баталгаажуулах'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Энэ үйлдлийг гүйцэтгэхийн тулд имэйл хаягаа баталгаажуулах шаардлагатай.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              '• Имэйл хаягаа шалгана уу\n• Баталгаажуулах холбоос дээр дарна уу\n• Дараа нь дахин оролдоно уу',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Дараа'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _sendVerificationEmail(context);
            },
            child: const Text('Имэйл илгээх'),
          ),
        ],
      ),
    );
  }

  /// Send verification email
  static Future<void> _sendVerificationEmail(BuildContext context) async {
    try {
      final authProvider =
          Provider.of<EnhancedAuthProvider>(context, listen: false);
      final result = await authProvider.sendEmailVerification();

      if (result.success) {
        if (context.mounted) {
          PopupUtils.showSuccess(
            context: context,
            message: result.message ?? 'Баталгаажуулах имэйл илгээгдлээ',
          );
        }
      } else {
        if (context.mounted) {
          PopupUtils.showError(
            context: context,
            message: result.message ?? 'Имэйл илгээхэд алдаа гарлаа',
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        PopupUtils.showError(
          context: context,
          message: 'Имэйл илгээхэд алдаа гарлаа: ${e.toString()}',
        );
      }
    }
  }

  /// Show account locked dialog
  static Future<void> _showAccountLockedDialog(
      BuildContext context, String message) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock_outlined, color: Colors.red[600]),
            const SizedBox(width: 12),
            const Text('Бүртгэл хаагдсан'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            const Text(
              'Хэрэв та энэ алдаа гэж бодож байвал бидэнтэй холбогдоно уу.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Ойлголоо'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final url = Uri.parse('https://www.instagram.com/iblameanar');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Тусламж'),
          ),
        ],
      ),
    );
  }

  /// Show account disabled dialog
  static Future<void> _showAccountDisabledDialog(
      BuildContext context, String message) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.person_off_outlined, color: Colors.red[600]),
            const SizedBox(width: 12),
            const Text('Бүртгэл идэвхгүй'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            const Text(
              'Тусламж авахын тулд бидэнтэй холбогдоно уу.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Ойлголоо'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final url = Uri.parse('https://www.instagram.com/iblameanar');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Тусламж'),
          ),
        ],
      ),
    );
  }

  /// Show login required dialog
  static Future<void> _showLoginRequiredDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.login_outlined, color: Colors.blue[600]),
            const SizedBox(width: 12),
            const Text('Нэвтрэх шаардлагатай'),
          ],
        ),
        content: const Text(
          'Энэ үйлдлийг гүйцэтгэхийн тулд эхлээд нэвтэрнэ үү.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Дараа'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed('/login');
            },
            child: const Text('Нэвтрэх'),
          ),
        ],
      ),
    );
  }
}

/// Widget that wraps its child with security protection
class SecureWidget extends StatelessWidget {
  final Widget child;
  final String operation;
  final bool requireEmailVerification;
  final bool requireActiveAccount;
  final Widget? fallbackWidget;
  final VoidCallback? onSecurityFailure;

  const SecureWidget({
    super.key,
    required this.child,
    required this.operation,
    this.requireEmailVerification = true,
    this.requireActiveAccount = true,
    this.fallbackWidget,
    this.onSecurityFailure,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<EnhancedAuthProvider>(
      builder: (context, auth, _) {
        return FutureBuilder<AuthSecurityResult>(
          future: auth.checkSecurity(
            operation: operation,
            requireEmailVerification: requireEmailVerification,
            requireActiveAccount: requireActiveAccount,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final result = snapshot.data;
            if (result?.success == true) {
              return child;
            }

            return fallbackWidget ??
                _buildSecurityBlockedWidget(context, result);
          },
        );
      },
    );
  }

  Widget _buildSecurityBlockedWidget(
      BuildContext context, AuthSecurityResult? result) {
    IconData icon;
    String title;
    String message;
    VoidCallback? action;

    switch (result?.code) {
      case AuthSecurityCode.emailNotVerified:
        icon = Icons.email_outlined;
        title = 'Имэйл баталгаажуулах';
        message = 'Энэ хэсгийг ашиглахын тулд имэйл хаягаа баталгаажуулна уу.';
        action = () => SecurityMiddleware._sendVerificationEmail(context);
        break;
      case AuthSecurityCode.notAuthenticated:
        icon = Icons.login_outlined;
        title = 'Нэвтрэх шаардлагатай';
        message = 'Энэ хэсгийг ашиглахын тулд нэвтэрнэ үү.';
        action = () => Navigator.of(context).pushNamed('/login');
        break;
      default:
        icon = Icons.security_outlined;
        title = 'Хандах эрх хүрэлцэхгүй';
        message =
            result?.message ?? 'Энэ хэсгийг ашиглах эрх танд байхгүй байна.';
        action = onSecurityFailure;
    }

    return Center(
      child: Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              if (action != null) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: action,
                  child: Text(
                    result?.code == AuthSecurityCode.emailNotVerified
                        ? 'Имэйл илгээх'
                        : result?.code == AuthSecurityCode.notAuthenticated
                            ? 'Нэвтрэх'
                            : 'Шийдвэрлэх',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Extension methods for easy security checks
extension SecurityExtensions on BuildContext {
  /// Quick security check
  Future<bool> checkSecurity(
    String operation, {
    bool requireEmailVerification = true,
    bool requireActiveAccount = true,
  }) async {
    try {
      final authProvider =
          Provider.of<EnhancedAuthProvider>(this, listen: false);
      final result = await authProvider.checkSecurity(
        operation: operation,
        requireEmailVerification: requireEmailVerification,
        requireActiveAccount: requireActiveAccount,
      );
      return result.success;
    } catch (e) {
      return false;
    }
  }

  /// Execute action with security check
  Future<T?> withSecurity<T>(
      String operation, Future<T> Function() action) async {
    return SecurityMiddleware.withSecurityCheck<T>(
      context: this,
      operation: operation,
      action: action,
    );
  }
}
