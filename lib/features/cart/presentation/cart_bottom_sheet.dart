import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../models/cart_item.dart';
import 'package:shoppy/features/checkout/presentation/checkout_page.dart';
import 'package:shoppy/features/checkout/models/checkout_item.dart';

class CartBottomSheet extends StatelessWidget {
  const CartBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: cart.items.length,
                  itemBuilder: (_, i) => _cartItemRow(context, cart.items[i]),
                ),
              ),
              const SizedBox(height: 12),
              _subtotalRow(cart.subtotal),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    if (cart.items.isEmpty) return;
                    final first = cart.items.first;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CheckoutPage(
                          email: 'anar0226@gmail.com',
                          fullAddress:
                              'Anar Borgil, 201 E South Temple, Brigham Apartments 815, Salt Lake City UT 84111, US',
                          subtotal: cart.subtotal,
                          shippingCost: 0,
                          tax: cart.subtotal * 0.0825,
                          item: CheckoutItem(
                            imageUrl: first.product.images.isNotEmpty
                                ? first.product.images.first
                                : '',
                            name: first.product.name,
                            variant: 'S',
                            price: first.product.price,
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('Continue to checkout'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _subtotalRow(double subtotal) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Subtotal', style: TextStyle(color: Colors.white)),
        Text('\$${subtotal.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white)),
      ],
    );
  }

  Widget _cartItemRow(BuildContext context, CartItem item) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // product image
          SizedBox(
            width: 60,
            height: 80,
            child: item.product.images.isNotEmpty
                ? (item.product.images.first.startsWith('http')
                    ? Image.network(item.product.images.first,
                        fit: BoxFit.cover)
                    : Image.asset(item.product.images.first, fit: BoxFit.cover))
                : Container(color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.name.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('S',
                    style: const TextStyle(
                        color: Colors.white70)), // placeholder size
                const SizedBox(height: 8),
                Row(
                  children: [
                    // delete
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.white70),
                      onPressed: () => cart.removeItem(item.product.id),
                    ),
                    _qtyButton(
                        '-', () => cart.changeQuantity(item.product.id, -1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('${item.quantity}',
                          style: const TextStyle(color: Colors.white)),
                    ),
                    _qtyButton(
                        '+', () => cart.changeQuantity(item.product.id, 1)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$${item.product.price.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 4),
              Text('\$100.00', // original price placeholder
                  style: const TextStyle(
                      color: Colors.white38,
                      decoration: TextDecoration.lineThrough)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(label, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}
