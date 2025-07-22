import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../auth/auth_service.dart';
import '../../features/products/models/product_model.dart';
import '../../core/services/inventory_service.dart';

class InventoryAdjustmentDialog extends StatefulWidget {
  final ProductModel product;
  final VoidCallback? onAdjustmentComplete;

  const InventoryAdjustmentDialog({
    super.key,
    required this.product,
    this.onAdjustmentComplete,
  });

  @override
  State<InventoryAdjustmentDialog> createState() =>
      _InventoryAdjustmentDialogState();
}

class _InventoryAdjustmentDialogState extends State<InventoryAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _adjustmentController = TextEditingController();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();

  String _adjustmentType = 'add';
  String _selectedReason = 'manual_adjustment';
  Map<String, String>? _selectedVariants;
  bool _isLoading = false;

  final List<String> _reasonOptions = [
    'manual_adjustment',
    'restock',
    'damaged',
    'returned',
    'promotion',
    'inventory_count',
    'other',
  ];

  @override
  void dispose() {
    _adjustmentController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildProductInfo(),
              const SizedBox(height: 24),
              _buildVariantSelector(),
              const SizedBox(height: 24),
              _buildAdjustmentSection(),
              const SizedBox(height: 24),
              _buildReasonSection(),
              const SizedBox(height: 24),
              _buildNotesSection(),
              const SizedBox(height: 32),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.tune, size: 28, color: Colors.blue),
        const SizedBox(width: 12),
        const Text(
          'Inventory Adjustment',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  Widget _buildProductInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade200,
            ),
            child: widget.product.images.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      widget.product.images.first,
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
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.product.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Category: ${widget.product.category}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Current Stock: ${widget.product.totalAvailableStock} units',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantSelector() {
    if (widget.product.variants.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Variant Selection',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select specific variant options to adjust:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              ...widget.product.variants.map((variant) {
                return _buildVariantDropdown(variant);
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVariantDropdown(ProductVariant variant) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              variant.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              value: _selectedVariants?[variant.name],
              onChanged: (value) {
                setState(() {
                  _selectedVariants ??= {};
                  if (value != null) {
                    _selectedVariants![variant.name] = value;
                  } else {
                    _selectedVariants!.remove(variant.name);
                  }
                });
              },
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Select option'),
                ),
                ...variant.options.map((option) {
                  final stock = variant.getStockForOption(option);
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text('$option ($stock units)'),
                  );
                }).toList(),
              ],
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Adjustment Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _adjustmentType,
                onChanged: (value) {
                  setState(() {
                    _adjustmentType = value!;
                  });
                },
                items: const [
                  DropdownMenuItem(
                    value: 'add',
                    child: Text('Add Stock'),
                  ),
                  DropdownMenuItem(
                    value: 'remove',
                    child: Text('Remove Stock'),
                  ),
                  DropdownMenuItem(
                    value: 'set',
                    child: Text('Set Stock Level'),
                  ),
                ],
                decoration: const InputDecoration(
                  labelText: 'Adjustment Type',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _adjustmentController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  labelText:
                      _adjustmentType == 'set' ? 'New Stock Level' : 'Quantity',
                  border: const OutlineInputBorder(),
                  suffixText: 'units',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a quantity';
                  }
                  final quantity = int.tryParse(value);
                  if (quantity == null || quantity <= 0) {
                    return 'Please enter a valid quantity';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildStockPreview(),
      ],
    );
  }

  Widget _buildStockPreview() {
    final adjustmentText = _adjustmentController.text;
    final adjustment = int.tryParse(adjustmentText);

    if (adjustment == null) {
      return const SizedBox.shrink();
    }

    int currentStock = widget.product.totalAvailableStock;
    int newStock;

    switch (_adjustmentType) {
      case 'add':
        newStock = currentStock + adjustment;
        break;
      case 'remove':
        newStock = (currentStock - adjustment).clamp(0, 999999);
        break;
      case 'set':
        newStock = adjustment;
        break;
      default:
        newStock = currentStock;
    }

    final difference = newStock - currentStock;
    final isIncrease = difference > 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isIncrease ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isIncrease ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isIncrease ? Icons.trending_up : Icons.trending_down,
            color: isIncrease ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(
            'Stock Preview: $currentStock → $newStock units',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            '${isIncrease ? '+' : ''}$difference',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isIncrease ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reason for Adjustment',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedReason,
          onChanged: (value) {
            setState(() {
              _selectedReason = value!;
            });
          },
          items: _reasonOptions.map((reason) {
            return DropdownMenuItem<String>(
              value: reason,
              child: Text(_getReasonDisplayName(reason)),
            );
          }).toList(),
          decoration: const InputDecoration(
            labelText: 'Select Reason',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Additional Notes (Optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter any additional notes about this adjustment...',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _performAdjustment,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Apply Adjustment'),
          ),
        ),
      ],
    );
  }

  String _getReasonDisplayName(String reason) {
    switch (reason) {
      case 'manual_adjustment':
        return 'Manual Adjustment';
      case 'restock':
        return 'Restock';
      case 'damaged':
        return 'Damaged Items';
      case 'returned':
        return 'Returned Items';
      case 'promotion':
        return 'Promotion/Sale';
      case 'inventory_count':
        return 'Inventory Count';
      case 'other':
        return 'Other';
      default:
        return reason;
    }
  }

  Future<void> _performAdjustment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = AuthService.instance.currentUser;
    if (user == null) {
      _showErrorMessage('User not authenticated');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final adjustmentText = _adjustmentController.text;
      final adjustmentValue = int.parse(adjustmentText);

      int actualAdjustment;

      switch (_adjustmentType) {
        case 'add':
          actualAdjustment = adjustmentValue;
          break;
        case 'remove':
          actualAdjustment = -adjustmentValue;
          break;
        case 'set':
          final currentStock = _selectedVariants != null
              ? _getCurrentVariantStock()
              : widget.product.stock;
          actualAdjustment = adjustmentValue - currentStock;
          break;
        default:
          actualAdjustment = 0;
      }

      final success = await InventoryService.adjustInventory(
        productId: widget.product.id,
        adjustment: actualAdjustment,
        reason: _selectedReason,
        userId: user.uid,
        selectedVariants: _selectedVariants,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (success) {
        if (mounted) {
          _showSuccessMessage('Inventory adjusted successfully');
          widget.onAdjustmentComplete?.call();
          Navigator.pop(context);
        }
      } else {
        if (context.mounted) {
          _showErrorMessage('Failed to adjust inventory');
        }
      }
    } catch (e) {
      _showErrorMessage('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  int _getCurrentVariantStock() {
    if (_selectedVariants == null || _selectedVariants!.isEmpty) {
      return widget.product.stock;
    }

    for (final variant in widget.product.variants) {
      final selectedOption = _selectedVariants![variant.name];
      if (selectedOption != null) {
        return variant.getStockForOption(selectedOption);
      }
    }

    return widget.product.stock;
  }

  void _showSuccessMessage(String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showErrorMessage(String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
