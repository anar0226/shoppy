import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/environment_config.dart';

/// Minimal, production-ready QPay API integration service
/// Based on official documentation: https://developer.qpay.mn/
class QPayService {
  static const String _authEndpoint = '/auth/token';
  static const String _refreshEndpoint = '/auth/refresh';
  static const String _invoiceEndpoint = '/invoice';
  static const String _paymentCheckEndpoint = '/v2/payment/check';
  static const Duration _apiTimeout = Duration(seconds: 30);

  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;

  // Get access token using Basic Auth or refresh token
  Future<String> _getAccessToken() async {
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken!;
    }

    // Try to refresh the token if we have a refresh token
    if (_refreshToken != null) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) return _accessToken!;
    }

    // Otherwise, get a new token using client credentials
    final username = EnvironmentConfig.qpayUsername;
    final password = EnvironmentConfig.qpayPassword;
    final baseUrl = EnvironmentConfig.qpayBaseUrl;

    if (username.isEmpty || password.isEmpty) {
      throw Exception(
          'QPay credentials are missing. Please check QPAY_USERNAME and QPAY_PASSWORD.');
    }

    final basicAuth =
        'Basic ${base64Encode(utf8.encode('$username:$password'))}';

    final response = await http
        .post(
          Uri.parse('$baseUrl$_authEndpoint'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': basicAuth,
          },
          body: jsonEncode({'grant_type': 'client_credentials'}),
        )
        .timeout(_apiTimeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _accessToken = data['access_token'];
      _refreshToken = data['refresh_token'];
      final expiresIn = data['expires_in'] ?? 3600;
      _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
      return _accessToken!;
    } else {
      final errorBody = response.body;
      try {
        final errorData = jsonDecode(errorBody);
        final errorMessage =
            errorData['message'] ?? errorData['error'] ?? 'Unknown error';
        throw Exception(
            'QPay Auth failed (${response.statusCode}): $errorMessage');
      } catch (e) {
        throw Exception(
            'QPay Auth failed (${response.statusCode}): $errorBody');
      }
    }
  }

  // Refresh access token using refresh_token
  Future<bool> _refreshAccessToken() async {
    final baseUrl = EnvironmentConfig.qpayBaseUrl;
    if (_refreshToken == null) return false;

    final response = await http
        .post(
          Uri.parse('$baseUrl$_refreshEndpoint'),
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
      return true;
    }
    return false;
  }

  // Create a new QPay invoice
  Future<Map<String, dynamic>> createInvoice({
    required String orderId,
    required double amount,
    required String description,
    required String customerCode,
  }) async {
    // Validate all inputs
    if (orderId.isEmpty) {
      throw Exception('Order ID cannot be empty');
    }
    if (amount <= 0) {
      throw Exception('Amount must be greater than 0');
    }
    if (description.isEmpty) {
      throw Exception('Description cannot be empty');
    }
    if (customerCode.isEmpty) {
      throw Exception('Customer code cannot be empty');
    }

    // Validate configuration first
    if (!EnvironmentConfig.hasPaymentConfig) {
      throw Exception(
          'QPay configuration is missing. Please check QPAY_USERNAME, QPAY_PASSWORD, and QPAY_INVOICE_CODE.');
    }

    try {
      final token = await _getAccessToken();
      final baseUrl = EnvironmentConfig.qpayBaseUrl;
      final invoiceCode = EnvironmentConfig.qpayInvoiceCode;

      final invoiceData = {
        'invoice_code': invoiceCode,
        'sender_invoice_no': orderId,
        'invoice_receiver_code': customerCode,
        'invoice_description': description,
        'amount': amount,
        'enable_expiry': false,
        'sender_branch_code': 'MAIN',
        'sender_staff_code': 'SYSTEM',
        'sender_terminal_code': 'MOBILE_APP',
        // Add callback/return/cancel URLs as needed
      };

      final response = await http
          .post(
            Uri.parse('$baseUrl$_invoiceEndpoint'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(invoiceData),
          )
          .timeout(_apiTimeout);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        // Check for different possible invoice ID fields
        final invoiceId = result['qPayInvoiceId'] ??
            result['invoice_id'] ??
            result['id'] ??
            result['qpay_invoice_id'];

        if (invoiceId != null) {
          return result;
        } else {
          // Return the response anyway, as it might contain other useful information
          return result;
        }
      } else if (response.statusCode == 401) {
        throw Exception(
            'QPay authentication failed. Please check your credentials.');
      } else if (response.statusCode == 400) {
        final errorBody = response.body;
        try {
          final errorData = jsonDecode(errorBody);
          final errorMessage =
              errorData['message'] ?? errorData['error'] ?? 'Bad request';
          throw Exception('QPay request invalid: $errorMessage');
        } catch (e) {
          throw Exception('QPay request invalid: $errorBody');
        }
      } else if (response.statusCode == 500) {
        throw Exception('QPay server error. Please try again later.');
      } else {
        final errorBody = response.body;
        try {
          final errorData = jsonDecode(errorBody);
          final errorMessage =
              errorData['message'] ?? errorData['error'] ?? 'Unknown error';
          throw Exception(
              'QPay Invoice failed (${response.statusCode}): $errorMessage');
        } catch (e) {
          throw Exception(
              'QPay Invoice failed (${response.statusCode}): $errorBody');
        }
      }
    } catch (e) {
      if (e.toString().contains('QPay Auth failed')) {
        throw Exception(
            'QPay authentication failed. Please check your credentials.');
      } else if (e.toString().contains('timeout')) {
        throw Exception(
            'QPay request timed out. Please check your internet connection.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception(
            'Cannot connect to QPay. Please check your internet connection.');
      } else {
        rethrow;
      }
    }
  }

  // Check payment status
  Future<Map<String, dynamic>> checkPaymentStatus(String qpayInvoiceId) async {
    final token = await _getAccessToken();
    final baseUrl = EnvironmentConfig.qpayBaseUrl;

    // Prepare request body according to QPay documentation
    final requestBody = {
      'object_type': 'INVOICE',
      'object_id': qpayInvoiceId,
      // Optional parameters for better tracking
      'merchant_branch_code': 'MAIN',
      'merchant_terminal_code': 'MOBILE_APP',
      'merchant_staff_code': 'SYSTEM',
    };

    debugPrint('QPay Payment Check Request: $requestBody');

    final response = await http
        .post(
          Uri.parse('$baseUrl$_paymentCheckEndpoint'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(requestBody),
        )
        .timeout(_apiTimeout);

    debugPrint('QPay Payment Check Response Status: ${response.statusCode}');
    debugPrint('QPay Payment Check Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      debugPrint('QPay Payment Check Success: $responseData');
      return responseData;
    } else {
      final errorMessage =
          'QPay Payment Check failed (${response.statusCode}): ${response.body}';
      debugPrint(errorMessage);
      throw Exception(errorMessage);
    }
  }

  // Check payment status by payment ID (alternative method)
  Future<Map<String, dynamic>> checkPaymentStatusByPaymentId(
      String paymentId) async {
    final token = await _getAccessToken();
    final baseUrl = EnvironmentConfig.qpayBaseUrl;

    // Use the get payment endpoint for payment ID
    final response = await http.get(
      Uri.parse('$baseUrl/v2/payment/$paymentId'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(_apiTimeout);

    debugPrint(
        'QPay Payment Check by Payment ID Response Status: ${response.statusCode}');
    debugPrint(
        'QPay Payment Check by Payment ID Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      debugPrint('QPay Payment Check by Payment ID Success: $responseData');
      return responseData;
    } else {
      final errorMessage =
          'QPay Payment Check by Payment ID failed (${response.statusCode}): ${response.body}';
      debugPrint(errorMessage);
      throw Exception(errorMessage);
    }
  }

  // Get invoice info by invoice ID
  Future<Map<String, dynamic>> getInvoice(String invoiceId) async {
    final token = await _getAccessToken();
    final baseUrl = EnvironmentConfig.qpayBaseUrl;

    final response = await http.get(
      Uri.parse('$baseUrl/v2/invoice/$invoiceId'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(_apiTimeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('QPay Get Invoice failed: \\${response.body}');
    }
  }

  // Cancel invoice by invoice ID
  Future<Map<String, dynamic>> cancelInvoice(String invoiceId) async {
    final token = await _getAccessToken();
    final baseUrl = EnvironmentConfig.qpayBaseUrl;

    final response = await http.delete(
      Uri.parse('$baseUrl/v2/invoice/$invoiceId'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(_apiTimeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('QPay Cancel Invoice failed: \\${response.body}');
    }
  }

  // Get payment info by payment ID
  Future<Map<String, dynamic>> getPayment(String paymentId) async {
    final token = await _getAccessToken();
    final baseUrl = EnvironmentConfig.qpayBaseUrl;

    final response = await http.get(
      Uri.parse('$baseUrl/v2/payment/$paymentId'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(_apiTimeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('QPay Get Payment failed: \\${response.body}');
    }
  }

  // Cancel payment by payment ID
  Future<Map<String, dynamic>> cancelPayment(String paymentId,
      {String? callbackUrl, String? note}) async {
    final token = await _getAccessToken();
    final baseUrl = EnvironmentConfig.qpayBaseUrl;

    final body = <String, dynamic>{};
    if (callbackUrl != null) body['callback_url'] = callbackUrl;
    if (note != null) body['note'] = note;

    final response = await http
        .delete(
          Uri.parse('$baseUrl/v2/payment/cancel/$paymentId'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: body.isNotEmpty ? jsonEncode(body) : null,
        )
        .timeout(_apiTimeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('QPay Cancel Payment failed: ${response.body}');
    }
  }

  // Refund payment by payment ID
  Future<Map<String, dynamic>> refundPayment(String paymentId,
      {String? callbackUrl, String? note}) async {
    final token = await _getAccessToken();
    final baseUrl = EnvironmentConfig.qpayBaseUrl;

    final body = <String, dynamic>{};
    if (callbackUrl != null) body['callback_url'] = callbackUrl;
    if (note != null) body['note'] = note;

    final response = await http
        .delete(
          Uri.parse('$baseUrl/v2/payment/refund/$paymentId'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: body.isNotEmpty ? jsonEncode(body) : null,
        )
        .timeout(_apiTimeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('QPay Refund Payment failed: ${response.body}');
    }
  }

  // List payments with pagination and filters
  Future<Map<String, dynamic>> listPayments({
    required String objectType,
    required String objectId,
    int pageNumber = 1,
    int pageLimit = 100,
    String? branchCode,
    String? terminalCode,
    String? staffCode,
  }) async {
    final token = await _getAccessToken();
    final baseUrl = EnvironmentConfig.qpayBaseUrl;

    final body = <String, dynamic>{
      'object_type': objectType,
      'object_id': objectId,
      'offset': {
        'page_number': pageNumber,
        'page_limit': pageLimit,
      },
    };
    if (branchCode != null) body['merchant_branch_code'] = branchCode;
    if (terminalCode != null) body['merchant_terminal_code'] = terminalCode;
    if (staffCode != null) body['merchant_staff_code'] = staffCode;

    final response = await http
        .post(
          Uri.parse('$baseUrl/v2/payment/list'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(_apiTimeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('QPay List Payments failed: ${response.body}');
    }
  }
}
