import 'package:flutter/material.dart';
import 'package:shoppy/features/home/presentation/main_scaffold.dart';
import 'package:shoppy/features/checkout/models/checkout_item.dart';
import 'package:shoppy/features/addresses/presentation/manage_addresses_page.dart';
import 'package:provider/provider.dart';
import 'package:shoppy/features/addresses/providers/address_provider.dart';
import 'package:shoppy/features/discounts/models/discount_model.dart';
import 'package:shoppy/features/discounts/services/discount_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CheckoutPage extends StatefulWidget {
  final String email;
  final String fullAddress;
  final double subtotal;
  final double shippingCost;
  final double tax;
  final CheckoutItem item;

  const CheckoutPage({
    super.key,
    required this.email,
    required this.fullAddress,
    required this.subtotal,
    required this.shippingCost,
    required this.tax,
    required this.item,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _discountCodeController = TextEditingController();
  final _discountService = DiscountService();

  DiscountModel? _appliedDiscount;
  bool _isApplyingDiscount = false;
  String? _discountError;

  double get _discountAmount {
    if (_appliedDiscount == null) return 0.0;

    switch (_appliedDiscount!.type) {
      case DiscountType.percentage:
        return widget.subtotal * (_appliedDiscount!.value / 100);
      case DiscountType.fixedAmount:
        return _appliedDiscount!.value;
      case DiscountType.freeShipping:
        return widget.shippingCost;
    }
  }

  double get _finalTotal {
    return (widget.subtotal - _discountAmount) +
        (_appliedDiscount?.type == DiscountType.freeShipping
            ? 0
            : widget.shippingCost) +
        widget.tax;
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
      // Find the discount by code
      final discountQuery = await FirebaseFirestore.instance
          .collection('discounts')
          .where('code', isEqualTo: code)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (discountQuery.docs.isEmpty) {
        setState(() {
          _discountError = 'Invalid discount code';
        });
        return;
      }

      final discountDoc = discountQuery.docs.first;
      final discount = DiscountModel.fromFirestore(discountDoc);

      // Check if discount has reached usage limit
      if (discount.currentUseCount >= discount.maxUseCount) {
        setState(() {
          _discountError = 'This discount code has reached its usage limit';
        });
        return;
      }

      // Apply the discount
      setState(() {
        _appliedDiscount = discount;
        _discountError = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Discount applied! You saved \$${_discountAmount.toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _discountError = 'Error applying discount code';
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

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      currentIndex: 0,
      showBackButton: true,
      onBack: () => Navigator.of(context).maybePop(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Review & Pay'),
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
                _sectionHeader('Ship to'),
                _buildShippingAddressTile(context),
                const SizedBox(height: 24),

                // Shipping method
                _sectionHeader('Shipping method'),
                _expandableTile(context, 'Standard · FREE'),
                const SizedBox(height: 24),

                // Payment section
                const Text('Payment',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('All transactions are secure and encrypted.'),
                const SizedBox(height: 16),

                _paymentOptionTile(
                    title: 'Pay now',
                    subtitle: 'Pay the entire amount today',
                    selected: true),
                const SizedBox(height: 12),
                _paymentOptionTile(
                    title: 'Pay in 4 installments of',
                    subtitle: '\$${(_finalTotal / 4).toStringAsFixed(2)}',
                    selected: false),
                const SizedBox(height: 24),

                // Order summary
                const Text('Order summary',
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
                _priceRow('Subtotal', widget.subtotal),

                // Show discount savings
                if (_discountAmount > 0) ...[
                  _priceRow(
                      'Discount (${_appliedDiscount!.code})', -_discountAmount),
                ],

                _priceRow(
                    'Shipping',
                    _appliedDiscount?.type == DiscountType.freeShipping
                        ? 0
                        : widget.shippingCost),
                _priceRow('Tax', widget.tax),
                const Divider(height: 32),
                _priceRow('Total', _finalTotal, isTotal: true),
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
                      onPressed: () async {
                        // Increment discount usage if discount was applied
                        if (_appliedDiscount != null) {
                          try {
                            await _discountService
                                .incrementUsageCount(_appliedDiscount!.id);
                          } catch (e) {
                            // Handle error silently for now
                          }
                        }
                        // TODO: Implement payment processing
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Order placed successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      child: Text(
                        'Pay \$${_finalTotal.toStringAsFixed(2)}',
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
      required bool selected}) {
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
        onTap: () {},
      ),
    );
  }

  Widget _orderItemRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: widget.item.imageUrl.startsWith('http')
              ? Image.network(widget.item.imageUrl,
                  width: 64, height: 64, fit: BoxFit.cover)
              : Image.asset(widget.item.imageUrl,
                  width: 64, height: 64, fit: BoxFit.cover),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.item.name.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              Text(widget.item.variant,
                  style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text('\$${widget.item.price.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
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
                      ? 'Discount applied'
                      : 'Discount code',
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
                  : Text(_appliedDiscount != null ? 'Applied' : 'Apply'),
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
            'Applied Discount: ${_appliedDiscount!.code}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        GestureDetector(
          onTap: _removeDiscount,
          child: const Text(
            'Remove',
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
                : '\$${value.toStringAsFixed(2)}',
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
            : 'Tap to add your shipping address';

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
