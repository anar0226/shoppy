import 'package:flutter/material.dart';
import '../widgets/top_nav_bar.dart';
import '../widgets/side_menu.dart';
import '../widgets/add_product_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/auth_service.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  String? _storeId;
  bool _storeLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadStoreId();
  }

  Future<void> _loadStoreId() async {
    final ownerId = AuthService.instance.currentUser?.uid;
    if (ownerId == null) {
      setState(() => _storeLoaded = true);
      return;
    }
    final snap = await FirebaseFirestore.instance
        .collection('stores')
        .where('ownerId', isEqualTo: ownerId)
        .limit(1)
        .get();
    setState(() {
      _storeLoaded = true;
      if (snap.docs.isNotEmpty) {
        _storeId = snap.docs.first.id;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          const SideMenu(selected: 'Products'),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TopNavBar(title: 'Products'),
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
      return const Center(child: Text('You do not have a store yet.'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('storeId', isEqualTo: _storeId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        final productCount = docs.length;
        double inventoryValue = 0;
        for (var d in docs) {
          final data = d.data();
          final price = (data['price'] ?? 0).toDouble();
          final stock = (data['stock'] ?? data['inventory'] ?? 0) as num;
          inventoryValue += price * stock;
        }

        return SingleChildScrollView(
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
                      Text('Products',
                          style: TextStyle(
                              fontSize: 28, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('Manage your product catalog'),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const AddProductDialog(),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add product'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  SizedBox(
                    width: 260,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search products...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 16),
                        const SizedBox(width: 4),
                        Text('$productCount products'),
                        const SizedBox(width: 16),
                        const Icon(Icons.attach_money, size: 16),
                        const SizedBox(width: 4),
                        Text(_formatCurrency(inventoryValue)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Product Catalog',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              docs.isEmpty
                  ? const Text('No products yet. Start by adding one!')
                  : _productTable(docs),
            ],
          ),
        );
      },
    );
  }

  Widget _productTable(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      width: double.infinity,
      child: DataTable(
        columnSpacing: 24,
        headingRowHeight: 56,
        dataRowHeight: 64,
        headingTextStyle:
            const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54),
        columns: const [
          DataColumn(label: Text('Product')),
          DataColumn(label: Text('SKU')),
          DataColumn(label: Text('Price')),
          DataColumn(label: Text('Inventory')),
          DataColumn(label: Text('Status')),
        ],
        rows: docs.map((doc) {
          final data = doc.data();
          final name = data['name'] ?? '';
          final price = (data['price'] ?? 0).toDouble();
          final stock = (data['stock'] ?? data['inventory'] ?? 0).toString();
          final isActive = data['isActive'] ?? true;
          return DataRow(cells: [
            DataCell(Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(name.isNotEmpty ? name[0] : '?',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('Created ${_formatDate(data['createdAt'])}',
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 12)),
                ],
              )
            ])),
            DataCell(Text(doc.id.substring(0, 6).toUpperCase())),
            DataCell(Text(_formatCurrency(price))),
            DataCell(Text(stock)),
            DataCell(Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? Colors.green.shade200 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(isActive ? 'active' : 'inactive',
                  style: const TextStyle(fontSize: 12, color: Colors.black87)),
            )),
          ]);
        }).toList(),
      ),
    );
  }

  String _formatCurrency(double value) {
    return '\$' + value.toStringAsFixed(2);
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    if (timestamp is Timestamp) {
      final dt = timestamp.toDate();
      return '${dt.month}/${dt.day}/${dt.year}';
    }
    return '';
  }
}
