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
import 'package:avii/features/orders/services/order_service.dart';
import 'package:avii/features/cart/models/cart_item.dart';
import 'package:avii/features/stores/models/store_model.dart';
import 'package:avii/features/products/models/product_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'qpay_payment_page.dart';
import '../../../core/utils/popup_utils.dart';
import '../../../admin_panel/services/notification_service.dart';
import '../../../core/services/qpay_service.dart';
import 'dart:ui' as ui;
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
  final _orderService = OrderService();
  final _qpayService = QPayService();

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
        setState(() {
          _discountError = 'Буруу хөнгөлөлтийн код';
        });
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

      PopupUtils.showSuccess(
        context: context,
        message:
            'Хөнгөлөлт амжилттай! хөнгөлөлсөн үнэ: ₮${_discountAmount.toStringAsFixed(2)}',
      );
    } catch (e) {
      setState(() {
        _discountError = 'Хөнгөлөлтийн кодыг ашиглахад алдаа гарлаа';
      });
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

  Future<void> _createOrder(
    Map<String, dynamic> orderData,
    String customerEmail,
    Map<String, dynamic> deliveryAddress,
  ) async {
    setState(() {
      _isProcessingOrder = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser!;

      // Group items by store ID
      final Map<String, List<CheckoutItem>> itemsByStore = {};
      for (final item in widget.items) {
        final storeId = item.storeId ?? 'shoppy-store';
        itemsByStore.putIfAbsent(storeId, () => []).add(item);
      }

      // Create separate orders for each store
      final List<String> orderIds = [];

      for (final entry in itemsByStore.entries) {
        final storeId = entry.key;
        final storeItems = entry.value;

        // Calculate totals for this store
        final storeSubtotal =
            storeItems.fold<double>(0, (sum, item) => sum + item.price);
        final storeShipping = widget.shippingCost /
            itemsByStore.length; // Distribute shipping cost
        final storeTax =
            (widget.tax / widget.subtotal) * storeSubtotal; // Proportional tax

        // Get the store from Firestore
        StoreModel store;
        try {
          final storeDoc = await FirebaseFirestore.instance
              .collection('stores')
              .doc(storeId)
              .get();

          if (storeDoc.exists) {
            store = StoreModel.fromFirestore(storeDoc);
          } else {
            // Get current user to use as store owner
            final currentUser = FirebaseAuth.instance.currentUser;
            final ownerId = currentUser?.uid ?? 'default-owner';

            // Create a default store with current user as owner
            final defaultStoreData = {
              'name': 'Avii.mn Store',
              'description': 'Default store for testing',
              'banner': '',
              'logo': '',
              'ownerId': ownerId,
              'isActive': true,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            };

            await FirebaseFirestore.instance
                .collection('stores')
                .doc(storeId)
                .set(defaultStoreData);

            store = StoreModel(
              id: storeId,
              name: 'Avii.mn Store',
              description: 'Default store for testing',
              banner: '',
              logo: '',
              ownerId: ownerId,
              status: 'active',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              settings: {},
            );
          }
        } catch (e) {
          // Fallback store with current user as owner
          final currentUser = FirebaseAuth.instance.currentUser;
          final ownerId = currentUser?.uid ?? 'default-owner';

          store = StoreModel(
            id: storeId,
            name: 'Shoppy Store',
            description: 'Default store for testing',
            banner: '',
            logo: '',
            ownerId: ownerId,
            status: 'active',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            settings: {},
          );
        }

        // Convert checkout items to cart items for this store
        final cartItems = <CartItem>[];

        for (int i = 0; i < storeItems.length; i++) {
          final item = storeItems[i];

          // Create a product from checkout item data
          final product = ProductModel(
            id: 'product-${DateTime.now().millisecondsSinceEpoch}-$i',
            storeId: storeId,
            name: item.name,
            description: 'Product from checkout',
            price: item.price,
            images: [item.imageUrl],
            category: item.category ?? 'General',
            stock: 1,
            variants: [],
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          cartItems.add(CartItem(
            product: product,
            quantity:
                1, // Default quantity to 1 since CheckoutItem doesn't have quantity
            selectedVariants:
                item.variant.isNotEmpty ? {'variant': item.variant} : null,
          ));
        }

        // Create the order for this store using OrderService
        final orderId = await _orderService.createOrder(
          user: user,
          subtotal: storeSubtotal,
          shipping: storeShipping,
          tax: storeTax,
          cart: cartItems,
          store: store,
        );

        orderIds.add(orderId);

        // Notify store owner about new order
        try {
          await NotificationService().notifyNewOrder(
            storeId: store.id,
            ownerId: store.ownerId,
            orderId: orderId,
            customerEmail: user.email ?? 'Unknown Customer',
            total: storeSubtotal + storeShipping + storeTax,
          );
        } catch (e) {
          print('Failed to send notification: $e');
          // Don't fail the order creation if notification fails
        }
      }

      // Show success message
      final orderCount = orderIds.length;
      final message = orderCount > 1
          ? 'Захиалга амжилттай үүсгэгдлээ! $orderCount дэлгүүрт захиалга илгээгдлээ.'
          : 'Захиалга амжилттай үүсгэгдлээ! Таны захиалгыг боловсруулж байна.';

      PopupUtils.showSuccess(
        context: context,
        message: message,
      );

      // Navigate to orders page after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/orders',
            (route) => route.isFirst,
          );
        }
      });
    } catch (e) {
      // Show error message
      PopupUtils.showError(
        context: context,
        message: 'Захиалга үүсгэхэд алдаа гарлаа: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingOrder = false;
        });
      }
    }
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
      // Generate order ID
      final orderId = DateTime.now().millisecondsSinceEpoch.toString();

      // Create order description
      final itemNames = widget.items.map((item) => item.name).join(', ');
      final description = 'Avii.mn захиалга: $itemNames';

      // Create QPay invoice
      final result = await _qpayService.createInvoice(
        orderId: orderId,
        amount: _finalTotal,
        description: description,
        customerEmail: customerEmail,
      );

      if (result.success && result.invoice != null) {
        final invoice = result.invoice!;

        // Get the QPay web payment URL
        String paymentUrl = invoice.bestPaymentUrl;

        // If no URL is available, generate one from QR code
        if (paymentUrl.isEmpty && invoice.qrCode.isNotEmpty) {
          final encodedQR = Uri.encodeComponent(invoice.qrCode);
          paymentUrl = 'https://qpay.mn/q/?q=$encodedQR';
        }

        debugPrint('QPay payment URL: $paymentUrl');
        debugPrint('QPay QR code: ${invoice.qrCode}');
        debugPrint('QPay short link: ${invoice.shortLink}');
        debugPrint('QPay deep link: ${invoice.deepLink}');

        if (paymentUrl.isNotEmpty) {
          // Open QPay payment gateway in browser
          final launched = await launchUrl(
            Uri.parse(paymentUrl),
            mode: LaunchMode.externalApplication,
          );

          if (launched) {
            // Store order data temporarily for when payment is completed
            // We'll create the order when we receive the webhook notification
            await _storeTemporaryOrder(
                orderId, orderData, customerEmail, deliveryAddress);

            // Navigate to payment waiting screen
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => PaymentWaitingScreen(
                    orderId: orderId,
                    amount: _finalTotal,
                    qpayInvoiceId: invoice.qpayInvoiceId,
                  ),
                ),
              );
            }
          } else {
            throw Exception('QPay төлбөрийн хуудас нээх боломжгүй байна');
          }
        } else {
          throw Exception(
              'QPay төлбөрийн холбоос үүсгэх боломжгүй байна. QR код: ${invoice.qrCode.isEmpty ? "олдсонгүй" : "байна"}');
        }
      } else {
        throw Exception(result.error ?? 'QPay нэхэмжлэх үүсгэх боломжгүй');
      }
    } catch (e) {
      PopupUtils.showError(
        context: context,
        message: 'QPay төлбөрт алдаа гарлаа: $e',
      );
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
        'items': widget.items
            .map((item) => {
                  'name': item.name,
                  'variant': item.variant,
                  'price': item.price,
                  'imageUrl': item.imageUrl,
                  'storeId': item.storeId,
                })
            .toList(),
      });
    } catch (e) {
      debugPrint('Error storing temporary order: $e');
    }
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
                _expandableTile(context, 'UBCab · Үнэгүй'),
                const SizedBox(height: 24),

                // Payment section
                const Text('Тооцоо хийх',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                    'Таны төлбөрийн мэдээлэлийг бид хэзээ ч хадгалахгүй.'),
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
                        backgroundColor: const Color.fromARGB(255, 22, 14, 179),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _isProcessingOrder
                          ? null
                          : () async {
                              // Check if user is authenticated
                              final user = FirebaseAuth.instance.currentUser;
                              if (user == null) {
                                PopupUtils.showError(
                                  context: context,
                                  message:
                                      'Please log in to continue with payment',
                                );
                                return;
                              }

                              // Check if email is verified
                              if (!user.emailVerified) {
                                PopupUtils.showError(
                                  context: context,
                                  message:
                                      'Төлбөр хийхээс өмнө имэйл хаягаа баталгаажуулна уу. Баталгаажуулах холбоосыг имэйл хаягтаа илгээлээ.',
                                );
                                // Send verification email
                                try {
                                  await user.sendEmailVerification();
                                  PopupUtils.showSuccess(
                                    context: context,
                                    message: 'Баталгаажуулах имэйл илгээгдлээ',
                                  );
                                } catch (e) {
                                  // Ignore error if verification email fails
                                }
                                return;
                              }

                              // Check if shipping address is provided
                              final addressProvider =
                                  Provider.of<AddressProvider>(context,
                                      listen: false);
                              if (addressProvider.addresses.isEmpty) {
                                PopupUtils.showError(
                                  context: context,
                                  message: 'Хүргэлтийн хаяг оруулна уу',
                                );
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
                          : Text(
                              'Төлөх дүн: ₮${_finalTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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

  Widget _sectionHeader(String title) =>
      Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey));

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
        color: selected ? Colors.grey.shade100 : Colors.white,
        border: Border.all(
            color: selected ? Colors.deepPurple : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading:
            Radio<bool>(value: true, groupValue: selected, onChanged: (_) {}),
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
                        style: const TextStyle(fontWeight: FontWeight.bold)),
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
                backgroundColor: _isApplyingDiscount
                    ? Colors.grey.shade400
                    : (_appliedDiscount != null
                        ? Colors.green.shade300
                        : Colors.grey.shade300),
                foregroundColor: Colors.black,
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
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal),
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
