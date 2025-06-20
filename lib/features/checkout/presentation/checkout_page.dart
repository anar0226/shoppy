import 'package:flutter/material.dart';
import 'package:shoppy/features/home/presentation/main_scaffold.dart';
import 'package:shoppy/features/checkout/models/checkout_item.dart';

class CheckoutPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final total = subtotal + shippingCost + tax;

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
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(email, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 24),

                    // Ship to
                    _sectionHeader('Ship to'),
                    _expandableTile(context, fullAddress),
                    const SizedBox(height: 24),

                    // Shipping method
                    _sectionHeader('Shipping method'),
                    _expandableTile(context, 'Standard · FREE'),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Checkbox(value: false, onChanged: (_) {}),
                        const Expanded(
                          child: Text(
                              'Sign me up for news and offers from this store'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Payment section
                    const Text('Payment',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
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
                        subtitle: '\$${(total / 4).toStringAsFixed(2)}',
                        selected: false),
                    const SizedBox(height: 24),

                    // Credit-card details removed for streamlined checkout

                    // Order summary
                    const Text('Order summary',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _orderItemRow(),
                    const SizedBox(height: 12),
                    _discountRow(),
                    const Divider(height: 32),
                    _priceRow('Subtotal', subtotal),
                    _priceRow('Shipping', shippingCost),
                    const Divider(height: 32),
                    _priceRow('Total', total, isTotal: true),
                    const SizedBox(height: 120),
                  ],
                ),
              ),

              // Bottom pay now bar
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 8)
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () {},
                          child: const Text('Pay now'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('\$${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
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
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              Text(item.variant, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text('\$${item.price.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _discountRow() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            decoration: InputDecoration(
              hintText: 'Discount code',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade300,
              foregroundColor: Colors.black),
          onPressed: () {},
          child: const Text('Apply'),
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
}
