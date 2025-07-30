import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/config/environment_config.dart';
import '../../core/services/qpay_service.dart';
import '../../core/utils/order_id_generator.dart';

class QPayDebugPage extends StatefulWidget {
  const QPayDebugPage({super.key});

  @override
  State<QPayDebugPage> createState() => _QPayDebugPageState();
}

class _QPayDebugPageState extends State<QPayDebugPage> {
  final QPayService _qpayService = QPayService();
  Map<String, dynamic>? _diagnostics;
  bool _loading = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _loading = true;
      _testResult = null;
    });

    final config = EnvironmentConfig.getConfigSummary();

    // Test QPay configuration
    String qpayStatus = 'Unknown';
    String qpayDetails = '';

    try {
      if (!EnvironmentConfig.hasPaymentConfig) {
        qpayStatus = 'Configuration Missing';
        qpayDetails = 'QPay credentials are not properly configured';
      } else {
        // Test QPay connection
        final testResult = await _qpayService.createInvoice(
          orderId: OrderIdGenerator.generateTest(),
          amount: 100.0,
          description: 'Test invoice for configuration validation',
          customerCode: 'test@example.com',
        );

        if (testResult['qPayInvoiceId'] != null) {
          qpayStatus = 'Working';
          qpayDetails = 'QPay API is accessible and working correctly';
        } else {
          qpayStatus = 'Error';
          qpayDetails = testResult['error'] ?? 'Unknown error occurred';
        }
      }
    } catch (e) {
      qpayStatus = 'Error';
      qpayDetails = e.toString();
    }

    setState(() {
      _diagnostics = {
        ...config,
        'qpayStatus': qpayStatus,
        'qpayDetails': qpayDetails,
        'qpayBaseUrl': EnvironmentConfig.qpayBaseUrl,
        'qpayUsernameLength': EnvironmentConfig.qpayUsername.length,
        'qpayPasswordLength': EnvironmentConfig.qpayPassword.length,
        'qpayInvoiceCodeLength': EnvironmentConfig.qpayInvoiceCode.length,
      };
      _loading = false;
    });
  }

  Future<void> _testQPayConnection() async {
    setState(() {
      _loading = true;
      _testResult = null;
    });

    try {
      final result = await _qpayService.createInvoice(
        orderId: OrderIdGenerator.generateTest(),
        amount: 100.0,
        description: 'Test connection to QPay API',
        customerCode: 'test@shoppy.mn',
      );

      setState(() {
        if (result['qPayInvoiceId'] != null) {
          _testResult = 'SUCCESS: QPay connection working!\n'
              'Invoice ID: ${result['qPayInvoiceId']}\n'
              'Payment URL: ${result['urls']?['payment'] ?? 'N/A'}';
        } else {
          _testResult = 'ERROR: ${result['error'] ?? 'Unknown error'}';
        }
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _testResult = 'EXCEPTION: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('QPay Debug'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildConfigurationSection(),
            const SizedBox(height: 24),
            _buildTestSection(),
            const SizedBox(height: 24),
            _buildActionsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'QPay Configuration Diagnostics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This page helps diagnose QPay configuration issues.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  _diagnostics?['qpayStatus'] == 'Working'
                      ? Icons.check_circle
                      : Icons.error,
                  color: _diagnostics?['qpayStatus'] == 'Working'
                      ? Colors.green
                      : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  'Status: ${_diagnostics?['qpayStatus'] ?? 'Loading...'}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _diagnostics?['qpayStatus'] == 'Working'
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configuration Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_diagnostics != null) ...[
              _buildConfigItem('Environment',
                  _diagnostics!['isProduction'] ? 'Production' : 'Development'),
              _buildConfigItem(
                  'QPay Base URL', _diagnostics!['qpayBaseUrl'] ?? 'Not set'),
              _buildConfigItem('QPay Username Length',
                  '${_diagnostics!['qpayUsernameLength']} characters'),
              _buildConfigItem('QPay Password Length',
                  '${_diagnostics!['qpayPasswordLength']} characters'),
              _buildConfigItem('QPay Invoice Code Length',
                  '${_diagnostics!['qpayInvoiceCodeLength']} characters'),
              _buildConfigItem('Has Payment Config',
                  _diagnostics!['hasPaymentConfig'] ? 'Yes' : 'No'),
              const Divider(),
              Text(
                'Details: ${_diagnostics!['qpayDetails']}',
                style: const TextStyle(fontSize: 14),
              ),
            ] else
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Connection Test',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_testResult != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _testResult!.startsWith('SUCCESS')
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  border: Border.all(
                    color: _testResult!.startsWith('SUCCESS')
                        ? Colors.green.shade200
                        : Colors.red.shade200,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _testResult!,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: _testResult!.startsWith('SUCCESS')
                        ? Colors.green.shade800
                        : Colors.red.shade800,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            ElevatedButton.icon(
              onPressed: _loading ? null : _testQPayConnection,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.network_check),
              label: Text(_loading ? 'Testing...' : 'Test QPay Connection'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _runDiagnostics,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Diagnostics'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_diagnostics != null) {
                        Clipboard.setData(ClipboardData(
                          text: _diagnostics.toString(),
                        ));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Diagnostics copied to clipboard'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
