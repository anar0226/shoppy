import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration for production deployment
class EnvironmentConfig {
  // Environment type
  static const bool isProduction =
      bool.fromEnvironment('PRODUCTION', defaultValue: false);
  static const bool isDebug =
      bool.fromEnvironment('DEBUG', defaultValue: false);

  // Payment configurations - Prioritize compile-time variables for production
  static String get qpayUsername {
    // First try compile-time environment variables (for CI/CD builds)
    const envValue = String.fromEnvironment('QPAY_USERNAME', defaultValue: '');
    if (envValue.isNotEmpty) {
      return envValue;
    }

    // Fallback to dotenv for development
    final dotenvValue = dotenv.env['QPAY_USERNAME'];
    if (dotenvValue != null && dotenvValue.isNotEmpty) {
      return dotenvValue;
    }

    return '';
  }

  static String get qpayPassword {
    const envValue = String.fromEnvironment('QPAY_PASSWORD', defaultValue: '');
    if (envValue.isNotEmpty) {
      return envValue;
    }

    final dotenvValue = dotenv.env['QPAY_PASSWORD'];
    if (dotenvValue != null && dotenvValue.isNotEmpty) {
      return dotenvValue;
    }

    return '';
  }

  static String get qpayInvoiceCode {
    const envValue =
        String.fromEnvironment('QPAY_INVOICE_CODE', defaultValue: '');
    if (envValue.isNotEmpty) {
      return envValue;
    }

    final dotenvValue = dotenv.env['QPAY_INVOICE_CODE'];
    if (dotenvValue != null && dotenvValue.isNotEmpty) {
      return dotenvValue;
    }

    return '';
  }

  static String get qpayBaseUrl {
    const envValue = String.fromEnvironment('QPAY_BASE_URL', defaultValue: '');
    if (envValue.isNotEmpty) {
      return envValue;
    }

    final dotenvValue = dotenv.env['QPAY_BASE_URL'];
    if (dotenvValue != null && dotenvValue.isNotEmpty) {
      return dotenvValue;
    }

    // Default to production QPay URL
    return 'https://merchant.qpay.mn/v2';
  }

  // Firebase configurations - Also prioritize compile-time variables
  static String get firebaseApiKey {
    const envValue =
        String.fromEnvironment('FIREBASE_API_KEY', defaultValue: '');
    if (envValue.isNotEmpty) {
      return envValue;
    }

    final dotenvValue = dotenv.env['F_API_KEY'];
    if (dotenvValue != null && dotenvValue.isNotEmpty) {
      return dotenvValue;
    }

    return '';
  }

  static String get firebaseAppId {
    const envValue =
        String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '');
    if (envValue.isNotEmpty) {
      return envValue;
    }

    final dotenvValue = dotenv.env['F_APP_ID'];
    if (dotenvValue != null && dotenvValue.isNotEmpty) {
      return dotenvValue;
    }

    return '';
  }

  static String get firebaseProjectId {
    const envValue =
        String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: '');
    if (envValue.isNotEmpty) {
      return envValue;
    }

    final dotenvValue = dotenv.env['F_PROJECT_ID'];
    if (dotenvValue != null && dotenvValue.isNotEmpty) {
      return dotenvValue;
    }

    return '';
  }

  static String get firebaseSenderId {
    const envValue =
        String.fromEnvironment('FIREBASE_SENDER_ID', defaultValue: '');
    if (envValue.isNotEmpty) {
      return envValue;
    }

    final dotenvValue = dotenv.env['F_SENDER_ID'];
    if (dotenvValue != null && dotenvValue.isNotEmpty) {
      return dotenvValue;
    }

    return '';
  }

  // Firebase Web VAPID key used to retrieve FCM token on web
  static String get firebaseWebVapidKey {
    const envValue =
        String.fromEnvironment('F_WEB_VAPID_KEY', defaultValue: '');
    if (envValue.isNotEmpty) {
      return envValue;
    }
    final dotenvValue = dotenv.env['F_WEB_VAPID_KEY'];
    if (dotenvValue != null && dotenvValue.isNotEmpty) {
      return dotenvValue;
    }
    return '';
  }

  // App configurations
  static const String appVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');
  static const String buildNumber =
      String.fromEnvironment('BUILD_NUMBER', defaultValue: '1');

  // Feature flags
  static const bool enableAnalytics =
      bool.fromEnvironment('ENABLE_ANALYTICS', defaultValue: true);
  static const bool enableCrashReporting =
      bool.fromEnvironment('ENABLE_CRASH_REPORTING', defaultValue: true);
  static const bool enablePerformanceMonitoring =
      bool.fromEnvironment('ENABLE_PERFORMANCE_MONITORING', defaultValue: true);

  // API endpoints
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'https://api.avii.mn');
  static const String cdnBaseUrl = String.fromEnvironment('CDN_BASE_URL',
      defaultValue: 'https://cdn.avii.mn');

  // Validation helpers
  static bool get hasPaymentConfig =>
      qpayUsername.isNotEmpty &&
      qpayPassword.isNotEmpty &&
      qpayInvoiceCode.isNotEmpty;

  // Get configuration summary for debugging (without sensitive data)
  static Map<String, dynamic> getConfigSummary() {
    return {
      'isProduction': isProduction,
      'isDebug': isDebug,
      'appVersion': appVersion,
      'buildNumber': buildNumber,
      'hasPaymentConfig': hasPaymentConfig,
      'enableAnalytics': enableAnalytics,
      'enableCrashReporting': enableCrashReporting,
      'enablePerformanceMonitoring': enablePerformanceMonitoring,
      'apiBaseUrl': apiBaseUrl,
      'cdnBaseUrl': cdnBaseUrl,
    };
  }
}
