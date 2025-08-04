import 'package:flutter/material.dart';
import 'package:avii/features/home/presentation/main_scaffold.dart';
import 'package:avii/features/checkout/models/checkout_item.dart';
import 'package:avii/features/addresses/presentation/manage_addresses_page.dart';
import 'package:provider/provider.dart';
import 'package:avii/features/addresses/providers/address_provider.dart';
import 'package:avii/features/discounts/models/discount_model.dart';
import 'package:avii/features/discounts/services/discount_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/utils/order_id_generator.dart';

import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/popup_utils.dart';
import '../../../core/services/qpay_service.dart';
import '../../../core/services/error_handler_service.dart';
import '../../../core/services/payment_timeout_service.dart';
import 'payment_waiting_screen.dart';

class CheckoutPage extends StatefulWidget {
  final String email;
  final String fullAddress;
  final double subtotal;
  final double shippingCost;
  final double tax;
  final List<CheckoutItem> items; // Changed from single item to list

  const CheckoutPage({
    super.key,
    required this.email,
    required this.fullAddress,
    required this.subtotal,
    required this.shippingCost,
    required this.tax,
    required this.items, // Changed from item to items
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _discountCodeController = TextEditingController();
  final _discountService = DiscountService();
  final _qpayService = QPayService();
  final _timeoutService = PaymentTimeoutService();

  DiscountModel? _appliedDiscount;
  bool _isApplyingDiscount = false;
  String? _discountError;
  bool _isProcessingOrder = false;
  // QPay is the only payment method

  // Calculate subtotal for a specific store
  double _subtotalForStore(String storeId) {
    double sum = 0.0;
    for (final item in widget.items) {
      if (item.storeId == storeId) {
        sum += item.price;
      }
    }
    return sum;
  }

  double get _discountAmount {
    if (_appliedDiscount == null) return 0.0;

    final storeSubtotal = _subtotalForStore(_appliedDiscount!.storeId);

    switch (_appliedDiscount!.type) {
      case DiscountType.percentage:
        return storeSubtotal * (_appliedDiscount!.value / 100);
      case DiscountType.fixedAmount:
        return _appliedDiscount!.value.clamp(0, storeSubtotal);
      case DiscountType.freeShipping:
        return widget.shippingCost;
    }
  }

  double get _finalTotal {
    return (widget.subtotal - _discountAmount) +
        (_appliedDiscount?.type == DiscountType.freeShipping
            ? 0
            : widget.shippingCost);
  }

  @override
  void dispose() {
    _discountCodeController.dispose();
    _timeoutService.dispose();
    super.dispose();
  }

  Future<void> _applyDiscountCode() async {
    final code = _discountCodeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _isApplyingDiscount = true;
      _discountError = null;
    });

    try {
      // Collect unique store IDs present in the cart
      final uniqueStoreIds =
          widget.items.map((item) => item.storeId).whereType<String>().toSet();

      // Find the discount by code
      final discountQuery = await FirebaseFirestore.instance
          .collection('discounts')
          .where('code', isEqualTo: code)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (discountQuery.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _discountError = 'Буруу хөнгөлөлтийн код';
          });
        }
        return;
      }

      final discountDoc = discountQuery.docs.first;
      final discount = DiscountModel.fromFirestore(discountDoc);

      // Check if discount belongs to one of the stores in the cart
      if (uniqueStoreIds.isNotEmpty &&
          !uniqueStoreIds.contains(discount.storeId)) {
        setState(() {
          _discountError =
              'Энэ хөнгөлөлтийн код таны сагсны бүтээгдэхүүнд хэрэглэж болохгүй';
        });
        return;
      }

      // Check if discount has reached usage limit
      if (discount.currentUseCount >= discount.maxUseCount) {
        setState(() {
          _discountError =
              'Энэ хөнгөлөлтийн код ашиглах хязгаартаа хүрсэн байна';
        });
        return;
      }

      // Check start / end dates (using raw data to avoid missing fields)
      final now = DateTime.now();
      final data = discountDoc.data();
      final Timestamp? startTs = data['startDate'];
      final Timestamp? endTs = data['endDate'];
      if (startTs != null && now.isBefore(startTs.toDate())) {
        setState(() {
          _discountError = 'Энэ хөнгөлөлт хараахан эхлээгүй байна';
        });
        return;
      }
      if (endTs != null && now.isAfter(endTs.toDate())) {
        setState(() {
          _discountError = 'Энэ хөнгөлөлтийн хугацаа дууссан байна';
        });
        return;
      }

      // Apply the discount
      setState(() {
        _appliedDiscount = discount;
        _discountError = null;
      });

      if (mounted) {
        PopupUtils.showSuccess(
          context: context,
          message:
              'Хөнгөлөлт амжилттай! хөнгөлөлсөн үнэ: ₮${_discountAmount.toStringAsFixed(2)}',
        );
      }
    } catch (error, stackTrace) {
      if (mounted) {
        await ErrorHandlerService.instance.handleError(
          operation: 'apply_discount_code',
          error: error,
          stackTrace: stackTrace,
          context: context,
          showUserMessage: false, // We show custom error message
          additionalContext: {
            'discountCode': _discountCodeController.text,
            'userId': FirebaseAuth.instance.currentUser?.uid,
          },
        );
      }

      if (mounted) {
        setState(() {
          _discountError = 'Хөнгөлөлтийн кодыг ашиглахад алдаа гарлаа';
        });
      }
    } finally {
      setState(() {
        _isApplyingDiscount = false;
      });
    }
  }

  void _removeDiscount() {
    setState(() {
      _appliedDiscount = null;
      _discountCodeController.clear();
      _discountError = null;
    });
  }

  Future<void> _handleQPayPayment(
    Map<String, dynamic> orderData,
    String customerEmail,
    Map<String, dynamic> deliveryAddress,
  ) async {
    setState(() {
      _isProcessingOrder = true;
    });

    try {
      // Validate inputs
      if (customerEmail.isEmpty) {
        throw Exception('Customer email is required');
      }
      if (_finalTotal <= 0) {
        throw Exception('Invalid order amount');
      }
      if (widget.items.isEmpty) {
        throw Exception('No items in cart');
      }

      // Generate order ID using the new generator
      final orderId = OrderIdGenerator.generate();

      // Create order description
      final itemNames = widget.items.map((item) => item.name).join(', ');
      final description = 'Avii.mn захиалга: $itemNames';

      // Create QPay invoice with comprehensive error handling
      Map<String, dynamic> result;
      try {
        result = await _qpayService.createInvoice(
          orderId: orderId,
          amount: _finalTotal,
          description: description,
          customerCode: customerEmail, // Use email as customer code
        );
      } catch (e) {
        // Handle specific QPay errors
        if (e.toString().contains('authentication failed')) {
          throw Exception('QPay тохиргооны алдаа. Админтай холбогдоно уу.');
        } else if (e.toString().contains('timeout')) {
          throw Exception('Сүлжээний холболт удаан байна. Дахин оролдоно уу.');
        } else if (e.toString().contains('Cannot connect')) {
          throw Exception(
              'QPay серверт холбогдох боломжгүй. Интернэт холболтоо шалгана уу.');
        } else {
          throw Exception('QPay нэхэмжлэх үүсгэх боломжгүй: $e');
        }
      }

      // Check for different possible invoice ID fields
      final invoiceId = result['qPayInvoiceId'] ??
          result['invoice_id'] ??
          result['id'] ??
          result['qpay_invoice_id'];

      if (invoiceId != null) {
        // Get the QPay web payment URL - check different possible URL fields
        String paymentUrl = '';

        // Safely access urls field
        final urls = result['urls'];
        if (urls is Map<String, dynamic>) {
          paymentUrl = urls['payment'] ?? '';
        }

        // Fallback to other URL fields
        if (paymentUrl.isEmpty) {
          paymentUrl = result['payment_url'] ?? result['url'] ?? '';
        }

        // If no URL is available, generate one from QR text
        if (paymentUrl.isEmpty) {
          final qrText = result['qr_text'] ?? result['qrText'] ?? '';
          if (qrText.isNotEmpty) {
            // Generate payment URL from QR text
            paymentUrl = 'https://qpay.mn/q/?q=${Uri.encodeComponent(qrText)}';
          }
        }

        debugPrint('QPay payment URL: $paymentUrl');
        debugPrint('QPay QR text: ${result['qr_text'] ?? result['qrText']}');

        // Safely access short and deep links
        String shortLink = '';
        String deepLink = '';
        if (urls is Map<String, dynamic>) {
          shortLink = urls['short'] ?? '';
          deepLink = urls['deeplink'] ?? '';
        }
        debugPrint('QPay short link: $shortLink');
        debugPrint('QPay deep link: $deepLink');

        if (paymentUrl.isNotEmpty) {
          // Validate and sanitize the payment URL
          Uri? paymentUri;
          try {
            paymentUri = Uri.parse(paymentUrl);
            // Ensure it's a valid HTTP/HTTPS URL
            if (!paymentUri.hasScheme ||
                (!paymentUri.scheme.startsWith('http'))) {
              // If it's not HTTP/HTTPS, try to make it HTTPS
              if (paymentUrl.startsWith('qpay://') ||
                  paymentUrl.startsWith('qpay.mn')) {
                paymentUrl =
                    'https://qpay.mn/q/?q=${Uri.encodeComponent(paymentUrl)}';
                paymentUri = Uri.parse(paymentUrl);
              } else {
                throw Exception('Invalid payment URL format');
              }
            }
          } catch (e) {
            debugPrint('Invalid payment URL: $paymentUrl');
            // If URL is invalid, show payment details dialog
            if (mounted) {
              _showPaymentDetailsDialog(paymentUrl, result);
            }
            return;
          }

          // Try to open QPay payment gateway with proper error handling
          bool launched = false;
          try {
            // First try to open with external application
            launched = await launchUrl(
              paymentUri,
              mode: LaunchMode.externalApplication,
            );
          } catch (e) {
            debugPrint('Failed to launch URL with external application: $e');

            // Fallback: try to open in browser
            try {
              launched = await launchUrl(
                paymentUri,
                mode: LaunchMode.platformDefault,
              );
            } catch (e2) {
              debugPrint('Failed to launch URL in browser: $e2');

              // Last resort: try to open with inAppWebView if it's HTTP/HTTPS
              if (paymentUri.scheme.startsWith('http')) {
                try {
                  launched = await launchUrl(
                    paymentUri,
                    mode: LaunchMode.inAppWebView,
                  );
                } catch (e3) {
                  debugPrint('Failed to launch URL in WebView: $e3');
                  launched = false;
                }
              } else {
                debugPrint(
                    'Cannot use WebView for non-HTTP URL: ${paymentUri.scheme}');
                launched = false;
              }
            }
          }

          if (launched) {
            // Store order data temporarily for when payment is completed
            // We'll create the order when we receive the webhook notification
            await _storeTemporaryOrder(
                orderId, orderData, customerEmail, deliveryAddress);

            // Start 10-minute timeout monitoring
            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser != null) {
              await _timeoutService.startTimeoutMonitoring(
                orderId: orderId,
                qpayInvoiceId: invoiceId,
                customerUserId: currentUser.uid,
                orderData: orderData,
                customerEmail: customerEmail,
                deliveryAddress: deliveryAddress,
              );
            }

            // Navigate to payment waiting screen
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => PaymentWaitingScreen(
                    orderId: orderId,
                    amount: _finalTotal,
                    qpayInvoiceId: invoiceId,
                  ),
                ),
              );
            }
          } else {
            // If we can't open the URL, show the QR code or payment details
            if (mounted) {
              _showPaymentDetailsDialog(paymentUrl, result);
            }
          }
        } else {
          throw Exception(
              'QPay төлбөрийн холбоос үүсгэх боломжгүй байна. QR код: ${(result['qrCode'] ?? result['qr_code'] ?? result['qr'])?.isEmpty ?? true ? "олдсонгүй" : "байна"}');
        }
      } else {
        throw Exception(
            'QPay нэхэмжлэх үүсгэх боломжгүй: ${result['error'] ?? result['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      if (mounted) {
        PopupUtils.showError(
          context: context,
          message: 'QPay төлбөрт алдаа гарлаа: $e',
        );
      }
    } finally {
      setState(() {
        _isProcessingOrder = false;
      });
    }
  }

  /// Store order data temporarily until payment is confirmed via webhook
  Future<void> _storeTemporaryOrder(
    String orderId,
    Map<String, dynamic> orderData,
    String customerEmail,
    Map<String, dynamic> deliveryAddress,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Store temporary order data in Firestore
      await FirebaseFirestore.instance
          .collection('temporary_orders')
          .doc(orderId)
          .set({
        'orderId': orderId,
        'userId': user.uid,
        'customerEmail': customerEmail,
        'orderData': orderData,
        'deliveryAddress': deliveryAddress,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending_payment',
      });
    } catch (e) {
      debugPrint('Error storing temporary order: $e');
    }
  }

  /// Show payment details dialog when URL launching fails
  void _showPaymentDetailsDialog(
      String paymentUrl, Map<String, dynamic> result) {
    final qrText = result['qr_text'] ?? result['qrText'] ?? '';
    final shortLink = result['short_url'] ?? '';
    final deepLink = result['deep_link'] ?? '';

    // Validate and format URLs for display
    String displayUrl = paymentUrl;
    if (paymentUrl.isNotEmpty && !paymentUrl.startsWith('http')) {
      displayUrl = 'https://qpay.mn/q/?q=${Uri.encodeComponent(paymentUrl)}';
    }

    // Generate QR code URL if we have QR text
    String qrCodeUrl = '';
    if (qrText.isNotEmpty) {
      qrCodeUrl = 'https://qpay.mn/q/?q=${Uri.encodeComponent(qrText)}';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Төлбөрийн мэдээлэл'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'QPay төлбөрийн хуудас нээх боломжгүй байна. Дараах аргуудыг ашиглана уу:'),
              const SizedBox(height: 16),
              if (qrCodeUrl.isNotEmpty) ...[
                const Text('1. Төлбөрийн холбоос:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SelectableText(qrCodeUrl),
                const SizedBox(height: 8),
                const Text('• Энэ холбоосыг хуулж браузерт оруулна уу',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
              ],
              if (displayUrl.isNotEmpty && displayUrl != qrCodeUrl) ...[
                const Text('2. Нэмэлт холбоос:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SelectableText(displayUrl),
                const SizedBox(height: 8),
              ],
              if (shortLink.isNotEmpty) ...[
                const Text('3. Богино холбоос:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SelectableText(shortLink),
                const SizedBox(height: 8),
              ],
              if (deepLink.isNotEmpty) ...[
                const Text('4. Deep Link:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SelectableText(deepLink),
                const SizedBox(height: 8),
                const Text('• QPay апп суулгасан бол энэ холбоосыг ашиглана уу',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
              ],
              if (qrText.isNotEmpty) ...[
                const Text('5. QR код текст:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SelectableText(qrText),
                const SizedBox(height: 8),
                const Text('• QPay апп-аа нээж QR кодыг уншуулна уу',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '💡 Зөвлөмж: QPay апп суулгасан бол төлбөр автоматаар нээгдэх болно.',
                  style: TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to payment waiting screen anyway
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => PaymentWaitingScreen(
                    orderId: DateTime.now().millisecondsSinceEpoch.toString(),
                    amount: _finalTotal,
                    qpayInvoiceId: result['qPayInvoiceId'] ??
                        result['invoice_id'] ??
                        result['id'] ??
                        '',
                  ),
                ),
              );
            },
            child: const Text('Үргэлжлүүлэх'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Болих'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      currentIndex: 0,
      showBackButton: true,
      onBack: () => Navigator.of(context).maybePop(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Төлбөр хийх'),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.email, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 24),

                // Ship to
                _sectionHeader('Хүргэлтийн хаяг'),
                _buildShippingAddressTile(context),
                const SizedBox(height: 24),

                // Shipping method
                _sectionHeader('Хүргэлтийн арга'),
                _expandableTile(context, 'UBCab · 6000₮'),
                const SizedBox(height: 24),

                // Payment section
                const Text('Тооцоо хийх',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                    'Таны төлбөрийн мэдээлэлийг бид хэзээ ч хадгалахгүй.',
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),

                _paymentOptionTile(
                    title: 'QPay',
                    subtitle: 'QPay-ээр төлөх',
                    selected: true,
                    onTap: null),
                const SizedBox(height: 24),

                // Order summary
                const Text('Захиалгын хураангуй',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _orderItemRow(),
                const SizedBox(height: 12),
                _discountRow(),

                // Show applied discount if any
                if (_appliedDiscount != null) ...[
                  const SizedBox(height: 8),
                  _appliedDiscountRow(),
                ],

                const Divider(height: 32),
                _priceRow('Нийт дүн', widget.subtotal),

                // Show discount savings
                if (_discountAmount > 0) ...[
                  _priceRow('Хөнгөлсөн дүн: (${_appliedDiscount!.code})',
                      -_discountAmount),
                ],

                _priceRow(
                    'Хүргэлтийн үнэ',
                    _appliedDiscount?.type == DiscountType.freeShipping
                        ? 0
                        : widget.shippingCost),
                const Divider(height: 32),
                _priceRow('Нийт дүн', _finalTotal, isTotal: true),
                const SizedBox(height: 32),

                // Centered checkout button
                Center(
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4285F4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _isProcessingOrder
                          ? null
                          : () async {
                              // Get address provider early to avoid async gap issues
                              final addressProvider =
                                  Provider.of<AddressProvider>(context,
                                      listen: false);

                              // Check if user is authenticated
                              final user = FirebaseAuth.instance.currentUser;
                              if (user == null) {
                                if (mounted) {
                                  PopupUtils.showError(
                                    context: context,
                                    message:
                                        'Та төлбөр хийхээс өмнө бүртгүүлэх хэрэгтэй.',
                                  );
                                }
                                return;
                              }

                              // Email verification is now optional for purchases

                              // Check if shipping address is provided
                              if (addressProvider.addresses.isEmpty) {
                                if (mounted) {
                                  PopupUtils.showError(
                                    context: context,
                                    message: 'Хүргэлтийн хаяг оруулна уу',
                                  );
                                }
                                return;
                              }

                              // Increment discount usage if discount was applied
                              if (_appliedDiscount != null) {
                                try {
                                  await _discountService.incrementUsageCount(
                                      _appliedDiscount!.id);
                                } catch (e) {
                                  // Handle error silently for now
                                }
                              }

                              // Prepare order data for QPay
                              final orderData = {
                                'items': widget.items
                                    .map((item) => {
                                          'name': item.name,
                                          'variant': item.variant,
                                          'price': item.price,
                                          'imageUrl': item.imageUrl,
                                        })
                                    .toList(),
                                'subtotal': widget.subtotal,
                                'shipping': _appliedDiscount?.type ==
                                        DiscountType.freeShipping
                                    ? 0
                                    : widget.shippingCost,
                                'tax': widget.tax,
                                'total': _finalTotal,
                                'discountAmount': _discountAmount,
                                'discountCode': _appliedDiscount?.code,
                              };

                              // Get shipping address
                              final shippingAddress =
                                  addressProvider.defaultAddress ??
                                      addressProvider.addresses.first;
                              final deliveryAddress = {
                                'fullAddress': shippingAddress.formatted(),
                                'firstName': shippingAddress.firstName,
                                'lastName': shippingAddress.lastName,
                                'line1': shippingAddress.line1,
                                'apartment': shippingAddress.apartment,
                                'phone': shippingAddress.phone,
                              };

                              // Handle QPay payment
                              await _handleQPayPayment(
                                  orderData, user.email ?? '', deliveryAddress);
                            },
                      child: _isProcessingOrder
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : RichText(
                              text: TextSpan(
                                children: [
                                  const TextSpan(
                                    text: 'Төлөх дүн: ',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '₮${_finalTotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Text(title,
      style: const TextStyle(fontSize: 14, color: Color(0xFF4285F4)));

  Widget _expandableTile(BuildContext context, String text) {
    return InkWell(
      onTap: () {},
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
            const Icon(Icons.keyboard_arrow_down),
          ],
        ),
      ),
    );
  }

  Widget _paymentOptionTile(
      {required String title,
      required String subtitle,
      required bool selected,
      VoidCallback? onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
            color: selected ? const Color(0xFF4285F4) : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Radio<bool>(
          value: true,
          groupValue: selected,
          onChanged: (_) {},
          activeColor: const Color(0xFF4285F4),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }

  Widget _orderItemRow() {
    return Column(
      children: widget.items
          .map((item) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: item.imageUrl.startsWith('http')
                          ? Image.network(item.imageUrl,
                              width: 64, height: 64, fit: BoxFit.cover)
                          : Image.asset(item.imageUrl,
                              width: 64, height: 64, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name.toUpperCase(),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          Text(item.variant,
                              style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('₮${item.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.grey)),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _discountRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _discountCodeController,
                enabled: _appliedDiscount == null,
                decoration: InputDecoration(
                  hintText: _appliedDiscount != null
                      ? 'Хөнгөлөлт амжилттай'
                      : 'Хөнгөлөлтийн код',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: _discountError != null
                          ? Colors.red
                          : Colors.grey.shade300,
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _appliedDiscount != null
                    ? Colors.white
                    : const Color(0xFF4285F4),
                side: BorderSide(color: const Color(0xFF4285F4), width: 1),
              ),
              onPressed: (_isApplyingDiscount || _appliedDiscount != null)
                  ? null
                  : _applyDiscountCode,
              child: _isApplyingDiscount
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black54,
                      ),
                    )
                  : Text(_appliedDiscount != null ? 'Амжилттай' : 'Шалгаx'),
            ),
          ],
        ),
        if (_discountError != null) ...[
          const SizedBox(height: 8),
          Text(
            _discountError!,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _appliedDiscountRow() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Хөнгөлөлтийн код: ${_appliedDiscount!.code}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        GestureDetector(
          onTap: _removeDiscount,
          child: const Text(
            'Устгах',
            style: TextStyle(color: Colors.blue, fontWeight: FontWeight.normal),
          ),
        ),
      ],
    );
  }

  Widget _priceRow(String label, double value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: isTotal ? 18 : 16,
                      fontWeight:
                          isTotal ? FontWeight.bold : FontWeight.normal)),
              if (label == 'Shipping') const SizedBox(width: 4),
              if (label == 'Shipping') const Icon(Icons.help_outline, size: 14),
            ],
          ),
          Text(
            label == 'Shipping' && value == 0
                ? 'FREE'
                : '₮${value.toStringAsFixed(2)}',
            style: TextStyle(
                fontSize: isTotal ? 18 : 16,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildShippingAddressTile(BuildContext context) {
    return Consumer<AddressProvider>(
      builder: (context, addressProvider, child) {
        final hasAddress = addressProvider.addresses.isNotEmpty;
        final currentAddress = hasAddress
            ? (addressProvider.defaultAddress?.formatted() ??
                addressProvider.addresses.first.formatted())
            : 'Xүргэлтийн xаягаа оруулна уу';

        return InkWell(
          onTap: () async {
            // Navigate to address management page
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManageAddressesPage()),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    currentAddress,
                    style: TextStyle(
                      fontSize: 16,
                      color: hasAddress ? Colors.black : Colors.blue,
                      fontWeight:
                          hasAddress ? FontWeight.normal : FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  hasAddress ? Icons.keyboard_arrow_down : Icons.add,
                  color: hasAddress ? Colors.black : Colors.blue,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
