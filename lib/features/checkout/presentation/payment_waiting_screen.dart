import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../../core/services/qpay_service.dart';
import '../../../core/utils/popup_utils.dart';
import '../../../features/home/presentation/main_scaffold.dart';

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
      // Check if order exists in Firestore (created by webhook)
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();

      if (orderDoc.exists) {
        // Order was created by webhook - payment successful
        _handlePaymentSuccess();
        return;
      }

      // Also check QPay payment status as backup
      final paymentStatus =
          await _qpayService.checkPaymentStatus(widget.qpayInvoiceId);

      if (paymentStatus.success && paymentStatus.isPaid) {
        // Payment confirmed by QPay but order might not be created yet
        // Wait a bit more for webhook to process
        await Future.delayed(const Duration(seconds: 3));

        // Check again if order was created
        final orderDocRetry = await FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .get();

        if (orderDocRetry.exists) {
          _handlePaymentSuccess();
        } else {
          // Webhook might have failed, but payment was successful
          // Show success but note that order processing might be delayed
          _handlePaymentSuccess(delayedProcessing: true);
        }
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

  void _handlePaymentFailure() {
    if (!mounted || _paymentCompleted) return;

    setState(() {
      _paymentCompleted = true;
      _isCheckingPayment = false;
    });

    _paymentCheckTimer?.cancel();

    PopupUtils.showError(
      context: context,
      message: 'Төлбөр амжилтгүй боллоо. Дахин оролдоно уу.',
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

              const SizedBox(height: 48),

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
            ],
          ),
        ),
      ),
    );
  }
}
