import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'production_logger.dart';

/// Production-ready error recovery service with graceful fallbacks
class ErrorRecoveryService {
  static final ErrorRecoveryService _instance =
      ErrorRecoveryService._internal();
  static ErrorRecoveryService get instance => _instance;
  ErrorRecoveryService._internal();

  final Map<String, DateTime> _lastAttempts = {};
  final Map<String, int> _attemptCounts = {};
  static const Duration _retryBackoff = Duration(seconds: 5);
  static const int _maxRetries = 3;

  /// Execute operation with automatic retry and error recovery
  Future<T?> executeWithRecovery<T>({
    required String operationName,
    required Future<T> Function() operation,
    Future<T?> Function()? fallback,
    bool logErrors = true,
    Duration? customTimeout,
    int? maxRetries,
  }) async {
    final effectiveMaxRetries = maxRetries ?? _maxRetries;
    final timeout = customTimeout ?? const Duration(seconds: 30);

    for (int attempt = 1; attempt <= effectiveMaxRetries; attempt++) {
      try {
        ProductionLogger.instance.startTrace('operation_$operationName');

        final result = await operation().timeout(timeout);

        await ProductionLogger.instance
            .stopTrace('operation_$operationName', attributes: {
          'success': true,
          'attempt': attempt,
        });

        // Reset attempt count on success
        _attemptCounts.remove(operationName);

        return result;
      } catch (error, stackTrace) {
        await ProductionLogger.instance
            .stopTrace('operation_$operationName', attributes: {
          'success': false,
          'attempt': attempt,
          'error': error.toString(),
        });

        if (logErrors) {
          await ProductionLogger.instance.error(
            'Operation failed: $operationName (attempt $attempt/$effectiveMaxRetries)',
            error: error,
            stackTrace: stackTrace,
            context: {
              'operation': operationName,
              'attempt': attempt,
              'maxRetries': effectiveMaxRetries,
              'errorType': _getErrorType(error),
            },
          );
        }

        // If this is the last attempt, try fallback
        if (attempt == effectiveMaxRetries) {
          if (fallback != null) {
            try {
              final fallbackResult = await fallback();
              await ProductionLogger.instance.warning(
                'Fallback succeeded for operation: $operationName',
                context: {
                  'operation': operationName,
                  'totalAttempts': attempt,
                },
              );
              return fallbackResult;
            } catch (fallbackError, fallbackStack) {
              await ProductionLogger.instance.error(
                'Fallback failed for operation: $operationName',
                error: fallbackError,
                stackTrace: fallbackStack,
                context: {
                  'operation': operationName,
                  'originalError': error.toString(),
                },
              );
            }
          }

          // All attempts failed
          _attemptCounts[operationName] = attempt;
          _lastAttempts[operationName] = DateTime.now();

          rethrow;
        }

        // Wait before retry with exponential backoff
        final delay = _retryBackoff * attempt;
        await Future.delayed(delay);
      }
    }

    return null;
  }

  /// Check network connectivity and recover if needed
  Future<bool> checkAndRecoverConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();

      if (connectivityResult == ConnectivityResult.none) {
        await ProductionLogger.instance.warning(
          'No network connectivity detected',
          context: {
            'connectivity': 'none',
            'recovery': 'waiting_for_connection',
          },
        );

        // Wait for connectivity to return
        await for (final result in Connectivity().onConnectivityChanged) {
          if (result != ConnectivityResult.none) {
            await ProductionLogger.instance.info(
              'Network connectivity recovered',
              context: {
                'connectivity': result.name,
                'recovery': 'successful',
              },
            );
            return true;
          }
        }
      }

      return true;
    } catch (error, stackTrace) {
      await ProductionLogger.instance.error(
        'Connectivity check failed',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Recover Firebase Auth session
  Future<bool> recoverAuthSession() async {
    try {
      final auth = FirebaseAuth.instance;
      final currentUser = auth.currentUser;

      if (currentUser == null) {
        await ProductionLogger.instance.warning(
          'No authenticated user found during recovery',
        );
        return false;
      }

      // Try to refresh the user token
      await currentUser.getIdToken(true);

      // Verify the user is still valid
      await currentUser.reload();
      final refreshedUser = auth.currentUser;

      if (refreshedUser == null) {
        await ProductionLogger.instance.warning(
          'User session invalid after refresh',
          context: {
            'userId': currentUser.uid,
            'recovery': 'session_invalid',
          },
        );
        return false;
      }

      await ProductionLogger.instance.info(
        'Auth session recovered successfully',
        context: {
          'userId': refreshedUser.uid,
          'recovery': 'successful',
        },
      );

      return true;
    } catch (error, stackTrace) {
      await ProductionLogger.instance.error(
        'Auth session recovery failed',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Recover Firestore connection
  Future<bool> recoverFirestoreConnection() async {
    try {
      // Try a simple read operation to test connectivity
      await FirebaseFirestore.instance
          .collection('_health_check')
          .doc('test')
          .get()
          .timeout(const Duration(seconds: 10));

      await ProductionLogger.instance.info(
        'Firestore connection recovered successfully',
      );

      return true;
    } catch (error, stackTrace) {
      await ProductionLogger.instance.error(
        'Firestore connection recovery failed',
        error: error,
        stackTrace: stackTrace,
      );

      // Try to re-enable network
      try {
        await FirebaseFirestore.instance.enableNetwork();
        await ProductionLogger.instance.info(
          'Firestore network re-enabled',
        );
        return true;
      } catch (enableError) {
        await ProductionLogger.instance.error(
          'Failed to re-enable Firestore network',
          error: enableError,
        );
        return false;
      }
    }
  }

  /// Graceful degradation for feature unavailability
  Future<T?> gracefulDegradation<T>({
    required String featureName,
    required Future<T> Function() primaryFunction,
    required T Function() fallbackFunction,
    String? fallbackMessage,
  }) async {
    try {
      return await executeWithRecovery(
        operationName: featureName,
        operation: primaryFunction,
        fallback: () async => fallbackFunction(),
      );
    } catch (error) {
      await ProductionLogger.instance.warning(
        'Feature degraded: $featureName',
        context: {
          'feature': featureName,
          'fallbackMessage': fallbackMessage,
          'error': error.toString(),
        },
      );

      return fallbackFunction();
    }
  }

  /// Handle critical errors with user-friendly messages
  String getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
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

    if (error is FirebaseException) {
      switch (error.code) {
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

    if (error.toString().contains('SocketException') ||
        error.toString().contains('TimeoutException')) {
      return 'Интернет холболтын алдаа. Холболтоо шалгаад дахин оролдоно уу.';
    }

    return 'Тодорхойгүй алдаа гарлаа. Дахин оролдоно уу.';
  }

  /// Get error type for categorization
  String _getErrorType(dynamic error) {
    if (error is FirebaseAuthException) return 'auth_error';
    if (error is FirebaseException) return 'firebase_error';
    if (error is TimeoutException) return 'timeout_error';
    if (error.toString().contains('SocketException')) return 'network_error';
    if (error.toString().contains('FormatException')) return 'format_error';
    return 'unknown_error';
  }

  /// Check if operation should be retried based on error type
  bool shouldRetry(dynamic error) {
    if (error is FirebaseAuthException) {
      // Don't retry permanent auth errors
      const permanentErrors = {
        'user-disabled',
        'user-not-found',
        'wrong-password',
        'invalid-email',
        'weak-password',
        'email-already-in-use',
      };
      return !permanentErrors.contains(error.code);
    }

    if (error is FirebaseException) {
      // Don't retry permission or not-found errors
      const permanentErrors = {
        'permission-denied',
        'not-found',
        'already-exists',
      };
      return !permanentErrors.contains(error.code);
    }

    // Retry network and timeout errors
    return error is TimeoutException ||
        error.toString().contains('SocketException') ||
        error.toString().contains('network');
  }

  /// Get recovery statistics
  Map<String, dynamic> getRecoveryStats() {
    return {
      'totalOperations': _attemptCounts.length,
      'failedOperations':
          _attemptCounts.entries.where((e) => e.value >= _maxRetries).length,
      'avgAttempts': _attemptCounts.values.isNotEmpty
          ? _attemptCounts.values.reduce((a, b) => a + b) /
              _attemptCounts.length
          : 0,
      'lastFailures': _lastAttempts.entries
          .where((e) =>
              _attemptCounts[e.key] != null &&
              _attemptCounts[e.key]! >= _maxRetries)
          .map((e) => {
                'operation': e.key,
                'lastAttempt': e.value.toIso8601String(),
                'attempts': _attemptCounts[e.key],
              })
          .toList(),
    };
  }

  /// Clear recovery statistics
  void clearStats() {
    _attemptCounts.clear();
    _lastAttempts.clear();
  }
}
