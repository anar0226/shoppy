import 'dart:math';

class OrderIdGenerator {
  static const String _chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  static final Random _random = Random();

  /// Generates a short, unique order ID that complies with QPay's 45-character limit
  /// Format: PREFIX_TIMESTAMP_RANDOM
  /// Example: ORD_1703123456_ABC123
  static String generate({
    String prefix = 'ORD',
    int timestampLength = 10,
    int randomLength = 6,
  }) {
    // Use seconds since epoch instead of milliseconds to save 3 characters
    final timestamp =
        (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();

    // Take only the last N digits of timestamp to keep it shorter
    final shortTimestamp = timestamp.length > timestampLength
        ? timestamp.substring(timestamp.length - timestampLength)
        : timestamp;

    // Generate random string
    final random = String.fromCharCodes(
      Iterable.generate(
        randomLength,
        (_) => _chars.codeUnitAt(_random.nextInt(_chars.length)),
      ),
    );

    final orderId = '${prefix}_${shortTimestamp}_$random';

    // Ensure it doesn't exceed 45 characters
    if (orderId.length > 45) {
      // If too long, truncate the random part
      final maxRandomLength =
          45 - prefix.length - shortTimestamp.length - 2; // -2 for underscores
      final truncatedRandom = random.substring(0, maxRandomLength);
      return '${prefix}_${shortTimestamp}_$truncatedRandom';
    }

    return orderId;
  }

  /// Generates a subscription-specific order ID
  /// Format: SUB_STOREID_TIMESTAMP_RANDOM
  static String generateSubscription({
    required String storeId,
    int timestampLength = 8,
    int randomLength = 4,
  }) {
    // Use a shorter prefix for subscriptions
    const prefix = 'SUB';

    // Use seconds since epoch
    final timestamp =
        (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final shortTimestamp = timestamp.length > timestampLength
        ? timestamp.substring(timestamp.length - timestampLength)
        : timestamp;

    // Generate random string
    final random = String.fromCharCodes(
      Iterable.generate(
        randomLength,
        (_) => _chars.codeUnitAt(_random.nextInt(_chars.length)),
      ),
    );

    // Calculate available space for storeId
    final usedSpace = prefix.length +
        shortTimestamp.length +
        random.length +
        3; // +3 for underscores
    final maxStoreIdLength = 45 - usedSpace;

    // Truncate storeId if necessary
    final shortStoreId = storeId.length > maxStoreIdLength
        ? storeId.substring(0, maxStoreIdLength)
        : storeId;

    final orderId = '${prefix}_${shortStoreId}_${shortTimestamp}_$random';

    // Final safety check
    if (orderId.length > 45) {
      // If still too long, use a hash of the storeId
      final hash = storeId.hashCode.abs().toString();
      final shortHash = hash.length > 6 ? hash.substring(0, 6) : hash;
      return '${prefix}_${shortHash}_${shortTimestamp}_$random';
    }

    return orderId;
  }

  /// Generates a test order ID for debugging
  /// Format: TEST_TIMESTAMP_RANDOM
  static String generateTest({
    int timestampLength = 8,
    int randomLength = 4,
  }) {
    const prefix = 'TEST';

    final timestamp =
        (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final shortTimestamp = timestamp.length > timestampLength
        ? timestamp.substring(timestamp.length - timestampLength)
        : timestamp;

    final random = String.fromCharCodes(
      Iterable.generate(
        randomLength,
        (_) => _chars.codeUnitAt(_random.nextInt(_chars.length)),
      ),
    );

    return '${prefix}_${shortTimestamp}_$random';
  }

  /// Validates if an order ID is within QPay's 45-character limit
  static bool isValidForQPay(String orderId) {
    return orderId.length <= 45;
  }

  /// Gets the length of an order ID for debugging
  static int getLength(String orderId) {
    return orderId.length;
  }
}
