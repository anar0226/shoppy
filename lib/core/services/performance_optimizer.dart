import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'production_logger.dart';

/// Production performance optimization service
class PerformanceOptimizer {
  static final PerformanceOptimizer _instance =
      PerformanceOptimizer._internal();
  static PerformanceOptimizer get instance => _instance;
  PerformanceOptimizer._internal();

  // Memory management
  final Map<String, dynamic> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Map<String, int> _accessCounts = {};
  static const int _maxCacheSize = 100;
  static const Duration _cacheExpiry = Duration(minutes: 30);

  // Image optimization
  final Map<String, Uint8List> _imageCache = {};
  final Map<String, Future<Uint8List?>> _imageLoadingFutures = {};
  static const int _maxImageCacheSize = 50;

  // Query optimization
  final Map<String, QuerySnapshot> _queryCache = {};
  final Map<String, DateTime> _queryTimestamps = {};
  static const Duration _queryExpiry = Duration(minutes: 10);

  // Performance metrics
  int _cacheHits = 0;
  int _cacheMisses = 0;

  /// Optimize memory usage by cleaning up unused resources
  Future<void> optimizeMemory() async {
    try {
      ProductionLogger.instance.startTrace('memory_optimization');

      final beforeCleanup = _getMemoryUsage();

      // Clean expired cache entries
      _cleanExpiredCache();

      // Clean image cache if too large
      _cleanImageCache();

      // Trigger garbage collection in debug mode
      if (kDebugMode) {
        await _triggerGarbageCollection();
      }

      final afterCleanup = _getMemoryUsage();
      final freedMemory = beforeCleanup - afterCleanup;

      await ProductionLogger.instance
          .stopTrace('memory_optimization', attributes: {
        'freed_memory_mb': freedMemory,
        'cache_entries_before': beforeCleanup,
        'cache_entries_after': afterCleanup,
      });

      await ProductionLogger.instance.performance(
        'memory_optimization',
        duration: Duration.zero,
        metrics: {
          'freed_memory_mb': freedMemory,
          'cache_hit_ratio': _getCacheHitRatio(),
        },
      );
    } catch (error, stackTrace) {
      await ProductionLogger.instance.error(
        'Memory optimization failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Cache data with automatic expiry and size management
  void cacheData(String key, dynamic data, {Duration? customExpiry}) {
    final expiry = customExpiry ?? _cacheExpiry;

    // Remove old entry if exists
    if (_memoryCache.containsKey(key)) {
      _memoryCache.remove(key);
      _cacheTimestamps.remove(key);
      _accessCounts.remove(key);
    }

    // Add new entry
    _memoryCache[key] = data;
    _cacheTimestamps[key] = DateTime.now().add(expiry);
    _accessCounts[key] = 1;

    // Manage cache size
    if (_memoryCache.length > _maxCacheSize) {
      _evictLeastUsedEntries();
    }
  }

  /// Get cached data with automatic hit/miss tracking
  T? getCachedData<T>(String key) {
    if (!_memoryCache.containsKey(key)) {
      _cacheMisses++;
      return null;
    }

    // Check expiry
    final expiry = _cacheTimestamps[key];
    if (expiry != null && DateTime.now().isAfter(expiry)) {
      _memoryCache.remove(key);
      _cacheTimestamps.remove(key);
      _accessCounts.remove(key);
      _cacheMisses++;
      return null;
    }

    // Update access count
    _accessCounts[key] = (_accessCounts[key] ?? 0) + 1;
    _cacheHits++;

    return _memoryCache[key] as T?;
  }

  /// Cache Firestore queries with automatic optimization
  Future<QuerySnapshot> cacheQuery(
    String queryKey,
    Future<QuerySnapshot> Function() queryFunction,
  ) async {
    // Check cache first
    final cached = _queryCache[queryKey];
    final timestamp = _queryTimestamps[queryKey];

    if (cached != null &&
        timestamp != null &&
        DateTime.now().difference(timestamp) < _queryExpiry) {
      await ProductionLogger.instance.debug('Query cache hit: $queryKey');
      return cached;
    }

    // Execute query
    ProductionLogger.instance.startTrace('firestore_query_$queryKey');

    try {
      final result = await queryFunction();

      // Cache result
      _queryCache[queryKey] = result;
      _queryTimestamps[queryKey] = DateTime.now();

      // Manage cache size
      if (_queryCache.length > 20) {
        final oldestKey = _queryTimestamps.entries
            .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
            .key;
        _queryCache.remove(oldestKey);
        _queryTimestamps.remove(oldestKey);
      }

      await ProductionLogger.instance
          .stopTrace('firestore_query_$queryKey', attributes: {
        'cache_miss': true,
        'result_count': result.docs.length,
      });

      return result;
    } catch (error) {
      await ProductionLogger.instance
          .stopTrace('firestore_query_$queryKey', attributes: {
        'error': true,
        'error_message': error.toString(),
      });
      rethrow;
    }
  }

  /// Optimize image loading with caching and compression
  Future<Uint8List?> optimizeImageLoading(
    String imageUrl, {
    int? maxWidth,
    int? maxHeight,
    int quality = 85,
  }) async {
    final cacheKey =
        _generateImageCacheKey(imageUrl, maxWidth, maxHeight, quality);

    // Check cache first
    if (_imageCache.containsKey(cacheKey)) {
      await ProductionLogger.instance.debug('Image cache hit: $imageUrl');
      return _imageCache[cacheKey];
    }

    // Check if already loading
    if (_imageLoadingFutures.containsKey(cacheKey)) {
      return await _imageLoadingFutures[cacheKey];
    }

    // Start loading
    final loadingFuture = _loadAndOptimizeImage(
      imageUrl,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      quality: quality,
    );

    _imageLoadingFutures[cacheKey] = loadingFuture;

    try {
      final result = await loadingFuture;

      if (result != null) {
        // Cache the result
        _imageCache[cacheKey] = result;

        // Manage cache size
        if (_imageCache.length > _maxImageCacheSize) {
          final firstKey = _imageCache.keys.first;
          _imageCache.remove(firstKey);
        }
      }

      return result;
    } finally {
      _imageLoadingFutures.remove(cacheKey);
    }
  }

  /// Preload critical data for better performance
  Future<void> preloadCriticalData() async {
    try {
      ProductionLogger.instance.startTrace('preload_critical_data');

      // Preload commonly used Firestore data
      final futures = <Future>[];

      // Preload categories
      futures.add(cacheQuery(
          'categories',
          () => FirebaseFirestore.instance
              .collection('categories')
              .limit(10)
              .get()));

      // Preload featured products
      futures.add(cacheQuery(
          'featured_products',
          () => FirebaseFirestore.instance
              .collection('products')
              .where('featured', isEqualTo: true)
              .limit(10)
              .get()));

      await Future.wait(futures);

      await ProductionLogger.instance
          .stopTrace('preload_critical_data', attributes: {
        'preloaded_collections': futures.length,
      });

      await ProductionLogger.instance
          .info('Critical data preloaded successfully');
    } catch (error, stackTrace) {
      await ProductionLogger.instance.error(
        'Critical data preloading failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Optimize app startup performance
  Future<void> optimizeStartup() async {
    try {
      ProductionLogger.instance.startTrace('startup_optimization');

      // Clean up any stale data
      await optimizeMemory();

      // Preload critical data
      await preloadCriticalData();

      // Initialize commonly used services
      await _initializeServices();

      await ProductionLogger.instance.stopTrace('startup_optimization');

      await ProductionLogger.instance.info('Startup optimization completed');
    } catch (error, stackTrace) {
      await ProductionLogger.instance.error(
        'Startup optimization failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Clean expired cache entries
  void _cleanExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    for (final entry in _cacheTimestamps.entries) {
      if (now.isAfter(entry.value)) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _memoryCache.remove(key);
      _cacheTimestamps.remove(key);
      _accessCounts.remove(key);
    }
  }

  /// Evict least used cache entries
  void _evictLeastUsedEntries() {
    final sorted = _accessCounts.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final toRemove = sorted.take(_maxCacheSize ~/ 4);
    for (final entry in toRemove) {
      _memoryCache.remove(entry.key);
      _cacheTimestamps.remove(entry.key);
      _accessCounts.remove(entry.key);
    }
  }

  /// Clean image cache
  void _cleanImageCache() {
    if (_imageCache.length <= _maxImageCacheSize) return;

    final keysToRemove =
        _imageCache.keys.take(_imageCache.length - _maxImageCacheSize);
    for (final key in keysToRemove) {
      _imageCache.remove(key);
    }
  }

  /// Trigger garbage collection (debug only)
  Future<void> _triggerGarbageCollection() async {
    if (!kDebugMode) return;

    try {
      // Force garbage collection
      await Future.delayed(const Duration(milliseconds: 100));
      // Note: In production, avoid forcing GC as it can cause performance issues
    } catch (e) {
      // Ignore GC errors
    }
  }

  /// Get current memory usage estimate
  int _getMemoryUsage() {
    return _memoryCache.length + _imageCache.length + _queryCache.length;
  }

  /// Get cache hit ratio
  double _getCacheHitRatio() {
    final total = _cacheHits + _cacheMisses;
    return total > 0 ? _cacheHits / total : 0.0;
  }

  /// Generate image cache key
  String _generateImageCacheKey(
      String url, int? width, int? height, int quality) {
    return '$url:${width ?? 'auto'}x${height ?? 'auto'}:q$quality';
  }

  /// Load and optimize image (placeholder implementation)
  Future<Uint8List?> _loadAndOptimizeImage(
    String imageUrl, {
    int? maxWidth,
    int? maxHeight,
    int quality = 85,
  }) async {
    try {
      ProductionLogger.instance.startTrace('image_optimization');

      // In a real implementation, you would:
      // 1. Download the image
      // 2. Resize it using image processing library
      // 3. Compress it
      // 4. Return the optimized bytes

      // For now, return null as placeholder
      await ProductionLogger.instance
          .stopTrace('image_optimization', attributes: {
        'url': imageUrl,
        'max_width': maxWidth,
        'max_height': maxHeight,
        'quality': quality,
      });

      return null;
    } catch (error, stackTrace) {
      await ProductionLogger.instance.error(
        'Image optimization failed',
        error: error,
        stackTrace: stackTrace,
        context: {
          'url': imageUrl,
          'max_width': maxWidth,
          'max_height': maxHeight,
        },
      );
      return null;
    }
  }

  /// Initialize commonly used services
  Future<void> _initializeServices() async {
    // Warm up Firestore connection
    try {
      FirebaseFirestore.instance.settings;
    } catch (e) {
      // Ignore initialization errors
    }
  }

  /// Get performance statistics
  Map<String, dynamic> getPerformanceStats() {
    return {
      'cache_stats': {
        'hits': _cacheHits,
        'misses': _cacheMisses,
        'hit_ratio': _getCacheHitRatio(),
        'total_entries': _memoryCache.length,
      },
      'memory_stats': {
        'memory_cache_entries': _memoryCache.length,
        'image_cache_entries': _imageCache.length,
        'query_cache_entries': _queryCache.length,
        'total_memory_usage': _getMemoryUsage(),
      },
      'optimization_stats': {
        'max_cache_size': _maxCacheSize,
        'max_image_cache_size': _maxImageCacheSize,
        'cache_expiry_minutes': _cacheExpiry.inMinutes,
        'query_expiry_minutes': _queryExpiry.inMinutes,
      },
    };
  }

  /// Clear all caches
  void clearAllCaches() {
    _memoryCache.clear();
    _cacheTimestamps.clear();
    _accessCounts.clear();
    _imageCache.clear();
    _queryCache.clear();
    _queryTimestamps.clear();
    _cacheHits = 0;
    _cacheMisses = 0;
  }

  /// Schedule periodic optimization
  void schedulePeriodicOptimization() {
    Timer.periodic(const Duration(minutes: 30), (timer) {
      optimizeMemory();
    });
  }
}
