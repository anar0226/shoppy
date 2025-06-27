import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// QPay Environment Configuration
enum QPayEnvironment {
  sandbox,
  production,
}

/// QPay Invoice Status
enum QPayInvoiceStatus {
  pending,
  paid,
  cancelled,
  expired,
}

/// QPay Invoice Model
class QPayInvoice {
  final String invoiceId;
  final String merchantId;
  final double amount;
  final String currency;
  final String customerName;
  final String description;
  final String? qrText;
  final String? qrImage;
  final QPayInvoiceStatus status;
  final DateTime createdAt;
  final DateTime? paidAt;
  final DateTime expiresAt;

  const QPayInvoice({
    required this.invoiceId,
    required this.merchantId,
    required this.amount,
    required this.currency,
    required this.customerName,
    required this.description,
    this.qrText,
    this.qrImage,
    required this.status,
    required this.createdAt,
    this.paidAt,
    required this.expiresAt,
  });

  factory QPayInvoice.fromJson(Map<String, dynamic> json) {
    return QPayInvoice(
      invoiceId: json['invoice_id']?.toString() ?? '',
      merchantId: json['merchant_id']?.toString() ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      currency: json['currency']?.toString() ?? 'MNT',
      customerName: json['customer_name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      qrText: json['qr_text']?.toString(),
      qrImage: json['qr_image']?.toString(),
      status: _parseStatus(json['invoice_status']?.toString()),
      createdAt: DateTime.tryParse(json['created_time']?.toString() ?? '') ??
          DateTime.now(),
      paidAt: json['paid_time'] != null
          ? DateTime.tryParse(json['paid_time'].toString())
          : null,
      expiresAt: DateTime.tryParse(json['expire_time']?.toString() ?? '') ??
          DateTime.now().add(const Duration(hours: 1)),
    );
  }

  static QPayInvoiceStatus _parseStatus(String? status) {
    switch (status?.toUpperCase()) {
      case 'PAID':
        return QPayInvoiceStatus.paid;
      case 'CANCELLED':
        return QPayInvoiceStatus.cancelled;
      case 'EXPIRED':
        return QPayInvoiceStatus.expired;
      default:
        return QPayInvoiceStatus.pending;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'invoice_id': invoiceId,
      'merchant_id': merchantId,
      'amount': amount,
      'currency': currency,
      'customer_name': customerName,
      'description': description,
      'qr_text': qrText,
      'qr_image': qrImage,
      'invoice_status': status.name.toUpperCase(),
      'created_time': createdAt.toIso8601String(),
      'paid_time': paidAt?.toIso8601String(),
      'expire_time': expiresAt.toIso8601String(),
    };
  }
}

/// QPay Payment Result
class QPayPaymentResult {
  final bool success;
  final String message;
  final QPayInvoice? invoice;
  final String? error;

  const QPayPaymentResult({
    required this.success,
    required this.message,
    this.invoice,
    this.error,
  });

  factory QPayPaymentResult.success(QPayInvoice invoice) {
    return QPayPaymentResult(
      success: true,
      message: 'Payment processed successfully',
      invoice: invoice,
    );
  }

  factory QPayPaymentResult.error(String error) {
    return QPayPaymentResult(
      success: false,
      message: 'Payment failed',
      error: error,
    );
  }
}

/// QPay Service for Payment Processing
class QPayService {
  static final QPayService _instance = QPayService._internal();
  factory QPayService() => _instance;
  QPayService._internal();

  late Dio _dio;
  late QPayEnvironment _environment;
  late String _username;
  late String _password;
  String? _accessToken;
  DateTime? _tokenExpiry;

  /// Initialize QPay service
  Future<void> initialize({
    required String username,
    required String password,
    QPayEnvironment environment = QPayEnvironment.sandbox,
  }) async {
    _username = username;
    _password = password;
    _environment = environment;

    _dio = Dio(BaseOptions(
      baseUrl: _getBaseUrl(),
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add request/response interceptors for debugging
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint(obj.toString()),
      ));
    }

    await _authenticate();
  }

  /// Get base URL based on environment
  String _getBaseUrl() {
    switch (_environment) {
      case QPayEnvironment.production:
        return 'https://merchant.qpay.mn/v2';
      case QPayEnvironment.sandbox:
        return 'https://merchant.qpay.mn/v2'; // Update when sandbox URL is available
    }
  }

  /// Authenticate with QPay
  Future<void> _authenticate() async {
    try {
      final response = await _dio.post(
        '/auth/token',
        data: {
          'username': _username,
          'password': _password,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        _accessToken = data['access_token'];
        final expiresIn = data['expires_in'] ?? 3600;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

        // Update authorization header
        _dio.options.headers['Authorization'] = 'Bearer $_accessToken';

        debugPrint('QPay authentication successful');
      } else {
        throw Exception('Authentication failed: ${response.statusMessage}');
      }
    } catch (e) {
      debugPrint('QPay authentication error: $e');
      throw Exception('Failed to authenticate with QPay: $e');
    }
  }

  /// Check if token needs refresh
  Future<void> _ensureAuthenticated() async {
    if (_accessToken == null ||
        _tokenExpiry == null ||
        DateTime.now()
            .isAfter(_tokenExpiry!.subtract(const Duration(minutes: 5)))) {
      await _authenticate();
    }
  }

  /// Create payment invoice
  Future<QPayPaymentResult> createInvoice({
    required String orderId,
    required double amount,
    required String customerName,
    required String customerEmail,
    required String description,
    String currency = 'MNT',
    Duration? expiry,
  }) async {
    try {
      await _ensureAuthenticated();

      final invoiceId = const Uuid().v4();
      final expiryDate = DateTime.now().add(expiry ?? const Duration(hours: 1));

      final payload = {
        'invoice_code': invoiceId,
        'sender_invoice_no': orderId,
        'invoice_receiver_code': customerName,
        'invoice_description': description,
        'amount': amount,
        'callback_url': '${_getCallbackUrl()}/qpay/callback',
      };

      final response = await _dio.post('/invoice', data: payload);

      if (response.statusCode == 200) {
        final data = response.data;

        final invoice = QPayInvoice(
          invoiceId: data['invoice_id']?.toString() ?? invoiceId,
          merchantId: _username,
          amount: amount,
          currency: currency,
          customerName: customerName,
          description: description,
          qrText: data['qr_text']?.toString(),
          qrImage: data['qr_image']?.toString(),
          status: QPayInvoiceStatus.pending,
          createdAt: DateTime.now(),
          expiresAt: expiryDate,
        );

        return QPayPaymentResult.success(invoice);
      } else {
        return QPayPaymentResult.error(
            'Failed to create invoice: ${response.statusMessage}');
      }
    } catch (e) {
      debugPrint('Create invoice error: $e');
      return QPayPaymentResult.error('Failed to create invoice: $e');
    }
  }

  /// Check payment status
  Future<QPayInvoice?> checkPayment(String invoiceId) async {
    try {
      await _ensureAuthenticated();

      final response = await _dio.post('/payment/check', data: {
        'object_type': 'INVOICE',
        'object_id': invoiceId,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        return QPayInvoice.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('Check payment error: $e');
      return null;
    }
  }

  /// Get payment details
  Future<QPayInvoice?> getPayment(String paymentId) async {
    try {
      await _ensureAuthenticated();

      final response = await _dio.get('/payment/$paymentId');

      if (response.statusCode == 200) {
        return QPayInvoice.fromJson(response.data);
      }
      return null;
    } catch (e) {
      debugPrint('Get payment error: $e');
      return null;
    }
  }

  /// Cancel payment
  Future<bool> cancelPayment(String paymentId) async {
    try {
      await _ensureAuthenticated();

      final response = await _dio.delete('/payment/$paymentId');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Cancel payment error: $e');
      return false;
    }
  }

  /// Handle payment callback/webhook
  Future<bool> processCallback(Map<String, dynamic> callbackData) async {
    try {
      // Verify callback signature for security
      if (!_verifyCallback(callbackData)) {
        debugPrint('Invalid callback signature');
        return false;
      }

      final invoiceId = callbackData['invoice_id']?.toString();
      final status = callbackData['payment_status']?.toString();

      if (invoiceId != null && status == 'PAID') {
        // Update payment status in your database
        await _updatePaymentStatus(invoiceId, QPayInvoiceStatus.paid);

        // Trigger order fulfillment (UBCab delivery)
        await _triggerOrderFulfillment(invoiceId);

        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Process callback error: $e');
      return false;
    }
  }

  /// Verify callback signature
  bool _verifyCallback(Map<String, dynamic> data) {
    // Implement signature verification based on QPay documentation
    // This would use HMAC-SHA256 with your secret key
    return true; // Simplified for example
  }

  /// Update payment status in Firestore
  Future<void> _updatePaymentStatus(
      String invoiceId, QPayInvoiceStatus status) async {
    // Implementation would update Firestore with payment status
    debugPrint('Updating payment status for $invoiceId to ${status.name}');
  }

  /// Trigger order fulfillment process
  Future<void> _triggerOrderFulfillment(String invoiceId) async {
    // Implementation would start the UBCab delivery process
    debugPrint('Triggering order fulfillment for $invoiceId');
  }

  /// Get callback URL for webhooks
  String _getCallbackUrl() {
    // Return your app's webhook endpoint
    return 'https://your-app-domain.com'; // Replace with actual domain
  }

  /// Generate payment URL for web checkout
  String generatePaymentUrl(QPayInvoice invoice) {
    final baseUrl = _environment == QPayEnvironment.production
        ? 'https://payment.qpay.mn'
        : 'https://payment.qpay.mn'; // Update sandbox URL when available

    return '$baseUrl/invoice/${invoice.invoiceId}';
  }
}

// **DATA MODELS**

class QPayInvoiceResult {
  final String invoiceId;
  final String qrText;
  final String qrImage;
  final Map<String, dynamic> urls;

  QPayInvoiceResult({
    required this.invoiceId,
    required this.qrText,
    required this.qrImage,
    required this.urls,
  });

  factory QPayInvoiceResult.fromJson(Map<String, dynamic> json) {
    return QPayInvoiceResult(
      invoiceId: json['invoice_id'] ?? '',
      qrText: json['qr_text'] ?? '',
      qrImage: json['qr_image'] ?? '',
      urls: Map<String, dynamic>.from(json['urls'] ?? {}),
    );
  }
}

class QPayRefundResult {
  final bool success;
  final String? error;
  final String? message;

  QPayRefundResult({
    required this.success,
    this.error,
    this.message,
  });

  factory QPayRefundResult.fromJson(Map<String, dynamic> json) {
    return QPayRefundResult(
      success: json['error'] == null,
      error: json['error'],
      message: json['message'],
    );
  }
}

class PaymentResult {
  final bool success;
  final String? orderId;
  final String? paymentIntentId;
  final String? error;
  final String? qrText;
  final String? qrImage;
  final Map<String, dynamic>? urls;

  PaymentResult({
    required this.success,
    this.orderId,
    this.paymentIntentId,
    this.error,
    this.qrText,
    this.qrImage,
    this.urls,
  });
}
