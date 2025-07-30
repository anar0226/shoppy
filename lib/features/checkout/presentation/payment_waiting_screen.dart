import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../../core/services/qpay_service.dart';
import '../../../core/services/payment_debug_service.dart';
import '../../../core/utils/popup_utils.dart';
import '../widgets/payment_timeout_countdown.dart';

class PaymentWaitingScreen extends StatefulWidget {
  final String orderId;
  final double amount;
  final String qpayInvoiceId;

  const PaymentWaitingScreen({
    super.key,
    required this.orderId,
    required this.amount,
    required this.qpayInvoiceId,
  });

  @override
  State<PaymentWaitingScreen> createState() => _PaymentWaitingScreenState();
}

class _PaymentWaitingScreenState extends State<PaymentWaitingScreen> {
  Timer? _paymentCheckTimer;
  final QPayService _qpayService = QPayService();
  final PaymentDebugService _debugService = PaymentDebugService();
  bool _isCheckingPayment = true;
  bool _paymentCompleted = false;

  @override
  void initState() {
    super.initState();
    _startPaymentStatusCheck();
  }

  @override
  void dispose() {
    _paymentCheckTimer?.cancel();
    super.dispose();
  }

  void _startPaymentStatusCheck() {
    // Check payment status every 5 seconds
    _paymentCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkPaymentStatus();
    });

    // Also check immediately
    _checkPaymentStatus();
  }

  Future<void> _checkPaymentStatus() async {
    if (!mounted || _paymentCompleted) return;

    try {
      // First, check if order exists in Firestore (created by webhook)
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();

      if (orderDoc.exists) {
        // Order was created by webhook - payment successful
        _handlePaymentSuccess();
        return;
      }

      // Check temporary order status
      final tempOrderDoc = await FirebaseFirestore.instance
          .collection('temporary_orders')
          .doc(widget.orderId)
          .get();

      if (tempOrderDoc.exists) {
        final tempOrderData = tempOrderDoc.data();
        final status = tempOrderData?['status'] as String?;

        if (status == 'payment_successful') {
          // Payment was successful but order creation might be delayed
          _handlePaymentSuccess(delayedProcessing: true);
          return;
        } else if (status == 'payment_failed' || status == 'timeout_expired') {
          // Payment failed or timed out
          _handlePaymentFailure(status ?? 'payment_failed');
          return;
        }
      }

      // Check QPay payment status directly
      try {
        final paymentStatus =
            await _qpayService.checkPaymentStatus(widget.qpayInvoiceId);
        final qpayStatus = paymentStatus['payment_status'] as String?;

        debugPrint(
            'QPay Payment Status: $qpayStatus for invoice: ${widget.qpayInvoiceId}');

        if (qpayStatus == 'PAID') {
          // Payment confirmed by QPay but webhook might be delayed
          // Wait a bit more for webhook to process
          await Future.delayed(const Duration(seconds: 5));

          // Check again if order was created
          final orderDocRetry = await FirebaseFirestore.instance
              .collection('orders')
              .doc(widget.orderId)
              .get();

          if (orderDocRetry.exists) {
            _handlePaymentSuccess();
          } else {
            // Payment successful but order processing delayed
            _handlePaymentSuccess(delayedProcessing: true);
          }
        } else if (qpayStatus == 'FAILED' ||
            qpayStatus == 'CANCELLED' ||
            qpayStatus == 'EXPIRED') {
          _handlePaymentFailure(qpayStatus ?? 'FAILED');
        } else if (qpayStatus == 'NEW') {
          // Payment is still pending, continue monitoring
          debugPrint('Payment still pending (NEW status)');
        } else {
          debugPrint('Unknown QPay status: $qpayStatus');
        }
        // For 'NEW' status, continue monitoring
      } catch (qpayError) {
        debugPrint('QPay status check error: $qpayError');

        // Try alternative method - check if we have a payment ID
        try {
          // Check if we can get payment info from temporary order
          final tempOrderDoc = await FirebaseFirestore.instance
              .collection('temporary_orders')
              .doc(widget.orderId)
              .get();

          if (tempOrderDoc.exists) {
            final tempOrderData = tempOrderDoc.data();
            final paymentId = tempOrderData?['paymentId'] as String?;

            if (paymentId != null) {
              debugPrint(
                  'Trying alternative payment check with payment ID: $paymentId');
              final altPaymentStatus =
                  await _qpayService.checkPaymentStatusByPaymentId(paymentId);
              final altQpayStatus =
                  altPaymentStatus['payment_status'] as String?;

              if (altQpayStatus == 'PAID') {
                _handlePaymentSuccess(delayedProcessing: true);
              }
            }
          }
        } catch (altError) {
          debugPrint('Alternative payment check also failed: $altError');
        }

        // Continue monitoring even if QPay check fails
      }
    } catch (e) {
      debugPrint('Error checking payment status: $e');
      // Continue checking - don't show error unless user explicitly closes
    }
  }

  void _handlePaymentSuccess({bool delayedProcessing = false}) {
    if (!mounted || _paymentCompleted) return;

    setState(() {
      _paymentCompleted = true;
      _isCheckingPayment = false;
    });

    _paymentCheckTimer?.cancel();

    // Show success message
    PopupUtils.showSuccess(
      context: context,
      message: delayedProcessing
          ? 'Төлбөр амжилттай хийгдлээ! Захиалга удахгүй боловсруулагдах болно.'
          : 'Төлбөр амжилттай хийгдлээ! Захиалга баталгаажлаа.',
    );

    // Navigate to orders page after a delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/orders',
          (route) => route.isFirst,
        );
      }
    });
  }

  void _handlePaymentFailure(String status) {
    if (!mounted || _paymentCompleted) return;

    setState(() {
      _paymentCompleted = true;
      _isCheckingPayment = false;
    });

    _paymentCheckTimer?.cancel();

    // Show failure message based on status
    String message;
    switch (status) {
      case 'payment_failed':
        message = 'Төлбөр амжилтгүй болсон. Дахин оролдоно уу.';
        break;
      case 'timeout_expired':
        message = 'Төлбөрийн хугацаа дууссан. Дахин оролдоно уу.';
        break;
      case 'FAILED':
        message = 'QPay дээр төлбөр амжилтгүй болсон.';
        break;
      case 'CANCELLED':
        message = 'Төлбөр цуцлагдсан.';
        break;
      case 'EXPIRED':
        message = 'QPay нэхэмжлэхийн хугацаа дууссан.';
        break;
      default:
        message = 'Төлбөр амжилтгүй болсон. Дахин оролдоно уу.';
    }

    PopupUtils.showError(
      context: context,
      message: message,
    );

    // Navigate back to checkout after a delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _closeScreen() {
    _paymentCheckTimer?.cancel();

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Төлбөрийн хүлээлтийг зогсоох'),
        content: const Text(
            'Та төлбөрийн хүлээлтийг зогсоохыг хүсэж байна уу? Хэрэв төлбөр хийгдсэн бол захиалга автоматаар баталгаажих болно.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Үргэлжлүүлэх'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/',
                (route) => false,
              );
            },
            child: const Text('Гарах'),
          ),
        ],
      ),
    );
  }

  Future<void> _debugPaymentStatus() async {
    try {
      final debugInfo = await _debugService.debugPaymentStatus(
        widget.orderId,
        widget.qpayInvoiceId,
      );

      // Show debug info in a dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Payment Debug Info'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order ID: ${widget.orderId}'),
                  Text('QPay Invoice ID: ${widget.qpayInvoiceId}'),
                  const SizedBox(height: 8),
                  Text('Order Exists: ${debugInfo['orderExists']}'),
                  Text('Temp Order Exists: ${debugInfo['tempOrderExists']}'),
                  if (debugInfo['qpayStatus'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                        'QPay Status: ${debugInfo['qpayStatus']['payment_status']}'),
                  ],
                  if (debugInfo['webhookCount'] != null) ...[
                    const SizedBox(height: 8),
                    Text('Webhook Count: ${debugInfo['webhookCount']}'),
                  ],
                  if (debugInfo['timeoutLogCount'] != null) ...[
                    Text('Timeout Log Count: ${debugInfo['timeoutLogCount']}'),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error debugging payment status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Loading indicator
              if (_isCheckingPayment) ...[
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 32),
              ],

              // Main message
              Text(
                _paymentCompleted
                    ? 'Төлбөр баталгаажлаа'
                    : 'Төлбөрийн баталгаажилтыг хүлээж байна',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Subtitle
              Text(
                _paymentCompleted
                    ? 'Захиалга амжилттай баталгаажлаа'
                    : 'QPay дээр төлбөрөө хийсний дараа энэ хуудас автоматаар шинэчлэгдэх болно',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // Order details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Захиалгын дугаар:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        Text(
                          widget.orderId,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Нийт дүн:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        Text(
                          '₮${widget.amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Payment timeout countdown
              if (!_paymentCompleted)
                PaymentTimeoutCountdown(
                  initialDuration: const Duration(minutes: 10),
                  orderId: widget.orderId,
                  onTimeout: () {
                    // Handle timeout - show message to user
                    if (mounted) {
                      PopupUtils.showError(
                        context: context,
                        message:
                            'Төлбөрийн хугацаа дууссан. Дахин оролдоно уу.',
                      );
                    }
                  },
                ),

              const SizedBox(height: 24),

              // Close button
              if (!_paymentCompleted)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _closeScreen,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.grey),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Хаах',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),

              // Debug button (only in debug mode)
              if (!_paymentCompleted && kDebugMode)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _debugPaymentStatus,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.orange.withValues(alpha: 0.1),
                      ),
                      child: const Text(
                        'Debug Payment Status',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
