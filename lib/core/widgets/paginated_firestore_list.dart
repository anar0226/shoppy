import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/listener_manager.dart';
import 'enhanced_paginated_list.dart';

/// Generic infinite-scroll list that paginates a Firestore [Query].
/// This is a wrapper around EnhancedPaginatedList for backward compatibility.
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
  @override
  Widget build(BuildContext context) {
    // Use the new EnhancedPaginatedList for better performance and memory management
    return EnhancedPaginatedList<T>(
      baseQuery: widget.query,
      fromDoc: widget.fromDoc,
      itemBuilder: widget.itemBuilder,
      pageSize: widget.pageSize,
      emptyBuilder: widget.emptyBuilder,
      enableRealTimeUpdates: false, // Maintain backward compatibility
      enablePullToRefresh: true,
      listId: 'paginated_firestore_list',
    );
  }
}
