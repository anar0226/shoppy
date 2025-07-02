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

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
            print('Error fetching product $productId: $e');
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
                  data = productQuery.docs.first.data() as Map<String, dynamic>;
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
              print('Error fetching variant data: $e');
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
          final statusText = _getStatusText(newStatus);
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

  void _calculateStatistics(
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

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterOrders(
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
  String _getStatusText(String status) {
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

  Color _getBadgeColor(String status) {
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
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
                        _ordersStreamTable(),
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

  Widget _ordersStreamTable() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('vendorId', isEqualTo: AuthService.instance.currentUser?.uid)
          .orderBy('createdAt', descending: true)
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
        final filteredDocs = _filterOrders(docs);

        // Calculate statistics when data changes
        _calculateStatistics(filteredDocs);

        return FutureBuilder<List<DataRow>>(
          future: _buildOrderRows(filteredDocs),
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
                  ...rows.map((row) => _buildCustomDataRow(row)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<List<DataRow>> _buildOrderRows(
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
        DataCell(Row(children: [
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
        ])),

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
        DataCell(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(customer),
            Text(email,
                style: TextStyle(
                    color: AppThemes.getSecondaryTextColor(context),
                    fontSize: 12)),
          ],
        )),

        // Date cell
        DataCell(Text('${date.year}/${date.month}/${date.day}')),

        // Total cell
        DataCell(Text('₮${total.toStringAsFixed(0)}')),

        // Status cell
        DataCell(GestureDetector(
          onTap: () => _showStatusEditDialog(id, status),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getBadgeColor(status),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_getStatusText(status),
                    style: TextStyle(
                        fontSize: 12, color: AppThemes.getTextColor(context))),
                const SizedBox(width: 4),
                const Icon(Icons.edit, size: 12),
              ],
            ),
          ),
        )),

        // Actions cell
        DataCell(Row(children: [
          IconButton(
            icon: const Icon(Icons.visibility, size: 18),
            onPressed: () {
              // TODO: Navigate to order details
            },
            tooltip: 'Дэлгэрэнгүй харах',
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            onPressed: () => _showStatusEditDialog(id, status),
            tooltip: 'Төлөв өөрчлөх',
          ),
        ])),
      ]));
    }

    return rows;
  }

  // Build custom data row with proper column distribution
  Widget _buildCustomDataRow(DataRow dataRow) {
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
              child: Container(
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
