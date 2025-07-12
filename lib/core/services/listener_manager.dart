import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Comprehensive listener management system to prevent memory leaks
class ListenerManager {
  static final ListenerManager _instance = ListenerManager._internal();
  factory ListenerManager() => _instance;
  ListenerManager._internal();

  // Track all active listeners
  final Map<String, StreamSubscription> _activeListeners = {};
  final Map<String, DateTime> _listenerCreationTimes = {};
  final Map<String, String> _listenerDescriptions = {};

  // Lifecycle tracking
  final Map<String, Set<String>> _widgetListeners = {};

  // Performance metrics
  int _totalListenersCreated = 0;
  int _totalListenersDisposed = 0;
  Duration _maxListenerDuration = Duration.zero;

  /// Create a managed stream subscription
  String addListener({
    required Stream stream,
    required Function(dynamic) onData,
    Function? onError,
    VoidCallback? onDone,
    bool? cancelOnError,
    String? description,
    String? widgetId,
    Duration? autoDisposeAfter,
  }) {
    final String listenerId = _generateListenerId();

    final subscription = stream.listen(
      onData,
      onError: onError,
      onDone: () {
        _removeListener(listenerId);
        onDone?.call();
      },
      cancelOnError: cancelOnError,
    );

    _activeListeners[listenerId] = subscription;
    _listenerCreationTimes[listenerId] = DateTime.now();
    _listenerDescriptions[listenerId] = description ?? 'Unknown listener';
    _totalListenersCreated++;

    // Associate with widget if provided
    if (widgetId != null) {
      _widgetListeners.putIfAbsent(widgetId, () => <String>{});
      _widgetListeners[widgetId]!.add(listenerId);
    }

    // Auto dispose after duration
    if (autoDisposeAfter != null) {
      Timer(autoDisposeAfter, () {
        disposeListener(listenerId);
      });
    }

    debugPrint(
        'Listener created: $listenerId (${_activeListeners.length} active)');
    return listenerId;
  }

  /// Create a managed Firestore document listener
  String addDocumentListener({
    required DocumentReference document,
    required Function(DocumentSnapshot) onData,
    Function? onError,
    VoidCallback? onDone,
    String? description,
    String? widgetId,
    bool includeMetadataChanges = false,
  }) {
    return addListener(
      stream:
          document.snapshots(includeMetadataChanges: includeMetadataChanges),
      onData: (dynamic data) => onData(data as DocumentSnapshot),
      onError: onError,
      onDone: onDone,
      description: description ?? 'Document: ${document.path}',
      widgetId: widgetId,
    );
  }

  /// Create a managed Firestore collection listener
  String addCollectionListener({
    required Query query,
    required Function(QuerySnapshot) onData,
    Function? onError,
    VoidCallback? onDone,
    String? description,
    String? widgetId,
    bool includeMetadataChanges = false,
  }) {
    return addListener(
      stream: query.snapshots(includeMetadataChanges: includeMetadataChanges),
      onData: (dynamic data) => onData(data as QuerySnapshot),
      onError: onError,
      onDone: onDone,
      description: description ?? 'Query: ${query.toString()}',
      widgetId: widgetId,
    );
  }

  /// Dispose a specific listener
  bool disposeListener(String listenerId) {
    final subscription = _activeListeners[listenerId];
    if (subscription != null) {
      subscription.cancel();
      _removeListener(listenerId);
      debugPrint('Listener disposed: $listenerId');
      return true;
    }
    return false;
  }

  /// Dispose all listeners associated with a widget
  int disposeWidgetListeners(String widgetId) {
    final listenerIds = _widgetListeners[widgetId];
    if (listenerIds == null) return 0;

    int disposed = 0;
    for (final listenerId in List.from(listenerIds)) {
      if (disposeListener(listenerId)) {
        disposed++;
      }
    }

    _widgetListeners.remove(widgetId);
    debugPrint('Disposed $disposed listeners for widget: $widgetId');
    return disposed;
  }

  /// Dispose all active listeners
  void disposeAllListeners() {
    final count = _activeListeners.length;
    for (final subscription in _activeListeners.values) {
      subscription.cancel();
    }

    _activeListeners.clear();
    _listenerCreationTimes.clear();
    _listenerDescriptions.clear();
    _widgetListeners.clear();
    _totalListenersDisposed += count;

    debugPrint('Disposed all $count listeners');
  }

  /// Get statistics about listeners
  ListenerStats getStats() {
    final now = DateTime.now();
    final List<Duration> durations = [];

    for (final creationTime in _listenerCreationTimes.values) {
      final duration = now.difference(creationTime);
      durations.add(duration);
      if (duration > _maxListenerDuration) {
        _maxListenerDuration = duration;
      }
    }

    return ListenerStats(
      activeListeners: _activeListeners.length,
      totalCreated: _totalListenersCreated,
      totalDisposed: _totalListenersDisposed,
      averageDuration: durations.isNotEmpty
          ? durations.reduce((a, b) => a + b) ~/ durations.length
          : Duration.zero,
      maxDuration: _maxListenerDuration,
      longestRunningListener: _getLongestRunningListener(),
      listenersByWidget: Map.from(_widgetListeners),
    );
  }

  /// Get detailed information about all active listeners
  List<ListenerInfo> getActiveListenersInfo() {
    final now = DateTime.now();
    final List<ListenerInfo> info = [];

    for (final entry in _activeListeners.entries) {
      final listenerId = entry.key;
      final creationTime = _listenerCreationTimes[listenerId]!;
      final description = _listenerDescriptions[listenerId]!;
      final duration = now.difference(creationTime);

      // Find associated widget
      String? widgetId;
      for (final entry in _widgetListeners.entries) {
        if (entry.value.contains(listenerId)) {
          widgetId = entry.key;
          break;
        }
      }

      info.add(ListenerInfo(
        id: listenerId,
        description: description,
        creationTime: creationTime,
        duration: duration,
        widgetId: widgetId,
      ));
    }

    return info;
  }

  /// Check for potential memory leaks
  List<ListenerInfo> checkForMemoryLeaks({
    Duration maxAge = const Duration(minutes: 30),
  }) {
    return getActiveListenersInfo()
        .where((info) => info.duration > maxAge)
        .toList();
  }

  /// Cleanup old listeners automatically
  int cleanupOldListeners({
    Duration maxAge = const Duration(hours: 1),
  }) {
    final leaks = checkForMemoryLeaks(maxAge: maxAge);
    int cleaned = 0;

    for (final leak in leaks) {
      if (disposeListener(leak.id)) {
        cleaned++;
        debugPrint('Auto-cleaned old listener: ${leak.description}');
      }
    }

    return cleaned;
  }

  /// Internal methods
  String _generateListenerId() {
    return 'listener_${DateTime.now().millisecondsSinceEpoch}_${_totalListenersCreated}';
  }

  void _removeListener(String listenerId) {
    _activeListeners.remove(listenerId);
    _listenerCreationTimes.remove(listenerId);
    _listenerDescriptions.remove(listenerId);
    _totalListenersDisposed++;

    // Remove from widget associations
    for (final entry in _widgetListeners.entries) {
      entry.value.remove(listenerId);
      if (entry.value.isEmpty) {
        _widgetListeners.remove(entry.key);
      }
    }
  }

  String? _getLongestRunningListener() {
    if (_listenerCreationTimes.isEmpty) return null;

    String? longestId;
    DateTime? earliestTime;

    for (final entry in _listenerCreationTimes.entries) {
      if (earliestTime == null || entry.value.isBefore(earliestTime)) {
        earliestTime = entry.value;
        longestId = entry.key;
      }
    }

    return longestId != null ? _listenerDescriptions[longestId] : null;
  }
}

/// Statistics about listeners
class ListenerStats {
  final int activeListeners;
  final int totalCreated;
  final int totalDisposed;
  final Duration averageDuration;
  final Duration maxDuration;
  final String? longestRunningListener;
  final Map<String, Set<String>> listenersByWidget;

  ListenerStats({
    required this.activeListeners,
    required this.totalCreated,
    required this.totalDisposed,
    required this.averageDuration,
    required this.maxDuration,
    required this.longestRunningListener,
    required this.listenersByWidget,
  });

  @override
  String toString() {
    return 'ListenerStats(active: $activeListeners, created: $totalCreated, '
        'disposed: $totalDisposed, avgDuration: $averageDuration)';
  }
}

/// Information about a specific listener
class ListenerInfo {
  final String id;
  final String description;
  final DateTime creationTime;
  final Duration duration;
  final String? widgetId;

  ListenerInfo({
    required this.id,
    required this.description,
    required this.creationTime,
    required this.duration,
    this.widgetId,
  });

  @override
  String toString() {
    return 'ListenerInfo(id: $id, description: $description, '
        'duration: $duration, widget: $widgetId)';
  }
}

/// Mixin for automatic listener management in StatefulWidgets
mixin ListenerManagerMixin<T extends StatefulWidget> on State<T> {
  late final String _widgetId;
  final ListenerManager _listenerManager = ListenerManager();

  @override
  void initState() {
    super.initState();
    _widgetId =
        '${T.toString()}_${hashCode}_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  void dispose() {
    _listenerManager.disposeWidgetListeners(_widgetId);
    super.dispose();
  }

  /// Add a managed listener that will be automatically disposed
  String addManagedListener({
    required Stream stream,
    required Function(dynamic) onData,
    Function? onError,
    VoidCallback? onDone,
    String? description,
  }) {
    return _listenerManager.addListener(
      stream: stream,
      onData: onData,
      onError: onError,
      onDone: onDone,
      description: description,
      widgetId: _widgetId,
    );
  }

  /// Add a managed document listener
  String addManagedDocumentListener({
    required DocumentReference document,
    required Function(DocumentSnapshot) onData,
    Function? onError,
    String? description,
  }) {
    return _listenerManager.addDocumentListener(
      document: document,
      onData: onData,
      onError: onError,
      description: description,
      widgetId: _widgetId,
    );
  }

  /// Add a managed collection listener
  String addManagedCollectionListener({
    required Query query,
    required Function(QuerySnapshot) onData,
    Function? onError,
    String? description,
  }) {
    return _listenerManager.addCollectionListener(
      query: query,
      onData: onData,
      onError: onError,
      description: description,
      widgetId: _widgetId,
    );
  }
}

/// Widget that automatically manages listener lifecycle
class ManagedStreamBuilder<T> extends StatefulWidget {
  final Stream<T> stream;
  final T? initialData;
  final Widget Function(BuildContext, AsyncSnapshot<T>) builder;
  final String? description;

  const ManagedStreamBuilder({
    super.key,
    required this.stream,
    required this.builder,
    this.initialData,
    this.description,
  });

  @override
  State<ManagedStreamBuilder<T>> createState() =>
      _ManagedStreamBuilderState<T>();
}

class _ManagedStreamBuilderState<T> extends State<ManagedStreamBuilder<T>>
    with ListenerManagerMixin {
  late AsyncSnapshot<T> _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.initialData != null
        ? AsyncSnapshot<T>.withData(ConnectionState.none, widget.initialData!)
        : AsyncSnapshot<T>.nothing();
    _subscribe();
  }

  void _subscribe() {
    addManagedListener(
      stream: widget.stream,
      onData: (dynamic data) {
        setState(() {
          _snapshot =
              AsyncSnapshot<T>.withData(ConnectionState.active, data as T);
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        setState(() {
          _snapshot = AsyncSnapshot<T>.withError(
              ConnectionState.active, error, stackTrace);
        });
      },
      description: widget.description ?? 'ManagedStreamBuilder<$T>',
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _snapshot);
  }
}
