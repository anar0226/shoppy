import 'package:flutter/material.dart';
import '../widgets/top_nav_bar.dart';
import '../widgets/side_menu.dart';
import '../widgets/add_product_dialog.dart';
import '../widgets/edit_product_dialog.dart';
import '../widgets/delete_confirmation_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/auth_service.dart';
import '../../features/products/models/product_model.dart';
import '../../features/settings/themes/app_themes.dart';

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
      backgroundColor: AppThemes.getBackgroundColor(context),
      body: Row(
        children: [
          const SideMenu(selected: 'Бүтээгдэхүүн'),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TopNavBar(title: 'Бүтээгдэхүүн'),
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
          final price = _toDouble(data['price']);
          final stock = _toNum(data['stock'] ?? data['inventory']);
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
                      Text('Бүтээгдэхүүн',
                          style: TextStyle(
                              fontSize: 28, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('Бүтээгдэхүүний каталогыг хянах'),
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
                    label: const Text('Бүтээгдэхүүн нэмэх'),
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
                        hintText: 'Бүтээгдэхүүн хайх...',
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
                        Text('$productCount Бүтээгдэхүүн'),
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
              const Text('Бүтээгдэхүүнүүд',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              docs.isEmpty
                  ? const Text('Бүтээгдэхүүн байхгүй байна.')
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
        color: AppThemes.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemes.getBorderColor(context)),
      ),
      width: double.infinity,
      child: DataTable(
        columnSpacing: 24,
        headingRowHeight: 56,
        dataRowHeight: 64,
        headingTextStyle: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppThemes.getSecondaryTextColor(context)),
        columns: const [
          DataColumn(label: Text('Бүтээгдэхүүн')),
          DataColumn(label: Text('SKU')),
          DataColumn(label: Text('Үнэ')),
          DataColumn(label: Text('Нөөц')),
          DataColumn(label: Text('Төлөв')),
          DataColumn(label: Text('Үйлдэл')),
        ],
        rows: docs.map((doc) {
          final data = doc.data();
          final name = data['name'] ?? '';
          final price = _toDouble(data['price']);
          final stock = (_toNum(data['stock'] ?? data['inventory'])).toString();
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
                  Text('Үүсгэсэн огноо ${_formatDate(data['createdAt'])}',
                      style: TextStyle(
                          color: AppThemes.getSecondaryTextColor(context),
                          fontSize: 12)),
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
              child: Text(isActive ? 'актив' : 'инактив',
                  style: TextStyle(
                      fontSize: 12, color: AppThemes.getTextColor(context))),
            )),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _editProduct(doc.id, data),
                    tooltip: 'Бүтээгдэхүүн өөрчлөх',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteProduct(doc.id, name),
                    tooltip: 'Бүтээгдэхүүн устгах',
                  ),
                ],
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }

  String _formatCurrency(double value) {
    return '₮${value.toStringAsFixed(0)}';
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    if (timestamp is Timestamp) {
      final dt = timestamp.toDate();
      return '${dt.month}/${dt.day}/${dt.year}';
    }
    return '';
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  num _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? 0;
    return 0;
  }

  void _editProduct(String productId, Map<String, dynamic> productData) {
    showDialog(
      context: context,
      builder: (_) => EditProductDialog(
        productId: productId,
        productData: productData,
      ),
    );
  }

  void _deleteProduct(String productId, String productName) {
    showDialog(
      context: context,
      builder: (_) => DeleteConfirmationDialog(
        productName: productName,
        onConfirm: () => _confirmDeleteProduct(productId, productName),
      ),
    );
  }

  Future<void> _confirmDeleteProduct(
      String productId, String productName) async {
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('"$productName" бүтээгдэхүүн амжилттай устгалаа')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Алдаа гарлаа: $e')),
        );
      }
    }
  }
}
