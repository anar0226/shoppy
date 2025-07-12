import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import '../config/environment_config.dart';

/// Production-ready QPay API Integration Service
/// Based on official documentation: https://developer.qpay.mn/
class QPayService {
  static final QPayService _instance = QPayService._internal();
  factory QPayService() => _instance;
  QPayService._internal();

  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;

  static String get _baseUrl => EnvironmentConfig.qpayBaseUrl;
  static const String _authEndpoint = '/auth/token';
  static const String _refreshEndpoint = '/auth/refresh';
  static const String _invoiceEndpoint = '/invoice';
  static const String _paymentCheckEndpoint = '/payment/check';

  /// Get access token using OAuth 2.0 (client_id, client_secret)
  /// As per QPay documentation: username = client_id, password = client_secret
  Future<String?> _getAccessToken() async {
    try {
      // Check if we have a valid token
      if (_accessToken != null &&
          _tokenExpiry != null &&
          DateTime.now()
              .isBefore(_tokenExpiry!.subtract(const Duration(minutes: 5)))) {
        return _accessToken;
      }

      // Try refresh token first if available
      if (_refreshToken != null) {
        final refreshed = await _refreshAccessToken();
        if (refreshed) return _accessToken;
      }

      log('QPayService: Requesting new access token');
      log('QPayService: Base URL: $_baseUrl');
      log('QPayService: Username (client_id): ${EnvironmentConfig.qpayUsername}');

      final response = await http.post(
        Uri.parse('$_baseUrl$_authEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization':
              'Basic ${base64Encode(utf8.encode('${EnvironmentConfig.qpayUsername}:${EnvironmentConfig.qpayPassword}'))}',
        },
        body: jsonEncode({}), // Empty body as per documentation
      );

      log('QPayService: Auth response status: ${response.statusCode}');
      log('QPayService: Auth response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];

        // Set expiry based on expires_in or default to 1 hour
        final expiresIn = data['expires_in'] ?? 3600;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

        log('QPayService: Successfully obtained access token');
        return _accessToken;
      } else {
        final errorData = jsonDecode(response.body);
        log('QPayService: Failed to get access token: ${response.statusCode} - ${errorData}');
        return null;
      }
    } catch (e) {
      log('QPayService: Error getting access token: $e');
      return null;
    }
  }

  /// Refresh access token using refresh_token
  Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null) return false;

    try {
      log('QPayService: Refreshing access token');

      final response = await http.post(
        Uri.parse('$_baseUrl$_refreshEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_refreshToken',
        },
        body: jsonEncode({}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];

        final expiresIn = data['expires_in'] ?? 3600;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

        log('QPayService: Successfully refreshed access token');
        return true;
      }
    } catch (e) {
      log('QPayService: Error refreshing token: $e');
    }

    return false;
  }

  /// Create QPay invoice according to official API specification
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

      // Prepare invoice data according to QPay API specification
      final invoiceData = {
        'invoice_code': EnvironmentConfig.qpayInvoiceCode,
        'sender_invoice_no': orderId,
        'invoice_receiver_code':
            customerEmail.replaceAll('@', '_').replaceAll('.', '_'),
        'invoice_description': description,
        'amount': amount,
        'callback_url':
            'https://us-central1-shoppy-6d81f.cloudfunctions.net/qpayWebhook',
        'return_url': 'avii://payment?action=success',
        'cancel_url': 'avii://payment?action=cancelled',

        // Optional fields for better tracking
        'sender_branch_code': 'MAIN',
        'sender_staff_code': 'SYSTEM',

        // Add customer data if available
        if (customerPhone != null)
          'invoice_receiver_data': {
            'phone': customerPhone,
            'email': customerEmail,
          },
      };

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
        return _parseInvoiceResponse(data, amount, description);
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ??
            errorData['error'] ??
            'Failed to create invoice';
        log('QPayService: Invoice creation failed: $errorMessage');
        return QPayInvoiceResult.error(errorMessage);
      }
    } catch (e) {
      log('QPayService: Error creating invoice: $e');
      return QPayInvoiceResult.error('Error creating invoice: $e');
    }
  }

  /// Parse QPay invoice response according to official API structure
  QPayInvoiceResult _parseInvoiceResponse(
      Map<String, dynamic> data, double amount, String description) {
    try {
      log('QPayService: Parsing invoice response: $data');

      // Extract invoice details according to QPay API response structure
      final invoiceId = data['invoice_id']?.toString() ?? '';
      final qpayInvoiceId = data['qpay_invoice_id']?.toString() ?? invoiceId;

      // QR code data
      final qrText = data['qr_text']?.toString() ?? '';
      final qrImage = data['qr_image']?.toString() ?? '';

      // URLs for payment - handle multiple possible field names
      String qpayShortlink = '';
      String qpayDeeplink = '';

      // Try different field names that QPay might use
      qpayShortlink = data['qPay_shortUrl']?.toString() ??
          data['qpay_shortlink']?.toString() ??
          data['qpay_shortUrl']?.toString() ??
          data['shortUrl']?.toString() ??
          '';

      qpayDeeplink = data['qpay_deeplink']?.toString() ??
          data['qPay_deeplink']?.toString() ??
          data['deeplink']?.toString() ??
          '';

      log('QPayService: Extracted qpayShortlink: $qpayShortlink');
      log('QPayService: Extracted qpayDeeplink: $qpayDeeplink');

      // URLs array (if present)
      List<dynamic> urlsArray = [];
      if (data['urls'] is List) {
        urlsArray = data['urls'] as List<dynamic>;
        log('QPayService: Found ${urlsArray.length} URLs in array');
      }

      // Extract additional URLs from the URLs array
      String additionalAppUrl = '';
      String additionalLinkUrl = '';

      if (urlsArray.isNotEmpty) {
        for (final urlItem in urlsArray) {
          if (urlItem is Map<String, dynamic>) {
            final link = urlItem['link']?.toString() ?? '';
            final name = urlItem['name']?.toString().toLowerCase() ?? '';

            log('QPayService: Processing URL item - name: $name, link: $link');

            if (name.contains('qpay') && additionalAppUrl.isEmpty) {
              additionalAppUrl = link;
            } else if (link.startsWith('http') && additionalLinkUrl.isEmpty) {
              additionalLinkUrl = link;
            }
          }
        }
      }

      log('QPayService: Additional app URL: $additionalAppUrl');
      log('QPayService: Additional link URL: $additionalLinkUrl');

      // Create URLs object with all available links
      final urls = QPayUrls(
        app: qpayDeeplink.isNotEmpty ? qpayDeeplink : additionalAppUrl,
        link: qpayShortlink.isNotEmpty ? qpayShortlink : additionalLinkUrl,
        logo: '',
      );

      // Generate web payment URL from QR code if no direct URL is available
      String finalShortLink = qpayShortlink;
      if (finalShortLink.isEmpty && qrText.isNotEmpty) {
        // Create QPay web URL from QR code
        final encodedQR = Uri.encodeComponent(qrText);
        finalShortLink = 'https://qpay.mn/q/?q=$encodedQR';
        log('QPayService: Generated web URL from QR code: $finalShortLink');
      }

      final invoice = QPayInvoice(
        id: invoiceId,
        qpayInvoiceId: qpayInvoiceId,
        amount: amount,
        description: description,
        status: 'PENDING',
        qrCode: qrText,
        qrImage: qrImage,
        deepLink: qpayDeeplink,
        shortLink: finalShortLink,
        urls: urls,
        createdAt: DateTime.now(),
      );

      log('QPayService: Successfully created invoice: ${invoice.id}');
      log('QPayService: QR Code length: ${qrText.length}');
      log('QPayService: Deep link: $qpayDeeplink');
      log('QPayService: Short link: $finalShortLink');
      log('QPayService: Best payment URL: ${invoice.bestPaymentUrl}');

      return QPayInvoiceResult.success(invoice);
    } catch (e) {
      log('QPayService: Error parsing invoice response: $e');
      return QPayInvoiceResult.error('Error parsing invoice response: $e');
    }
  }

  /// Check payment status according to QPay API
  Future<QPayPaymentStatus> checkPaymentStatus(String qpayInvoiceId) async {
    try {
      log('QPayService: Checking payment status for invoice: $qpayInvoiceId');

      final token = await _getAccessToken();
      if (token == null) {
        return QPayPaymentStatus.error('Failed to authenticate with QPay');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl$_paymentCheckEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'object_type': 'INVOICE',
          'object_id': qpayInvoiceId,
        }),
      );

      log('QPayService: Payment status response: ${response.statusCode}');
      log('QPayService: Payment status body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Handle both single payment and array of payments
        List<dynamic> payments = [];
        if (data['rows'] is List) {
          payments = data['rows'];
        } else if (data is List) {
          payments = data;
        } else if (data['payment_status'] != null) {
          payments = [data];
        }

        if (payments.isNotEmpty) {
          final payment = payments.first;
          return QPayPaymentStatus.success(
            status: payment['payment_status'] ?? 'PENDING',
            paidAmount: (payment['payment_amount'] ?? 0).toDouble(),
            paidDate: payment['payment_date'] != null
                ? DateTime.tryParse(payment['payment_date'])
                : null,
            paymentId: payment['payment_id']?.toString(),
          );
        } else {
          return QPayPaymentStatus.success(status: 'PENDING');
        }
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ??
            errorData['error'] ??
            'Failed to check payment status';
        return QPayPaymentStatus.error(errorMessage);
      }
    } catch (e) {
      log('QPayService: Error checking payment status: $e');
      return QPayPaymentStatus.error('Error checking payment status: $e');
    }
  }

  /// Debug method to test QPay connection and API responses
  Future<Map<String, dynamic>> debugQPayConnection() async {
    final debugInfo = <String, dynamic>{
      'baseUrl': _baseUrl,
      'username': EnvironmentConfig.qpayUsername,
      'hasPassword': EnvironmentConfig.qpayPassword.isNotEmpty,
      'invoiceCode': EnvironmentConfig.qpayInvoiceCode,
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      // Test authentication
      final token = await _getAccessToken();
      debugInfo['authSuccess'] = token != null;
      debugInfo['hasAccessToken'] = _accessToken != null;
      debugInfo['hasRefreshToken'] = _refreshToken != null;
      debugInfo['tokenExpiry'] = _tokenExpiry?.toIso8601String();

      if (token != null) {
        // Test invoice creation with minimal data
        final testInvoiceData = {
          'invoice_code': EnvironmentConfig.qpayInvoiceCode,
          'sender_invoice_no': 'DEBUG_${DateTime.now().millisecondsSinceEpoch}',
          'invoice_receiver_code': 'debug_user',
          'invoice_description': 'Debug test invoice',
          'amount': 100.0,
          'callback_url':
              'https://us-central1-shoppy-6d81f.cloudfunctions.net/qpayWebhook',
          'sender_branch_code': 'MAIN',
          'sender_staff_code': 'SYSTEM',
        };

        final response = await http.post(
          Uri.parse('$_baseUrl$_invoiceEndpoint'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(testInvoiceData),
        );

        debugInfo['testInvoiceStatus'] = response.statusCode;
        debugInfo['testInvoiceResponse'] = response.body;

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          debugInfo['responseKeys'] = data.keys.toList();
          debugInfo['hasQrText'] = data.containsKey('qr_text');
          debugInfo['hasQrImage'] = data.containsKey('qr_image');
          debugInfo['hasQpayShortlink'] = data.containsKey('qpay_shortlink');
          debugInfo['hasQpayDeeplink'] = data.containsKey('qpay_deeplink');
          debugInfo['hasUrls'] = data.containsKey('urls');
          debugInfo['invoiceId'] = data['invoice_id']?.toString();
          debugInfo['qpayInvoiceId'] = data['qpay_invoice_id']?.toString();
        }
      }
    } catch (e) {
      debugInfo['error'] = e.toString();
    }

    return debugInfo;
  }
}

/// QPay Invoice Model - Updated to match API response
class QPayInvoice {
  final String id;
  final String qpayInvoiceId;
  final double amount;
  final String description;
  final String status;
  final String qrCode;
  final String qrImage;
  final String deepLink;
  final String shortLink;
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
    required this.shortLink,
    required this.urls,
    required this.createdAt,
  });

  bool get isPaid => status == 'PAID';
  bool get isPending => status == 'PENDING';
  bool get isExpired => status == 'EXPIRED';
  bool get isCanceled => status == 'CANCELED';

  /// Get the best available payment URL
  String get bestPaymentUrl {
    // Try shortLink first (this should be the web payment URL)
    if (shortLink.isNotEmpty && shortLink != 'https://qpay.mn') {
      return shortLink;
    }

    // Try urls.link
    if (urls.link.isNotEmpty && urls.link != 'https://qpay.mn') {
      return urls.link;
    }

    // If we have a QR code, generate the web payment URL
    if (qrCode.isNotEmpty) {
      final encodedQR = Uri.encodeComponent(qrCode);
      return 'https://qpay.mn/q/?q=$encodedQR';
    }

    // Try deepLink as last resort
    if (deepLink.isNotEmpty) {
      return deepLink;
    }

    // Try urls.app as final fallback
    if (urls.app.isNotEmpty) {
      return urls.app;
    }

    // Return empty string to indicate no URL available
    return '';
  }

  /// Get the best available deep link for app
  String get bestDeepLink {
    if (deepLink.isNotEmpty) return deepLink;
    if (urls.app.isNotEmpty) return urls.app;
    return '';
  }
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
