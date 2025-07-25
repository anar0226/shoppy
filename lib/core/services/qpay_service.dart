import 'dart:convert';
import 'dart:developer';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/environment_config.dart';

/// Production-ready QPay API Integration Service
/// Enhanced with timeout handling, reconciliation, and refund processing
/// Based on official documentation: https://developer.qpay.mn/
class QPayService {
  static final QPayService _instance = QPayService._internal();
  factory QPayService() => _instance;
  QPayService._internal();

  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;

  // Timeout configurations
  static const Duration _defaultTimeout = Duration(minutes: 30);
  static const Duration _apiTimeout = Duration(seconds: 30);

  static String get _baseUrl => EnvironmentConfig.qpayBaseUrl;
  static const String _authEndpoint = '/auth/token';
  static const String _refreshEndpoint = '/auth/refresh';
  static const String _invoiceEndpoint = '/invoice';
  static const String _paymentCheckEndpoint = '/payment/check';
  static const String _paymentCancelEndpoint = '/payment/cancel';
  static const String _paymentRefundEndpoint = '/payment/refund';
  static const String _paymentListEndpoint = '/payment/list';

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

      // Get credentials from environment
      final username = EnvironmentConfig.qpayUsername;
      final password = EnvironmentConfig.qpayPassword;

      if (username.isEmpty || password.isEmpty) {
        log('QPayService: Missing QPay credentials in environment');
        throw Exception('QPay credentials not configured');
      }

      log('QPayService: Requesting new access token from $_baseUrl$_authEndpoint');

      final response = await http
          .post(
            Uri.parse('$_baseUrl$_authEndpoint'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'User-Agent': 'Shoppy-Mobile-App/1.0',
            },
            body: jsonEncode({
              'username': username,
              'password': password,
            }),
          )
          .timeout(_apiTimeout);

      log('QPayService: Token response status: ${response.statusCode}');
      log('QPayService: Token response headers: ${response.headers}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];

        final expiresIn = data['expires_in'] ?? 3600;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

        log('QPayService: Successfully obtained access token');
        return _accessToken;
      } else {
        final errorBody = response.body;
        log('QPayService: Failed to get access token: ${response.statusCode} - $errorBody');
        throw Exception(
            'QPay authentication failed: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      log('QPayService: Error getting access token: $e');
      if (e is TimeoutException) {
        throw Exception('QPay API timeout - check network connection');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('Network error - unable to connect to QPay API');
      } else if (e.toString().contains('HandshakeException')) {
        throw Exception('SSL/TLS error - check certificate configuration');
      }
      rethrow;
    }
  }

  /// Refresh access token using refresh_token
  Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null) return false;

    try {
      log('QPayService: Refreshing access token');

      final response = await http
          .post(
            Uri.parse('$_baseUrl$_refreshEndpoint'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $_refreshToken',
            },
            body: jsonEncode({}),
          )
          .timeout(_apiTimeout);

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

  /// Create QPay invoice with enhanced timeout handling
  Future<QPayInvoiceResult> createInvoice({
    required String orderId,
    required double amount,
    required String description,
    required String customerEmail,
    String? customerPhone,
    Map<String, dynamic>? metadata,
    Duration? customTimeout,
  }) async {
    try {
      log('QPayService: Creating invoice for order $orderId, amount: $amount');

      final token = await _getAccessToken();
      if (token == null) {
        return QPayInvoiceResult.error('Failed to authenticate with QPay');
      }

      // Calculate invoice expiry time
      final expiryTime = DateTime.now().add(customTimeout ?? _defaultTimeout);

      // Prepare invoice data according to QPay API specification
      final invoiceData = {
        'invoice_code': EnvironmentConfig.qpayInvoiceCode,
        'sender_invoice_no': orderId,
        'invoice_receiver_code':
            customerEmail.replaceAll('@', '_').replaceAll('.', '_'),
        'invoice_description': description,
        'amount': amount,
        'callback_url': metadata?['type'] == 'subscription'
            ? 'https://us-central1-shoppy-6d81f.cloudfunctions.net/subscriptionWebhook'
            : 'https://us-central1-shoppy-6d81f.cloudfunctions.net/qpayWebhook',
        'return_url': 'avii://payment?action=success&order_id=$orderId',
        'cancel_url': 'avii://payment?action=cancelled&order_id=$orderId',
        'expiry_date': expiryTime.toIso8601String(),
        'enable_expiry': true,

        // Enhanced tracking fields
        'sender_branch_code': 'MAIN',
        'sender_staff_code': 'SYSTEM',
        'sender_terminal_code': 'MOBILE_APP',

        // Add customer data if available
        if (customerPhone != null)
          'invoice_receiver_data': {
            'phone': customerPhone,
            'email': customerEmail,
          },

        // Add metadata for tracking
        if (metadata != null) 'metadata': metadata,
      };

      log('QPayService: Invoice data: ${jsonEncode(invoiceData)}');

      final response = await http
          .post(
            Uri.parse('$_baseUrl$_invoiceEndpoint'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(invoiceData),
          )
          .timeout(_apiTimeout);

      log('QPayService: Invoice response status: ${response.statusCode}');
      log('QPayService: Invoice response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _parseInvoiceResponse(data, amount, description, expiryTime);
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

  /// Parse QPay invoice response with enhanced timeout tracking
  QPayInvoiceResult _parseInvoiceResponse(Map<String, dynamic> data,
      double amount, String description, DateTime expiryTime) {
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
        expiresAt: expiryTime,
        timeoutDuration: _defaultTimeout,
      );

      log('QPayService: Successfully created invoice: ${invoice.id}');
      log('QPayService: QR Code length: ${qrText.length}');
      log('QPayService: Deep link: $qpayDeeplink');
      log('QPayService: Short link: $finalShortLink');
      log('QPayService: Best payment URL: ${invoice.bestPaymentUrl}');
      log('QPayService: Expires at: ${invoice.expiresAt}');

      return QPayInvoiceResult.success(invoice);
    } catch (e) {
      log('QPayService: Error parsing invoice response: $e');
      return QPayInvoiceResult.error('Error parsing invoice response: $e');
    }
  }

  /// Check payment status with enhanced error handling
  Future<QPayPaymentStatus> checkPaymentStatus(String qpayInvoiceId) async {
    try {
      log('QPayService: Checking payment status for invoice: $qpayInvoiceId');

      final token = await _getAccessToken();
      if (token == null) {
        return QPayPaymentStatus.error('Failed to authenticate with QPay');
      }

      final response = await http
          .post(
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
          )
          .timeout(_apiTimeout);

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
            qpayInvoiceId: qpayInvoiceId,
            currency: payment['payment_currency'] ?? 'MNT',
            paymentMethod: payment['paid_by'] ?? 'CARD',
          );
        } else {
          return QPayPaymentStatus.success(
            status: 'PENDING',
            qpayInvoiceId: qpayInvoiceId,
          );
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

  /// Cancel payment invoice
  Future<QPayOperationResult> cancelPayment(String qpayInvoiceId) async {
    try {
      log('QPayService: Cancelling payment for invoice: $qpayInvoiceId');

      final token = await _getAccessToken();
      if (token == null) {
        return QPayOperationResult.error('Failed to authenticate with QPay');
      }

      final response = await http.delete(
        Uri.parse('$_baseUrl$_paymentCancelEndpoint/$qpayInvoiceId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(_apiTimeout);

      log('QPayService: Cancel payment response: ${response.statusCode}');
      log('QPayService: Cancel payment body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return QPayOperationResult.success(
          message: data['message'] ?? 'Payment cancelled successfully',
          data: data,
        );
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ??
            errorData['error'] ??
            'Failed to cancel payment';
        return QPayOperationResult.error(errorMessage);
      }
    } catch (e) {
      log('QPayService: Error cancelling payment: $e');
      return QPayOperationResult.error('Error cancelling payment: $e');
    }
  }

  /// Process refund with comprehensive handling
  Future<QPayRefundResult> processRefund({
    required String paymentId,
    required double refundAmount,
    required String reason,
    String? callbackUrl,
    String? note,
  }) async {
    try {
      log('QPayService: Processing refund for payment: $paymentId, amount: $refundAmount');

      final token = await _getAccessToken();
      if (token == null) {
        return QPayRefundResult.error('Failed to authenticate with QPay');
      }

      final refundData = {
        'payment_id': paymentId,
        'amount': refundAmount,
        'reason': reason,
        if (callbackUrl != null) 'callback_url': callbackUrl,
        if (note != null) 'note': note,
      };

      final response = await http
          .delete(
            Uri.parse('$_baseUrl$_paymentRefundEndpoint/$paymentId'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(refundData),
          )
          .timeout(_apiTimeout);

      log('QPayService: Refund response: ${response.statusCode}');
      log('QPayService: Refund body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return QPayRefundResult.success(
          refundId: data['refund_id']?.toString() ?? '',
          paymentId: paymentId,
          refundAmount: refundAmount,
          status: data['status'] ?? 'PROCESSING',
          message: data['message'] ?? 'Refund processed successfully',
          refundDate: DateTime.now(),
        );
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error'] ??
            errorData['message'] ??
            'Failed to process refund';

        // Handle specific error cases
        if (errorMessage.contains('PAYMENT_SETTLED')) {
          return QPayRefundResult.error(
              'Payment has already been settled and cannot be refunded');
        }

        return QPayRefundResult.error(errorMessage);
      }
    } catch (e) {
      log('QPayService: Error processing refund: $e');
      return QPayRefundResult.error('Error processing refund: $e');
    }
  }

  /// Get payment history for reconciliation
  Future<QPayPaymentListResult> getPaymentHistory({
    required String objectType,
    required String objectId,
    int pageNumber = 1,
    int pageLimit = 100,
    String? branchCode,
    String? terminalCode,
    String? staffCode,
  }) async {
    try {
      log('QPayService: Getting payment history for $objectType:$objectId');

      final token = await _getAccessToken();
      if (token == null) {
        return QPayPaymentListResult.error('Failed to authenticate with QPay');
      }

      final requestData = {
        'object_type': objectType,
        'object_id': objectId,
        'offset': {
          'page_number': pageNumber,
          'page_limit': pageLimit,
        },
        if (branchCode != null) 'merchant_branch_code': branchCode,
        if (terminalCode != null) 'merchant_terminal_code': terminalCode,
        if (staffCode != null) 'merchant_staff_code': staffCode,
      };

      final response = await http
          .post(
            Uri.parse('$_baseUrl$_paymentListEndpoint'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(requestData),
          )
          .timeout(_apiTimeout);

      log('QPayService: Payment list response: ${response.statusCode}');
      log('QPayService: Payment list body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final payments = <QPayPaymentRecord>[];

        if (data['rows'] is List) {
          for (final payment in data['rows']) {
            payments.add(QPayPaymentRecord.fromJson(payment));
          }
        }

        return QPayPaymentListResult.success(
          payments: payments,
          totalCount: data['total_count'] ?? payments.length,
          pageNumber: pageNumber,
          pageLimit: pageLimit,
        );
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ??
            errorData['error'] ??
            'Failed to get payment history';
        return QPayPaymentListResult.error(errorMessage);
      }
    } catch (e) {
      log('QPayService: Error getting payment history: $e');
      return QPayPaymentListResult.error('Error getting payment history: $e');
    }
  }

  /// Enhanced payment reconciliation
  Future<QPayReconciliationResult> reconcilePayments({
    required String objectType,
    required String objectId,
    required List<String> expectedPaymentIds,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      log('QPayService: Starting payment reconciliation for $objectType:$objectId');

      final paymentHistoryResult = await getPaymentHistory(
        objectType: objectType,
        objectId: objectId,
        pageLimit: 100,
      );

      if (!paymentHistoryResult.success) {
        return QPayReconciliationResult.error(
            paymentHistoryResult.error ?? 'Failed to get payment history');
      }

      final qpayPayments = paymentHistoryResult.payments!;
      final discrepancies = <QPayDiscrepancy>[];
      final reconciledPayments = <QPayPaymentRecord>[];

      // Check for missing payments in QPay
      for (final expectedId in expectedPaymentIds) {
        final qpayPayment = qpayPayments.firstWhere(
          (p) => p.paymentId == expectedId,
          orElse: () => QPayPaymentRecord.empty(),
        );

        if (qpayPayment.paymentId.isEmpty) {
          discrepancies.add(QPayDiscrepancy(
            type: QPayDiscrepancyType.missingInQPay,
            paymentId: expectedId,
            description: 'Payment not found in QPay system',
            expectedAmount: 0,
            actualAmount: 0,
          ));
        } else {
          reconciledPayments.add(qpayPayment);
        }
      }

      // Check for extra payments in QPay
      for (final qpayPayment in qpayPayments) {
        if (!expectedPaymentIds.contains(qpayPayment.paymentId)) {
          discrepancies.add(QPayDiscrepancy(
            type: QPayDiscrepancyType.extraInQPay,
            paymentId: qpayPayment.paymentId,
            description: 'Payment found in QPay but not expected',
            expectedAmount: 0,
            actualAmount: qpayPayment.amount,
          ));
        }
      }

      // Apply date filters if provided
      if (startDate != null || endDate != null) {
        final filteredPayments = qpayPayments.where((payment) {
          final paymentDate = payment.paymentDate;
          if (paymentDate == null) return false;

          if (startDate != null && paymentDate.isBefore(startDate)) {
            return false;
          }
          if (endDate != null && paymentDate.isAfter(endDate)) return false;

          return true;
        }).toList();

        log('QPayService: Filtered ${filteredPayments.length} payments by date range');
      }

      return QPayReconciliationResult.success(
        reconciledPayments: reconciledPayments,
        discrepancies: discrepancies,
        totalReconciled: reconciledPayments.length,
        totalDiscrepancies: discrepancies.length,
        reconciliationDate: DateTime.now(),
      );
    } catch (e) {
      log('QPayService: Error during payment reconciliation: $e');
      return QPayReconciliationResult.error(
          'Error during payment reconciliation: $e');
    }
  }

  /// Get comprehensive payment analytics
  Future<QPayAnalyticsResult> getPaymentAnalytics({
    required String objectType,
    required String objectId,
    DateTime? startDate,
    DateTime? endDate,
    String? paymentMethod,
  }) async {
    try {
      log('QPayService: Getting payment analytics for $objectType:$objectId');

      final paymentHistoryResult = await getPaymentHistory(
        objectType: objectType,
        objectId: objectId,
        pageLimit: 1000, // Get more data for analytics
      );

      if (!paymentHistoryResult.success) {
        return QPayAnalyticsResult.error(
            paymentHistoryResult.error ?? 'Failed to get payment data');
      }

      final payments = paymentHistoryResult.payments!;

      // Filter by date range if provided
      final filteredPayments = payments.where((payment) {
        final paymentDate = payment.paymentDate;
        if (paymentDate == null) return false;

        if (startDate != null && paymentDate.isBefore(startDate)) return false;
        if (endDate != null && paymentDate.isAfter(endDate)) return false;

        if (paymentMethod != null && payment.paymentMethod != paymentMethod) {
          return false;
        }

        return true;
      }).toList();

      // Calculate analytics
      final totalPayments = filteredPayments.length;
      final totalAmount = filteredPayments.fold<double>(
        0,
        (sum, payment) => sum + payment.amount,
      );

      final paidPayments =
          filteredPayments.where((p) => p.status == 'PAID').length;
      final failedPayments =
          filteredPayments.where((p) => p.status == 'FAILED').length;
      final refundedPayments =
          filteredPayments.where((p) => p.status == 'REFUNDED').length;

      // Payment method breakdown
      final paymentMethodBreakdown = <String, int>{};
      for (final payment in filteredPayments) {
        paymentMethodBreakdown[payment.paymentMethod] =
            (paymentMethodBreakdown[payment.paymentMethod] ?? 0) + 1;
      }

      // Success rate calculation
      final successRate =
          totalPayments > 0 ? (paidPayments / totalPayments) * 100 : 0.0;

      return QPayAnalyticsResult.success(
        totalPayments: totalPayments,
        totalAmount: totalAmount,
        paidPayments: paidPayments,
        failedPayments: failedPayments,
        refundedPayments: refundedPayments,
        successRate: successRate,
        paymentMethodBreakdown: paymentMethodBreakdown,
        averagePaymentAmount:
            totalPayments > 0 ? totalAmount / totalPayments : 0,
        period: {
          'startDate': startDate?.toIso8601String(),
          'endDate': endDate?.toIso8601String(),
        },
      );
    } catch (e) {
      log('QPayService: Error getting payment analytics: $e');
      return QPayAnalyticsResult.error('Error getting payment analytics: $e');
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

        final response = await http
            .post(
              Uri.parse('$_baseUrl$_invoiceEndpoint'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode(testInvoiceData),
            )
            .timeout(_apiTimeout);

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

  /// Simple debug method to check environment variables
  static Map<String, dynamic> debugEnvironment() {
    return {
      'qpayUsername': EnvironmentConfig.qpayUsername,
      'hasQpayPassword': EnvironmentConfig.qpayPassword.isNotEmpty,
      'qpayInvoiceCode': EnvironmentConfig.qpayInvoiceCode,
      'qpayBaseUrl': EnvironmentConfig.qpayBaseUrl,
      'hasPaymentConfig': EnvironmentConfig.hasPaymentConfig,
    };
  }
}

/// QPay Invoice Model - Enhanced with timeout handling
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
  final DateTime expiresAt;
  final Duration timeoutDuration;

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
    required this.expiresAt,
    required this.timeoutDuration,
  });

  bool get isPaid => status == 'PAID';
  bool get isPending => status == 'PENDING';
  bool get isExpired =>
      status == 'EXPIRED' || DateTime.now().isAfter(expiresAt);
  bool get isCanceled => status == 'CANCELED';
  bool get isTimedOut => DateTime.now().isAfter(expiresAt);

  /// Get remaining time before expiry
  Duration get remainingTime {
    final now = DateTime.now();
    if (now.isAfter(expiresAt)) {
      return Duration.zero;
    }
    return expiresAt.difference(now);
  }

  /// Get timeout percentage (0-100)
  double get timeoutPercentage {
    final elapsed = DateTime.now().difference(createdAt);
    final percentage =
        (elapsed.inMilliseconds / timeoutDuration.inMilliseconds) * 100;
    return percentage.clamp(0, 100);
  }

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

/// QPay Payment Status - Enhanced with more details
class QPayPaymentStatus {
  final bool success;
  final String? status;
  final double? paidAmount;
  final DateTime? paidDate;
  final String? paymentId;
  final String? qpayInvoiceId;
  final String? currency;
  final String? paymentMethod;
  final String? error;

  const QPayPaymentStatus({
    required this.success,
    this.status,
    this.paidAmount,
    this.paidDate,
    this.paymentId,
    this.qpayInvoiceId,
    this.currency,
    this.paymentMethod,
    this.error,
  });

  factory QPayPaymentStatus.success({
    required String status,
    double? paidAmount,
    DateTime? paidDate,
    String? paymentId,
    String? qpayInvoiceId,
    String? currency,
    String? paymentMethod,
  }) {
    return QPayPaymentStatus(
      success: true,
      status: status,
      paidAmount: paidAmount,
      paidDate: paidDate,
      paymentId: paymentId,
      qpayInvoiceId: qpayInvoiceId,
      currency: currency,
      paymentMethod: paymentMethod,
    );
  }

  factory QPayPaymentStatus.error(String error) {
    return QPayPaymentStatus(success: false, error: error);
  }

  bool get isPaid => status == 'PAID';
  bool get isPending => status == 'PENDING';
  bool get isExpired => status == 'EXPIRED';
  bool get isCanceled => status == 'CANCELED';
  bool get isFailed => status == 'FAILED';
  bool get isRefunded => status == 'REFUNDED';
}

/// QPay Operation Result
class QPayOperationResult {
  final bool success;
  final String? message;
  final Map<String, dynamic>? data;
  final String? error;

  const QPayOperationResult({
    required this.success,
    this.message,
    this.data,
    this.error,
  });

  factory QPayOperationResult.success({
    required String message,
    Map<String, dynamic>? data,
  }) {
    return QPayOperationResult(
      success: true,
      message: message,
      data: data,
    );
  }

  factory QPayOperationResult.error(String error) {
    return QPayOperationResult(success: false, error: error);
  }
}

/// QPay Refund Result
class QPayRefundResult {
  final bool success;
  final String? refundId;
  final String? paymentId;
  final double? refundAmount;
  final String? status;
  final String? message;
  final DateTime? refundDate;
  final String? error;

  const QPayRefundResult({
    required this.success,
    this.refundId,
    this.paymentId,
    this.refundAmount,
    this.status,
    this.message,
    this.refundDate,
    this.error,
  });

  factory QPayRefundResult.success({
    required String refundId,
    required String paymentId,
    required double refundAmount,
    required String status,
    required String message,
    required DateTime refundDate,
  }) {
    return QPayRefundResult(
      success: true,
      refundId: refundId,
      paymentId: paymentId,
      refundAmount: refundAmount,
      status: status,
      message: message,
      refundDate: refundDate,
    );
  }

  factory QPayRefundResult.error(String error) {
    return QPayRefundResult(success: false, error: error);
  }

  bool get isProcessing => status == 'PROCESSING';
  bool get isCompleted => status == 'COMPLETED';
  bool get isFailed => status == 'FAILED';
}

/// QPay Payment Record for reconciliation
class QPayPaymentRecord {
  final String paymentId;
  final DateTime? paymentDate;
  final String status;
  final double amount;
  final String currency;
  final String paymentMethod;
  final String? qrCode;
  final String objectType;
  final String objectId;

  const QPayPaymentRecord({
    required this.paymentId,
    this.paymentDate,
    required this.status,
    required this.amount,
    required this.currency,
    required this.paymentMethod,
    this.qrCode,
    required this.objectType,
    required this.objectId,
  });

  factory QPayPaymentRecord.fromJson(Map<String, dynamic> json) {
    return QPayPaymentRecord(
      paymentId: json['payment_id']?.toString() ?? '',
      paymentDate: json['payment_date'] != null
          ? DateTime.tryParse(json['payment_date'])
          : null,
      status: json['payment_status']?.toString() ?? 'UNKNOWN',
      amount: (json['payment_amount'] ?? 0).toDouble(),
      currency: json['payment_currency']?.toString() ?? 'MNT',
      paymentMethod: json['paid_by']?.toString() ?? 'UNKNOWN',
      qrCode: json['qr_code']?.toString(),
      objectType: json['object_type']?.toString() ?? '',
      objectId: json['object_id']?.toString() ?? '',
    );
  }

  factory QPayPaymentRecord.empty() {
    return const QPayPaymentRecord(
      paymentId: '',
      status: 'UNKNOWN',
      amount: 0,
      currency: 'MNT',
      paymentMethod: 'UNKNOWN',
      objectType: '',
      objectId: '',
    );
  }
}

/// QPay Payment List Result
class QPayPaymentListResult {
  final bool success;
  final List<QPayPaymentRecord>? payments;
  final int? totalCount;
  final int? pageNumber;
  final int? pageLimit;
  final String? error;

  const QPayPaymentListResult({
    required this.success,
    this.payments,
    this.totalCount,
    this.pageNumber,
    this.pageLimit,
    this.error,
  });

  factory QPayPaymentListResult.success({
    required List<QPayPaymentRecord> payments,
    required int totalCount,
    required int pageNumber,
    required int pageLimit,
  }) {
    return QPayPaymentListResult(
      success: true,
      payments: payments,
      totalCount: totalCount,
      pageNumber: pageNumber,
      pageLimit: pageLimit,
    );
  }

  factory QPayPaymentListResult.error(String error) {
    return QPayPaymentListResult(success: false, error: error);
  }
}

/// QPay Discrepancy Types
enum QPayDiscrepancyType {
  missingInQPay,
  extraInQPay,
  amountMismatch,
  statusMismatch,
  dateMismatch,
}

/// QPay Discrepancy
class QPayDiscrepancy {
  final QPayDiscrepancyType type;
  final String paymentId;
  final String description;
  final double expectedAmount;
  final double actualAmount;
  final DateTime? timestamp;

  const QPayDiscrepancy({
    required this.type,
    required this.paymentId,
    required this.description,
    required this.expectedAmount,
    required this.actualAmount,
    this.timestamp,
  });
}

/// QPay Reconciliation Result
class QPayReconciliationResult {
  final bool success;
  final List<QPayPaymentRecord>? reconciledPayments;
  final List<QPayDiscrepancy>? discrepancies;
  final int? totalReconciled;
  final int? totalDiscrepancies;
  final DateTime? reconciliationDate;
  final String? error;

  const QPayReconciliationResult({
    required this.success,
    this.reconciledPayments,
    this.discrepancies,
    this.totalReconciled,
    this.totalDiscrepancies,
    this.reconciliationDate,
    this.error,
  });

  factory QPayReconciliationResult.success({
    required List<QPayPaymentRecord> reconciledPayments,
    required List<QPayDiscrepancy> discrepancies,
    required int totalReconciled,
    required int totalDiscrepancies,
    required DateTime reconciliationDate,
  }) {
    return QPayReconciliationResult(
      success: true,
      reconciledPayments: reconciledPayments,
      discrepancies: discrepancies,
      totalReconciled: totalReconciled,
      totalDiscrepancies: totalDiscrepancies,
      reconciliationDate: reconciliationDate,
    );
  }

  factory QPayReconciliationResult.error(String error) {
    return QPayReconciliationResult(success: false, error: error);
  }

  bool get hasDiscrepancies => (totalDiscrepancies ?? 0) > 0;
  double get reconciliationRate =>
      (totalReconciled ?? 0) /
      ((totalReconciled ?? 0) + (totalDiscrepancies ?? 0));
}

/// QPay Analytics Result
class QPayAnalyticsResult {
  final bool success;
  final int? totalPayments;
  final double? totalAmount;
  final int? paidPayments;
  final int? failedPayments;
  final int? refundedPayments;
  final double? successRate;
  final Map<String, int>? paymentMethodBreakdown;
  final double? averagePaymentAmount;
  final Map<String, dynamic>? period;
  final String? error;

  const QPayAnalyticsResult({
    required this.success,
    this.totalPayments,
    this.totalAmount,
    this.paidPayments,
    this.failedPayments,
    this.refundedPayments,
    this.successRate,
    this.paymentMethodBreakdown,
    this.averagePaymentAmount,
    this.period,
    this.error,
  });

  factory QPayAnalyticsResult.success({
    required int totalPayments,
    required double totalAmount,
    required int paidPayments,
    required int failedPayments,
    required int refundedPayments,
    required double successRate,
    required Map<String, int> paymentMethodBreakdown,
    required double averagePaymentAmount,
    required Map<String, dynamic> period,
  }) {
    return QPayAnalyticsResult(
      success: true,
      totalPayments: totalPayments,
      totalAmount: totalAmount,
      paidPayments: paidPayments,
      failedPayments: failedPayments,
      refundedPayments: refundedPayments,
      successRate: successRate,
      paymentMethodBreakdown: paymentMethodBreakdown,
      averagePaymentAmount: averagePaymentAmount,
      period: period,
    );
  }

  factory QPayAnalyticsResult.error(String error) {
    return QPayAnalyticsResult(success: false, error: error);
  }
}
