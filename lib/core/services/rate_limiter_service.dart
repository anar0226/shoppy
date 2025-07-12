import 'dart:collection';
import 'package:flutter/foundation.dart';

class RateLimiterService {
  static final RateLimiterService _instance = RateLimiterService._internal();
  factory RateLimiterService() => _instance;
  RateLimiterService._internal();

  // Track requests by operation type
  final Map<String, Queue<DateTime>> _requestHistory = {};

  // Rate limit configurations
  static const Map<String, RateLimit> _rateLimits = {
    'firestore_read': RateLimit(maxRequests: 50, windowSeconds: 60),
    'firestore_write': RateLimit(maxRequests: 20, windowSeconds: 60),
    'auth_attempt': RateLimit(
        maxRequests: 5, windowSeconds: 300), // 5 attempts per 5 minutes
    'search_query': RateLimit(maxRequests: 30, windowSeconds: 60),
    'cart_action': RateLimit(maxRequests: 100, windowSeconds: 60),
    'image_upload': RateLimit(maxRequests: 10, windowSeconds: 300),
    'email_verification':
        RateLimit(maxRequests: 3, windowSeconds: 600), // 3 per 10 minutes
    'password_reset': RateLimit(maxRequests: 3, windowSeconds: 600),
  };

  /// Check if an operation is allowed under rate limits
  bool isAllowed(String operation) {
    final limit = _rateLimits[operation];
    if (limit == null) {
      debugPrint('No rate limit configured for operation: $operation');
      return true; // Allow if no limit configured
    }

    final now = DateTime.now();
    final history =
        _requestHistory.putIfAbsent(operation, () => Queue<DateTime>());

    // Remove old requests outside the time window
    while (history.isNotEmpty &&
        now.difference(history.first).inSeconds > limit.windowSeconds) {
      history.removeFirst();
    }

    // Check if we're under the limit
    if (history.length >= limit.maxRequests) {
      debugPrint(
          'Rate limit exceeded for $operation: ${history.length}/${limit.maxRequests} requests in ${limit.windowSeconds}s');
      return false;
    }

    // Record this request
    history.addLast(now);
    return true;
  }

  /// Get remaining requests for an operation
  int getRemainingRequests(String operation) {
    final limit = _rateLimits[operation];
    if (limit == null) return 999; // Unlimited if no limit configured

    final now = DateTime.now();
    final history =
        _requestHistory.putIfAbsent(operation, () => Queue<DateTime>());

    // Remove old requests outside the time window
    while (history.isNotEmpty &&
        now.difference(history.first).inSeconds > limit.windowSeconds) {
      history.removeFirst();
    }

    return (limit.maxRequests - history.length).clamp(0, limit.maxRequests);
  }

  /// Get time until rate limit resets (in seconds)
  int getTimeUntilReset(String operation) {
    final limit = _rateLimits[operation];
    if (limit == null) return 0;

    final history = _requestHistory[operation];
    if (history == null || history.isEmpty) return 0;

    final oldestRequest = history.first;
    final resetTime = oldestRequest.add(Duration(seconds: limit.windowSeconds));
    final now = DateTime.now();

    return resetTime.isAfter(now) ? resetTime.difference(now).inSeconds : 0;
  }

  /// Clear rate limit history for an operation (for testing)
  void clearHistory(String operation) {
    _requestHistory.remove(operation);
  }

  /// Clear all rate limit history
  void clearAllHistory() {
    _requestHistory.clear();
  }

  /// Record a request without checking limits (for external rate limiting)
  void recordRequest(String operation) {
    final now = DateTime.now();
    final history =
        _requestHistory.putIfAbsent(operation, () => Queue<DateTime>());
    history.addLast(now);
  }

  /// Record successful operation (for analytics and security tracking)
  void recordSuccess(String operation) {
    // Clear any accumulated requests for this operation on success
    final now = DateTime.now();
    final history = _requestHistory[operation];

    if (history != null && history.isNotEmpty) {
      // Keep only recent successful operations for rate limiting purposes
      final limit = _rateLimits[operation];
      if (limit != null) {
        while (history.isNotEmpty &&
            now.difference(history.first).inSeconds > limit.windowSeconds) {
          history.removeFirst();
        }
      }
    }

    debugPrint('Recorded successful operation: $operation');
  }
}

class RateLimit {
  final int maxRequests;
  final int windowSeconds;

  const RateLimit({
    required this.maxRequests,
    required this.windowSeconds,
  });
}

/// Exception thrown when rate limit is exceeded
class RateLimitExceededException implements Exception {
  final String operation;
  final int retryAfterSeconds;

  const RateLimitExceededException(this.operation, this.retryAfterSeconds);

  @override
  String toString() {
    return 'Rate limit exceeded for $operation. Retry after $retryAfterSeconds seconds.';
  }
}

/// Mixin for adding rate limiting to services
mixin RateLimitedService {
  final RateLimiterService _rateLimiter = RateLimiterService();

  /// Check rate limit and throw exception if exceeded
  void checkRateLimit(String operation) {
    if (!_rateLimiter.isAllowed(operation)) {
      final retryAfter = _rateLimiter.getTimeUntilReset(operation);
      throw RateLimitExceededException(operation, retryAfter);
    }
  }

  /// Check rate limit and return false if exceeded (no exception)
  bool tryCheckRateLimit(String operation) {
    return _rateLimiter.isAllowed(operation);
  }
}
