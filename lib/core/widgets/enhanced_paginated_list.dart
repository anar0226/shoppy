import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/listener_manager.dart';

/// Enhanced paginated list widget with real-time updates and memory optimization
class EnhancedPaginatedList<T> extends StatefulWidget {
  final Query baseQuery;
  final T Function(DocumentSnapshot) fromDoc;
  final Widget Function(BuildContext, T) itemBuilder;
  final bool Function(T)? filter;
  final int Function(T, T)? comparator;
  final int pageSize;
  final bool enableRealTimeUpdates;
  final bool enableSearch;
  final String? Function(T)? searchExtractor;
  final WidgetBuilder? emptyBuilder;
  final WidgetBuilder? errorBuilder;
  final WidgetBuilder? loadingBuilder;
  final EdgeInsets? padding;
  final String? listId;
  final bool enablePullToRefresh;
  final ScrollController? scrollController;
  final Function(List<T>)? onDataChanged;
  final Duration? cacheTimeout;

  const EnhancedPaginatedList({
    super.key,
    required this.baseQuery,
    required this.fromDoc,
    required this.itemBuilder,
    this.filter,
    this.comparator,
    this.pageSize = 20,
    this.enableRealTimeUpdates = false,
    this.enableSearch = false,
    this.searchExtractor,
    this.emptyBuilder,
    this.errorBuilder,
    this.loadingBuilder,
    this.padding,
    this.listId,
    this.enablePullToRefresh = true,
    this.scrollController,
    this.onDataChanged,
    this.cacheTimeout,
  });

  @override
  State<EnhancedPaginatedList<T>> createState() =>
      _EnhancedPaginatedListState<T>();
}

class _EnhancedPaginatedListState<T> extends State<EnhancedPaginatedList<T>>
    with ListenerManagerMixin {
  final DatabaseService _db = DatabaseService();
  final ScrollController _scrollController = ScrollController();
  final List<T> _items = [];
  final Set<String> _loadedDocIds = {};

  DocumentSnapshot? _lastDoc;
  bool _isLoading = false;
  bool _hasMore = true;
  bool _hasError = false;
  String? _errorMessage;
  String _searchQuery = '';

  // Real-time listener management
  Timer? _debounceTimer;

  // Performance tracking
  int _totalItemsLoaded = 0;
  DateTime? _lastRefresh;

  @override
  void initState() {
    super.initState();

    // Use provided scroll controller or create one
    if (widget.scrollController != null) {
      widget.scrollController!.addListener(_onScroll);
    } else {
      _scrollController.addListener(_onScroll);
    }

    // Initial load
    _loadInitialData();

    // Setup real-time updates if enabled
    if (widget.enableRealTimeUpdates) {
      _setupRealTimeUpdates();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  ScrollController get _effectiveScrollController =>
      widget.scrollController ?? _scrollController;

  void _onScroll() {
    if (!_effectiveScrollController.hasClients || _isLoading || !_hasMore) {
      return;
    }

    final position = _effectiveScrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _loadNextPage();
    }
  }

  Future<void> _loadInitialData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final query = _buildQuery();
      final snapshot = await _db.executeQuery(
        query: query,
        useCache: widget.cacheTimeout != null,
      );

      _processSnapshot(snapshot, isInitial: true);
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      Query query = _buildQuery();

      if (_lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      final snapshot = await _db.executeQuery(
        query: query,
        useCache: widget.cacheTimeout != null,
      );

      _processSnapshot(snapshot, isInitial: false);
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Query _buildQuery() {
    return widget.baseQuery.limit(widget.pageSize);
  }

  void _processSnapshot(QuerySnapshot snapshot, {required bool isInitial}) {
    if (snapshot.docs.isEmpty) {
      setState(() {
        _hasMore = false;
      });
      return;
    }

    final newItems = <T>[];
    final newDocIds = <String>{};

    for (final doc in snapshot.docs) {
      // Avoid duplicates
      if (!_loadedDocIds.contains(doc.id)) {
        try {
          final item = widget.fromDoc(doc);

          // Apply filter if provided
          if (widget.filter == null || widget.filter!(item)) {
            newItems.add(item);
            newDocIds.add(doc.id);
          }
        } catch (e) {
          debugPrint('Error processing document ${doc.id}: $e');
        }
      }
    }

    setState(() {
      if (isInitial) {
        _items.clear();
        _loadedDocIds.clear();
      }

      _items.addAll(newItems);
      _loadedDocIds.addAll(newDocIds);
      _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      _hasMore = snapshot.docs.length >= widget.pageSize;
      _totalItemsLoaded += newItems.length;
    });

    // Sort if comparator provided
    if (widget.comparator != null) {
      _items.sort(widget.comparator!);
    }

    // Notify data changed
    widget.onDataChanged?.call(_items);
  }

  void _setupRealTimeUpdates() {
    addManagedCollectionListener(
      query: widget.baseQuery,
      onData: (QuerySnapshot snapshot) {
        _handleRealTimeUpdate(snapshot);
      },
      onError: (error) {
        debugPrint('Real-time update error: $error');
      },
      description: 'Real-time updates for ${widget.listId ?? 'list'}',
    );
  }

  void _handleRealTimeUpdate(QuerySnapshot snapshot) {
    // Debounce rapid updates
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _processRealTimeChanges(snapshot);
      }
    });
  }

  void _processRealTimeChanges(QuerySnapshot snapshot) {
    bool hasChanges = false;

    for (final change in snapshot.docChanges) {
      switch (change.type) {
        case DocumentChangeType.added:
          _handleDocumentAdded(change.doc);
          hasChanges = true;
          break;
        case DocumentChangeType.modified:
          _handleDocumentModified(change.doc);
          hasChanges = true;
          break;
        case DocumentChangeType.removed:
          _handleDocumentRemoved(change.doc);
          hasChanges = true;
          break;
      }
    }

    if (hasChanges) {
      setState(() {
        // Sort if comparator provided
        if (widget.comparator != null) {
          _items.sort(widget.comparator!);
        }
      });

      widget.onDataChanged?.call(_items);
    }
  }

  void _handleDocumentAdded(DocumentSnapshot doc) {
    if (_loadedDocIds.contains(doc.id)) return;

    try {
      final item = widget.fromDoc(doc);

      // Apply filter if provided
      if (widget.filter == null || widget.filter!(item)) {
        _items.add(item);
        _loadedDocIds.add(doc.id);
      }
    } catch (e) {
      debugPrint('Error processing added document ${doc.id}: $e');
    }
  }

  void _handleDocumentModified(DocumentSnapshot doc) {
    try {
      final item = widget.fromDoc(doc);
      final index =
          _items.indexWhere((existing) => _getDocId(existing) == doc.id);

      if (index != -1) {
        // Apply filter if provided
        if (widget.filter == null || widget.filter!(item)) {
          _items[index] = item;
        } else {
          // Item no longer matches filter, remove it
          _items.removeAt(index);
          _loadedDocIds.remove(doc.id);
        }
      } else if (widget.filter == null || widget.filter!(item)) {
        // Item now matches filter, add it
        _items.add(item);
        _loadedDocIds.add(doc.id);
      }
    } catch (e) {
      debugPrint('Error processing modified document ${doc.id}: $e');
    }
  }

  void _handleDocumentRemoved(DocumentSnapshot doc) {
    final index =
        _items.indexWhere((existing) => _getDocId(existing) == doc.id);

    if (index != -1) {
      _items.removeAt(index);
      _loadedDocIds.remove(doc.id);
    }
  }

  String _getDocId(T item) {
    // Try to extract document ID from item
    // This is a simplified implementation - in practice, you might want to
    // store the doc ID in your model or use a different approach
    return item.hashCode.toString();
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _items.clear();
      _loadedDocIds.clear();
      _lastDoc = null;
      _hasMore = true;
      _hasError = false;
      _errorMessage = null;
    });

    _lastRefresh = DateTime.now();
    await _loadInitialData();
  }

  void updateSearchQuery(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  List<T> get _filteredItems {
    if (!widget.enableSearch || _searchQuery.isEmpty) {
      return _items;
    }

    if (widget.searchExtractor == null) {
      return _items;
    }

    final lowercaseQuery = _searchQuery.toLowerCase();
    return _items.where((item) {
      final searchText = widget.searchExtractor!(item);
      return searchText != null &&
          searchText.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError && _items.isEmpty) {
      return widget.errorBuilder?.call(context) ?? _buildDefaultError();
    }

    if (_isLoading && _items.isEmpty) {
      return widget.loadingBuilder?.call(context) ?? _buildDefaultLoading();
    }

    final filteredItems = _filteredItems;

    if (filteredItems.isEmpty) {
      return widget.emptyBuilder?.call(context) ?? _buildDefaultEmpty();
    }

    Widget listView = ListView.builder(
      controller: _effectiveScrollController,
      padding: widget.padding,
      itemCount: filteredItems.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == filteredItems.length) {
          return _buildLoadingIndicator();
        }

        return widget.itemBuilder(context, filteredItems[index]);
      },
    );

    if (widget.enablePullToRefresh) {
      listView = RefreshIndicator(
        onRefresh: _handleRefresh,
        child: listView,
      );
    }

    return listView;
  }

  Widget _buildDefaultLoading() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildDefaultEmpty() {
    return const Center(
      child: Text('No items found'),
    );
  }

  Widget _buildDefaultError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error loading data',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Unknown error',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadInitialData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(),
    );
  }

  /// Get performance statistics
  PaginationStats getStats() {
    return PaginationStats(
      totalItems: _items.length,
      totalLoaded: _totalItemsLoaded,
      hasMore: _hasMore,
      isLoading: _isLoading,
      lastRefresh: _lastRefresh,
      realtimeEnabled: widget.enableRealTimeUpdates,
    );
  }
}

/// Performance statistics for pagination
class PaginationStats {
  final int totalItems;
  final int totalLoaded;
  final bool hasMore;
  final bool isLoading;
  final DateTime? lastRefresh;
  final bool realtimeEnabled;

  PaginationStats({
    required this.totalItems,
    required this.totalLoaded,
    required this.hasMore,
    required this.isLoading,
    required this.lastRefresh,
    required this.realtimeEnabled,
  });

  @override
  String toString() {
    return 'PaginationStats(items: $totalItems, loaded: $totalLoaded, '
        'hasMore: $hasMore, loading: $isLoading, realtime: $realtimeEnabled)';
  }
}

/// Builder for search-enabled paginated lists
class SearchablePaginatedList<T> extends StatefulWidget {
  final Query baseQuery;
  final T Function(DocumentSnapshot) fromDoc;
  final Widget Function(BuildContext, T) itemBuilder;
  final String? Function(T) searchExtractor;
  final bool Function(T)? filter;
  final int pageSize;
  final String searchHint;
  final WidgetBuilder? emptyBuilder;
  final EdgeInsets? padding;

  const SearchablePaginatedList({
    super.key,
    required this.baseQuery,
    required this.fromDoc,
    required this.itemBuilder,
    required this.searchExtractor,
    this.filter,
    this.pageSize = 20,
    this.searchHint = 'Search...',
    this.emptyBuilder,
    this.padding,
  });

  @override
  State<SearchablePaginatedList<T>> createState() =>
      _SearchablePaginatedListState<T>();
}

class _SearchablePaginatedListState<T>
    extends State<SearchablePaginatedList<T>> {
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<_EnhancedPaginatedListState> _listKey = GlobalKey();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: widget.searchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _updateSearch('');
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
            onChanged: _updateSearch,
          ),
        ),

        // List
        Expanded(
          child: EnhancedPaginatedList<T>(
            key: _listKey,
            baseQuery: widget.baseQuery,
            fromDoc: widget.fromDoc,
            itemBuilder: widget.itemBuilder,
            filter: widget.filter,
            pageSize: widget.pageSize,
            enableSearch: true,
            searchExtractor: widget.searchExtractor,
            emptyBuilder: widget.emptyBuilder,
            padding: widget.padding,
          ),
        ),
      ],
    );
  }

  void _updateSearch(String query) {
    _listKey.currentState?.updateSearchQuery(query);
  }
}
