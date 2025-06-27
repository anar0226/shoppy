import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/qpay_service.dart';
import '../../../core/services/order_fulfillment_service.dart';

class QPayCheckoutPage extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final String customerEmail;
  final String customerPhone;
  final Map<String, dynamic> deliveryAddress;

  const QPayCheckoutPage({
    super.key,
    required this.orderData,
    required this.customerEmail,
    required this.customerPhone,
    required this.deliveryAddress,
  });

  @override
  State<QPayCheckoutPage> createState() => _QPayCheckoutPageState();
}

class _QPayCheckoutPageState extends State<QPayCheckoutPage> {
  final OrderFulfillmentService _fulfillmentService = OrderFulfillmentService();

  OrderFulfillmentResult? _fulfillmentResult;
  Timer? _paymentCheckTimer;
  bool _isProcessing = false;
  bool _isPaymentCompleted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializePayment();
  }

  @override
  void dispose() {
    _paymentCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializePayment() async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final result = await _fulfillmentService.processOrder(
        orderData: widget.orderData,
        customerEmail: widget.customerEmail,
        customerPhone: widget.customerPhone,
        deliveryAddress: widget.deliveryAddress,
      );

      setState(() {
        _fulfillmentResult = result;
        _isProcessing = false;
      });

      if (result.success) {
        _startPaymentMonitoring(result.orderId!);
      } else {
        setState(() {
          _error = result.error;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize payment: $e';
        _isProcessing = false;
      });
    }
  }

  void _startPaymentMonitoring(String orderId) {
    _paymentCheckTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final statusResult = await _fulfillmentService.getOrderStatus(orderId);

        if (statusResult.success) {
          final paymentStatus = statusResult.paymentStatus;

          if (paymentStatus == 'paid') {
            timer.cancel();
            setState(() {
              _isPaymentCompleted = true;
            });

            // Navigate to order tracking page after a brief delay
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                Navigator.of(context).pushReplacementNamed(
                  '/order-tracking',
                  arguments: {'orderId': orderId},
                );
              }
            });
          } else if (paymentStatus == 'failed' ||
              paymentStatus == 'cancelled') {
            timer.cancel();
            setState(() {
              _error = 'Payment failed or was cancelled';
            });
          }
        }
      } catch (e) {
        // Continue monitoring even if there's a temporary error
        debugPrint('Payment monitoring error: $e');
      }
    });
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _openQPayApp() {
    // This would open the QPay app if available
    // For now, show instructions
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open QPay App'),
        content: const Text(
          'Please open your bank\'s mobile app or QPay Wallet app and scan the QR code to complete the payment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (!_isPaymentCompleted) {
              _showCancelConfirmation();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isProcessing) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_isPaymentCompleted) {
      return _buildSuccessState();
    }

    if (_fulfillmentResult?.success == true) {
      return _buildPaymentState();
    }

    return _buildErrorState();
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Preparing your payment...',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Payment Error',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'An unexpected error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializePayment,
              child: const Text('Retry'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Payment Successful!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your order has been processed and delivery has been requested.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            const Text('Redirecting to order tracking...'),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentState() {
    final invoice = _fulfillmentResult!.paymentInvoice!;
    final amount = invoice.amount;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Order Summary Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order Summary',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _buildOrderItem('Subtotal', widget.orderData['subtotal']),
                  _buildOrderItem('Shipping', widget.orderData['shipping']),
                  _buildOrderItem('Tax', widget.orderData['tax']),
                  const Divider(),
                  _buildOrderItem('Total', amount, isTotal: true),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Payment Instructions
          Text(
            'Scan QR Code to Pay',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Open your bank\'s mobile app or QPay Wallet and scan the QR code below to complete your payment.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),

          const SizedBox(height: 24),

          // QR Code Display
          if (invoice.qrText != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: QrImageView(
                data: invoice.qrText!,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 16),

            // QR Code Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _copyToClipboard(invoice.qrText!),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy Code'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    foregroundColor: Colors.black87,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _openQPayApp,
                  icon: const Icon(Icons.mobile_friendly),
                  label: const Text('Open App'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ] else if (invoice.qrImage != null) ...[
            // Display QR image from URL
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: CachedNetworkImage(
                imageUrl: invoice.qrImage!,
                width: 200,
                height: 200,
                placeholder: (context, url) =>
                    const CircularProgressIndicator(),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Payment Status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              border: Border.all(color: Colors.orange[200]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Waiting for Payment',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      Text(
                        'Please complete the payment using your mobile banking app.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Delivery Information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delivery Information',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Once payment is confirmed, your order will be automatically sent to UBCab for delivery. You\'ll receive notifications about the delivery status.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.deliveryAddress['fullAddress'] ??
                              'Delivery address',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Cancel Button
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _showCancelConfirmation,
              child: const Text(
                'Cancel Order',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(String label, dynamic value, {bool isTotal = false}) {
    final displayValue =
        value is num ? '₮${value.toStringAsFixed(0)}' : value.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            displayValue,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text(
          'Are you sure you want to cancel this order? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Keep Order'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _cancelOrder();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelOrder() async {
    if (_fulfillmentResult?.orderId != null) {
      final success = await _fulfillmentService.cancelOrder(
        _fulfillmentResult!.orderId!,
        'Cancelled by customer',
      );

      if (success) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to cancel order. Please contact support.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      Navigator.of(context).pop();
    }
  }
}
