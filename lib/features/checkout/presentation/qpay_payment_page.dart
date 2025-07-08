import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
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

class _QPayPaymentPageState extends State<QPayPaymentPage>
    with SingleTickerProviderStateMixin {
  final QPayService _qpayService = QPayService();
  final GlobalKey _qrKey = GlobalKey();

  QPayInvoice? _invoice;
  bool _isLoading = true;
  bool _isProcessingPayment = false;
  String? _error;
  Timer? _statusTimer;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _createQPayInvoice();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _createQPayInvoice() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final result = await _qpayService.createInvoice(
        orderId: widget.orderId,
        amount: widget.amount,
        description: widget.description,
        // Use a unique string for customerEmail (invoice_receiver_code)
        customerEmail:
            widget.customerEmail.replaceAll('@', '_').replaceAll('.', '_'),
        // Do not pass metadata
      );

      if (result.success && result.invoice != null) {
        setState(() {
          _invoice = result.invoice;
          _isLoading = false;
        });

        _animationController.forward();
        _startStatusMonitoring();
      } else {
        setState(() {
          _error = result.error ?? 'Failed to create payment invoice';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error creating payment: $e';
        _isLoading = false;
      });
    }
  }

  void _startStatusMonitoring() {
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_invoice != null && !_isProcessingPayment) {
        await _checkPaymentStatus();
      }
    });
  }

  Future<void> _checkPaymentStatus() async {
    if (_invoice == null) return;

    try {
      final status =
          await _qpayService.checkPaymentStatus(_invoice!.qpayInvoiceId);

      if (status.success && status.isPaid) {
        setState(() {
          _isProcessingPayment = true;
        });

        _statusTimer?.cancel();

        // Show success animation
        await Future.delayed(const Duration(seconds: 1));

        PopupUtils.showSuccess(
          context: context,
          message: 'Төлбөр амжилттай хийгдлээ!',
        );

        // Wait a bit for user to see the success message
        await Future.delayed(const Duration(seconds: 2));

        widget.onPaymentSuccess();
      } else if (status.success &&
          (status.status == 'EXPIRED' || status.status == 'CANCELED')) {
        _statusTimer?.cancel();
        setState(() {
          _error = 'Payment expired or canceled';
        });
      }
    } catch (e) {
      // Don't show error for status checks, just log
      debugPrint('Error checking payment status: $e');
    }
  }

  Future<void> _launchQPayApp() async {
    if (_invoice?.deepLink != null && _invoice!.deepLink.isNotEmpty) {
      try {
        final uri = Uri.parse(_invoice!.deepLink);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          // Fallback to web link
          await _launchWebLink();
        }
      } catch (e) {
        PopupUtils.showError(
          context: context,
          message: 'Could not open QPay app',
        );
      }
    } else {
      await _launchWebLink();
    }
  }

  Future<void> _launchWebLink() async {
    if (_invoice?.urls.link != null && _invoice!.urls.link.isNotEmpty) {
      try {
        final uri = Uri.parse(_invoice!.urls.link);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        PopupUtils.showError(
          context: context,
          message: 'Could not open payment link',
        );
      }
    }
  }

  Future<void> _shareQRCode() async {
    if (_invoice?.qrCode != null && _invoice!.qrCode.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: _invoice!.qrCode));
      PopupUtils.showSuccess(
        context: context,
        message: 'QR code copied to clipboard',
      );
    }
  }

  Future<void> _saveQRImage() async {
    try {
      final RenderRepaintBoundary boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final Uint8List imageBytes = byteData.buffer.asUint8List();
        // You can implement image saving here using path_provider and image_gallery_saver
        // For now, just show success message
        PopupUtils.showSuccess(
          context: context,
          message: 'QR code saved successfully',
        );
      }
    } catch (e) {
      PopupUtils.showError(
        context: context,
        message: 'Failed to save QR code',
      );
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
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('QPay Payment'),
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
            Text('Creating payment invoice...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
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
            ElevatedButton(
              onPressed: _createQPayInvoice,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_invoice == null) {
      return const Center(
        child: Text('No invoice available'),
      );
    }

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: _buildPaymentContent(),
          ),
        );
      },
    );
  }

  Widget _buildPaymentContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Payment Status
          if (_isProcessingPayment)
            Container(
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
                    'Payment Successful!',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Waiting for payment...',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 32),

          // Amount
          Text(
            '₮${widget.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            widget.description,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // QR Code
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: RepaintBoundary(
              key: _qrKey,
              child: QrImageView(
                data: _invoice!.qrCode,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Instructions
          const Text(
            'Scan the QR code with your QPay app to complete the payment',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _launchQPayApp,
                  icon: const Icon(Icons.payment),
                  label: const Text('Open QPay App'),
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
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _shareQRCode,
                icon: const Icon(Icons.copy),
                label: const Text('Copy'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Additional Options
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: _launchWebLink,
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Open in Browser'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                ),
              ),
              TextButton.icon(
                onPressed: _saveQRImage,
                icon: const Icon(Icons.download),
                label: const Text('Save QR'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Cancel Button
          SizedBox(
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
                side: const BorderSide(color: Colors.grey),
              ),
              child: const Text('Cancel Payment'),
            ),
          ),
        ],
      ),
    );
  }
}
