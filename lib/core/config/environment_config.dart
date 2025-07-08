import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration for production deployment
class EnvironmentConfig {
  // Environment type
  static const bool isProduction =
      bool.fromEnvironment('PRODUCTION', defaultValue: false);
  static const bool isDebug =
      bool.fromEnvironment('DEBUG', defaultValue: false);

  // Payment configurations - Load from dotenv at runtime
  static String get qpayUsername =>
      dotenv.env['QPAY_USERNAME'] ??
      const String.fromEnvironment('QPAY_USERNAME', defaultValue: '');
  static String get qpayPassword =>
      dotenv.env['QPAY_PASSWORD'] ??
      const String.fromEnvironment('QPAY_PASSWORD', defaultValue: '');
  static String get qpayInvoiceCode =>
      dotenv.env['QPAY_INVOICE_CODE'] ??
      const String.fromEnvironment('QPAY_INVOICE_CODE', defaultValue: '');
  static String get qpayBaseUrl =>
      dotenv.env['QPAY_BASE_URL'] ??
      const String.fromEnvironment('QPAY_BASE_URL',
          defaultValue: 'https://merchant.qpay.mn/v2');

  // UBCab delivery configurations
  static const String ubcabApiKey =
      String.fromEnvironment('UBCAB_API_KEY', defaultValue: '');
  static const String ubcabMerchantId =
      String.fromEnvironment('UBCAB_MERCHANT_ID', defaultValue: '');
  static const bool ubcabProduction =
      bool.fromEnvironment('UBCAB_PRODUCTION', defaultValue: false);

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
      defaultValue: 'https://api.shoppy.mn');
  static const String cdnBaseUrl = String.fromEnvironment('CDN_BASE_URL',
      defaultValue: 'https://cdn.shoppy.mn');

  // Validation helpers
  static bool get hasPaymentConfig =>
      qpayUsername.isNotEmpty &&
      qpayPassword.isNotEmpty &&
      qpayInvoiceCode.isNotEmpty;
  static bool get hasDeliveryConfig =>
      ubcabApiKey.isNotEmpty && ubcabMerchantId.isNotEmpty;

  // Get configuration summary for debugging (without sensitive data)
  static Map<String, dynamic> getConfigSummary() {
    return {
      'isProduction': isProduction,
      'isDebug': isDebug,
      'appVersion': appVersion,
      'buildNumber': buildNumber,
      'hasPaymentConfig': hasPaymentConfig,
      'hasDeliveryConfig': hasDeliveryConfig,
      'enableAnalytics': enableAnalytics,
      'enableCrashReporting': enableCrashReporting,
      'enablePerformanceMonitoring': enablePerformanceMonitoring,
      'apiBaseUrl': apiBaseUrl,
      'cdnBaseUrl': cdnBaseUrl,
    };
  }
}
