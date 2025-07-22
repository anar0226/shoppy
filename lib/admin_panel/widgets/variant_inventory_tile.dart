import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../features/products/models/product_model.dart';

class VariantInventoryTile extends StatefulWidget {
  final ProductModel product;
  final ProductVariant variant;
  final Function(String variantName, String option, int newStock) onAdjustStock;

  const VariantInventoryTile({
    super.key,
    required this.product,
    required this.variant,
    required this.onAdjustStock,
  });

  @override
  State<VariantInventoryTile> createState() => _VariantInventoryTileState();
}

class _VariantInventoryTileState extends State<VariantInventoryTile> {
  final Map<String, TextEditingController> _stockControllers = {};
  final Map<String, bool> _isEditing = {};

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  @override
  void dispose() {
    for (final controller in _stockControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeControllers() {
    for (final option in widget.variant.options) {
      final stock = widget.variant.getStockForOption(option);
      _stockControllers[option] = TextEditingController(text: stock.toString());
      _isEditing[option] = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tune,
                size: 20,
                color: Colors.blue.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                widget.variant.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              _buildInventoryToggle(),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.variant.trackInventory)
            _buildVariantOptions()
          else
            _buildUnlimitedStockInfo(),
        ],
      ),
    );
  }

  Widget _buildInventoryToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: widget.variant.trackInventory
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.variant.trackInventory ? Colors.green : Colors.grey,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.variant.trackInventory
                ? Icons.check_circle
                : Icons.all_inclusive,
            size: 16,
            color: widget.variant.trackInventory ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            widget.variant.trackInventory ? 'Tracked' : 'Unlimited',
            style: TextStyle(
              fontSize: 12,
              color: widget.variant.trackInventory ? Colors.green : Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantOptions() {
    return Column(
      children: widget.variant.options.map((option) {
        return _buildVariantOptionTile(option);
      }).toList(),
    );
  }

  Widget _buildVariantOptionTile(String option) {
    final stock = widget.variant.getStockForOption(option);
    final isEditing = _isEditing[option] ?? false;
    final controller = _stockControllers[option]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Option name
          Expanded(
            flex: 2,
            child: Text(
              option,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Stock display/edit
          Expanded(
            flex: 1,
            child: Row(
              children: [
                if (isEditing) ...[
                  Expanded(
                    child: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStockColor(stock).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _getStockColor(stock)),
                    ),
                    child: Text(
                      '$stock units',
                      style: TextStyle(
                        fontSize: 12,
                        color: _getStockColor(stock),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Action buttons
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isEditing) ...[
                IconButton(
                  onPressed: () => _saveStockChange(option),
                  icon: const Icon(Icons.check, size: 20),
                  color: Colors.green,
                  tooltip: 'Save',
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
                IconButton(
                  onPressed: () => _cancelEdit(option),
                  icon: const Icon(Icons.close, size: 20),
                  color: Colors.red,
                  tooltip: 'Cancel',
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ] else ...[
                IconButton(
                  onPressed: () => _startEditing(option),
                  icon: const Icon(Icons.edit, size: 18),
                  color: Colors.blue,
                  tooltip: 'Edit Stock',
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
                IconButton(
                  onPressed: () => _showQuickActions(option),
                  icon: const Icon(Icons.more_vert, size: 18),
                  color: Colors.grey,
                  tooltip: 'Quick Actions',
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnlimitedStockInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.all_inclusive,
            size: 24,
            color: Colors.blue.shade600,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'This variant has unlimited stock. No inventory tracking is enabled.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStockColor(int stock) {
    if (stock == 0) return Colors.grey;
    if (stock <= 2) return Colors.red;
    if (stock <= 5) return Colors.orange;
    return Colors.green;
  }

  void _startEditing(String option) {
    setState(() {
      _isEditing[option] = true;
    });
  }

  void _cancelEdit(String option) {
    setState(() {
      _isEditing[option] = false;
      // Reset controller to original value
      final stock = widget.variant.getStockForOption(option);
      _stockControllers[option]!.text = stock.toString();
    });
  }

  void _saveStockChange(String option) {
    final newStockText = _stockControllers[option]!.text;
    final newStock = int.tryParse(newStockText);

    if (newStock == null || newStock < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid stock number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isEditing[option] = false;
    });

    widget.onAdjustStock(widget.variant.name, option, newStock);
  }

  void _showQuickActions(String option) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildQuickActionsSheet(option),
    );
  }

  Widget _buildQuickActionsSheet(String option) {
    final currentStock = widget.variant.getStockForOption(option);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flash_on, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                'Quick Actions - $option',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Current stock info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.inventory, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Current Stock: $currentStock units',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Quick action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _quickAdjustStock(option, currentStock + 10);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('+10'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _quickAdjustStock(option, currentStock + 50);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('+50'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 8),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: currentStock >= 10
                      ? () {
                          Navigator.pop(context);
                          _quickAdjustStock(option, currentStock - 10);
                        }
                      : null,
                  icon: const Icon(Icons.remove),
                  label: const Text('-10'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _quickAdjustStock(option, 0);
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Set to 0'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Custom amount input
          TextField(
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              labelText: 'Set custom amount',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.edit),
            ),
            onSubmitted: (value) {
              final newStock = int.tryParse(value);
              if (newStock != null && newStock >= 0) {
                Navigator.pop(context);
                _quickAdjustStock(option, newStock);
              }
            },
          ),

          const SizedBox(height: 16),

          // Cancel button
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }

  void _quickAdjustStock(String option, int newStock) {
    if (newStock < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stock cannot be negative'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Update the controller
    _stockControllers[option]!.text = newStock.toString();

    // Call the adjustment function
    widget.onAdjustStock(widget.variant.name, option, newStock);

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Stock updated for $option: $newStock units'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
