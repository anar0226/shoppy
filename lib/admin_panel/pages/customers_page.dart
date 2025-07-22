import 'package:flutter/material.dart';
import '../widgets/side_menu.dart';
import '../widgets/top_nav_bar.dart';
import '../../features/settings/themes/app_themes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/auth_service.dart';
import '../../core/utils/type_utils.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  String? _storeId;
  bool _storeLoaded = false;
  String _searchQuery = '';

  // Statistics variables
  int totalCustomers = 0;
  double totalRevenue = 0.0;
  int totalOrders = 0;

  // Cache to prevent unnecessary recalculation
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _lastOrders;

  @override
  void initState() {
    super.initState();
    _loadStoreId();
  }

  @override
  void dispose() {
    // Clean up any resources if needed
    super.dispose();
  }

  Future<void> _loadStoreId() async {
    final ownerId = AuthService.instance.currentUser?.uid;
    if (ownerId == null) {
      if (mounted) {
        setState(() => _storeLoaded = true);
      }
      return;
    }
    final snap = await FirebaseFirestore.instance
        .collection('stores')
        .where('ownerId', isEqualTo: ownerId)
        .limit(1)
        .get();
    if (mounted) {
      setState(() {
        _storeLoaded = true;
        if (snap.docs.isNotEmpty) {
          _storeId = snap.docs.first.id;
        }
      });
    }
  }

  void _calculateStatistics(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> orders) {
    // Avoid recalculation if orders haven't changed
    if (_lastOrders != null && _ordersEqual(_lastOrders!, orders)) {
      return;
    }

    _lastOrders = orders;

    final Set<String> uniqueCustomers = {};
    double revenue = 0.0;

    for (var order in orders) {
      final data = order.data();

      // Track unique customers using enhanced logic
      final customerEmail = data['customerEmail'] as String? ??
          data['userEmail'] as String? ??
          data['email'] as String? ??
          '';

      // Use email as primary key, fallback to userId if no email
      String customerKey = customerEmail.isNotEmpty
          ? customerEmail
          : (data['userId'] as String? ?? 'unknown-${order.id}');

      if (customerKey.isNotEmpty && customerKey != 'unknown-${order.id}') {
        uniqueCustomers.add(customerKey);
      }

      // Calculate revenue
      final orderTotal =
          TypeUtils.safeCastDouble(data['total'], defaultValue: 0.0);
      revenue += orderTotal;
    }

    final newTotalCustomers = uniqueCustomers.length;
    final newTotalRevenue = revenue;
    final newTotalOrders = orders.length;

    // Only update state if values have actually changed
    if (totalCustomers != newTotalCustomers ||
        totalRevenue != newTotalRevenue ||
        totalOrders != newTotalOrders) {
      totalCustomers = newTotalCustomers;
      totalRevenue = newTotalRevenue;
      totalOrders = newTotalOrders;

      // Schedule state update for next frame to avoid rebuilding during build
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      }
    }
  }

  bool _ordersEqual(List<QueryDocumentSnapshot<Map<String, dynamic>>> orders1,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> orders2) {
    if (orders1.length != orders2.length) return false;
    for (int i = 0; i < orders1.length; i++) {
      if (orders1[i].id != orders2[i].id) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemes.getBackgroundColor(context),
      body: Row(
        children: [
          const SideMenu(selected: 'Үйлчлүүлэгчид'),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TopNavBar(title: 'Үйлчлүүлэгчид'),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (!_storeLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_storeId == null) {
      return const Center(child: Text('Танд одоогоор дэлгүүр байхгүй байна.'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('storeId', isEqualTo: _storeId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data?.docs ?? [];

        // Calculate statistics directly (no postFrameCallback to avoid rebuild loop)
        _calculateStatistics(orders);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildStatsRow(),
              const SizedBox(height: 24),
              const Text('Үйлчлүүлэгчид',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _buildCustomersTable(orders),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Үйлчлүүлэгчид',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppThemes.getTextColor(context))),
            const SizedBox(height: 4),
            Text('Үйлчлүүлэгчдийн мэдээлэл харах, засах',
                style:
                    TextStyle(color: AppThemes.getSecondaryTextColor(context))),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        SizedBox(
          width: 300,
          child: TextField(
            style: TextStyle(color: AppThemes.getTextColor(context)),
            decoration: InputDecoration(
              hintText: 'Үйлчлүүлэгч хайх...',
              hintStyle:
                  TextStyle(color: AppThemes.getSecondaryTextColor(context)),
              prefixIcon: Icon(Icons.search,
                  color: AppThemes.getSecondaryTextColor(context)),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              isDense: true,
            ),
            onChanged: (value) {
              if (mounted) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              }
            },
          ),
        ),
        const Spacer(),
        Row(
          children: [
            Icon(Icons.person_outline,
                size: 16, color: AppThemes.getSecondaryTextColor(context)),
            const SizedBox(width: 4),
            Text('$totalCustomers үйлчлүүлэгч',
                style: TextStyle(color: AppThemes.getTextColor(context))),
            const SizedBox(width: 16),
            Icon(Icons.attach_money,
                size: 16, color: AppThemes.getSecondaryTextColor(context)),
            const SizedBox(width: 4),
            Text('₮${totalRevenue.toStringAsFixed(0)} орлого',
                style: TextStyle(color: AppThemes.getTextColor(context))),
            const SizedBox(width: 16),
            Icon(Icons.shopping_cart_outlined,
                size: 16, color: AppThemes.getSecondaryTextColor(context)),
            const SizedBox(width: 4),
            Text('$totalOrders захиалга',
                style: TextStyle(color: AppThemes.getTextColor(context))),
          ],
        ),
      ],
    );
  }

  Widget _buildCustomersTable(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> orders) {
    // Group orders by customer
    final Map<String, Map<String, dynamic>> customerData = {};

    // Debug: Print order count and first order structure (only in debug mode)
    if (orders.isNotEmpty) {
      debugPrint(
          '📊 Processing ${orders.length} orders for customer extraction');
      if (orders.isNotEmpty) {
        final firstOrder = orders.first.data();
        debugPrint('🔍 Sample order fields: ${firstOrder.keys.toList()}');
        debugPrint('📧 Customer fields in first order:');
        debugPrint('   customerEmail: ${firstOrder['customerEmail']}');
        debugPrint('   userEmail: ${firstOrder['userEmail']}');
        debugPrint('   email: ${firstOrder['email']}');
        debugPrint('   customerName: ${firstOrder['customerName']}');
        debugPrint('   userId: ${firstOrder['userId']}');
      }
    }

    for (var order in orders) {
      final data = order.data();

      // Try multiple possible field names for customer email
      final customerEmail = data['customerEmail'] as String? ??
          data['userEmail'] as String? ??
          data['email'] as String? ??
          '';

      // Try multiple possible field names for customer name
      String customerName = data['customerName'] as String? ??
          data['name'] as String? ??
          data['displayName'] as String? ??
          '';

      // Enhanced fallback logic for customer name
      if (customerName.isEmpty) {
        if (customerEmail.isNotEmpty) {
          // Use email username as fallback
          customerName = customerEmail.split('@').first;
        } else {
          // Try to get user ID and create a placeholder name
          final userId = data['userId'] as String? ?? '';
          if (userId.isNotEmpty) {
            customerName = 'User ${userId.substring(0, 8)}';
          } else {
            customerName = 'Үл мэдэгдэх үйлчлүүлэгч';
          }
        }
      }

      // Use email as primary key, fallback to userId if no email
      String customerKey = customerEmail.isNotEmpty
          ? customerEmail
          : (data['userId'] as String? ?? 'unknown-${order.id}');

      if (customerKey.isNotEmpty && customerKey != 'unknown-${order.id}') {
        if (!customerData.containsKey(customerKey)) {
          customerData[customerKey] = {
            'name': customerName,
            'email': customerEmail.isNotEmpty ? customerEmail : 'Имэйл байхгүй',
            'userId': data['userId'] ?? '',
            'orders': 0,
            'totalSpent': 0.0,
            'lastOrderDate': null,
            'status': 'идэвхтэй',
            'address': data['shippingAddress'] ??
                data['deliveryAddress'] ??
                data['address'] ??
                '',
          };
        }

        customerData[customerKey]!['orders'] += 1;
        customerData[customerKey]!['totalSpent'] +=
            TypeUtils.safeCastDouble(data['total'], defaultValue: 0.0);

        final orderDate = (data['createdAt'] ??
            data['date'] ??
            data['updatedAt']) as Timestamp?;
        if (orderDate != null) {
          if (customerData[customerKey]!['lastOrderDate'] == null ||
              orderDate
                  .toDate()
                  .isAfter(customerData[customerKey]!['lastOrderDate'])) {
            customerData[customerKey]!['lastOrderDate'] = orderDate.toDate();
          }
        }
      }
    }

    // Debug: Print extraction results
    debugPrint(
        '✅ Extracted ${customerData.length} unique customers from ${orders.length} orders');
    if (customerData.isNotEmpty) {
      debugPrint('👥 Sample customers:');
      customerData.entries.take(3).forEach((entry) {
        final customer = entry.value;
        debugPrint(
            '   ${customer['name']} (${customer['email']}) - ${customer['orders']} orders');
      });
    }

    // Filter customers based on search query
    final filteredCustomers = customerData.entries.where((entry) {
      if (_searchQuery.isEmpty) return true;
      final customer = entry.value;
      return customer['name'].toString().toLowerCase().contains(_searchQuery) ||
          customer['email'].toString().toLowerCase().contains(_searchQuery);
    }).toList();

    if (filteredCustomers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Text(
            _searchQuery.isEmpty
                ? 'Үйлчлүүлэгч байхгүй байна.'
                : 'Хайлтад тохирох үйлчлүүлэгч олдсонгүй.',
            style: TextStyle(
              fontSize: 16,
              color: AppThemes.getSecondaryTextColor(context),
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppThemes.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemes.getBorderColor(context)),
      ),
      child: DataTable(
        columnSpacing: 24,
        headingRowHeight: 56,
        dataRowHeight: 64,
        headingTextStyle: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppThemes.getSecondaryTextColor(context)),
        columns: [
          DataColumn(
              label: Text('Үйлчлүүлэгч',
                  style: TextStyle(
                      color: AppThemes.getSecondaryTextColor(context)))),
          DataColumn(
              label: Text('И-мэйл',
                  style: TextStyle(
                      color: AppThemes.getSecondaryTextColor(context)))),
          DataColumn(
              label: Text('Захиалгын тоо',
                  style: TextStyle(
                      color: AppThemes.getSecondaryTextColor(context)))),
          DataColumn(
              label: Text('Нийт зарцуулсан',
                  style: TextStyle(
                      color: AppThemes.getSecondaryTextColor(context)))),
          DataColumn(
              label: Text('Сүүлийн захиалга',
                  style: TextStyle(
                      color: AppThemes.getSecondaryTextColor(context)))),
          DataColumn(
              label: Text('Үйлдэл',
                  style: TextStyle(
                      color: AppThemes.getSecondaryTextColor(context)))),
        ],
        rows: filteredCustomers.map((entry) {
          final customer = entry.value;
          final name = customer['name'] as String;
          final email = customer['email'] as String;
          final orders = customer['orders'] as int;
          final totalSpent = customer['totalSpent'] as double;
          final lastOrderDate = customer['lastOrderDate'] as DateTime?;

          final initials = name
              .split(' ')
              .map((e) => e.isNotEmpty ? e[0] : '')
              .take(2)
              .join()
              .toUpperCase();

          return DataRow(cells: [
            // Customer name with avatar
            DataCell(Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.blue.shade200,
                child: Text(initials,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 12)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(name,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppThemes.getTextColor(context)),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ])),
            // Email
            DataCell(Text(email,
                style: TextStyle(color: AppThemes.getTextColor(context)),
                overflow: TextOverflow.ellipsis)),
            // Orders count
            DataCell(Text(orders.toString(),
                style: TextStyle(color: AppThemes.getTextColor(context)))),
            // Total spent
            DataCell(Text('₮${totalSpent.toStringAsFixed(0)}',
                style: TextStyle(color: AppThemes.getTextColor(context)))),
            // Last order date
            DataCell(Text(
                lastOrderDate != null
                    ? '${lastOrderDate.year}/${lastOrderDate.month}/${lastOrderDate.day}'
                    : '-',
                style: TextStyle(color: AppThemes.getTextColor(context)))),
            // Actions
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility,
                      size: 18, color: Colors.blue),
                  onPressed: () => _viewCustomerDetails(customer),
                  tooltip: 'Дэлгэрэнгүй харах',
                ),
                IconButton(
                  icon: const Icon(Icons.email, size: 18, color: Colors.green),
                  onPressed: () => _contactCustomer(email),
                  tooltip: 'И-мэйл илгээх',
                ),
              ],
            )),
          ]);
        }).toList(),
      ),
    );
  }

  void _viewCustomerDetails(Map<String, dynamic> customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Үйлчлүүлэгчийн мэдээлэл'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Нэр:', customer['name']),
              _buildDetailRow('И-мэйл:', customer['email']),
              _buildDetailRow('Захиалгын тоо:', customer['orders'].toString()),
              _buildDetailRow('Нийт зарцуулсан:',
                  '₮${customer['totalSpent'].toStringAsFixed(0)}'),
              if (customer['address'] != null && customer['address'].isNotEmpty)
                _buildDetailRow('Хаяг:', customer['address']),
              if (customer['lastOrderDate'] != null)
                _buildDetailRow('Сүүлийн захиалга:',
                    '${customer['lastOrderDate'].year}/${customer['lastOrderDate'].month}/${customer['lastOrderDate'].day}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Хаах'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _contactCustomer(String email) {
    // This would integrate with email service
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'И-мэйл хаяг: $email руу мессеж илгээх функц удахгүй нэмэгдэнэ'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
