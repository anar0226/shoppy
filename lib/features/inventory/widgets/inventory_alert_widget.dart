import 'package:flutter/material.dart';
import '../../../core/services/inventory_service.dart';

class InventoryAlertWidget extends StatefulWidget {
  final String storeId;
  final bool showDetailedView;

  const InventoryAlertWidget({
    Key? key,
    required this.storeId,
    this.showDetailedView = false,
  }) : super(key: key);

  @override
  State<InventoryAlertWidget> createState() => _InventoryAlertWidgetState();
}

class _InventoryAlertWidgetState extends State<InventoryAlertWidget> {
  List<String> _lowStockProducts = [];
  List<Map<String, dynamic>> _reorderProducts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        InventoryService.getProductsWithLowStock(storeId: widget.storeId),
        InventoryService.getProductsNeedingReorder(storeId: widget.storeId),
      ]);

      setState(() {
        _lowStockProducts = results[0].cast<String>();
        _reorderProducts = (results[1] as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      debugPrint('Error loading inventory alerts: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final totalAlerts = _lowStockProducts.length + _reorderProducts.length;

    if (totalAlerts == 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('All inventory levels are healthy'),
            ],
          ),
        ),
      );
    }

    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Text(
                  'Inventory Alerts ($totalAlerts)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_lowStockProducts.isNotEmpty)
              _buildAlertRow(
                'Low Stock',
                _lowStockProducts.length,
                Colors.red,
                Icons.inventory,
              ),
            if (_reorderProducts.isNotEmpty)
              _buildAlertRow(
                'Needs Reorder',
                _reorderProducts.length,
                Colors.orange,
                Icons.refresh,
              ),
            if (widget.showDetailedView && totalAlerts > 0) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _showDetailedAlerts(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                ),
                child: const Text('View Details'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAlertRow(String title, int count, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text('$title: $count products'),
        ],
      ),
    );
  }

  void _showDetailedAlerts(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Inventory Alerts',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        const TabBar(
                          labelColor: Colors.orange,
                          tabs: [
                            Tab(text: 'Low Stock'),
                            Tab(text: 'Reorder'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildLowStockList(scrollController),
                              _buildReorderList(scrollController),
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
        },
      ),
    );
  }

  Widget _buildLowStockList(ScrollController scrollController) {
    if (_lowStockProducts.isEmpty) {
      return const Center(child: Text('No low stock products'));
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: _lowStockProducts.length,
      itemBuilder: (context, index) {
        final productId = _lowStockProducts[index];
        return LowStockProductTile(productId: productId);
      },
    );
  }

  Widget _buildReorderList(ScrollController scrollController) {
    if (_reorderProducts.isEmpty) {
      return const Center(child: Text('No products need reordering'));
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: _reorderProducts.length,
      itemBuilder: (context, index) {
        final reorderData = _reorderProducts[index];
        return ReorderProductTile(reorderData: reorderData);
      },
    );
  }
}

class LowStockProductTile extends StatelessWidget {
  final String productId;

  const LowStockProductTile({
    Key? key,
    required this.productId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _getProductData(productId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ListTile(
            leading: CircularProgressIndicator(),
            title: Text('Loading...'),
          );
        }

        if (!snapshot.hasData) {
          return const ListTile(
            leading: Icon(Icons.error),
            title: Text('Product not found'),
          );
        }

        final product = snapshot.data!;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: product['image'] != null
                ? Image.network(
                    product['image'],
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  )
                : const Icon(Icons.inventory),
            title: Text(product['name'] ?? 'Unknown Product'),
            subtitle: Text('Stock: ${product['stock']} (Low)'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'LOW',
                style: TextStyle(
                  color: Colors.red[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            onTap: () => _showQuickActions(context, product),
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _getProductData(String productId) async {
    try {
      // This would typically fetch from Firestore
      // For now, return mock data
      return {
        'id': productId,
        'name': 'Product $productId',
        'stock': 2,
        'image': null,
      };
    } catch (e) {
      return null;
    }
  }

  void _showQuickActions(BuildContext context, Map<String, dynamic> product) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              product['name'],
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Quick Restock'),
              onTap: () {
                Navigator.pop(context);
                _showRestockDialog(context, product);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Product'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to product edit page
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off),
              title: const Text('Hide Product'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement hide product
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRestockDialog(BuildContext context, Map<String, dynamic> product) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restock ${product['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current Stock: ${product['stock']}'),
            const SizedBox(height: 16),
            TextFormField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Add Quantity',
                hintText: 'Enter quantity to add',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement restock functionality
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Restock completed')),
              );
            },
            child: const Text('Restock'),
          ),
        ],
      ),
    );
  }
}

class ReorderProductTile extends StatelessWidget {
  final Map<String, dynamic> reorderData;

  const ReorderProductTile({
    Key? key,
    required this.reorderData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.refresh, color: Colors.orange),
        title: Text(reorderData['productName'] ?? 'Unknown Product'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current: ${reorderData['currentStock']}'),
            Text('Reorder Point: ${reorderData['reorderPoint']}'),
            Text('Suggested: ${reorderData['reorderQuantity']}'),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'REORDER',
            style: TextStyle(
              color: Colors.orange[700],
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        onTap: () => _showReorderDialog(context),
      ),
    );
  }

  void _showReorderDialog(BuildContext context) {
    final controller = TextEditingController(
      text: reorderData['reorderQuantity'].toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reorder ${reorderData['productName']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current Stock: ${reorderData['currentStock']}'),
            Text('Reorder Point: ${reorderData['reorderPoint']}'),
            const SizedBox(height: 16),
            TextFormField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Reorder Quantity',
                hintText: 'Enter quantity to order',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement reorder functionality
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reorder initiated')),
              );
            },
            child: const Text('Place Order'),
          ),
        ],
      ),
    );
  }
}

class InventoryHealthIndicator extends StatefulWidget {
  final String storeId;

  const InventoryHealthIndicator({
    Key? key,
    required this.storeId,
  }) : super(key: key);

  @override
  State<InventoryHealthIndicator> createState() =>
      _InventoryHealthIndicatorState();
}

class _InventoryHealthIndicatorState extends State<InventoryHealthIndicator> {
  double _healthScore = 0.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _calculateHealthScore();
  }

  Future<void> _calculateHealthScore() async {
    setState(() => _isLoading = true);

    try {
      final report = await InventoryService.getInventoryValuation(
        storeId: widget.storeId,
      );

      final totalProducts = report['totalProducts'] as int? ?? 0;
      final outOfStock = report['outOfStockCount'] as int? ?? 0;
      final lowStock = report['lowStockCount'] as int? ?? 0;

      final score = totalProducts > 0
          ? ((totalProducts - outOfStock - lowStock) / totalProducts)
          : 0.0;

      setState(() {
        _healthScore = score;
      });
    } catch (e) {
      debugPrint('Error calculating health score: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    Color scoreColor = Colors.green;
    String scoreText = 'Excellent';

    if (_healthScore < 0.5) {
      scoreColor = Colors.red;
      scoreText = 'Poor';
    } else if (_healthScore < 0.75) {
      scoreColor = Colors.orange;
      scoreText = 'Fair';
    } else if (_healthScore < 0.9) {
      scoreColor = Colors.blue;
      scoreText = 'Good';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Inventory Health',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: _healthScore,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '${(_healthScore * 100).round()}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: scoreColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              scoreText,
              style: TextStyle(
                color: scoreColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
