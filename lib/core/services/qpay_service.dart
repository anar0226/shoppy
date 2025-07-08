import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/environment_config.dart';

/// QPay API Integration Service
class QPayService {
  static final QPayService _instance = QPayService._internal();
  factory QPayService() => _instance;
  QPayService._internal();

  String? _accessToken;
  DateTime? _tokenExpiry;

  static String get _baseUrl => EnvironmentConfig.qpayBaseUrl;
  static const String _authEndpoint = '/auth/token';
  static const String _invoiceEndpoint = '/invoice';
  static const String _paymentEndpoint = '/payment/check';

  /// Get access token (authenticate with QPay)
  Future<String?> _getAccessToken() async {
    try {
      // Check if we have a valid token
      if (_accessToken != null &&
          _tokenExpiry != null &&
          DateTime.now()
              .isBefore(_tokenExpiry!.subtract(const Duration(minutes: 5)))) {
        return _accessToken;
      }

      log('QPayService: Requesting new access token');
      log('QPayService: Using SANDBOX environment');
      log('QPayService: Username: ${EnvironmentConfig.qpayUsername}');
      log('QPayService: Password length: ${EnvironmentConfig.qpayPassword.length}');
      log('QPayService: Invoice Code: ${EnvironmentConfig.qpayInvoiceCode}');
      log('QPayService: Base URL: $_baseUrl');
      log('QPayService: Full auth URL: $_baseUrl$_authEndpoint');

      final response = await http.post(
        Uri.parse('$_baseUrl$_authEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          // Basic Auth header (username:password Base64)
          'Authorization':
              'Basic ${base64Encode(utf8.encode('${EnvironmentConfig.qpayUsername}:${EnvironmentConfig.qpayPassword}'))}',
        },
        // Empty body as per QPay documentation
        body: jsonEncode({}),
      );

      log('QPayService: Auth response status: ${response.statusCode}');
      log('QPayService: Auth response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        _accessToken = data['access_token'];

        // QPay tokens typically expire in 1 hour
        _tokenExpiry = DateTime.now().add(const Duration(hours: 1));

        log('QPayService: Successfully obtained access token');
        return _accessToken;
      } else {
        log('QPayService: Failed to get access token: ${response.statusCode} - ${response.body}');

        // If credentials are not approved, provide helpful error message
        if (response.statusCode == 401 &&
            response.body.contains('NO_CREDENTIALS')) {
          log('QPayService: CREDENTIALS NOT APPROVED - Please contact QPay support to activate your merchant account');
          log('QPayService: Note: Using SANDBOX environment - make sure credentials are for sandbox testing');
        }

        return null;
      }
    } catch (e) {
      log('QPayService: Error getting access token: $e');
      return null;
    }
  }

  /// Create QPay invoice
  Future<QPayInvoiceResult> createInvoice({
    required String orderId,
    required double amount,
    required String description,
    required String customerEmail,
    String? customerPhone,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      log('QPayService: Creating invoice for order $orderId, amount: $amount');

      final token = await _getAccessToken();
      if (token == null) {
        return QPayInvoiceResult.error('Failed to authenticate with QPay');
      }

      final invoiceData = {
        'invoice_code': EnvironmentConfig.qpayInvoiceCode,
        'sender_invoice_no': orderId,
        // QPay API expects a unique string for invoice_receiver_code, not email. Use orderId+userId or similar.
        'invoice_receiver_code':
            customerEmail.replaceAll('@', '_').replaceAll('.', '_'),
        'invoice_description': description,
        'amount': amount, // QPay API expects this as a number
        'callback_url': '${EnvironmentConfig.apiBaseUrl}/qpay-webhook',
        'sender_branch_code': 'MAIN',
        'sender_staff_code': 'SYSTEM',
      };

      // No metadata field per QPay API

      log('QPayService: Invoice data: ${jsonEncode(invoiceData)}');

      final response = await http.post(
        Uri.parse('$_baseUrl$_invoiceEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(invoiceData),
      );

      log('QPayService: Invoice response status: ${response.statusCode}');
      log('QPayService: Invoice response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Log the actual response structure for debugging
        log('QPayService: Parsed response data: $data');

        // Handle the actual QPay response structure
        // QPay returns invoice_id directly, not nested
        final invoiceId = data['invoice_id']?.toString() ?? '';

        // For now, use the same ID for both fields until we get the actual response structure
        final qpayInvoiceId = data['qpay_invoice_id']?.toString() ?? invoiceId;

        // QR code and other fields might be in a different structure
        final qrText =
            data['qr_text']?.toString() ?? data['qr_code']?.toString() ?? '';
        final qrImage = data['qr_image']?.toString() ?? '';
        final deepLink = data['qpay_deeplink']?.toString() ??
            data['deeplink']?.toString() ??
            '';

        // URLs might be nested or not present
        Map<String, dynamic> urlsData = {};
        if (data['urls'] is Map) {
          urlsData = Map<String, dynamic>.from(data['urls']);
        }

        return QPayInvoiceResult.success(
          QPayInvoice(
            id: invoiceId,
            qpayInvoiceId: qpayInvoiceId,
            amount: amount,
            description: description,
            status: 'PENDING',
            qrCode: qrText,
            qrImage: qrImage,
            deepLink: deepLink,
            urls: QPayUrls(
              app: urlsData['app']?.toString() ?? '',
              link: urlsData['link']?.toString() ?? '',
              logo: urlsData['logo']?.toString() ?? '',
            ),
            createdAt: DateTime.now(),
          ),
        );
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ?? 'Failed to create invoice';
        log('QPayService: Invoice creation failed: $errorMessage');
        return QPayInvoiceResult.error(errorMessage);
      }
    } catch (e) {
      log('QPayService: Error creating invoice: $e');
      return QPayInvoiceResult.error('Error creating invoice: $e');
    }
  }

  /// Check payment status
  Future<QPayPaymentStatus> checkPaymentStatus(String qpayInvoiceId) async {
    try {
      log('QPayService: Checking payment status for invoice: $qpayInvoiceId');

      final token = await _getAccessToken();
      if (token == null) {
        return QPayPaymentStatus.error('Failed to authenticate with QPay');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl$_paymentEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'invoice_id': qpayInvoiceId,
        }),
      );

      log('QPayService: Payment status response: ${response.statusCode}');
      log('QPayService: Payment status body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        return QPayPaymentStatus.success(
          status: data['payment_status'] ?? 'PENDING',
          paidAmount: (data['paid_amount'] ?? 0).toDouble(),
          paidDate: data['paid_date'] != null
              ? DateTime.tryParse(data['paid_date'])
              : null,
          paymentId: data['payment_id']?.toString(),
        );
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage =
            errorData['message'] ?? 'Failed to check payment status';
        return QPayPaymentStatus.error(errorMessage);
      }
    } catch (e) {
      log('QPayService: Error checking payment status: $e');
      return QPayPaymentStatus.error('Error checking payment status: $e');
    }
  }

  /// Cancel invoice
  Future<bool> cancelInvoice(String qpayInvoiceId) async {
    try {
      log('QPayService: Canceling invoice: $qpayInvoiceId');

      final token = await _getAccessToken();
      if (token == null) {
        return false;
      }

      final response = await http.delete(
        Uri.parse('$_baseUrl$_invoiceEndpoint/$qpayInvoiceId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      log('QPayService: Cancel response: ${response.statusCode}');

      return response.statusCode == 200;
    } catch (e) {
      log('QPayService: Error canceling invoice: $e');
      return false;
    }
  }

  /// Get invoice details
  Future<QPayInvoiceResult> getInvoiceDetails(String qpayInvoiceId) async {
    try {
      log('QPayService: Getting invoice details: $qpayInvoiceId');

      final token = await _getAccessToken();
      if (token == null) {
        return QPayInvoiceResult.error('Failed to authenticate with QPay');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl$_invoiceEndpoint/$qpayInvoiceId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      log('QPayService: Invoice details response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        return QPayInvoiceResult.success(
          QPayInvoice(
            id: data['invoice_id']?.toString() ?? '',
            qpayInvoiceId: data['qpay_invoice_id']?.toString() ?? '',
            amount: (data['amount'] ?? 0).toDouble(),
            description: data['invoice_description'] ?? '',
            status: data['invoice_status'] ?? 'UNKNOWN',
            qrCode: data['qr_text'] ?? '',
            qrImage: data['qr_image'] ?? '',
            deepLink: data['qpay_deeplink'] ?? '',
            urls: QPayUrls(
              app: data['urls']?['app'] ?? '',
              link: data['urls']?['link'] ?? '',
              logo: data['urls']?['logo'] ?? '',
            ),
            createdAt:
                DateTime.tryParse(data['created_time'] ?? '') ?? DateTime.now(),
          ),
        );
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage =
            errorData['message'] ?? 'Failed to get invoice details';
        return QPayInvoiceResult.error(errorMessage);
      }
    } catch (e) {
      log('QPayService: Error getting invoice details: $e');
      return QPayInvoiceResult.error('Error getting invoice details: $e');
    }
  }
}

/// QPay Invoice Model
class QPayInvoice {
  final String id;
  final String qpayInvoiceId;
  final double amount;
  final String description;
  final String status;
  final String qrCode;
  final String qrImage;
  final String deepLink;
  final QPayUrls urls;
  final DateTime createdAt;

  const QPayInvoice({
    required this.id,
    required this.qpayInvoiceId,
    required this.amount,
    required this.description,
    required this.status,
    required this.qrCode,
    required this.qrImage,
    required this.deepLink,
    required this.urls,
    required this.createdAt,
  });

  bool get isPaid => status == 'PAID';
  bool get isPending => status == 'PENDING';
  bool get isExpired => status == 'EXPIRED';
  bool get isCanceled => status == 'CANCELED';
}

/// QPay URLs
class QPayUrls {
  final String app;
  final String link;
  final String logo;

  const QPayUrls({
    required this.app,
    required this.link,
    required this.logo,
  });
}

/// QPay Invoice Result
class QPayInvoiceResult {
  final bool success;
  final QPayInvoice? invoice;
  final String? error;

  const QPayInvoiceResult({
    required this.success,
    this.invoice,
    this.error,
  });

  factory QPayInvoiceResult.success(QPayInvoice invoice) {
    return QPayInvoiceResult(success: true, invoice: invoice);
  }

  factory QPayInvoiceResult.error(String error) {
    return QPayInvoiceResult(success: false, error: error);
  }
}

/// QPay Payment Status
class QPayPaymentStatus {
  final bool success;
  final String? status;
  final double? paidAmount;
  final DateTime? paidDate;
  final String? paymentId;
  final String? error;

  const QPayPaymentStatus({
    required this.success,
    this.status,
    this.paidAmount,
    this.paidDate,
    this.paymentId,
    this.error,
  });

  factory QPayPaymentStatus.success({
    required String status,
    double? paidAmount,
    DateTime? paidDate,
    String? paymentId,
  }) {
    return QPayPaymentStatus(
      success: true,
      status: status,
      paidAmount: paidAmount,
      paidDate: paidDate,
      paymentId: paymentId,
    );
  }

  factory QPayPaymentStatus.error(String error) {
    return QPayPaymentStatus(success: false, error: error);
  }

  bool get isPaid => status == 'PAID';
  bool get isPending => status == 'PENDING';
  bool get isExpired => status == 'EXPIRED';
  bool get isCanceled => status == 'CANCELED';
}
