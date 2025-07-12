import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import '../config/environment_config.dart';

class QPayWebhookConfig {
  static String get _baseUrl => EnvironmentConfig.qpayBaseUrl;

  /// Configure webhook URL through QPay API
  static Future<bool> configureWebhook({
    required String accessToken,
    required String webhookUrl,
    List<String> events = const [
      'payment.paid',
      'payment.failed',
      'payment.cancelled'
    ],
  }) async {
    try {
      log('QPayWebhookConfig: Configuring webhook URL: $webhookUrl');

      final response = await http.post(
        Uri.parse('$_baseUrl/webhook/configure'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'webhook_url': webhookUrl,
          'events': events,
          'secret': _generateWebhookSecret(),
        }),
      );

      log('QPayWebhookConfig: Response status: ${response.statusCode}');
      log('QPayWebhookConfig: Response body: ${response.body}');

      if (response.statusCode == 200) {
        log('QPayWebhookConfig: Webhook configured successfully');
        return true;
      } else {
        log('QPayWebhookConfig: Failed to configure webhook: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      log('QPayWebhookConfig: Error configuring webhook: $e');
      return false;
    }
  }

  /// Test webhook connection
  static Future<bool> testWebhook({
    required String accessToken,
    required String webhookUrl,
  }) async {
    try {
      log('QPayWebhookConfig: Testing webhook URL: $webhookUrl');

      final response = await http.post(
        Uri.parse('$_baseUrl/webhook/test'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'webhook_url': webhookUrl,
          'test_event': 'payment.paid',
        }),
      );

      log('QPayWebhookConfig: Test response status: ${response.statusCode}');

      return response.statusCode == 200;
    } catch (e) {
      log('QPayWebhookConfig: Error testing webhook: $e');
      return false;
    }
  }

  /// Generate a secure webhook secret
  static String _generateWebhookSecret() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final merchantId = EnvironmentConfig.qpayUsername;
    return 'avii_webhook_${merchantId}_$timestamp';
  }

  /// Get webhook configuration
  static Future<Map<String, dynamic>?> getWebhookConfig({
    required String accessToken,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/webhook/config'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      log('QPayWebhookConfig: Error getting webhook config: $e');
    }
    return null;
  }
}
