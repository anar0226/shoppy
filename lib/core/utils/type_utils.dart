/// Utility functions for safe type conversions and null-safe operations
class TypeUtils {
  /// Safely parse string to int with default fallback
  static int safeParseInt(String? value, {int defaultValue = 0}) {
    if (value == null || value.trim().isEmpty) return defaultValue;
    return int.tryParse(value.trim()) ?? defaultValue;
  }

  /// Safely parse string to double with default fallback
  static double safeParseDouble(String? value, {double defaultValue = 0.0}) {
    if (value == null || value.trim().isEmpty) return defaultValue;
    return double.tryParse(value.trim()) ?? defaultValue;
  }

  /// Safely get int from dynamic value
  static int safeCastInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return safeParseInt(value, defaultValue: defaultValue);
    return defaultValue;
  }

  /// Safely get double from dynamic value
  static double safeCastDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return safeParseDouble(value, defaultValue: defaultValue);
    }
    return defaultValue;
  }

  /// Safely get string from dynamic value
  static String safeCastString(dynamic value, {String defaultValue = ''}) {
    if (value == null) return defaultValue;
    if (value is String) return value;
    return value.toString();
  }

  /// Check if string is not null and not empty
  static bool isNotEmpty(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  /// Check if URL is valid for network images
  static bool isValidImageUrl(String? url) {
    if (!isNotEmpty(url)) return false;
    final uri = Uri.tryParse(url!);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  /// Safely extract storeId from dynamic data (handles both String and List cases)
  static String extractStoreId(dynamic storeIdData) {
    if (storeIdData == null) return '';
    if (storeIdData is String) return storeIdData;
    if (storeIdData is List && storeIdData.isNotEmpty) {
      return storeIdData.first.toString();
    }
    return storeIdData.toString();
  }
}
