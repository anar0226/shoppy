import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import '../auth/auth_service.dart';
import '../../features/products/models/product_model.dart';
import '../../features/inventory/providers/inventory_provider.dart';
import '../../features/inventory/services/low_stock_notification_service.dart';
import '../../core/services/inventory_service.dart';
import 'inventory_adjustment_dialog.dart';
import 'variant_inventory_tile.dart';

class InventoryManagementWidget extends StatefulWidget {
  const InventoryManagementWidget({super.key});

  @override
  State<InventoryManagementWidget> createState() =>
      _InventoryManagementWidgetState();
}

class _InventoryManagementWidgetState extends State<InventoryManagementWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final LowStockNotificationService _notificationService =
      LowStockNotificationService();

  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _inventoryFilter = 'All';

  final List<String> _categories = [
    'All',
    'Low Stock',
    'Critical Stock',
    'Out of Stock'
  ];
  final List<String> _inventoryFilters = [
    'All',
    'Simple Products',
    'Variant Products'
  ];

  @override
  void initState() {
    super.initState();
    _initializeInventoryManagement();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _initializeInventoryManagement() {
    // Initialize inventory provider
    final inventoryProvider = context.read<InventoryProvider>();
    if (!inventoryProvider.isInitialized) {
      inventoryProvider.initialize();
    }

    // Initialize notification service
    _notificationService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (context, inventoryProvider, child) {
        return Column(
          children: [
            _buildHeader(),
            _buildFilters(),
            _buildInventoryStats(inventoryProvider),
            Expanded(
              child: _buildInventoryList(inventoryProvider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.inventory, size: 32, color: Colors.blue),
          const SizedBox(width: 16),
          const Text(
            'Inventory Management',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _showBulkUpdateDialog,
            icon: const Icon(Icons.upload, size: 20),
            label: const Text('Bulk Update'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _exportInventoryReport,
            icon: const Icon(Icons.download, size: 20),
            label: const Text('Export'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              value: _selectedCategory,
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                });
              },
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              decoration: InputDecoration(
                labelText: 'Stock Status',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              value: _inventoryFilter,
              onChanged: (value) {
                setState(() {
                  _inventoryFilter = value!;
                });
              },
              items: _inventoryFilters.map((filter) {
                return DropdownMenuItem(
                  value: filter,
                  child: Text(filter),
                );
              }).toList(),
              decoration: InputDecoration(
                labelText: 'Product Type',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryStats(InventoryProvider inventoryProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Products',
              _getTotalProducts(inventoryProvider).toString(),
              Icons.inventory_2,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              'Low Stock',
              _getLowStockCount(inventoryProvider).toString(),
              Icons.warning,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              'Critical Stock',
              _getCriticalStockCount(inventoryProvider).toString(),
              Icons.error,
              Colors.red,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              'Out of Stock',
              _getOutOfStockCount(inventoryProvider).toString(),
              Icons.remove_circle,
              Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryList(InventoryProvider inventoryProvider) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getProductsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No products found'),
          );
        }

        final products = snapshot.data!.docs
            .map((doc) => ProductModel.fromFirestore(doc))
            .where(_filterProduct)
            .toList();

        if (products.isEmpty) {
          return const Center(
            child: Text('No products match your filters'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return _buildProductInventoryCard(product, inventoryProvider);
          },
        );
      },
    );
  }

  Widget _buildProductInventoryCard(
      ProductModel product, InventoryProvider inventoryProvider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade200,
          ),
          child: product.images.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    product.images.first,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.image, color: Colors.grey);
                    },
                  ),
                )
              : const Icon(Icons.image, color: Colors.grey),
        ),
        title: Text(
          product.name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category: ${product.category}'),
            const SizedBox(height: 4),
            _buildStockStatus(product),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _showInventoryAdjustmentDialog(product),
              icon: const Icon(Icons.edit, color: Colors.blue),
              tooltip: 'Adjust Inventory',
            ),
            IconButton(
              onPressed: () => _showInventoryHistory(product),
              icon: const Icon(Icons.history, color: Colors.green),
              tooltip: 'View History',
            ),
          ],
        ),
        children: [
          _buildInventoryDetails(product, inventoryProvider),
        ],
      ),
    );
  }

  Widget _buildStockStatus(ProductModel product) {
    Color statusColor;
    String statusText;

    if (product.totalAvailableStock == 0) {
      statusColor = Colors.grey;
      statusText = 'Out of Stock';
    } else if (product.totalAvailableStock <= 2) {
      statusColor = Colors.red;
      statusText = 'Critical Stock';
    } else if (product.totalAvailableStock <= 5) {
      statusColor = Colors.orange;
      statusText = 'Low Stock';
    } else {
      statusColor = Colors.green;
      statusText = 'In Stock';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: statusColor),
      ),
      child: Text(
        '$statusText (${product.totalAvailableStock})',
        style: TextStyle(
          color: statusColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInventoryDetails(
      ProductModel product, InventoryProvider inventoryProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (product.variants.isEmpty)
            _buildSimpleProductInventory(product)
          else
            _buildVariantInventory(product, inventoryProvider),
        ],
      ),
    );
  }

  Widget _buildSimpleProductInventory(ProductModel product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Simple Product Inventory',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Stock',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${product.stock} units',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () => _showInventoryAdjustmentDialog(product),
                child: const Text('Adjust Stock'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVariantInventory(
      ProductModel product, InventoryProvider inventoryProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Variant Inventory',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: product.variants.map((variant) {
            return VariantInventoryTile(
              product: product,
              variant: variant,
              onAdjustStock: (variantName, option, newStock) {
                _adjustVariantStock(product, variantName, option, newStock);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Stream<QuerySnapshot> _getProductsStream() {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('products')
        .where('ownerId', isEqualTo: user.uid)
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots();
  }

  bool _filterProduct(ProductModel product) {
    // Search filter
    if (_searchQuery.isNotEmpty) {
      if (!product.name.toLowerCase().contains(_searchQuery.toLowerCase()) &&
          !product.category
              .toLowerCase()
              .contains(_searchQuery.toLowerCase())) {
        return false;
      }
    }

    // Stock status filter
    if (_selectedCategory != 'All') {
      switch (_selectedCategory) {
        case 'Low Stock':
          if (product.totalAvailableStock > 5 ||
              product.totalAvailableStock <= 2) {
            return false;
          }
          break;
        case 'Critical Stock':
          if (product.totalAvailableStock > 2 ||
              product.totalAvailableStock == 0) {
            return false;
          }
          break;
        case 'Out of Stock':
          if (product.totalAvailableStock > 0) {
            return false;
          }
          break;
      }
    }

    // Product type filter
    if (_inventoryFilter != 'All') {
      switch (_inventoryFilter) {
        case 'Simple Products':
          if (product.variants.isNotEmpty) {
            return false;
          }
          break;
        case 'Variant Products':
          if (product.variants.isEmpty) {
            return false;
          }
          break;
      }
    }

    return true;
  }

  int _getTotalProducts(InventoryProvider inventoryProvider) {
    // Calculate total products from inventory states
    int total = 0;
    for (final storeInventory in inventoryProvider.inventoryStates.values) {
      total += storeInventory.length.toInt();
    }
    return total;
  }

  int _getLowStockCount(InventoryProvider inventoryProvider) {
    int count = 0;
    for (final storeInventory in inventoryProvider.inventoryStates.values) {
      for (final productInventory in storeInventory.values) {
        final stock = productInventory['totalAvailableStock'] as int? ?? 0;
        if (stock > 2 && stock <= 5) {
          count++;
        }
      }
    }
    return count;
  }

  int _getCriticalStockCount(InventoryProvider inventoryProvider) {
    int count = 0;
    for (final storeInventory in inventoryProvider.inventoryStates.values) {
      for (final productInventory in storeInventory.values) {
        final stock = productInventory['totalAvailableStock'] as int? ?? 0;
        if (stock > 0 && stock <= 2) {
          count++;
        }
      }
    }
    return count;
  }

  int _getOutOfStockCount(InventoryProvider inventoryProvider) {
    int count = 0;
    for (final storeInventory in inventoryProvider.inventoryStates.values) {
      for (final productInventory in storeInventory.values) {
        final stock = productInventory['totalAvailableStock'] as int? ?? 0;
        if (stock == 0) {
          count++;
        }
      }
    }
    return count;
  }

  void _showInventoryAdjustmentDialog(ProductModel product) {
    showDialog(
      context: context,
      builder: (context) => InventoryAdjustmentDialog(
        product: product,
        onAdjustmentComplete: () {
          // Refresh the inventory data
          setState(() {});
        },
      ),
    );
  }

  void _showInventoryHistory(ProductModel product) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          width: 600,
          height: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.history, size: 24, color: Colors.blue),
                  const SizedBox(width: 12),
                  Text(
                    'Inventory History - ${product.name}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _buildInventoryHistoryList(product),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryHistoryList(ProductModel product) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('inventory_audit_log')
          .where('productId', isEqualTo: product.id)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No inventory history found'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildHistoryItem(data);
          },
        );
      },
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> data) {
    final adjustment = data['adjustment'] as int? ?? 0;
    final reason = data['reason'] as String? ?? '';
    final timestamp =
        (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final previousStock = data['previousStock'] as int? ?? 0;
    final newStock = data['newStock'] as int? ?? 0;

    return ListTile(
      leading: Icon(
        adjustment > 0 ? Icons.add_circle : Icons.remove_circle,
        color: adjustment > 0 ? Colors.green : Colors.red,
      ),
      title: Text(
        '${adjustment > 0 ? '+' : ''}$adjustment units',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reason: $reason'),
          Text('Stock: $previousStock → $newStock'),
          Text('Date: ${_formatDate(timestamp)}'),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _adjustVariantStock(
    ProductModel product,
    String variantName,
    String option,
    int newStock,
  ) async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return;

      final success = await InventoryService.adjustInventory(
        productId: product.id,
        adjustment: newStock - _getVariantStock(product, variantName, option),
        reason: 'manual_adjustment',
        userId: user.uid,
        selectedVariants: {variantName: option},
        notes: 'Adjusted via admin panel',
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Inventory adjusted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to adjust inventory'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  int _getVariantStock(
      ProductModel product, String variantName, String option) {
    final variant = product.variants.firstWhere(
      (v) => v.name == variantName,
      orElse: () => ProductVariant(
        name: '',
        options: [],
        priceAdjustments: {},
        stockByOption: {},
      ),
    );
    return variant.getStockForOption(option);
  }

  void _showBulkUpdateDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Bulk Inventory Update',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Upload a CSV file with inventory adjustments',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Bulk update feature coming soon!'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload CSV'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _exportInventoryReport() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Export feature coming soon!'),
        ),
      );
    }
  }
}
