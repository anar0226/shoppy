import 'package:flutter/material.dart';
import '../widgets/top_nav_bar.dart';
import '../widgets/side_menu.dart';
import '../../features/settings/themes/app_themes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/auth_service.dart';
import '../../core/utils/type_utils.dart';
import '../../features/orders/services/order_service.dart';
import '../../features/notifications/notification_service.dart';
import '../../features/products/models/product_model.dart';
import '../../core/services/database_service.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  // Store ID for queries
  String? _storeId;

  // Statistics variables
  int totalOrders = 0;
  double totalRevenue = 0.0;
  int uniqueCustomers = 0;

  // Search and filter variables
  String _searchQuery = '';
  String _selectedStatus = 'бүх төлөв';
  final TextEditingController _searchController = TextEditingController();
  final OrderService _orderService = OrderService();

  // Cache for product details
  final Map<String, ProductModel> _productCache = {};

  @override
  void initState() {
    super.initState();
    _loadStoreId();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStoreId() async {
    try {
      final ownerId = AuthService.instance.currentUser?.uid;
      if (ownerId == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('stores')
          .where('ownerId', isEqualTo: ownerId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          _storeId = snapshot.docs.first.id;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  // Get product details for order items
  Future<List<Map<String, dynamic>>> _getOrderProductDetails(
      List<dynamic> items) async {
    final List<Map<String, dynamic>> productDetails = [];

    for (final item in items) {
      final productId = item['productId'] as String? ?? '';
      final variant = item['variant'] as String? ?? '';
      final quantity = item['quantity'] as int? ?? 1;

      if (productId.isNotEmpty) {
        ProductModel? product = _productCache[productId];

        if (product == null) {
          try {
            // First try the old structure (products/{productId})
            final productDoc = await FirebaseFirestore.instance
                .collection('products')
                .doc(productId)
                .get();

            if (productDoc.exists) {
              product = ProductModel.fromFirestore(productDoc);
              _productCache[productId] = product;
            } else {
              // Fallback: search in collection group using a field query (not documentId)
              final productQuery = await FirebaseFirestore.instance
                  .collectionGroup('products')
                  .where('productId', isEqualTo: productId)
                  .limit(1)
                  .get();

              if (productQuery.docs.isNotEmpty) {
                product = ProductModel.fromFirestore(productQuery.docs.first);
                _productCache[productId] = product;
              }
            }
          } catch (e) {
            debugPrint('Error fetching product $productId: $e');
          }
        }

        if (product != null) {
          // Calculate remaining stock
          int remainingStock = product.stock;

          // If there's a variant, try to get its specific stock from Firestore
          if (variant.isNotEmpty) {
            try {
              // First try the old structure (products/{productId})
              final productDoc = await FirebaseFirestore.instance
                  .collection('products')
                  .doc(productId)
                  .get();

              Map<String, dynamic>? data;
              if (productDoc.exists) {
                data = productDoc.data() as Map<String, dynamic>;
              } else {
                // Fallback: search in collection group using a field query (not documentId)
                final productQuery = await FirebaseFirestore.instance
                    .collectionGroup('products')
                    .where('productId', isEqualTo: productId)
                    .limit(1)
                    .get();

                if (productQuery.docs.isNotEmpty) {
                  data = productQuery.docs.first.data();
                }
              }

              if (data != null) {
                final variants = data['variants'] as List<dynamic>? ?? [];

                for (final variantData in variants) {
                  if (variantData is Map<String, dynamic> &&
                      variantData['name'] == variant) {
                    remainingStock = variantData['inventory'] ?? 0;
                    break;
                  }
                }
              }
            } catch (e) {
              debugPrint('Error fetching variant data: $e');
            }
          }

          productDetails.add({
            'name': product.name,
            'variant': variant,
            'quantity': quantity,
            'remainingStock': remainingStock,
            'price': product.price,
            'image': product.images.isNotEmpty ? product.images.first : '',
          });
        } else {
          // Fallback if product not found
          productDetails.add({
            'name': item['name'] ?? 'Үл мэдэгдэх бүтээгдэхүүн',
            'variant': variant,
            'quantity': quantity,
            'remainingStock': 0,
            'price': item['price'] ?? 0.0,
            'image': item['imageUrl'] ?? '',
          });
        }
      }
    }

    return productDetails;
  }

  // Show status edit dialog
  Future<void> _showStatusEditDialog(
      String orderId, String currentStatus) async {
    final statuses = [
      {'value': 'placed', 'label': 'захиалсан', 'color': Colors.orange},
      {'value': 'paid', 'label': 'төлөгдсөн', 'color': Colors.blue},
      {'value': 'shipped', 'label': 'хүргэж байна', 'color': Colors.purple},
      {'value': 'delivered', 'label': 'хүргэгдсэн', 'color': Colors.green},
      {'value': 'cancelled', 'label': 'цуцлагдсан', 'color': Colors.red},
    ];

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Захиалгын төлөв өөрчлөх'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: statuses.map((status) {
            final isSelected = status['value'] == currentStatus;
            return ListTile(
              title: Text(status['label'] as String),
              leading: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: status['color'] as Color,
                  shape: BoxShape.circle,
                ),
              ),
              trailing: isSelected ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop(status['value'] as String),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Цуцлах'),
          ),
        ],
      ),
    );

    if (result != null && result != currentStatus) {
      await _updateOrderStatus(orderId, result);
    }
  }

  // Update order status
  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _orderService.updateOrderStatus(orderId, newStatus);

      // Send notification about status change
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();

      if (orderDoc.exists) {
        final orderData = orderDoc.data()!;
        final customerUserId = orderData['userId'] as String?;

        if (customerUserId != null) {
          final statusText = getStatusText(newStatus);
          await NotificationService.sendOrderTrackingNotification(
            userId: customerUserId,
            orderId: orderId,
            status: newStatus,
            title: 'Захиалгын төлөв шинэчлэгдлээ',
            message: 'Таны захиалгын төлөв: $statusText',
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Захиалгын төлөв амжилттай шинэчлэгдлээ'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Алдаа гарлаа: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show detailed order information dialog
  Future<void> _showOrderDetailsDialog(
      QueryDocumentSnapshot<Map<String, dynamic>> order) async {
    final data = order.data();
    final items = List<dynamic>.from(data['items'] ?? []);
    final orderId = order.id;
    final status = data['status'] ?? 'placed';
    final total = TypeUtils.safeCastDouble(data['total'], defaultValue: 0.0);
    final createdAt =
        (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    // Customer information
    final customerEmail = data['customerEmail'] ?? data['userEmail'] ?? '';
    final customerName = data['customerName'] ?? customerEmail.split('@').first;
    final customerPhone = data['customerPhone'] ?? data['phone'] ?? '';

    // Address information
    final deliveryAddress =
        data['deliveryAddress'] as Map<String, dynamic>? ?? {};
    final shippingAddress = data['shippingAddress'] as String? ?? '';

    // Payment information
    final paymentMethod = data['paymentMethod'] ?? 'card';
    final paymentIntentId = data['paymentIntentId'] ?? '';

    // Get product details
    final productDetails = await _getOrderProductDetails(items);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long,
                        color: Colors.blue.shade700, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Захиалгын дэлгэрэнгүй',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          Text(
                            'Захиалга #${orderId.substring(0, 8).toUpperCase()}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Order Summary
                      buildOrderSummarySection(
                          orderId, status, total, createdAt),
                      const SizedBox(height: 24),

                      // Customer Information
                      buildCustomerInfoSection(
                          customerName, customerEmail, customerPhone),
                      const SizedBox(height: 24),

                      // Delivery Address
                      buildDeliveryAddressSection(
                          deliveryAddress, shippingAddress),
                      const SizedBox(height: 24),

                      // Products
                      buildProductsSection(productDetails),
                      const SizedBox(height: 24),

                      // Payment Information
                      buildPaymentInfoSection(
                          paymentMethod, paymentIntentId, total),
                      const SizedBox(height: 24),

                      // Shipping Instructions
                      buildShippingInstructionsSection(data),
                    ],
                  ),
                ),
              ),

              // Footer Actions
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _showStatusEditDialog(orderId, status);
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Төлөв өөрчлөх'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          // Could add print functionality here
                        },
                        icon: const Icon(Icons.print),
                        label: const Text('Хэвлэх'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper methods for building dialog sections
  Widget buildOrderSummarySection(
      String orderId, String status, double total, DateTime createdAt) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Захиалгын мэдээлэл',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Захиалгын дугаар:',
                  style: TextStyle(color: Colors.grey.shade600)),
              Text('#${orderId.substring(0, 8).toUpperCase()}...',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Огноо:', style: TextStyle(color: Colors.grey.shade600)),
              Text(
                  '${createdAt.year}/${createdAt.month}/${createdAt.day} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Төлөв:', style: TextStyle(color: Colors.grey.shade600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: getBadgeColor(status),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(getStatusText(status),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Нийт дүн:', style: TextStyle(color: Colors.grey.shade600)),
              Text('₮${total.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildCustomerInfoSection(
      String customerName, String customerEmail, String customerPhone) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline,
                  color: Colors.green.shade600, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Хэрэглэгчийн мэдээлэл',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (customerName.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Нэр:', style: TextStyle(color: Colors.grey.shade600)),
                Text(customerName,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('И-мэйл:', style: TextStyle(color: Colors.grey.shade600)),
              Flexible(
                child: Text(
                    customerEmail.isNotEmpty
                        ? customerEmail
                        : 'Мэдээлэл байхгүй',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          if (customerPhone.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Утас:', style: TextStyle(color: Colors.grey.shade600)),
                Text(customerPhone,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget buildDeliveryAddressSection(
      Map<String, dynamic> deliveryAddress, String shippingAddress) {
    final hasDetailedAddress = deliveryAddress.isNotEmpty;
    final displayAddress = hasDetailedAddress
        ? '${deliveryAddress['line1'] ?? ''} ${deliveryAddress['line2'] ?? ''}'
            .trim()
        : shippingAddress;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_outlined,
                  color: Colors.orange.shade600, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Хүргэлтийн хаяг',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasDetailedAddress) ...[
            if (deliveryAddress['firstName'] != null ||
                deliveryAddress['lastName'] != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Хүлээн авагч:',
                      style: TextStyle(color: Colors.grey.shade600)),
                  Text(
                      '${deliveryAddress['firstName'] ?? ''} ${deliveryAddress['lastName'] ?? ''}'
                          .trim(),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (deliveryAddress['phone'] != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Утас:', style: TextStyle(color: Colors.grey.shade600)),
                  Text(deliveryAddress['phone'].toString(),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Хаяг:', style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      displayAddress.isNotEmpty
                          ? displayAddress
                          : 'Хаяг байхгүй',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            if (deliveryAddress['city'] != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Хот:', style: TextStyle(color: Colors.grey.shade600)),
                  Text(deliveryAddress['city'].toString(),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ],
            if (deliveryAddress['postalCode'] != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Шуудангийн код:',
                      style: TextStyle(color: Colors.grey.shade600)),
                  Text(deliveryAddress['postalCode'].toString(),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Хаяг:', style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      displayAddress.isNotEmpty
                          ? displayAddress
                          : 'Хаяг байхгүй',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget buildProductsSection(List<Map<String, dynamic>> productDetails) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_outlined,
                  color: Colors.purple.shade600, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Захиалсан бүтээгдэхүүн',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...productDetails
              .map((product) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.purple.shade100),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey.shade200,
                          ),
                          child: product['image'].isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    product['image'],
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(
                                        Icons.inventory_2,
                                        size: 24,
                                        color: Colors.grey.shade400),
                                  ),
                                )
                              : Icon(Icons.inventory_2,
                                  size: 24, color: Colors.grey.shade400),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product['name'],
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (product['variant'].isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Хувилбар: ${product['variant']}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Тоо: ${product['quantity']}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600),
                                  ),
                                  Text(
                                    '₮${(product['price'] * product['quantity']).toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              if (product['remainingStock'] != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Үлдэгдэл: ${product['remainingStock']} ширхэг',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: product['remainingStock'] <= 5
                                          ? Colors.red.shade600
                                          : Colors.grey.shade600),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ],
      ),
    );
  }

  Widget buildPaymentInfoSection(
      String paymentMethod, String paymentIntentId, double total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payment, color: Colors.teal.shade600, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Төлбөрийн мэдээлэл',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Төлбөрийн хэрэгсэл:',
                  style: TextStyle(color: Colors.grey.shade600)),
              Text(_getPaymentMethodDisplay(paymentMethod),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          if (paymentIntentId.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Гүйлгээний дугаар:',
                    style: TextStyle(color: Colors.grey.shade600)),
                Text(
                    '••••${paymentIntentId.substring(paymentIntentId.length - 4)}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Нийт төлсөн дүн:',
                  style: TextStyle(color: Colors.grey.shade600)),
              Text('₮${total.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildShippingInstructionsSection(Map<String, dynamic> data) {
    final notes = data['notes'] as String? ?? '';
    final specialInstructions = data['specialInstructions'] as String? ?? '';
    final deliveryPreference = data['deliveryPreference'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping_outlined,
                  color: Colors.indigo.shade600, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Хүргэлтийн заавар',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (notes.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Тэмдэглэл:',
                    style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(notes,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (specialInstructions.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Тусгай заавар:',
                    style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(specialInstructions,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (deliveryPreference.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Хүргэлтийн хүсэлт:',
                    style: TextStyle(color: Colors.grey.shade600)),
                Text(deliveryPreference,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ],
          if (notes.isEmpty &&
              specialInstructions.isEmpty &&
              deliveryPreference.isEmpty)
            Text(
              'Тусгай заавар байхгүй',
              style: TextStyle(
                  color: Colors.grey.shade600, fontStyle: FontStyle.italic),
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.indigo.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: Colors.indigo.shade700, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Хүргэлтийн өмнө хэрэглэгчтэй холбогдож баталгаажуулна уу',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.indigo.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getPaymentMethodDisplay(String paymentMethod) {
    switch (paymentMethod.toLowerCase()) {
      case 'qpay':
        return 'QPay';
      case 'card':
      case 'visa':
      case 'mastercard':
        return 'Карт';
      case 'cash':
      case 'bank_transfer':
        return 'Банкны шилжүүлэг';
      default:
        return 'Карт';
    }
  }

  void calculateStatistics(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final newTotalOrders = docs.length;
    double newTotalRevenue = 0.0;
    Set<String> customerEmails = {};

    for (var doc in docs) {
      final data = doc.data();
      // Calculate total revenue
      final orderTotal =
          TypeUtils.safeCastDouble(data['total'], defaultValue: 0.0);
      newTotalRevenue += orderTotal;

      // Count unique customers
      final customerEmail = data['customerEmail'] as String? ??
          data['userEmail'] as String? ??
          data['customerId'] as String? ??
          '';
      if (customerEmail.isNotEmpty) {
        customerEmails.add(customerEmail);
      }
    }

    final newUniqueCustomers = customerEmails.length;

    // Only update state if values have actually changed
    if (totalOrders != newTotalOrders ||
        totalRevenue != newTotalRevenue ||
        uniqueCustomers != newUniqueCustomers) {
      totalOrders = newTotalOrders;
      totalRevenue = newTotalRevenue;
      uniqueCustomers = newUniqueCustomers;

      // Schedule state update for next frame to avoid rebuilding during build
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      }
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> filterOrders(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> orders) {
    return orders.where((order) {
      final data = order.data();
      final orderId = order.id.toLowerCase();
      final customerEmail = (data['customerEmail'] ?? data['userEmail'] ?? '')
          .toString()
          .toLowerCase();
      final customerName =
          (data['customerName'] ?? '').toString().toLowerCase();
      final status = (data['status'] ?? '').toString().toLowerCase();

      // Search filter
      bool matchesSearch = true;
      if (_searchQuery.isNotEmpty) {
        final searchLower = _searchQuery.toLowerCase();
        matchesSearch = orderId.contains(searchLower) ||
            customerEmail.contains(searchLower) ||
            customerName.contains(searchLower);
      }

      // Status filter
      bool matchesStatus = true;
      if (_selectedStatus != 'бүх төлөв') {
        String targetStatus = '';
        switch (_selectedStatus) {
          case 'захиалсан':
            targetStatus = 'placed';
            break;
          case 'хүргэгдсэн':
            targetStatus = 'delivered';
            break;
          case 'цуцлагдсан':
            targetStatus = 'cancelled';
            break;
        }
        matchesStatus = status == targetStatus;
      }

      return matchesSearch && matchesStatus;
    }).toList();
  }

  // Translate status to Mongolian
  String getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
      case 'pending':
        return 'захиалсан';
      case 'paid':
        return 'төлөгдсөн';
      case 'shipped':
      case 'delivering':
        return 'хүргэж байна';
      case 'delivered':
        return 'хүргэгдсэн';
      case 'cancelled':
        return 'цуцлагдсан';
      default:
        return 'захиалсан';
    }
  }

  Color getBadgeColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'delivered':
        return Colors.green.shade200;
      case 'placed':
      case 'pending':
        return Colors.orange.shade200;
      case 'shipped':
      case 'delivering':
        return Colors.blue.shade200;
      case 'cancelled':
        return Colors.red.shade200;
      default:
        return Colors.grey.shade200;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemes.getBackgroundColor(context),
      body: Row(
        children: [
          const SideMenu(selected: 'Захиалгууд'),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TopNavBar(title: 'Захиалгууд'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Захиалгууд',
                                    style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold)),
                                SizedBox(height: 4),
                                Text('Хэрэглэгчийн захиалгуудыг хянах'),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Захиалга үүсгэх'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 260,
                                    child: TextField(
                                      controller: _searchController,
                                      onChanged: (value) {
                                        setState(() {
                                          _searchQuery = value;
                                        });
                                      },
                                      decoration: InputDecoration(
                                        hintText: 'Захиалга хайх...',
                                        prefixIcon: const Icon(Icons.search),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 180,
                                    child: DropdownButtonFormField<String>(
                                      value: _selectedStatus,
                                      items: const [
                                        DropdownMenuItem(
                                            value: 'бүх төлөв',
                                            child: Text('бүх төлөв')),
                                        DropdownMenuItem(
                                            value: 'захиалсан',
                                            child: Text('захиалсан')),
                                        DropdownMenuItem(
                                            value: 'хүргэгдсэн',
                                            child: Text('хүргэгдсэн')),
                                        DropdownMenuItem(
                                            value: 'цуцлагдсан',
                                            child: Text('цуцлагдсан')),
                                      ],
                                      onChanged: (String? newValue) {
                                        if (newValue != null) {
                                          setState(() {
                                            _selectedStatus = newValue;
                                          });
                                        }
                                      },
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.shopping_cart_outlined,
                                    size: 16),
                                const SizedBox(width: 4),
                                Text('$totalOrders захиалга'),
                                const SizedBox(width: 16),
                                const Icon(Icons.attach_money, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                    '₮${totalRevenue.toStringAsFixed(0)} орлого'),
                                const SizedBox(width: 16),
                                const Icon(Icons.person_outline, size: 16),
                                const SizedBox(width: 4),
                                Text('$uniqueCustomers хэрэглэгч'),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text('Захиалгын хянах',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        ordersStreamTable(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget ordersStreamTable() {
    if (_storeId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: DatabaseService()
          .collection('orders')
          .where('storeId', isEqualTo: _storeId)
          .orderBy('createdAt', descending: true)
          .limit(50) // Add pagination limit
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Алдаа: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];

        // Apply search and status filters
        final filteredDocs = filterOrders(docs);

        // Calculate statistics when data changes
        calculateStatistics(filteredDocs);

        return FutureBuilder<List<DataRow>>(
          future: buildOrderRows(filteredDocs),
          builder: (context, rowSnapshot) {
            if (rowSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final rows = rowSnapshot.data ?? [];

            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppThemes.getCardColor(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppThemes.getBorderColor(context)),
              ),
              child: Column(
                children: [
                  // Header row
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppThemes.getCardColor(context),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      border: Border(
                        bottom: BorderSide(
                            color: AppThemes.getBorderColor(context)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Захиалга',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppThemes.getSecondaryTextColor(context),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Бүтээгдэхүүн',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppThemes.getSecondaryTextColor(context),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            'Хэрэглэгч',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppThemes.getSecondaryTextColor(context),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            'Огноо',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppThemes.getSecondaryTextColor(context),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            'Нийт дүн',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppThemes.getSecondaryTextColor(context),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            'Төлөв',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppThemes.getSecondaryTextColor(context),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            'Үйлдэл',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppThemes.getSecondaryTextColor(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Data rows
                  ...rows.map((row) => buildCustomDataRow(row)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<List<DataRow>> buildOrderRows(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final List<DataRow> rows = [];

    for (final doc in docs) {
      final data = doc.data();
      final id = doc.id;
      final email = data['customerEmail'] ?? data['userEmail'] ?? '';

      // Get customer name with fallback logic
      String customer = data['customerName'] ?? '';
      if (customer.isEmpty) {
        customer = email.isNotEmpty ? email.split('@').first : 'Үл мэдэгдэх';
      }

      final date = (data['createdAt'] as Timestamp?)?.toDate() ??
          (data['date'] as Timestamp?)?.toDate() ??
          DateTime.now();
      final total = TypeUtils.safeCastDouble(data['total'], defaultValue: 0.0);
      final status = data['status'] ?? 'placed';
      final items = List<dynamic>.from(data['items'] ?? []);

      // Get product details
      final productDetails = await _getOrderProductDetails(items);

      rows.add(DataRow(cells: [
        // Order cell
        DataCell(Builder(
          builder: (context) => Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shopping_cart_outlined,
                  size: 20, color: Colors.black),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('#${id.substring(0, 8)}...',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('Захиалгын дугаар',
                    style: TextStyle(
                        color: AppThemes.getSecondaryTextColor(context),
                        fontSize: 12)),
              ],
            )
          ]),
        )),

        // Product details cell
        DataCell(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: productDetails.map((product) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                children: [
                  // Product image
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.grey.shade200,
                    ),
                    child: product['image'].isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              product['image'],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                  Icons.inventory_2,
                                  size: 12,
                                  color: Colors.grey.shade400),
                            ),
                          )
                        : Icon(Icons.inventory_2,
                            size: 12, color: Colors.grey.shade400),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product['name'],
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (product['variant'].isNotEmpty)
                          Text(
                            'Хувилбар: ${product['variant']}',
                            style: TextStyle(
                                fontSize: 9, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          'Тоо: ${product['quantity']} | Үлдэгдэл: ${product['remainingStock']}',
                          style: TextStyle(
                              fontSize: 9, color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        )),

        // Customer cell
        DataCell(Builder(
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(customer),
              Text(email,
                  style: TextStyle(
                      color: AppThemes.getSecondaryTextColor(context),
                      fontSize: 12)),
            ],
          ),
        )),

        // Date cell
        DataCell(Text('${date.year}/${date.month}/${date.day}')),

        // Total cell
        DataCell(Text('₮${total.toStringAsFixed(0)}')),

        // Status cell
        DataCell(Builder(
          builder: (context) => GestureDetector(
            onTap: () async {
              if (!mounted) return;
              _showStatusEditDialog(id, status);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: getBadgeColor(status),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(getStatusText(status),
                      style: TextStyle(
                          fontSize: 12,
                          color: AppThemes.getTextColor(context))),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit, size: 12),
                ],
              ),
            ),
          ),
        )),

        // Actions cell
        DataCell(Row(children: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.visibility, size: 18, color: Colors.blue),
              onPressed: () async {
                if (!mounted) return;
                _showOrderDetailsDialog(doc);
              },
              tooltip: 'Дэлгэрэнгүй харах',
            ),
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () async {
                if (!mounted) return;
                _showStatusEditDialog(id, status);
              },
              tooltip: 'Төлөв өөрчлөх',
            ),
          ),
        ])),
      ]));
    }

    return rows;
  }

  // Build custom data row with proper column distribution
  Widget buildCustomDataRow(DataRow dataRow) {
    final cells = dataRow.cells;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom:
              BorderSide(color: AppThemes.getBorderColor(context), width: 0.5),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order column
            Expanded(
              flex: 2,
              child: cells[0].child,
            ),
            // Product column with fixed height and scrolling
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 80,
                child: SingleChildScrollView(
                  child: cells[1].child,
                ),
              ),
            ),
            // Customer column
            Expanded(
              flex: 1,
              child: cells[2].child,
            ),
            // Date column
            Expanded(
              flex: 1,
              child: cells[3].child,
            ),
            // Total column
            Expanded(
              flex: 1,
              child: cells[4].child,
            ),
            // Status column
            Expanded(
              flex: 1,
              child: cells[5].child,
            ),
            // Actions column
            Expanded(
              flex: 1,
              child: cells[6].child,
            ),
          ],
        ),
      ),
    );
  }
}
