import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'production_logger.dart';
import 'error_recovery_service.dart';

/// Comprehensive error handling service for professional-grade error management
class ErrorHandlerService {
  static final ErrorHandlerService _instance = ErrorHandlerService._internal();
  static ErrorHandlerService get instance => _instance;
  ErrorHandlerService._internal();

  /// Handle errors with comprehensive logging, user feedback, and recovery
  Future<T?> handleError<T>({
    required String operation,
    required dynamic error,
    StackTrace? stackTrace,
    BuildContext? context,
    Map<String, dynamic>? additionalContext,
    bool showUserMessage = true,
    bool logError = true,
    bool isFatal = false,
    T? fallbackValue,
    VoidCallback? onRetry,
  }) async {
    try {
      // 1. Log error to production logger
      if (logError) {
        await ProductionLogger.instance.error(
          'Error in operation: $operation',
          error: error,
          stackTrace: stackTrace,
          context: {
            'operation': operation,
            'errorType': _getErrorType(error),
            'isFatal': isFatal,
            'hasUserContext': context != null,
            'hasRetryCallback': onRetry != null,
            ...?additionalContext,
          },
          isFatal: isFatal,
        );
      }

      // 2. Show user-friendly message if context is available
      if (showUserMessage && context != null && context.mounted) {
        final userMessage = _getUserFriendlyMessage(error);
        _showErrorToUser(context, userMessage, onRetry);
      }

      // 3. Return fallback value if provided
      return fallbackValue;
    } catch (handlingError) {
      // Error in error handling - log and continue
      debugPrint('Error in error handling: $handlingError');
      return fallbackValue;
    }
  }

  /// Handle errors with automatic retry logic
  Future<T?> handleErrorWithRetry<T>({
    required String operation,
    required Future<T> Function() action,
    BuildContext? context,
    Map<String, dynamic>? additionalContext,
    bool showUserMessage = true,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
    T? fallbackValue,
  }) async {
    return await ErrorRecoveryService.instance.executeWithRecovery<T>(
      operationName: operation,
      operation: action,
      fallback: fallbackValue != null ? () async => fallbackValue : null,
      maxRetries: maxRetries,
      logErrors: true,
    );
  }

  /// Handle Firebase-specific errors
  Future<T?> handleFirebaseError<T>({
    required String operation,
    required dynamic error,
    StackTrace? stackTrace,
    BuildContext? context,
    Map<String, dynamic>? additionalContext,
    bool showUserMessage = true,
    T? fallbackValue,
    VoidCallback? onRetry,
  }) async {
    // Add Firebase-specific context
    final firebaseContext = {
      'firebaseErrorCode': _getFirebaseErrorCode(error),
      'isNetworkError': _isNetworkError(error),
      'isPermissionError': _isPermissionError(error),
      'isAuthError': _isAuthError(error),
      ...?additionalContext,
    };

    return await handleError<T>(
      operation: operation,
      error: error,
      stackTrace: stackTrace,
      context: context,
      additionalContext: firebaseContext,
      showUserMessage: showUserMessage,
      fallbackValue: fallbackValue,
      onRetry: onRetry,
    );
  }

  /// Handle network errors specifically
  Future<T?> handleNetworkError<T>({
    required String operation,
    required dynamic error,
    StackTrace? stackTrace,
    BuildContext? context,
    Map<String, dynamic>? additionalContext,
    bool showUserMessage = true,
    T? fallbackValue,
    VoidCallback? onRetry,
  }) async {
    final networkContext = {
      'isNetworkError': true,
      'errorType': 'network',
      'canRetry': true,
      ...?additionalContext,
    };

    return await handleError<T>(
      operation: operation,
      error: error,
      stackTrace: stackTrace,
      context: context,
      additionalContext: networkContext,
      showUserMessage: showUserMessage,
      fallbackValue: fallbackValue,
      onRetry: onRetry,
    );
  }

  /// Handle validation errors
  Future<T?> handleValidationError<T>({
    required String operation,
    required String validationMessage,
    BuildContext? context,
    Map<String, dynamic>? additionalContext,
    bool showUserMessage = true,
    T? fallbackValue,
  }) async {
    final validationContext = {
      'errorType': 'validation',
      'validationMessage': validationMessage,
      'canRetry': false,
      ...?additionalContext,
    };

    return await handleError<T>(
      operation: operation,
      error: validationMessage,
      context: context,
      additionalContext: validationContext,
      showUserMessage: showUserMessage,
      logError: false, // Don't log validation errors as they're user errors
      fallbackValue: fallbackValue,
    );
  }

  /// Handle critical errors that should crash the app
  Future<Never> handleCriticalError({
    required String operation,
    required dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? additionalContext,
  }) async {
    await ProductionLogger.instance.error(
      'CRITICAL ERROR in operation: $operation',
      error: error,
      stackTrace: stackTrace,
      context: {
        'operation': operation,
        'errorType': _getErrorType(error),
        'isFatal': true,
        'severity': 'critical',
        ...?additionalContext,
      },
      isFatal: true,
    );

    // In production, we might want to show a crash screen
    // For now, rethrow to let Flutter handle it
    throw error;
  }

  /// Safe async operation wrapper
  Future<T?> safeAsyncOperation<T>({
    required String operation,
    required Future<T> Function() action,
    BuildContext? context,
    Map<String, dynamic>? additionalContext,
    bool showUserMessage = true,
    bool logError = true,
    T? fallbackValue,
    VoidCallback? onRetry,
  }) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      return await handleError<T>(
        operation: operation,
        error: error,
        stackTrace: stackTrace,
        context: context,
        additionalContext: additionalContext,
        showUserMessage: showUserMessage,
        logError: logError,
        fallbackValue: fallbackValue,
        onRetry: onRetry,
      );
    }
  }

  /// Get error type for categorization
  String _getErrorType(dynamic error) {
    if (error is FirebaseAuthException) return 'firebase_auth';
    if (error is FirebaseException) return 'firebase';
    if (error is TimeoutException) return 'timeout';
    if (error.toString().contains('SocketException')) return 'network';
    if (error.toString().contains('FormatException')) return 'format';
    if (error.toString().contains('Permission')) return 'permission';
    return 'unknown';
  }

  /// Get Firebase error code
  String? _getFirebaseErrorCode(dynamic error) {
    if (error is FirebaseAuthException) return error.code;
    if (error is FirebaseException) return error.code;
    return null;
  }

  /// Check if error is network-related
  bool _isNetworkError(dynamic error) {
    if (error is FirebaseException) {
      return error.code == 'unavailable' || error.code == 'deadline-exceeded';
    }
    return error.toString().contains('SocketException') ||
        error.toString().contains('network') ||
        error.toString().contains('timeout');
  }

  /// Check if error is permission-related
  bool _isPermissionError(dynamic error) {
    if (error is FirebaseException) {
      return error.code == 'permission-denied';
    }
    return error.toString().contains('permission') ||
        error.toString().contains('access');
  }

  /// Check if error is auth-related
  bool _isAuthError(dynamic error) {
    return error is FirebaseAuthException;
  }

  /// Get user-friendly error message
  String _getUserFriendlyMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      return _getAuthErrorMessage(error.code);
    }

    if (error is FirebaseException) {
      return _getFirebaseErrorMessage(error.code);
    }

    if (_isNetworkError(error)) {
      return 'Интернет холболтын алдаа. Холболтоо шалгаад дахин оролдоно уу.';
    }

    if (error.toString().contains('timeout')) {
      return 'Хүсэлт хэт удаж байна. Дахин оролдоно уу.';
    }

    return 'Алдаа гарлаа. Дахин оролдоно уу.';
  }

  /// Get auth error message in Mongolian
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'network-request-failed':
        return 'Интернет холболтын алдаа. Дахин оролдоно уу.';
      case 'too-many-requests':
        return 'Хэт олон хүсэлт илгээсэн байна. Түр хүлээгээд дахин оролдоно уу.';
      case 'user-disabled':
        return 'Таны бүртгэл түр хаагдсан байна. Дэмжлэгтэй холбогдоно уу.';
      case 'user-not-found':
        return 'Хэрэглэгч олдсонгүй. И-мэйл хаягаа шалгаад дахин оролдоно уу.';
      case 'wrong-password':
        return 'Нууц үг буруу байна. Дахин оролдоно уу.';
      case 'invalid-email':
        return 'И-мэйл хаягын формат буруу байна.';
      case 'weak-password':
        return 'Нууц үг хэт сул байна. Илүү хүчтэй нууц үг сонгоно уу.';
      case 'email-already-in-use':
        return 'Энэ и-мэйл хаяг аль хэдийн бүртгэгдсэн байна.';
      default:
        return 'Нэвтрэхэд алдаа гарлаа. Дахин оролдоно уу.';
    }
  }

  /// Get Firebase error message in Mongolian
  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'permission-denied':
        return 'Хандах эрх байхгүй байна.';
      case 'unavailable':
        return 'Үйлчилгээ түр хүртээмжгүй байна. Дахин оролдоно уу.';
      case 'cancelled':
        return 'Үйлдэл цуцлагдлаа.';
      case 'deadline-exceeded':
        return 'Хүсэлт хэт удаж байна. Дахин оролдоно уу.';
      case 'not-found':
        return 'Хүссэн мэдээлэл олдсонгүй.';
      case 'already-exists':
        return 'Мэдээлэл аль хэдийн байна.';
      case 'resource-exhausted':
        return 'Хэт олон хүсэлт илгээсэн байна. Түр хүлээгээд дахин оролдоно уу.';
      default:
        return 'Алдаа гарлаа. Дахин оролдоно уу.';
    }
  }

  /// Show error to user with optional retry button
  void _showErrorToUser(
      BuildContext context, String message, VoidCallback? onRetry) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: onRetry != null
            ? SnackBarAction(
                label: 'Дахин оролдох',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  /// Create standardized error handling wrapper for UI operations
  Widget errorBoundary({
    required Widget child,
    required String operation,
    Widget? fallbackWidget,
    VoidCallback? onRetry,
  }) {
    return ErrorBoundaryWidget(
      operation: operation,
      fallbackWidget: fallbackWidget,
      onRetry: onRetry,
      child: child,
    );
  }
}

/// Error boundary widget for catching and handling widget errors
class ErrorBoundaryWidget extends StatefulWidget {
  final Widget child;
  final String operation;
  final Widget? fallbackWidget;
  final VoidCallback? onRetry;

  const ErrorBoundaryWidget({
    Key? key,
    required this.child,
    required this.operation,
    this.fallbackWidget,
    this.onRetry,
  }) : super(key: key);

  @override
  State<ErrorBoundaryWidget> createState() => _ErrorBoundaryWidgetState();
}

class _ErrorBoundaryWidgetState extends State<ErrorBoundaryWidget> {
  bool _hasError = false;
  String _errorMessage = '';

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.fallbackWidget ?? _buildErrorWidget();
    }

    return widget.child;
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'Алдаа гарлаа',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (widget.onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _errorMessage = '';
                });
                widget.onRetry!();
              },
              child: const Text('Дахин оролдох'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Extension methods for common error handling patterns
extension ErrorHandlingExtensions on Future {
  /// Safe execution with error handling
  Future<T?> handleErrors<T>({
    required String operation,
    BuildContext? context,
    Map<String, dynamic>? additionalContext,
    bool showUserMessage = true,
    bool logError = true,
    T? fallbackValue,
    VoidCallback? onRetry,
  }) async {
    try {
      return await this as T;
    } catch (error, stackTrace) {
      return await ErrorHandlerService.instance.handleError<T>(
        operation: operation,
        error: error,
        stackTrace: stackTrace,
        context: context,
        additionalContext: additionalContext,
        showUserMessage: showUserMessage,
        logError: logError,
        fallbackValue: fallbackValue,
        onRetry: onRetry,
      );
    }
  }
}
