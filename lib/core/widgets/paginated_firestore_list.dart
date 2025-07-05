import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Generic infinite-scroll list that paginates a Firestore [Query].
///
/// Usage:
/// ```dart
/// PaginatedFirestoreList<OrderModel>(
///   query: FirebaseFirestore.instance
///           .collection('users')
///           .doc(uid)
///           .collection('orders')
///           .orderBy('createdAt', descending: true),
///   pageSize: 20,
///   itemBuilder: (ctx, order) => OrderTile(order),
///   fromDoc: OrderModel.fromFirestore,
/// )
/// ```
class PaginatedFirestoreList<T> extends StatefulWidget {
  const PaginatedFirestoreList({
    super.key,
    required this.query,
    required this.fromDoc,
    required this.itemBuilder,
    this.pageSize = 20,
    this.emptyBuilder,
  });

  final Query query;
  final T Function(DocumentSnapshot doc) fromDoc;
  final Widget Function(BuildContext, T) itemBuilder;
  final int pageSize;
  final WidgetBuilder? emptyBuilder;

  @override
  State<PaginatedFirestoreList<T>> createState() =>
      _PaginatedFirestoreListState<T>();
}

class _PaginatedFirestoreListState<T> extends State<PaginatedFirestoreList<T>> {
  final List<T> _items = [];
  DocumentSnapshot? _lastDoc;
  bool _isLoading = false;
  bool _hasMore = true;
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchNextPage();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients || _isLoading || !_hasMore) return;

    if (_controller.position.pixels >=
        _controller.position.maxScrollExtent - 200) {
      _fetchNextPage();
    }
  }

  Future<void> _fetchNextPage() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    try {
      Query cur = widget.query.limit(widget.pageSize);
      if (_lastDoc != null) cur = cur.startAfterDocument(_lastDoc!);

      final snapshot = await cur.get();
      if (snapshot.docs.isNotEmpty) {
        _lastDoc = snapshot.docs.last;
        final mapped = snapshot.docs.map(widget.fromDoc).toList();
        setState(() => _items.addAll(mapped));
        if (snapshot.docs.length < widget.pageSize) _hasMore = false;
      } else {
        setState(() => _hasMore = false);
      }
    } catch (e) {
      debugPrint('Pagination fetch error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && !_isLoading) {
      return widget.emptyBuilder?.call(context) ?? const SizedBox.shrink();
    }

    return ListView.builder(
      controller: _controller,
      itemCount: _items.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return widget.itemBuilder(context, _items[index]);
      },
    );
  }
}
