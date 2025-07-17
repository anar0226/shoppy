import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/inventory_service.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../products/models/product_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../../../core/services/production_logger.dart';
import '../../../core/services/error_recovery_service.dart';

class InventoryManagementPage extends StatefulWidget {
  final String storeId;

  const InventoryManagementPage({
    Key? key,
    required this.storeId,
  }) : super(key: key);

  @override
  State<InventoryManagementPage> createState() =>
      _InventoryManagementPageState();
}

class _InventoryManagementPageState extends State<InventoryManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  Map<String, dynamic>? _inventoryReport;
  List<String> _lowStockProducts = [];
  List<Map<String, dynamic>> _reorderProducts = [];
  List<Map<String, dynamic>> _auditTrail = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadInventoryData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInventoryData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        InventoryService.getInventoryValuation(storeId: widget.storeId),
        InventoryService.getProductsWithLowStock(storeId: widget.storeId),
        InventoryService.getProductsNeedingReorder(storeId: widget.storeId),
        InventoryService.getInventoryMovementReport(storeId: widget.storeId),
      ]);

      setState(() {
        _inventoryReport = results[0] as Map<String, dynamic>?;
        _lowStockProducts = (results[1] as List).cast<String>();
        _reorderProducts = (results[2] as List).cast<Map<String, dynamic>>();
        _auditTrail =
            ((results[3] as Map<String, dynamic>)['movements'] as List?)
                    ?.cast<Map<String, dynamic>>() ??
                [];
      });
    } catch (e) {
      _showError('Failed to load inventory data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Management'),
        backgroundColor: const Color(0xFF1F226C),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Adjustments'),
            Tab(text: 'Alerts'),
            Tab(text: 'Analytics'),
            Tab(text: 'Audit Trail'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildAdjustmentsTab(),
                _buildAlertsTab(),
                _buildAnalyticsTab(),
                _buildAuditTrailTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    if (_inventoryReport == null) {
      return const Center(child: Text('No inventory data available'));
    }

    final report = _inventoryReport!;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Key Metrics Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Total Products',
                  '${report['totalProducts'] ?? 0}',
                  Icons.inventory,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Total Stock',
                  '${report['totalStock'] ?? 0}',
                  Icons.storage,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Total Value',
                  '₮${NumberFormat('#,###').format(report['totalValue'] ?? 0)}',
                  Icons.attach_money,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Low Stock',
                  '${report['lowStockCount'] ?? 0}',
                  Icons.warning,
                  Colors.red,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Category Breakdown
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Category Breakdown',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: _buildCategoryBreakdown(report['categoryBreakdown'] ?? {}),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdown(Map<String, dynamic> categoryData) {
    if (categoryData.isEmpty) {
      return const Center(child: Text('No category data available'));
    }

    return ListView.builder(
      itemCount: categoryData.length,
      itemBuilder: (context, index) {
        final category = categoryData.keys.elementAt(index);
        final data = categoryData[category] as Map<String, dynamic>;

        return Card(
          child: ListTile(
            title: Text(category),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Products: ${data['productCount']}'),
                Text('Stock: ${data['totalStock']}'),
                Text(
                    'Value: ₮${NumberFormat('#,###').format(data['totalValue'])}'),
              ],
            ),
            trailing: CircularProgressIndicator(
              value: (data['totalStock'] as int) /
                  (_inventoryReport!['totalStock'] as int),
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.blue.withOpacity(0.7),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdjustmentsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          ElevatedButton.icon(
            onPressed: () => _showManualAdjustmentDialog(),
            icon: const Icon(Icons.edit),
            label: const Text('Manual Adjustment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F226C),
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _showBulkUpdateDialog(),
            icon: const Icon(Icons.upload_file),
            label: const Text('Bulk Update'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Recent Adjustments',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _buildRecentAdjustments(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAdjustments() {
    final recentAdjustments = _auditTrail.take(10).toList();

    if (recentAdjustments.isEmpty) {
      return const Center(child: Text('No recent adjustments'));
    }

    return ListView.builder(
      itemCount: recentAdjustments.length,
      itemBuilder: (context, index) {
        final adjustment = recentAdjustments[index];
        final timestamp = (adjustment['timestamp'] as Timestamp?)?.toDate();

        return Card(
          child: ListTile(
            title: Text(adjustment['productName'] ?? 'Unknown Product'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Adjustment: ${adjustment['adjustment']}'),
                Text('Reason: ${adjustment['reason'] ?? 'No reason'}'),
                if (timestamp != null)
                  Text(
                      'Date: ${DateFormat('MMM dd, yyyy HH:mm').format(timestamp)}'),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (adjustment['adjustment'] as int) > 0
                    ? Colors.green
                    : Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                (adjustment['adjustment'] as int) > 0
                    ? '+${adjustment['adjustment']}'
                    : '${adjustment['adjustment']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlertsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Low Stock Alert
          Card(
            color: Colors.red[50],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(
                        'Low Stock Alert (${_lowStockProducts.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                      '${_lowStockProducts.length} products are running low on stock'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Reorder Alert
          Card(
            color: Colors.orange[50],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.refresh, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'Reorder Alert (${_reorderProducts.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                      '${_reorderProducts.length} products need to be reordered'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Product Lists
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    labelColor: Color(0xFF1F226C),
                    tabs: [
                      Tab(text: 'Low Stock'),
                      Tab(text: 'Reorder'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildLowStockList(),
                        _buildReorderList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockList() {
    if (_lowStockProducts.isEmpty) {
      return const Center(child: Text('No low stock products'));
    }

    return ListView.builder(
      itemCount: _lowStockProducts.length,
      itemBuilder: (context, index) {
        final productId = _lowStockProducts[index];

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('products')
              .doc(productId)
              .get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const ListTile(
                title: Text('Loading...'),
                leading: CircularProgressIndicator(),
              );
            }

            final product = ProductModel.fromFirestore(snapshot.data!);

            return Card(
              child: ListTile(
                leading: product.images.isNotEmpty
                    ? Image.network(
                        product.images.first,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      )
                    : const Icon(Icons.image_not_supported),
                title: Text(product.name),
                subtitle: Text('Stock: ${product.totalAvailableStock}'),
                trailing: ElevatedButton(
                  onPressed: () => _showQuickAdjustmentDialog(product),
                  child: const Text('Adjust'),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReorderList() {
    if (_reorderProducts.isEmpty) {
      return const Center(child: Text('No products need reordering'));
    }

    return ListView.builder(
      itemCount: _reorderProducts.length,
      itemBuilder: (context, index) {
        final reorderData = _reorderProducts[index];

        return Card(
          child: ListTile(
            title: Text(reorderData['productName'] ?? 'Unknown Product'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current Stock: ${reorderData['currentStock']}'),
                Text('Reorder Point: ${reorderData['reorderPoint']}'),
                Text('Suggested Quantity: ${reorderData['reorderQuantity']}'),
              ],
            ),
            trailing: ElevatedButton(
              onPressed: () => _showReorderDialog(reorderData),
              child: const Text('Reorder'),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsTab() {
    if (_inventoryReport == null) {
      return const Center(child: Text('No analytics data available'));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildAnalyticsCard(
                  'Avg Value/Product',
                  '₮${NumberFormat('#,###').format(_inventoryReport!['averageValuePerProduct'] ?? 0)}',
                  Icons.analytics,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAnalyticsCard(
                  'Out of Stock',
                  '${_inventoryReport!['outOfStockCount'] ?? 0}',
                  Icons.error,
                  Colors.red,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Inventory Health Score
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Inventory Health Score',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildHealthScore(),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Performance Metrics
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Performance Metrics',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(child: _buildPerformanceMetrics()),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthScore() {
    final totalProducts = _inventoryReport!['totalProducts'] as int;
    final outOfStock = _inventoryReport!['outOfStockCount'] as int;
    final lowStock = _inventoryReport!['lowStockCount'] as int;

    final healthScore = totalProducts > 0
        ? ((totalProducts - outOfStock - lowStock) / totalProducts * 100)
            .round()
        : 0;

    Color scoreColor = Colors.green;
    if (healthScore < 50) {
      scoreColor = Colors.red;
    } else if (healthScore < 75) {
      scoreColor = Colors.orange;
    }

    return Column(
      children: [
        LinearProgressIndicator(
          value: healthScore / 100,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
          minHeight: 8,
        ),
        const SizedBox(height: 8),
        Text(
          '$healthScore%',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: scoreColor,
          ),
        ),
        Text(
          _getHealthScoreDescription(healthScore),
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  String _getHealthScoreDescription(int score) {
    if (score >= 90) return 'Excellent inventory health';
    if (score >= 75) return 'Good inventory health';
    if (score >= 50) return 'Fair inventory health';
    return 'Poor inventory health - needs attention';
  }

  Widget _buildPerformanceMetrics() {
    final metrics = [
      {'label': 'Stock Turnover', 'value': 'N/A', 'trend': 'stable'},
      {'label': 'Days Sales Outstanding', 'value': 'N/A', 'trend': 'up'},
      {'label': 'Inventory Accuracy', 'value': '95%', 'trend': 'up'},
      {'label': 'Carrying Cost', 'value': '12%', 'trend': 'down'},
    ];

    return ListView.builder(
      itemCount: metrics.length,
      itemBuilder: (context, index) {
        final metric = metrics[index];

        return ListTile(
          title: Text(metric['label']!),
          subtitle: Text(metric['value']!),
          trailing: Icon(
            metric['trend'] == 'up'
                ? Icons.trending_up
                : metric['trend'] == 'down'
                    ? Icons.trending_down
                    : Icons.trending_flat,
            color: metric['trend'] == 'up'
                ? Colors.green
                : metric['trend'] == 'down'
                    ? Colors.red
                    : Colors.grey,
          ),
        );
      },
    );
  }

  Widget _buildAuditTrailTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _exportAuditTrail(),
                  icon: const Icon(Icons.download),
                  label: const Text('Export'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _filterAuditTrail(),
                  icon: const Icon(Icons.filter_list),
                  label: const Text('Filter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _buildAuditTrailList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditTrailList() {
    if (_auditTrail.isEmpty) {
      return const Center(child: Text('No audit trail data'));
    }

    return ListView.builder(
      itemCount: _auditTrail.length,
      itemBuilder: (context, index) {
        final entry = _auditTrail[index];
        final timestamp = (entry['timestamp'] as Timestamp?)?.toDate();

        return Card(
          child: ExpansionTile(
            title: Text(entry['productName'] ?? 'Unknown Product'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Type: ${entry['type'] ?? 'Unknown'}'),
                if (timestamp != null)
                  Text(
                      'Date: ${DateFormat('MMM dd, yyyy HH:mm').format(timestamp)}'),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (entry['adjustment'] as int) > 0
                    ? Colors.green
                    : Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                (entry['adjustment'] as int) > 0
                    ? '+${entry['adjustment']}'
                    : '${entry['adjustment']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (entry['previousStock'] != null)
                      Text('Previous Stock: ${entry['previousStock']}'),
                    if (entry['newStock'] != null)
                      Text('New Stock: ${entry['newStock']}'),
                    if (entry['reason'] != null)
                      Text('Reason: ${entry['reason']}'),
                    if (entry['notes'] != null)
                      Text('Notes: ${entry['notes']}'),
                    if (entry['userId'] != null)
                      Text('User: ${entry['userId']}'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showManualAdjustmentDialog() {
    showDialog(
      context: context,
      builder: (context) => ManualAdjustmentDialog(
        storeId: widget.storeId,
        onAdjustmentMade: () {
          _loadInventoryData();
          _showSuccess('Inventory adjustment completed successfully');
        },
      ),
    );
  }

  void _showBulkUpdateDialog() {
    showDialog(
      context: context,
      builder: (context) => BulkUpdateDialog(
        storeId: widget.storeId,
        onUpdateComplete: () {
          _loadInventoryData();
          _showSuccess('Bulk update completed successfully');
        },
      ),
    );
  }

  void _showQuickAdjustmentDialog(ProductModel product) {
    showDialog(
      context: context,
      builder: (context) => QuickAdjustmentDialog(
        product: product,
        onAdjustmentMade: () {
          _loadInventoryData();
          _showSuccess('Quick adjustment completed');
        },
      ),
    );
  }

  void _showReorderDialog(Map<String, dynamic> reorderData) {
    showDialog(
      context: context,
      builder: (context) => ReorderDialog(
        reorderData: reorderData,
        onReorderComplete: () {
          _loadInventoryData();
          _showSuccess('Reorder process initiated');
        },
      ),
    );
  }

  void _exportAuditTrail() {
    // TODO: Implement export functionality
    _showSuccess('Export feature coming soon');
  }

  void _filterAuditTrail() {
    // TODO: Implement filter functionality
    _showSuccess('Filter feature coming soon');
  }
}

// Dialog widgets for various inventory operations
class ManualAdjustmentDialog extends StatefulWidget {
  final String storeId;
  final VoidCallback onAdjustmentMade;

  const ManualAdjustmentDialog({
    Key? key,
    required this.storeId,
    required this.onAdjustmentMade,
  }) : super(key: key);

  @override
  State<ManualAdjustmentDialog> createState() => _ManualAdjustmentDialogState();
}

class _ManualAdjustmentDialogState extends State<ManualAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _productController = TextEditingController();
  final _adjustmentController = TextEditingController();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = false;
  ProductModel? _selectedProduct;

  @override
  void dispose() {
    _productController.dispose();
    _adjustmentController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manual Inventory Adjustment'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _productController,
                decoration: const InputDecoration(
                  labelText: 'Product Name or SKU',
                  hintText: 'Search for product...',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a product name or SKU';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _adjustmentController,
                decoration: const InputDecoration(
                  labelText: 'Adjustment Amount',
                  hintText: 'Enter positive or negative number',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an adjustment amount';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'Why are you making this adjustment?',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please provide a reason for the adjustment';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  hintText: 'Additional notes...',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitAdjustment,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }

  Future<void> _submitAdjustment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid ?? '';

      // TODO: Implement product search and selection
      // For now, we'll use a placeholder product ID
      final productId = 'placeholder_product_id';

      final success = await InventoryService.adjustInventory(
        productId: productId,
        adjustment: int.parse(_adjustmentController.text),
        reason: _reasonController.text,
        userId: userId,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      if (success) {
        widget.onAdjustmentMade();
        Navigator.of(context).pop();
      } else {
        throw Exception('Failed to adjust inventory');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

class BulkUpdateDialog extends StatefulWidget {
  final String storeId;
  final VoidCallback onUpdateComplete;

  const BulkUpdateDialog({
    Key? key,
    required this.storeId,
    required this.onUpdateComplete,
  }) : super(key: key);

  @override
  State<BulkUpdateDialog> createState() => _BulkUpdateDialogState();
}

class _BulkUpdateDialogState extends State<BulkUpdateDialog> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bulk Inventory Update'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Upload a CSV file with the following columns:'),
          const SizedBox(height: 8),
          const Text(
            'productId, sku, stock',
            style: TextStyle(fontFamily: 'monospace'),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _selectFile,
            icon: const Icon(Icons.upload_file),
            label: const Text('Select CSV File'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Future<void> _selectFile() async {
    // TODO: Implement file picker and CSV processing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('File upload feature coming soon'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}

class QuickAdjustmentDialog extends StatefulWidget {
  final ProductModel product;
  final VoidCallback onAdjustmentMade;

  const QuickAdjustmentDialog({
    Key? key,
    required this.product,
    required this.onAdjustmentMade,
  }) : super(key: key);

  @override
  State<QuickAdjustmentDialog> createState() => _QuickAdjustmentDialogState();
}

class _QuickAdjustmentDialogState extends State<QuickAdjustmentDialog> {
  final _adjustmentController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _adjustmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Adjust Stock: ${widget.product.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Current Stock: ${widget.product.totalAvailableStock}'),
          const SizedBox(height: 16),
          TextFormField(
            controller: _adjustmentController,
            decoration: const InputDecoration(
              labelText: 'Adjustment Amount',
              hintText: 'Enter positive or negative number',
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitQuickAdjustment,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Adjust'),
        ),
      ],
    );
  }

  Future<void> _submitQuickAdjustment() async {
    if (_adjustmentController.text.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid ?? '';

      final success = await InventoryService.adjustInventory(
        productId: widget.product.id,
        adjustment: int.parse(_adjustmentController.text),
        reason: 'Quick adjustment',
        userId: userId,
      );

      if (success) {
        widget.onAdjustmentMade();
        Navigator.of(context).pop();
      } else {
        throw Exception('Failed to adjust inventory');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

class ReorderDialog extends StatefulWidget {
  final Map<String, dynamic> reorderData;
  final VoidCallback onReorderComplete;

  const ReorderDialog({
    Key? key,
    required this.reorderData,
    required this.onReorderComplete,
  }) : super(key: key);

  @override
  State<ReorderDialog> createState() => _ReorderDialogState();
}

class _ReorderDialogState extends State<ReorderDialog> {
  final _quantityController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _quantityController.text = widget.reorderData['reorderQuantity'].toString();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Reorder: ${widget.reorderData['productName']}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Current Stock: ${widget.reorderData['currentStock']}'),
          Text('Reorder Point: ${widget.reorderData['reorderPoint']}'),
          const SizedBox(height: 16),
          TextFormField(
            controller: _quantityController,
            decoration: const InputDecoration(
              labelText: 'Reorder Quantity',
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitReorder,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Reorder'),
        ),
      ],
    );
  }

  Future<void> _submitReorder() async {
    if (_quantityController.text.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid ?? '';

      final success = await InventoryService.adjustInventory(
        productId: widget.reorderData['productId'],
        adjustment: int.parse(_quantityController.text),
        reason: 'Reorder - Stock replenishment',
        userId: userId,
        notes: 'Automatic reorder based on reorder point',
      );

      if (success) {
        widget.onReorderComplete();
        Navigator.of(context).pop();
      } else {
        throw Exception('Failed to process reorder');
      }
    } catch (error, stackTrace) {
      // Log the error with full context
      await ProductionLogger.instance.error(
        'Inventory reorder failed',
        error: error,
        stackTrace: stackTrace,
        context: {
          'operation': 'inventory_reorder',
          'productId': widget.reorderData['productId'],
          'userId': auth.FirebaseAuth.instance.currentUser?.uid,
          'errorType': ErrorRecoveryService.instance.getErrorMessage(error),
        },
      );

      // Show user-friendly error message
      if (mounted) {
        final userMessage =
            ErrorRecoveryService.instance.getErrorMessage(error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Дахин оролдох',
              textColor: Colors.white,
              onPressed: () => _submitReorder(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
