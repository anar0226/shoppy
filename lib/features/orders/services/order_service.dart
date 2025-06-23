import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shoppy/features/cart/models/cart_item.dart';
import 'package:shoppy/features/stores/models/store_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrderService {
  final _db = FirebaseFirestore.instance;

  Future<void> createOrder({
    required User user,
    required double subtotal,
    required double shipping,
    required double tax,
    required List<CartItem> cart,
    required StoreModel store,
  }) async {
    final items = cart
        .map((c) => {
              'productId': c.product.id,
              'name': c.product.name,
              'imageUrl':
                  c.product.images.isNotEmpty ? c.product.images.first : '',
              'price': c.product.price,
              'variant': c.variant ?? '',
              'quantity': c.quantity,
            })
        .toList();

    final orderData = {
      'status': 'placed',
      'createdAt': FieldValue.serverTimestamp(),
      'subtotal': subtotal,
      'shippingCost': shipping,
      'tax': tax,
      'total': subtotal + shipping + tax,
      'items': items,
      'storeId': store.id,
      'storeName': store.name,
      'userId': user.uid,
      'userEmail': user.email ?? '',
    };

    await _db
        .collection('users')
        .doc(user.uid)
        .collection('orders')
        .add(orderData);
    await _db.collection('orders').add(orderData);
  }
}
