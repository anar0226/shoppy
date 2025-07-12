import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../../../core/services/qpay_service.dart';
import '../../../core/utils/popup_utils.dart';
import '../../../features/home/presentation/main_scaffold.dart';

class QPayPaymentPage extends StatefulWidget {
  final String orderId;
  final double amount;
  final String description;
  final String customerEmail;
  final VoidCallback onPaymentSuccess;
  final VoidCallback onPaymentCancel;

  const QPayPaymentPage({
    super.key,
    required this.orderId,
    required this.amount,
    required this.description,
    required this.customerEmail,
    required this.onPaymentSuccess,
    required this.onPaymentCancel,
  });

  @override
  State<QPayPaymentPage> createState() => _QPayPaymentPageState();
}

class _QPayPaymentPageState extends State<QPayPaymentPage> {
  final QPayService _qpayService = QPayService();

  QPayInvoice? _invoice;
  List<PaymentMethod> _paymentMethods = [];
  bool _isLoading = true;
  bool _isProcessingPayment = false;
  bool _showQRCode = false;
  String? _error;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _createQPayInvoice();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _createQPayInvoice() async {
    try {
      if (!mounted) return;

      setState(() {
        _isLoading = true;
        _error = null;
      });

      debugPrint('Creating QPay invoice for order: ${widget.orderId}');

      final result = await _qpayService.createInvoice(
        orderId: widget.orderId,
        amount: widget.amount,
        description: widget.description,
        customerEmail: widget.customerEmail,
      );

      if (!mounted) return;

      if (result.success && result.invoice != null) {
        setState(() {
          _invoice = result.invoice;
          _paymentMethods = _parsePaymentMethods(result.invoice!);
          _isLoading = false;
        });
        _startStatusMonitoring();
      } else {
        setState(() {
          _error = result.error ?? 'Failed to create payment invoice';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error creating QPay invoice: $e');
      if (mounted) {
        setState(() {
          _error = 'Error creating payment: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<PaymentMethod> _parsePaymentMethods(QPayInvoice invoice) {
    final List<PaymentMethod> methods = [];

    // Parse URLs from invoice response
    if (invoice.urls.app.isNotEmpty) {
      try {
        // The URLs are typically in a structured format
        // For now, we'll create some common payment methods based on what QPay typically provides
        methods.addAll([
          PaymentMethod(
            name: 'QPay Wallet',
            description: 'QPay хэтэвч',
            logo: 'https://qpay.mn/q/logo/qpay.png',
            deepLink: 'qpaywallet://q?qPay_QRcode=${invoice.qrCode}',
            color: const Color(0xFF1976D2),
          ),
          PaymentMethod(
            name: 'Khan Bank',
            description: 'Хаан банк',
            logo: 'https://qpay.mn/q/logo/khanbank.png',
            deepLink: 'khanbank://q?qPay_QRcode=${invoice.qrCode}',
            color: const Color(0xFF2E7D32),
          ),
          PaymentMethod(
            name: 'TDB Online',
            description: 'Худалдаа хөгжлийн банк',
            logo: 'https://qpay.mn/q/logo/tdbbank.png',
            deepLink: 'tdbbank://q?qPay_QRcode=${invoice.qrCode}',
            color: const Color(0xFF1565C0),
          ),
          PaymentMethod(
            name: 'Social Pay',
            description: 'Голомт банк',
            logo: 'https://qpay.mn/q/logo/socialpay.png',
            deepLink: 'socialpay-payment://q?qPay_QRcode=${invoice.qrCode}',
            color: const Color(0xFF00ACC1),
          ),
          PaymentMethod(
            name: 'State Bank 3.0',
            description: 'Төрийн банк 3.0',
            logo: 'https://qpay.mn/q/logo/state_3.png',
            deepLink: 'statebankmongolia://q?qPay_QRcode=${invoice.qrCode}',
            color: const Color(0xFF3F51B5),
          ),
          PaymentMethod(
            name: 'Xac Bank',
            description: 'Хас банк',
            logo: 'https://qpay.mn/q/logo/xacbank.png',
            deepLink: 'xacbank://q?qPay_QRcode=${invoice.qrCode}',
            color: const Color(0xFFFF5722),
          ),
          PaymentMethod(
            name: 'Capitron Bank',
            description: 'Капитрон банк',
            logo: 'https://qpay.mn/q/logo/capitronbank.png',
            deepLink: 'capitronbank://q?qPay_QRcode=${invoice.qrCode}',
            color: const Color(0xFF673AB7),
          ),
          PaymentMethod(
            name: 'Bogd Bank',
            description: 'Богд банк',
            logo: 'https://qpay.mn/q/logo/bogdbank.png',
            deepLink: 'bogdbank://q?qPay_QRcode=${invoice.qrCode}',
            color: const Color(0xFF4CAF50),
          ),
          PaymentMethod(
            name: 'NIBank',
            description: 'Үндэсний хөрөнгө оруулалтын банк',
            logo: 'https://qpay.mn/q/logo/nibank.jpeg',
            deepLink: 'nibank://q?qPay_QRcode=${invoice.qrCode}',
            color: const Color(0xFF8D6E63),
          ),
          PaymentMethod(
            name: 'Most Money',
            description: 'МОСТ мони',
            logo: 'https://qpay.mn/q/logo/most.png',
            deepLink: 'most://q?qPay_QRcode=${invoice.qrCode}',
            color: const Color(0xFF4CAF50),
          ),
          PaymentMethod(
            name: 'Trans Bank',
            description: 'Тээвэр хөгжлийн банк',
            logo: 'https://qpay.mn/q/logo/transbank.png',
            deepLink: 'transbank://q?qPay_QRcode=${invoice.qrCode}',
            color: const Color(0xFF795548),
          ),
          PaymentMethod(
            name: 'M Bank',
            description: 'М банк',
            logo: 'https://qpay.mn/q/logo/mbank.png',
            deepLink: 'mbank://q?qPay_QRcode=${invoice.qrCode}',
            color: const Color(0xFF009688),
          ),
          PaymentMethod(
            name: 'Chinggis Khaan',
            description: 'Чингис Хаан банк',
            logo: 'https://qpay.mn/q/logo/ckbank.png',
            deepLink: 'ckbank://q?qPay_QRcode=${invoice.qrCode}',
            color: const Color(0xFF7B1FA2),
          ),
          PaymentMethod(
            name: 'Monpay',
            description: 'Мон Пэй',
            logo: 'https://qpay.mn/q/logo/monpay.png',
            deepLink: 'Monpay://q?qPay_QRcode=${invoice.qrCode}',
            color: const Color(0xFF212121),
          ),
          PaymentMethod(
            name: 'Toki',
            description: 'Toki App',
            logo: 'https://qpay.mn/q/logo/toki.png',
            deepLink: 'toki://q?qPay_QRcode=${invoice.qrCode}',
            color: const Color(0xFFFFC107),
          ),
          PaymentMethod(
            name: 'Ard App',
            description: 'Ард Апп',
            logo: 'https://qpay.mn/q/logo/ardapp.png',
            deepLink: 'ard://q?qPay_QRcode=${invoice.qrCode}',
            color: const Color(0xFFE53935),
          ),
        ]);
      } catch (e) {
        debugPrint('Error parsing payment methods: $e');
      }
    }

    return methods;
  }

  void _startStatusMonitoring() {
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_invoice != null && !_isProcessingPayment && mounted) {
        await _checkPaymentStatus();
      }
    });
  }

  Future<void> _checkPaymentStatus() async {
    if (_invoice == null || !mounted) return;

    try {
      final status =
          await _qpayService.checkPaymentStatus(_invoice!.qpayInvoiceId);

      if (status.success && status.status == 'PAID' && mounted) {
        setState(() {
          _isProcessingPayment = true;
        });

        _statusTimer?.cancel();

        PopupUtils.showSuccess(
          context: context,
          message: 'Төлбөр амжилттай хийгдлээ!',
        );

        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          widget.onPaymentSuccess();
        }
      } else if (status.success &&
          (status.status == 'EXPIRED' || status.status == 'CANCELED') &&
          mounted) {
        _statusTimer?.cancel();
        setState(() {
          _error = 'Төлбөр дууссан эсвэл цуцалсан';
        });
      }
    } catch (e) {
      debugPrint('Error checking payment status: $e');
    }
  }

  Future<void> _launchPaymentMethod(PaymentMethod method) async {
    try {
      debugPrint('Launching payment method: ${method.name}');
      debugPrint('Deep link: ${method.deepLink}');

      final launched = await launchUrl(
        Uri.parse(method.deepLink),
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        // Fallback to web browser if app is not installed
        if (_invoice!.bestPaymentUrl != 'https://qpay.mn') {
          final webLaunched = await launchUrl(
            Uri.parse(_invoice!.bestPaymentUrl),
            mode: LaunchMode.externalApplication,
          );

          if (!webLaunched && mounted) {
            PopupUtils.showError(
              context: context,
              message: '${method.name} аппыг нээх боломжгүй байна',
            );
          }
        } else {
          PopupUtils.showError(
            context: context,
            message: '${method.name} аппыг нээх боломжгүй байна',
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching payment method: $e');
      if (mounted) {
        PopupUtils.showError(
          context: context,
          message: '${method.name} аппыг нээх үед алдаа гарлаа',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      currentIndex: 0,
      showBackButton: true,
      onBack: () {
        _statusTimer?.cancel();
        widget.onPaymentCancel();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: const Text('QPay төлбөр'),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              _statusTimer?.cancel();
              widget.onPaymentCancel();
            },
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Төлбөрийн нэхэмжлэх үүсгэж байна...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _createQPayInvoice,
                icon: const Icon(Icons.refresh),
                label: const Text('Дахин оролдох'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_invoice == null) {
      return const Center(
        child: Text('Төлбөрийн мэдээлэл олдсонгүй'),
      );
    }

    return _buildPaymentGateway();
  }

  Widget _buildPaymentGateway() {
    return Column(
      children: [
        // Header with QPay logo and amount
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // QPay Logo
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.payment,
                  size: 48,
                  color: Color(0xFF1976D2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Most accepted',
                style: TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
              const Text(
                'payment gateway',
                style: TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '₮${widget.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.description,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        // Payment Status
        if (_isProcessingPayment)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Төлбөр амжилттай хийгдлээ!',
                  style: TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

        // Payment Methods Grid
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // QR Code Toggle Button
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _showQRCode = !_showQRCode;
                      });
                    },
                    icon: Icon(_showQRCode ? Icons.grid_view : Icons.qr_code),
                    label: Text(
                        _showQRCode ? 'Банк/Аппуудыг харах' : 'QR код харах'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                // QR Code or Payment Methods
                if (_showQRCode)
                  _buildQRCodeSection()
                else
                  _buildPaymentMethodsGrid(),
              ],
            ),
          ),
        ),

        // Cancel Button
        Container(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                _statusTimer?.cancel();
                widget.onPaymentCancel();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Төлбөрийг цуцлах'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQRCodeSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_invoice!.qrCode.isNotEmpty)
            QrImageView(
              data: _invoice!.qrCode,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            )
          else
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('QR код үүсэж байна...'),
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            'QPay аппаар QR кодыг скан хийж төлбөрөө хийнэ үү',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              if (_invoice!.qrCode.isNotEmpty) {
                await Clipboard.setData(ClipboardData(text: _invoice!.qrCode));
                PopupUtils.showSuccess(
                  context: context,
                  message: 'QR кодыг хуулбарт хуулгалаа',
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('QR код хуулах'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade200,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: _paymentMethods.length,
      itemBuilder: (context, index) {
        final method = _paymentMethods[index];
        return _buildPaymentMethodCard(method);
      },
    );
  }

  Widget _buildPaymentMethodCard(PaymentMethod method) {
    return GestureDetector(
      onTap: () => _launchPaymentMethod(method),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: method.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getIconForPaymentMethod(method.name),
                color: method.color,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              method.name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForPaymentMethod(String name) {
    switch (name.toLowerCase()) {
      case 'qpay wallet':
        return Icons.account_balance_wallet;
      case 'khan bank':
        return Icons.account_balance;
      case 'tdb online':
        return Icons.sync;
      case 'social pay':
        return Icons.chat_bubble;
      case 'state bank 3.0':
        return Icons.account_balance;
      case 'xac bank':
        return Icons.close;
      case 'capitron bank':
        return Icons.trending_up;
      case 'bogd bank':
        return Icons.landscape;
      case 'nibank':
        return Icons.account_balance;
      case 'most money':
        return Icons.account_balance_wallet;
      case 'trans bank':
        return Icons.local_shipping;
      case 'm bank':
        return Icons.text_fields;
      case 'chinggis khaan':
        return Icons.circle;
      case 'monpay':
        return Icons.payments;
      case 'toki':
        return Icons.circle;
      case 'ard app':
        return Icons.apps;
      default:
        return Icons.payment;
    }
  }
}

class PaymentMethod {
  final String name;
  final String description;
  final String logo;
  final String deepLink;
  final Color color;

  PaymentMethod({
    required this.name,
    required this.description,
    required this.logo,
    required this.deepLink,
    required this.color,
  });
}
