import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'database_service.dart';
import 'listener_manager.dart';

/// Enterprise-grade paginated query service with advanced features
class PaginatedQueryService {
  static final PaginatedQueryService _instance =
      PaginatedQueryService._internal();
  factory PaginatedQueryService() => _instance;
  PaginatedQueryService._internal();

  final DatabaseService _db = DatabaseService();
  final ListenerManager _listenerManager = ListenerManager();

  // Active paginated queries tracking
  final Map<String, PaginatedQueryState> _activeQueries = {};

  /// Execute paginated query with full optimization
  Future<PaginatedQueryResult<T>> executePaginatedQuery<T>({
    required String queryId,
    required Query baseQuery,
    required T Function(DocumentSnapshot) fromDoc,
    int pageSize = 20,
    DocumentSnapshot? lastDocument,
    bool useCache = true,
    Duration? cacheTimeout,
    bool Function(T)? filter,
    int Function(T, T)? comparator,
  }) async {
    debugPrint('PaginatedQueryService: Executing paginated query: $queryId');

    try {
      // Build paginated query
      Query query = baseQuery;

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(pageSize + 1); // +1 to check if there are more

      // Execute query with database service optimization
      final snapshot = await _db.executeQuery(
        query: query,
        useCache: useCache,
        customTimeout: cacheTimeout,
      );

      // Process results
      final items = <T>[];
      final docs = snapshot.docs;
      bool hasMore = docs.length > pageSize;

      // Remove extra document if we have more than pageSize
      final processingDocs = hasMore ? docs.take(pageSize).toList() : docs;

      for (final doc in processingDocs) {
        try {
          final item = fromDoc(doc);

          // Apply filter if provided
          if (filter == null || filter(item)) {
            items.add(item);
          }
        } catch (e) {
          debugPrint(
              'PaginatedQueryService: Error processing document ${doc.id}: $e');
        }
      }

      // Apply sorting if provided
      if (comparator != null) {
        items.sort(comparator);
      }

      // Update state
      final state =
          _activeQueries[queryId] ??= PaginatedQueryState(queryId: queryId);
      state.totalLoaded += items.length;
      state.lastDocument = hasMore ? processingDocs.last : null;
      state.hasMore = hasMore;
      state.lastLoadTime = DateTime.now();

      final result = PaginatedQueryResult<T>(
        items: items,
        hasMore: hasMore,
        lastDocument: hasMore ? processingDocs.last : null,
        totalLoaded: state.totalLoaded,
        pageSize: pageSize,
        queryId: queryId,
      );

      debugPrint(
          'PaginatedQueryService: Query $queryId completed - ${items.length} items, hasMore: $hasMore');
      return result;
    } catch (e) {
      debugPrint('PaginatedQueryService: Error executing query $queryId: $e');
      rethrow;
    }
  }

  /// Get paginated categories with caching
  Future<PaginatedQueryResult<Map<String, dynamic>>> getPaginatedCategories({
    String? storeId,
    DocumentSnapshot? lastDocument,
    int pageSize = 20,
    bool activeOnly = true,
  }) async {
    Query query = _db.collection('categories');

    if (storeId != null) {
      query = query.where('storeId', isEqualTo: storeId);
    }

    if (activeOnly) {
      query = query.where('isActive', isEqualTo: true);
    }

    query = query
        .orderBy('sortOrder', descending: false)
        .orderBy('name', descending: false);

    return executePaginatedQuery<Map<String, dynamic>>(
      queryId: 'categories_${storeId ?? 'global'}',
      baseQuery: query,
      fromDoc: (doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>},
      pageSize: pageSize,
      lastDocument: lastDocument,
    );
  }

  /// Get paginated products with advanced filtering
  Future<PaginatedQueryResult<Map<String, dynamic>>> getPaginatedProducts({
    String? storeId,
    String? category,
    String? subCategory,
    String? leafCategory,
    DocumentSnapshot? lastDocument,
    int pageSize = 20,
    bool activeOnly = true,
    double? minPrice,
    double? maxPrice,
    bool? inStock,
  }) async {
    Query query = _db.firestore.collectionGroup('products');

    // Apply filters
    if (storeId != null) {
      query = query.where('storeId', isEqualTo: storeId);
    }

    if (activeOnly) {
      query = query.where('isActive', isEqualTo: true);
    }

    if (inStock == true) {
      query = query.where('inventory', isGreaterThan: 0);
    }

    // Category filtering - use most specific available
    if (leafCategory != null && leafCategory.isNotEmpty) {
      query = query.where('leafCategory', isEqualTo: leafCategory);
    } else if (subCategory != null && subCategory.isNotEmpty) {
      query = query.where('subCategory', isEqualTo: subCategory);
    } else if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }

    // Price filtering (client-side for now, can be optimized with composite indexes)
    query = query.orderBy('createdAt', descending: true);

    return executePaginatedQuery<Map<String, dynamic>>(
      queryId: 'products_${storeId ?? 'all'}_${category ?? 'all'}',
      baseQuery: query,
      fromDoc: (doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>},
      pageSize: pageSize,
      lastDocument: lastDocument,
      filter: (item) {
        // Client-side price filtering
        if (minPrice != null || maxPrice != null) {
          final price = (item['price'] as num?)?.toDouble() ?? 0.0;
          if (minPrice != null && price < minPrice) return false;
          if (maxPrice != null && price > maxPrice) return false;
        }
        return true;
      },
    );
  }

  /// Get paginated orders with comprehensive filtering
  Future<PaginatedQueryResult<Map<String, dynamic>>> getPaginatedOrders({
    String? userId,
    String? storeId,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    DocumentSnapshot? lastDocument,
    int pageSize = 20,
  }) async {
    Query query = _db.collection('orders');

    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }

    if (storeId != null) {
      query = query.where('storeId', isEqualTo: storeId);
    }

    if (status != null && status != 'all') {
      query = query.where('status', isEqualTo: status);
    }

    if (startDate != null) {
      query = query.where('createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }

    if (endDate != null) {
      query = query.where('createdAt',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    query = query.orderBy('createdAt', descending: true);

    return executePaginatedQuery<Map<String, dynamic>>(
      queryId: 'orders_${userId ?? storeId ?? 'all'}',
      baseQuery: query,
      fromDoc: (doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>},
      pageSize: pageSize,
      lastDocument: lastDocument,
    );
  }

  /// Get paginated users with filtering
  Future<PaginatedQueryResult<Map<String, dynamic>>> getPaginatedUsers({
    String? searchQuery,
    String? statusFilter,
    String? userTypeFilter,
    DateTime? fromDate,
    DateTime? toDate,
    DocumentSnapshot? lastDocument,
    int pageSize = 20,
  }) async {
    Query query = _db.collection('users');

    // Apply basic filters
    if (statusFilter != null && statusFilter != 'All Status') {
      bool isActive = statusFilter == 'Active';
      query = query.where('isActive', isEqualTo: isActive);
    }

    if (userTypeFilter != null && userTypeFilter != 'All Types') {
      query = query.where('userType', isEqualTo: userTypeFilter.toLowerCase());
    }

    if (fromDate != null) {
      query = query.where('createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate));
    }

    if (toDate != null) {
      query = query.where('createdAt',
          isLessThanOrEqualTo: Timestamp.fromDate(toDate));
    }

    query = query.orderBy('createdAt', descending: true);

    return executePaginatedQuery<Map<String, dynamic>>(
      queryId: 'users_${statusFilter ?? 'all'}',
      baseQuery: query,
      fromDoc: (doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>},
      pageSize: pageSize,
      lastDocument: lastDocument,
      filter: searchQuery != null && searchQuery.isNotEmpty
          ? (item) {
              final email = (item['email'] as String?)?.toLowerCase() ?? '';
              final name =
                  (item['displayName'] as String?)?.toLowerCase() ?? '';
              final searchLower = searchQuery.toLowerCase();
              return email.contains(searchLower) || name.contains(searchLower);
            }
          : null,
    );
  }

  /// Get paginated stores
  Future<PaginatedQueryResult<Map<String, dynamic>>> getPaginatedStores({
    String? searchQuery,
    String? statusFilter,
    DocumentSnapshot? lastDocument,
    int pageSize = 20,
  }) async {
    Query query = _db.collection('stores');

    if (statusFilter != null && statusFilter != 'all') {
      query = query.where('status', isEqualTo: statusFilter);
    }

    query = query.orderBy('createdAt', descending: true);

    return executePaginatedQuery<Map<String, dynamic>>(
      queryId: 'stores_${statusFilter ?? 'all'}',
      baseQuery: query,
      fromDoc: (doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>},
      pageSize: pageSize,
      lastDocument: lastDocument,
      filter: searchQuery != null && searchQuery.isNotEmpty
          ? (item) {
              final name = (item['name'] as String?)?.toLowerCase() ?? '';
              final description =
                  (item['description'] as String?)?.toLowerCase() ?? '';
              final searchLower = searchQuery.toLowerCase();
              return name.contains(searchLower) ||
                  description.contains(searchLower);
            }
          : null,
    );
  }

  /// Get paginated notifications
  Future<PaginatedQueryResult<Map<String, dynamic>>> getPaginatedNotifications({
    required String userId,
    bool? readStatus,
    DocumentSnapshot? lastDocument,
    int pageSize = 20,
  }) async {
    Query query =
        _db.collection('notifications').where('userId', isEqualTo: userId);

    if (readStatus != null) {
      query = query.where('read', isEqualTo: readStatus);
    }

    query = query.orderBy('createdAt', descending: true);

    return executePaginatedQuery<Map<String, dynamic>>(
      queryId: 'notifications_$userId',
      baseQuery: query,
      fromDoc: (doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>},
      pageSize: pageSize,
      lastDocument: lastDocument,
    );
  }

  /// Reset pagination state for a query
  void resetPaginationState(String queryId) {
    _activeQueries.remove(queryId);
    debugPrint('PaginatedQueryService: Reset pagination state for $queryId');
  }

  /// Get pagination state for a query
  PaginatedQueryState? getPaginationState(String queryId) {
    return _activeQueries[queryId];
  }

  /// Clear all pagination states
  void clearAllStates() {
    _activeQueries.clear();
    debugPrint('PaginatedQueryService: Cleared all pagination states');
  }

  /// Get performance statistics
  Map<String, dynamic> getPerformanceStats() {
    return {
      'activeQueries': _activeQueries.length,
      'queryIds': _activeQueries.keys.toList(),
      'totalItemsLoaded': _activeQueries.values
          .fold(0, (sum, state) => sum + state.totalLoaded),
      'averagePageSize': _activeQueries.values.isNotEmpty
          ? _activeQueries.values
                  .fold(0, (sum, state) => sum + state.totalLoaded) /
              _activeQueries.values.length
          : 0,
    };
  }
}

/// Paginated query result
class PaginatedQueryResult<T> {
  final List<T> items;
  final bool hasMore;
  final DocumentSnapshot? lastDocument;
  final int totalLoaded;
  final int pageSize;
  final String queryId;

  PaginatedQueryResult({
    required this.items,
    required this.hasMore,
    required this.lastDocument,
    required this.totalLoaded,
    required this.pageSize,
    required this.queryId,
  });

  @override
  String toString() {
    return 'PaginatedQueryResult(items: ${items.length}, hasMore: $hasMore, '
        'totalLoaded: $totalLoaded, pageSize: $pageSize, queryId: $queryId)';
  }
}

/// Pagination state tracking
class PaginatedQueryState {
  final String queryId;
  int totalLoaded = 0;
  DocumentSnapshot? lastDocument;
  bool hasMore = true;
  DateTime? lastLoadTime;

  PaginatedQueryState({
    required this.queryId,
  });

  @override
  String toString() {
    return 'PaginatedQueryState(queryId: $queryId, totalLoaded: $totalLoaded, '
        'hasMore: $hasMore, lastLoadTime: $lastLoadTime)';
  }
}
