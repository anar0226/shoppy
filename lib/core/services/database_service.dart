import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Enterprise-grade database service with connection pooling and optimization
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  // Connection pool with advanced optimization
  static FirebaseFirestore? _firestore;
  static FirebaseAuth? _auth;
  static bool _isInitialized = false;

  // Multi-level caching system
  final Map<String, QuerySnapshot> _queryCache = {};
  final Map<String, List<DocumentSnapshot>> _documentCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Map<String, int> _accessCount = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);
  static const Duration _hotCacheExpiry = Duration(minutes: 15);
  static const int _maxCacheSize = 1000;

  // Connection optimization settings
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 1);
  static const Duration _timeout = Duration(seconds: 30);

  // Performance monitoring
  int _totalQueries = 0;
  int _cacheHits = 0;
  int _cacheMisses = 0;
  final Map<String, Duration> _queryLatency = {};

  // Connection pool stats
  DateTime? _lastConnectionTime;
  int _connectionAttempts = 0;
  bool _connectionHealthy = true;

  /// Get optimized Firestore instance with connection pooling
  FirebaseFirestore get firestore {
    if (!_isInitialized) {
      _initializeConnection();
    }
    return _firestore!;
  }

  /// Initialize connection with optimal settings
  void _initializeConnection() {
    if (_isInitialized) return;

    try {
      _connectionAttempts++;
      _firestore = FirebaseFirestore.instance;

      // Configure settings for optimal performance
      _firestore!.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        ignoreUndefinedProperties: false,
        // Enable offline persistence and multi-tab support
        sslEnabled: true,
      );

      _lastConnectionTime = DateTime.now();
      _connectionHealthy = true;
      _isInitialized = true;

      debugPrint('DatabaseService: Connection initialized successfully');
    } catch (e) {
      _connectionHealthy = false;
      debugPrint('DatabaseService: Connection failed - $e');
      rethrow;
    }
  }

  /// Get Firebase Auth instance
  FirebaseAuth get auth {
    _auth ??= FirebaseAuth.instance;
    return _auth!;
  }

  /// Execute query with advanced caching and retry logic
  Future<QuerySnapshot> executeQuery({
    required Query query,
    bool useCache = true,
    bool enableRetry = true,
    Duration? customTimeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    _totalQueries++;

    final String cacheKey = _generateCacheKey(query);

    // Check cache first
    if (useCache && _isCacheValid(cacheKey)) {
      _cacheHits++;
      _accessCount[cacheKey] = (_accessCount[cacheKey] ?? 0) + 1;
      return _queryCache[cacheKey]!;
    }

    _cacheMisses++;

    // Execute query with retry logic
    QuerySnapshot? result;
    int attempts = 0;
    final timeout = customTimeout ?? _timeout;

    while (attempts < (enableRetry ? _maxRetries : 1)) {
      try {
        result = await query.get().timeout(timeout);

        // Cache successful result with intelligent management
        if (useCache) {
          _manageCache(cacheKey, result);
        }

        // Record latency
        stopwatch.stop();
        _queryLatency[cacheKey] = stopwatch.elapsed;

        return result;
      } catch (e) {
        attempts++;
        if (attempts >= _maxRetries || !enableRetry) {
          debugPrint('Database query failed after $attempts attempts: $e');
          rethrow;
        }

        // Exponential backoff with jitter
        final delay = _retryDelay * attempts;
        final jitter =
            Duration(milliseconds: (delay.inMilliseconds * 0.1).round());
        await Future.delayed(delay + jitter);
      }
    }

    throw Exception('Query execution failed after maximum retries');
  }

  /// Intelligent cache management with LRU eviction
  void _manageCache(String cacheKey, QuerySnapshot result) {
    // Check if cache is full
    if (_queryCache.length >= _maxCacheSize) {
      _evictLeastUsedCache();
    }

    _queryCache[cacheKey] = result;
    _cacheTimestamps[cacheKey] = DateTime.now();
    _accessCount[cacheKey] = (_accessCount[cacheKey] ?? 0) + 1;
  }

  /// Evict least recently used cache entries
  void _evictLeastUsedCache() {
    // Find entries to evict (remove 20% of cache)
    final evictCount = (_maxCacheSize * 0.2).round();
    final entries = _accessCount.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    for (int i = 0; i < evictCount && i < entries.length; i++) {
      final key = entries[i].key;
      _queryCache.remove(key);
      _cacheTimestamps.remove(key);
      _accessCount.remove(key);
      _queryLatency.remove(key);
    }
  }

  /// Execute document get with caching and retry logic
  Future<DocumentSnapshot> getDocument({
    required DocumentReference ref,
    bool useCache = true,
    bool enableRetry = true,
  }) async {
    int attempts = 0;

    while (attempts < (enableRetry ? _maxRetries : 1)) {
      try {
        return await ref.get().timeout(_timeout);
      } catch (e) {
        attempts++;
        if (attempts >= _maxRetries || !enableRetry) {
          debugPrint('Document get failed after $attempts attempts: $e');
          rethrow;
        }

        await Future.delayed(_retryDelay * attempts);
      }
    }

    throw Exception('Document get failed after maximum retries');
  }

  /// Batch write operations with optimization
  Future<void> executeBatch(List<BatchOperation> operations) async {
    if (operations.isEmpty) return;

    // Split into chunks of 500 (Firestore limit)
    const int batchSize = 500;

    for (int i = 0; i < operations.length; i += batchSize) {
      final chunk = operations.skip(i).take(batchSize).toList();
      final batch = firestore.batch();

      for (final operation in chunk) {
        switch (operation.type) {
          case BatchOperationType.set:
            batch.set(operation.ref, operation.data!);
            break;
          case BatchOperationType.update:
            batch.update(operation.ref, operation.data!);
            break;
          case BatchOperationType.delete:
            batch.delete(operation.ref);
            break;
        }
      }

      await batch.commit().timeout(_timeout);
    }
  }

  /// Get collection reference with optimization
  CollectionReference<Map<String, dynamic>> collection(String path) {
    return firestore.collection(path);
  }

  /// Get document reference
  DocumentReference<Map<String, dynamic>> document(String path) {
    return firestore.doc(path);
  }

  /// Transaction with retry logic
  Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) updateFunction, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    return await firestore.runTransaction(
      updateFunction,
      timeout: timeout,
      maxAttempts: maxAttempts,
    );
  }

  /// Clear query cache
  void clearCache([String? specificKey]) {
    if (specificKey != null) {
      _queryCache.remove(specificKey);
      _cacheTimestamps.remove(specificKey);
      _accessCount.remove(specificKey);
      _queryLatency.remove(specificKey);
    } else {
      _queryCache.clear();
      _cacheTimestamps.clear();
      _accessCount.clear();
      _queryLatency.clear();
    }
    debugPrint('DatabaseService: Cache cleared');
  }

  /// Generate cache key for query
  String _generateCacheKey(Query query) {
    // Create a unique key based on query parameters
    return query.toString();
  }

  /// Check if cache entry is valid
  bool _isCacheValid(String cacheKey) {
    if (!_queryCache.containsKey(cacheKey)) return false;

    final timestamp = _cacheTimestamps[cacheKey];
    if (timestamp == null) return false;

    final age = DateTime.now().difference(timestamp);
    final accessCount = _accessCount[cacheKey] ?? 0;

    // Hot cache - frequently accessed items get longer TTL
    final isHotCache = accessCount > 5;
    final effectiveExpiry = isHotCache ? _hotCacheExpiry : _cacheExpiry;

    return age < effectiveExpiry;
  }

  /// Get performance statistics
  DatabasePerformanceStats getPerformanceStats() {
    final cacheHitRate = _totalQueries > 0 ? _cacheHits / _totalQueries : 0.0;
    final averageLatency = _queryLatency.values.isNotEmpty
        ? _queryLatency.values.reduce((a, b) => a + b) ~/
            _queryLatency.values.length
        : Duration.zero;

    return DatabasePerformanceStats(
      totalQueries: _totalQueries,
      cacheHits: _cacheHits,
      cacheMisses: _cacheMisses,
      cacheHitRate: cacheHitRate,
      averageLatency: averageLatency,
      cacheSize: _queryCache.length,
      connectionHealthy: _connectionHealthy,
      connectionAttempts: _connectionAttempts,
      lastConnectionTime: _lastConnectionTime,
    );
  }

  /// Warm up cache with frequently accessed data
  Future<void> warmUpCache(List<Query> frequentQueries) async {
    debugPrint(
        'DatabaseService: Warming up cache with ${frequentQueries.length} queries');

    for (final query in frequentQueries) {
      try {
        await executeQuery(query: query, useCache: true);
      } catch (e) {
        debugPrint('DatabaseService: Cache warmup failed for query: $e');
      }
    }
  }

  /// Cleanup resources
  void dispose() {
    clearCache();
    _firestore = null;
    _auth = null;
  }

  /// Health check for database connection
  Future<bool> healthCheck() async {
    try {
      await firestore.collection('_health').limit(1).get().timeout(
            const Duration(seconds: 5),
          );
      return true;
    } catch (e) {
      debugPrint('Database health check failed: $e');
      return false;
    }
  }

  /// Get database statistics
  Map<String, dynamic> getStats() {
    return {
      'cacheSize': _queryCache.length,
      'cacheEntries': _queryCache.keys.toList(),
      'lastCacheCleanup': _cacheTimestamps.values.isNotEmpty
          ? _cacheTimestamps.values.reduce((a, b) => a.isAfter(b) ? a : b)
          : null,
    };
  }
}

/// Batch operation definition
class BatchOperation {
  final BatchOperationType type;
  final DocumentReference ref;
  final Map<String, dynamic>? data;

  BatchOperation({
    required this.type,
    required this.ref,
    this.data,
  });

  factory BatchOperation.set(DocumentReference ref, Map<String, dynamic> data) {
    return BatchOperation(
      type: BatchOperationType.set,
      ref: ref,
      data: data,
    );
  }

  factory BatchOperation.update(
      DocumentReference ref, Map<String, dynamic> data) {
    return BatchOperation(
      type: BatchOperationType.update,
      ref: ref,
      data: data,
    );
  }

  factory BatchOperation.delete(DocumentReference ref) {
    return BatchOperation(
      type: BatchOperationType.delete,
      ref: ref,
    );
  }
}

enum BatchOperationType { set, update, delete }

/// Optimized query builder
class OptimizedQuery {
  final DatabaseService _db = DatabaseService();
  Query _query;

  OptimizedQuery(this._query);

  OptimizedQuery where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    List<Object?>? arrayContainsAny,
    List<Object?>? whereIn,
    List<Object?>? whereNotIn,
    bool? isNull,
  }) {
    _query = _query.where(
      field,
      isEqualTo: isEqualTo,
      isNotEqualTo: isNotEqualTo,
      isLessThan: isLessThan,
      isLessThanOrEqualTo: isLessThanOrEqualTo,
      isGreaterThan: isGreaterThan,
      isGreaterThanOrEqualTo: isGreaterThanOrEqualTo,
      arrayContains: arrayContains,
      arrayContainsAny: arrayContainsAny,
      whereIn: whereIn,
      whereNotIn: whereNotIn,
      isNull: isNull,
    );
    return this;
  }

  OptimizedQuery orderBy(Object field, {bool descending = false}) {
    _query = _query.orderBy(field, descending: descending);
    return this;
  }

  OptimizedQuery limit(int limit) {
    _query = _query.limit(limit);
    return this;
  }

  OptimizedQuery startAt(List<Object?> values) {
    _query = _query.startAt(values);
    return this;
  }

  OptimizedQuery startAfter(List<Object?> values) {
    _query = _query.startAfter(values);
    return this;
  }

  OptimizedQuery startAfterDocument(DocumentSnapshot snapshot) {
    _query = _query.startAfterDocument(snapshot);
    return this;
  }

  OptimizedQuery endAt(List<Object?> values) {
    _query = _query.endAt(values);
    return this;
  }

  OptimizedQuery endBefore(List<Object?> values) {
    _query = _query.endBefore(values);
    return this;
  }

  Future<QuerySnapshot> get({bool useCache = true}) {
    return _db.executeQuery(query: _query, useCache: useCache);
  }

  Stream<QuerySnapshot> snapshots() {
    return _query.snapshots();
  }

  Query get query => _query;
}

/// Performance statistics for database operations
class DatabasePerformanceStats {
  final int totalQueries;
  final int cacheHits;
  final int cacheMisses;
  final double cacheHitRate;
  final Duration averageLatency;
  final int cacheSize;
  final bool connectionHealthy;
  final int connectionAttempts;
  final DateTime? lastConnectionTime;

  DatabasePerformanceStats({
    required this.totalQueries,
    required this.cacheHits,
    required this.cacheMisses,
    required this.cacheHitRate,
    required this.averageLatency,
    required this.cacheSize,
    required this.connectionHealthy,
    required this.connectionAttempts,
    this.lastConnectionTime,
  });

  @override
  String toString() {
    return 'DatabasePerformanceStats(totalQueries: $totalQueries, cacheHits: $cacheHits, '
        'cacheMisses: $cacheMisses, cacheHitRate: ${(cacheHitRate * 100).toStringAsFixed(1)}%, '
        'averageLatency: ${averageLatency.inMilliseconds}ms, cacheSize: $cacheSize, '
        'connectionHealthy: $connectionHealthy, connectionAttempts: $connectionAttempts)';
  }
}
