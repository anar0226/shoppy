import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class DeepLinkService {
  static const MethodChannel _channel = MethodChannel('deep_links');
  static DeepLinkService? _instance;

  factory DeepLinkService() {
    _instance ??= DeepLinkService._internal();
    return _instance!;
  }

  DeepLinkService._internal();

  StreamController<String>? _linkStreamController;
  Stream<String>? _linkStream;

  /// Initialize deep link handling
  void initialize() {
    _linkStreamController = StreamController<String>.broadcast();
    _linkStream = _linkStreamController!.stream;

    // Listen for incoming links when app is already running
    _channel.setMethodCallHandler(_handleIncomingLink);

    // Check for initial link when app starts
    _getInitialLink();
  }

  /// Get the stream of incoming deep links
  Stream<String>? get linkStream => _linkStream;

  /// Handle incoming deep links while app is running
  Future<dynamic> _handleIncomingLink(MethodCall call) async {
    if (call.method == 'onLink') {
      final String link = call.arguments;
      _linkStreamController?.add(link);
      _processDeepLink(link);
    }
  }

  /// Get initial link when app starts from a deep link
  Future<void> _getInitialLink() async {
    try {
      final String? initialLink = await _channel.invokeMethod('getInitialLink');
      if (initialLink != null) {
        _linkStreamController?.add(initialLink);
        _processDeepLink(initialLink);
      }
    } on PlatformException catch (e) {
      debugPrint('Failed to get initial link: ${e.message}');
    }
  }

  /// Process incoming deep links
  void _processDeepLink(String link) {
    debugPrint('DeepLinkService: Processing link: $link');

    final uri = Uri.tryParse(link);
    if (uri == null) return;

    switch (uri.scheme) {
      case 'qpay':
        _handleQPayLink(uri);
        break;
      case 'avii':
        _handleAviiLink(uri);
        break;
      default:
        debugPrint('DeepLinkService: Unknown scheme: ${uri.scheme}');
    }
  }

  /// Handle QPay deep links
  void _handleQPayLink(Uri uri) {
    debugPrint('DeepLinkService: QPay link received: $uri');

    // Extract payment information from QPay callback
    final paymentId = uri.queryParameters['payment_id'];
    final status = uri.queryParameters['status'];
    final invoiceId = uri.queryParameters['invoice_id'];

    if (paymentId != null && status != null) {
      _notifyPaymentResult(paymentId, status, invoiceId);
    }
  }

  /// Handle Avii app deep links
  void _handleAviiLink(Uri uri) {
    debugPrint('DeepLinkService: Avii link received: $uri');

    switch (uri.host) {
      case 'payment':
        _handlePaymentLink(uri);
        break;
      case 'product':
        _handleProductLink(uri);
        break;
      case 'store':
        _handleStoreLink(uri);
        break;
      default:
        debugPrint('DeepLinkService: Unknown Avii host: ${uri.host}');
    }
  }

  /// Handle payment-related deep links
  void _handlePaymentLink(Uri uri) {
    final action = uri.queryParameters['action'];
    final orderId = uri.queryParameters['order_id'];

    switch (action) {
      case 'success':
        _notifyPaymentResult(orderId ?? '', 'PAID', null);
        break;
      case 'failed':
        _notifyPaymentResult(orderId ?? '', 'FAILED', null);
        break;
      case 'cancelled':
        _notifyPaymentResult(orderId ?? '', 'CANCELLED', null);
        break;
    }
  }

  /// Handle product deep links
  void _handleProductLink(Uri uri) {
    final productId = uri.queryParameters['id'];
    if (productId != null) {
      // Navigate to product page
      debugPrint('DeepLinkService: Navigate to product: $productId');
    }
  }

  /// Handle store deep links
  void _handleStoreLink(Uri uri) {
    final storeId = uri.queryParameters['id'];
    if (storeId != null) {
      // Navigate to store page
      debugPrint('DeepLinkService: Navigate to store: $storeId');
    }
  }

  /// Notify payment result to listeners
  void _notifyPaymentResult(
      String paymentId, String status, String? invoiceId) {
    debugPrint(
        'DeepLinkService: Payment result - ID: $paymentId, Status: $status');

    // You can implement a callback system here to notify the payment page
    // For now, we'll use a simple event system
    _linkStreamController?.add('payment:$status:$paymentId:${invoiceId ?? ''}');
  }

  /// Dispose resources
  void dispose() {
    _linkStreamController?.close();
    _linkStreamController = null;
    _linkStream = null;
  }
}
