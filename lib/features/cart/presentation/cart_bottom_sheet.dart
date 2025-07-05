import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../models/cart_item.dart';
import 'package:avii/features/checkout/presentation/checkout_page.dart';
import 'package:avii/features/checkout/models/checkout_item.dart';
import 'package:avii/features/addresses/providers/address_provider.dart';
import 'package:avii/features/addresses/presentation/manage_addresses_page.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import '../../../core/utils/popup_utils.dart';

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
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  itemBuilder: (context, index) {
                    final item = cart.items[index];
                    return _CartItemTile(context: context, item: item);
                  },
                ),
              ),
              const SizedBox(height: 12),
              _subtotalRow(cart.subtotal),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 22, 14, 179),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    if (cart.items.isEmpty) return;

                    final addrProvider =
                        Provider.of<AddressProvider>(context, listen: false);

                    if (addrProvider.addresses.isEmpty) {
                      PopupUtils.showWarning(
                        context: context,
                        message: 'Хүргэлтийн хаяг оруулна уу',
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ManageAddressesPage()),
                      );
                      return;
                    }

                    final shippingAddr = addrProvider.addresses.first;

                    // Convert all cart items to checkout items
                    final checkoutItems = cart.items
                        .map((cartItem) => CheckoutItem(
                              imageUrl: cartItem.product.images.isNotEmpty
                                  ? cartItem.product.images.first
                                  : '',
                              name: cartItem.product.name,
                              variant: cartItem.variant ?? 'Standard',
                              price: cartItem.product.price,
                              storeId: cartItem.product
                                  .storeId, // Include storeId for validation
                            ))
                        .toList();

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CheckoutPage(
                          email:
                              fb_auth.FirebaseAuth.instance.currentUser?.email ?? '',
                          fullAddress: shippingAddr.formatted(),
                          subtotal: cart.subtotal,
                          shippingCost: 0,
                          tax: cart.subtotal * 0.0825,
                          items: checkoutItems, // Pass all items
                        ),
                      ),
                    );
                  },
                  child: const Text('checkout хийх'),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    child: const Text('Буцах'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              )
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
        const Text('Нийт дүн', style: TextStyle(color: Colors.white)),
        Text('₮${subtotal.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white)),
      ],
    );
  }

  Widget _CartItemTile(
      {required BuildContext context, required CartItem item}) {
    final cart = Provider.of<CartProvider>(context, listen: false);

    // Calculate original price if product is discounted
    double? originalPrice;
    if (item.product.isDiscounted && item.product.discountPercent > 0) {
      originalPrice =
          item.product.price / (1 - item.product.discountPercent / 100);
    }

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
                Text(item.variant ?? 'стандарт',
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // delete - just red icon
                    IconButton(
                      icon:
                          const Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: () => cart.removeItem(item.product.id),
                      padding: const EdgeInsets.all(4),
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    const SizedBox(width: 8),
                    _qtyButton(
                        '-', () => cart.changeQuantity(item.product.id, -1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text('${item.quantity}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
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
              Text('₮${item.product.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              if (originalPrice != null) ...[
                const SizedBox(height: 4),
                Text('₮${originalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.white54,
                        decoration: TextDecoration.lineThrough,
                        fontSize: 14)),
              ],
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
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
      ),
    );
  }
}
