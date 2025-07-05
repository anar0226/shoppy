/// Comprehensive validation utilities for production-ready forms
class ValidationUtils {
  // Email validation
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'И-мэйл хаяг оруулна уу';
    }

    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Зөв и-мэйл хаяг оруулна уу';
    }

    return null;
  }

  // Password validation
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Нууц үг оруулна уу';
    }

    if (value.length < 8) {
      return 'Нууц үг хамгийн багадаа 8 тэмдэгт байх ёстой';
    }

    // Check for at least one uppercase letter
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Нууц үгэнд хамгийн багадаа нэг том үсэг байх ёстой';
    }

    // Check for at least one lowercase letter
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Нууц үгэнд хамгийн багадаа нэг жижиг үсэг байх ёстой';
    }

    // Check for at least one number
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Нууц үгэнд хамгийн багадаа нэг тоо байх ёстой';
    }

    return null;
  }

  // Phone number validation (Mongolia format)
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Утасны дугаар оруулна уу';
    }

    // Remove spaces and dashes
    final cleanNumber = value.replaceAll(RegExp(r'[\s-]'), '');

    // Check for Mongolia phone number format (8 digits)
    if (cleanNumber.length == 8 &&
        RegExp(r'^[0-9]{8}$').hasMatch(cleanNumber)) {
      return null;
    }

    // Check for international format (+976 followed by 8 digits)
    if (cleanNumber.startsWith('+976') && cleanNumber.length == 12) {
      final localPart = cleanNumber.substring(4);
      if (RegExp(r'^[0-9]{8}$').hasMatch(localPart)) {
        return null;
      }
    }

    return '8 оронтой утасны дугаар оруулна уу';
  }

  // Name validation
  static String? validateName(String? value, {int minLength = 2}) {
    if (value == null || value.trim().isEmpty) {
      return 'Нэр оруулна уу';
    }

    if (value.trim().length < minLength) {
      return 'Нэр хамгийн багадаа $minLength тэмдэгт байх ёстой';
    }

    // Check for valid characters (letters, spaces, hyphens)
    if (!RegExp(r'^[a-zA-Zа-яёА-ЯЁ\s\-]+$').hasMatch(value.trim())) {
      return 'Нэрэнд зөвхөн үсэг, зай, зураас орж болно';
    }

    return null;
  }

  // Price validation
  static String? validatePrice(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Үнэ оруулна уу';
    }

    final price = double.tryParse(value.trim());
    if (price == null || price <= 0) {
      return 'Зөв үнэ оруулна уу';
    }

    if (price > 999999999) {
      return 'Үнэ хэт өндөр байна';
    }

    return null;
  }

  // Product description validation
  static String? validateDescription(String? value,
      {int minLength = 10, int maxLength = 1000}) {
    if (value == null || value.trim().isEmpty) {
      return 'Тайлбар оруулна уу';
    }

    if (value.trim().length < minLength) {
      return 'Тайлбар хамгийн багадаа $minLength тэмдэгт байх ёстой';
    }

    if (value.trim().length > maxLength) {
      return 'Тайлбар хамгийн ихдээ $maxLength тэмдэгт байх ёстой';
    }

    return null;
  }

  // Search query validation (XSS protection)
  static String? validateSearchQuery(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Search can be empty
    }

    // Check for potential XSS patterns
    final xssPatterns = [
      RegExp(r'<script', caseSensitive: false),
      RegExp(r'javascript:', caseSensitive: false),
      RegExp(r'onload=', caseSensitive: false),
      RegExp(r'onerror=', caseSensitive: false),
    ];

    for (final pattern in xssPatterns) {
      if (pattern.hasMatch(value)) {
        return 'Буруу оролт илэрлээ';
      }
    }

    if (value.length > 100) {
      return 'Хайлт хэт урт байна';
    }

    return null;
  }

  // Review content validation
  static String? validateReviewContent(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Үнэлгээ оруулна уу';
    }

    if (value.trim().length < 5) {
      return 'Үнэлгээ хамгийн багадаа 5 тэмдэгт байх ёстой';
    }

    if (value.trim().length > 500) {
      return 'Үнэлгээ хамгийн ихдээ 500 тэмдэгт байх ёстой';
    }

    // Basic profanity check (add more words as needed)
    final profanityWords = [
      'муу',
      'муухай',
      'новш'
    ]; // Add actual profanity words
    final lowerContent = value.toLowerCase();

    for (final word in profanityWords) {
      if (lowerContent.contains(word)) {
        return 'Зохисгүй үг ашиглахыг хориглоно';
      }
    }

    return null;
  }

  // Address validation
  static String? validateAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Хаяг оруулна уу';
    }

    if (value.trim().length < 5) {
      return 'Хаяг хамгийн багадаа 5 тэмдэгт байх ёстой';
    }

    if (value.trim().length > 200) {
      return 'Хаяг хэт урт байна';
    }

    return null;
  }

  // Discount code validation
  static String? validateDiscountCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Хөнгөлөлтийн код оруулна уу';
    }

    if (value.trim().length < 3) {
      return 'Код хамгийн багадаа 3 тэмдэгт байх ёстой';
    }

    if (value.trim().length > 20) {
      return 'Код хэт урт байна';
    }

    // Only allow alphanumeric characters and hyphens
    if (!RegExp(r'^[A-Z0-9\-]+$').hasMatch(value.trim().toUpperCase())) {
      return 'Кодонд зөвхөн үсэг, тоо, зураас орж болно';
    }

    return null;
  }

  // Sanitize input to prevent XSS
  static String sanitizeInput(String input) {
    return input
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('&', '&amp;');
  }

  // Check if string contains only safe characters
  static bool isSafeString(String input) {
    // Allow letters, numbers, spaces, and common punctuation
    final safePattern = RegExp(r'^[a-zA-Zа-яёА-ЯЁ0-9\s\.\,\!\?\-\(\)]+$');
    return safePattern.hasMatch(input);
  }
}
