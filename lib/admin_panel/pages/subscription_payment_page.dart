import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/qpay_service.dart';
import '../../core/config/environment_config.dart';
import '../../features/subscription/services/subscription_service.dart';
import '../../features/subscription/models/payment_model.dart';
import 'qpay_debug_page.dart';
import '../../features/stores/models/store_model.dart';

class SubscriptionPaymentPage extends StatefulWidget {
  final String? storeId;
  final String? userId;

  const SubscriptionPaymentPage({
    Key? key,
    this.storeId,
    this.userId,
  }) : super(key: key);

  @override
  State<SubscriptionPaymentPage> createState() =>
      _SubscriptionPaymentPageState();
}

class _SubscriptionPaymentPageState extends State<SubscriptionPaymentPage> {
  final QPayService _qpayService = QPayService();
  final SubscriptionService _subscriptionService = SubscriptionService();

  bool _loading = false;
  bool _paymentInProgress = false;
  String? _error;
  String? _successMessage;

  QPayInvoice? _qpayInvoice;
  String? _paymentUrl;
  Timer? _paymentCheckTimer;
  String? _currentStoreId;
  String? _currentUserId;

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
    setState(() => _loading = true);

    try {
      // Get current user and store ID
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Хэрэглэгч нэвтрээгүй байна');
      }

      _currentUserId = widget.userId ?? user.uid;

      // Get store ID
      if (widget.storeId != null) {
        _currentStoreId = widget.storeId;
      } else {
        _currentStoreId = await _subscriptionService.getCurrentUserStoreId();
        if (_currentStoreId == null) {
          throw Exception('Дэлгүүр олдсонгүй');
        }
      }

      // Check if subscription is already active
      final status =
          await _subscriptionService.checkSubscriptionStatus(_currentStoreId!);
      if (status == SubscriptionStatus.active) {
        setState(() {
          _successMessage = 'Таны захиалга идэвхтэй байна';
          _loading = false;
        });
        return;
      }

      // Create QPay invoice for subscription payment
      await _createSubscriptionInvoice();
    } catch (e) {
      developer.log('Subscription payment initialization error: $e',
          name: 'SubscriptionPaymentPage');
      setState(() {
        _error = 'Төлбөр эхлүүлэхэд алдаа гарлаа: $e';
        _loading = false;
      });
    }
  }

  Future<void> _createSubscriptionInvoice() async {
    try {
      // Check if QPay configuration is available
      if (!EnvironmentConfig.hasPaymentConfig) {
        throw Exception(
            'QPay мэдээлэл тохируулагдаагүй байна. Админтай холбогдоно уу.');
      }

      final orderId =
          'SUBSCRIPTION_${_currentStoreId}_${DateTime.now().millisecondsSinceEpoch}';

      developer.log(
          'Creating QPay invoice with config: ${EnvironmentConfig.getConfigSummary()}',
          name: 'SubscriptionPaymentPage');

      final result = await _qpayService.createInvoice(
        orderId: orderId,
        amount: SubscriptionService.monthlyFee,
        description: 'Сарын төлбөр - Shoppy дэлгүүр',
        customerEmail: FirebaseAuth.instance.currentUser?.email ?? '',
        metadata: {
          'type': 'subscription',
          'storeId': _currentStoreId,
          'userId': _currentUserId,
        },
        customTimeout:
            const Duration(minutes: 15), // 15 minutes for subscription payment
      );

      if (result.success && result.invoice != null) {
        final invoice = result.invoice!;

        developer.log(
            'QPay invoice created successfully: ${invoice.qpayInvoiceId}',
            name: 'SubscriptionPaymentPage');

        // Store pending payment record
        await FirebaseFirestore.instance.collection('payments').add({
          'orderId': orderId,
          'storeId': _currentStoreId,
          'userId': _currentUserId,
          'amount': SubscriptionService.monthlyFee,
          'currency': 'MNT',
          'status': 'pending',
          'paymentMethod': 'qpay',
          'transactionId': orderId,
          'qpayInvoiceId': invoice.qpayInvoiceId,
          'createdAt': FieldValue.serverTimestamp(),
          'description': 'Сарын төлбөр - Shoppy дэлгүүр',
          'metadata': {
            'type': 'subscription',
            'webhookProcessed': false,
          },
        });

        // Get the best payment URL
        String paymentUrl = invoice.bestPaymentUrl;
        if (paymentUrl.isEmpty && invoice.qrCode.isNotEmpty) {
          final encodedQR = Uri.encodeComponent(invoice.qrCode);
          paymentUrl = 'https://qpay.mn/q/?q=$encodedQR';
        }

        if (paymentUrl.isNotEmpty) {
          setState(() {
            _qpayInvoice = invoice;
            _paymentUrl = paymentUrl;
            _loading = false;
          });

          // Start payment status monitoring
          _startPaymentStatusMonitoring(orderId);
        } else {
          throw Exception('QPay төлбөрийн холбоос олдсонгүй');
        }
      } else {
        final errorMessage =
            result.error ?? 'QPay нэхэмжлэх үүсгэхэд алдаа гарлаа';
        developer.log('QPay invoice creation failed: $errorMessage',
            name: 'SubscriptionPaymentPage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      developer.log('Subscription invoice creation error: $e',
          name: 'SubscriptionPaymentPage');
      setState(() {
        _error = 'Төлбөр эхлүүлэхэд алдаа гарлаа: $e';
        _loading = false;
      });
    }
  }

  void _startPaymentStatusMonitoring(String orderId) {
    if (_qpayInvoice == null) return;

    _paymentCheckTimer =
        Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final status =
            await _qpayService.checkPaymentStatus(_qpayInvoice!.qpayInvoiceId);

        if (status.success && status.isPaid) {
          // Payment successful
          await _processSuccessfulPayment(status, orderId);
          timer.cancel();
        } else if (status.success && (status.isExpired || status.isCanceled)) {
          // Payment expired or canceled
          setState(() {
            _error = 'Төлбөр цуцлагдсан эсвэл хугацаа дууссан';
            _paymentInProgress = false;
          });
          timer.cancel();
        }
      } catch (e) {
        developer.log('Payment status check error: $e',
            name: 'SubscriptionPaymentPage');
      }
    });
  }

  Future<void> _processSuccessfulPayment(
      QPayPaymentStatus status, String orderId) async {
    try {
      // Get the payment record from Firestore
      final paymentDoc = await FirebaseFirestore.instance
          .collection('payments')
          .where('orderId', isEqualTo: orderId)
          .limit(1)
          .get();
      if (paymentDoc.docs.isNotEmpty) {
        final payment = PaymentModel.fromFirestore(paymentDoc.docs.first);

        // Update payment with success status
        final successfulPayment = payment.copyWith(
          status: PaymentStatus.completed,
          processedAt: DateTime.now(),
        );

        // Update Firestore payment record
        await paymentDoc.docs.first.reference.update({
          'status': 'completed',
          'processedAt': FieldValue.serverTimestamp(),
          'transactionId': status.paymentId,
          'paidAmount': status.paidAmount,
          'metadata': {
            ...(payment.metadata ?? {}),
            'webhookProcessed': true,
          },
        });

        // Process payment in subscription service
        await _subscriptionService.processPayment(successfulPayment);

        setState(() {
          _successMessage =
              'Төлбөр амжилттай төлөгдлөө! Таны захиалга идэвхжлээ.';
          _paymentInProgress = false;
        });

        // Navigate to store setup after a short delay
        Timer(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/admin/store-setup');
          }
        });
      } else {
        developer.log('Payment record not found for orderId: $orderId',
            name: 'SubscriptionPaymentPage');
        setState(() {
          _error = 'Төлбөр боловсруулахад алдаа гарлаа: Төлбөр түүх олдсонгүй.';
          _paymentInProgress = false;
        });
      }
    } catch (e) {
      developer.log('Payment processing error: $e',
          name: 'SubscriptionPaymentPage');
      setState(() {
        _error = 'Төлбөр боловсруулахад алдаа гарлаа: $e';
        _paymentInProgress = false;
      });
    }
  }

  Future<void> _retryPayment() async {
    setState(() {
      _error = null;
      _successMessage = null;
      _qpayInvoice = null;
      _paymentUrl = null;
    });
    await _createSubscriptionInvoice();
  }

  Future<void> _cancelPayment() async {
    if (_qpayInvoice != null) {
      try {
        await _qpayService.cancelPayment(_qpayInvoice!.qpayInvoiceId);
      } catch (e) {
        developer.log('Cancel payment error: $e',
            name: 'SubscriptionPaymentPage');
      }
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Сарын төлбөр'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (_paymentInProgress)
            TextButton(
              onPressed: _cancelPayment,
              child: const Text('Цуцлах'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _successMessage != null
              ? _buildSuccessView()
              : _error != null
                  ? _buildErrorView()
                  : _qpayInvoice != null
                      ? _buildPaymentView()
                      : const Center(
                          child: Text('Төлбөр эхлүүлэхэд алдаа гарлаа')),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 80,
            ),
            const SizedBox(height: 24),
            Text(
              _successMessage!,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Дэлгүүрийн тохиргоо руу шилжиж байна...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 80,
            ),
            const SizedBox(height: 24),
            Text(
              _error!,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _retryPayment,
                  child: const Text('Дахин оролдох'),
                ),
                TextButton(
                  onPressed: _cancelPayment,
                  child: const Text('Цуцлах'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const QPayDebugPage(),
                      ),
                    );
                  },
                  child: const Text('Debug'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDebugInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          const Text(
            'Сарын төлбөр',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Shoppy дэлгүүрийн сарын төлбөр',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Amount Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'Төлөх дүн',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${SubscriptionService.monthlyFee.toStringAsFixed(0)} ₮',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Сарын төлбөр',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Payment Methods
          const Text(
            'Төлбөрийн арга',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // QPay Option
          Card(
            child: ListTile(
              leading: Image.asset(
                'assets/images/logos/QPAY.png',
                width: 40,
                height: 40,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.payment, size: 40);
                },
              ),
              title: const Text('QPay'),
              subtitle: const Text('QPay апп эсвэл веб'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _openQPayPayment,
            ),
          ),
          const SizedBox(height: 24),

          // Payment Instructions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Төлбөрийн заавар:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• QPay дээр дарж төлбөр хийх',
                    style: TextStyle(fontSize: 14),
                  ),
                  const Text(
                    '• Төлбөр амжилттай болмогц автоматаар шилжинэ',
                    style: TextStyle(fontSize: 14),
                  ),
                  const Text(
                    '• Төлбөр 15 минутын дараа автоматаар цуцлагдана',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Payment Status
          if (_paymentInProgress) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              'Төлбөр хүлээгдэж буй...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.orange,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Хугацаа: ${_qpayInvoice?.remainingTime.inMinutes ?? 0} мин',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  void _openQPayPayment() {
    if (_qpayInvoice == null) return;

    final paymentUrl = _paymentUrl ?? _qpayInvoice!.bestPaymentUrl;
    if (paymentUrl.isNotEmpty) {
      // Open QPay payment URL
      // You can use url_launcher package here
      // For now, we'll just show a dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('QPay төлбөр'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('QPay төлбөр нээх үү?'),
              const SizedBox(height: 16),
              if (_qpayInvoice!.qrCode.isNotEmpty)
                Image.network(
                  _qpayInvoice!.qrImage,
                  width: 200,
                  height: 200,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.qr_code, size: 200);
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Цуцлах'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Here you would launch the URL
                // launchUrl(Uri.parse(paymentUrl));
              },
              child: const Text('Нээх'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildDebugInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Debug Information:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Has QPay Config: ${EnvironmentConfig.hasPaymentConfig}'),
          Text('QPay Base URL: ${EnvironmentConfig.qpayBaseUrl}'),
          Text(
              'QPay Username Length: ${EnvironmentConfig.qpayUsername.length}'),
          Text(
              'QPay Password Length: ${EnvironmentConfig.qpayPassword.length}'),
          Text(
              'QPay Invoice Code Length: ${EnvironmentConfig.qpayInvoiceCode.length}'),
        ],
      ),
    );
  }
}
