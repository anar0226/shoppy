import 'package:flutter/foundation.dart';

/// Configuration for custom authentication action URLs
class AuthActionConfig {
  static const String _customDomain = 'avii.mn';
  static const String _authPath = '/_/auth/action';

  /// Get the custom action URL for authentication
  static String get actionUrl {
    if (kIsWeb) {
      return 'https://$_customDomain$_authPath';
    }
    // For mobile apps, use the default Firebase auth domain
    return 'https://shoppy-6d81f.firebaseapp.com/__/auth/handler';
  }

  /// Get the custom action URL with query parameters
  static String getActionUrlWithParams({
    required String mode,
    required String oobCode,
    String? continueUrl,
    String? lang,
  }) {
    final baseUrl = actionUrl;
    final params = <String>[];

    params.add('mode=$mode');
    params.add('oobCode=$oobCode');

    if (continueUrl != null) {
      params.add('continueUrl=${Uri.encodeComponent(continueUrl)}');
    }

    if (lang != null) {
      params.add('lang=$lang');
    }

    return '$baseUrl?${params.join('&')}';
  }

  /// Check if the current URL is a custom auth action URL
  static bool isCustomAuthActionUrl(String url) {
    return url.contains('$_customDomain$_authPath');
  }

  /// Extract parameters from custom auth action URL
  static Map<String, String> extractParamsFromUrl(String url) {
    final uri = Uri.parse(url);
    return uri.queryParameters;
  }
}
