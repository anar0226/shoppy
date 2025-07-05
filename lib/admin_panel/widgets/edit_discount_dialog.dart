import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/auth_service.dart';
import '../../features/discounts/models/discount_model.dart';
import '../../features/discounts/services/discount_service.dart';
import '../../core/utils/type_utils.dart';

class EditDiscountDialog extends StatefulWidget {
  final String discountId;
  final DiscountModel discount;

  const EditDiscountDialog({
    super.key,
    required this.discountId,
    required this.discount,
  });

  @override
  State<EditDiscountDialog> createState() => _EditDiscountDialogState();
}

class _EditDiscountDialogState extends State<EditDiscountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _discountService = DiscountService();

  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _maxUseCountCtrl = TextEditingController();

  late DiscountType _selectedType;
  String _status = 'Active';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadDiscountData();
  }

  void _loadDiscountData() {
    final discount = widget.discount;

    _nameCtrl.text = discount.name;
    _codeCtrl.text = discount.code;
    _valueCtrl.text = discount.type == DiscountType.freeShipping
        ? '0'
        : discount.value.toString();
    _maxUseCountCtrl.text = discount.maxUseCount.toString();
    _selectedType = discount.type;
    _status = discount.isActive ? 'Active' : 'Inactive';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _valueCtrl.dispose();
    _maxUseCountCtrl.dispose();
    super.dispose();
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  String _getValueHintText() {
    switch (_selectedType) {
      case DiscountType.freeShipping:
        return '0 (Free shipping has no value)';
      case DiscountType.percentage:
        return 'e.g., 20 (for 20% off)';
      case DiscountType.fixedAmount:
        return 'e.g., 10 (for \$10 off)';
    }
  }

  String? _validateValue(String? value) {
    if (_selectedType == DiscountType.freeShipping) {
      return null; // Free shipping doesn't need value validation
    }

    final numValue = double.tryParse(value ?? '');
    if (numValue == null || numValue <= 0) {
      return 'Enter a valid value';
    }

    if (_selectedType == DiscountType.percentage && numValue > 100) {
      return 'Percentage cannot exceed 100%';
    }

    return null;
  }

  Future<void> _updateDiscount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final user = AuthService.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final storeSnap = await FirebaseFirestore.instance
          .collection('stores')
          .where('ownerId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (storeSnap.docs.isEmpty) throw Exception('No store found');

      final storeId = storeSnap.docs.first.id;
      final code = _codeCtrl.text.trim().toUpperCase();

      // Check if code is unique (excluding current discount)
      final isUnique =
          await _discountService.isCodeUnique(storeId, code, widget.discountId);
      if (!isUnique) {
        throw Exception('Discount code "$code" already exists');
      }

      // Get value based on type
      double value = 0.0;
      if (_selectedType != DiscountType.freeShipping) {
        value = double.parse(_valueCtrl.text);
      }

      final updatedDiscount = DiscountModel(
        id: widget.discountId,
        storeId: storeId,
        code: code,
        name: _nameCtrl.text.trim(),
        type: _selectedType,
        value: value,
        maxUseCount:
            TypeUtils.safeParseInt(_maxUseCountCtrl.text, defaultValue: 0),
        currentUseCount: widget.discount.currentUseCount, // Keep existing usage
        isActive: _status == 'Active',
        createdAt: widget.discount.createdAt, // Keep original creation date
        updatedAt: DateTime.now(),
      );

      await _discountService.updateDiscount(widget.discountId, updatedDiscount);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Discount updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        height: 650,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Edit Discount',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Discount Name'),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          hintText: 'e.g., Summer Sale 2024',
                        ),
                        validator: (v) =>
                            v?.trim().isEmpty == true ? 'Name required' : null,
                      ),
                      const SizedBox(height: 16),
                      _label('CODE'),
                      TextFormField(
                        controller: _codeCtrl,
                        decoration: const InputDecoration(
                          hintText: 'e.g., SUMMER20',
                        ),
                        textCapitalization: TextCapitalization.characters,
                        validator: (v) {
                          if (v?.trim().isEmpty == true) {
                            return 'Code required';
                          }
                          if (v!.trim().length < 3) {
                            return 'Code must be at least 3 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _label('Type'),
                      DropdownButtonFormField<DiscountType>(
                        value: _selectedType,
                        items: const [
                          DropdownMenuItem(
                            value: DiscountType.freeShipping,
                            child: Row(
                              children: [
                                Icon(Icons.local_shipping_outlined, size: 18),
                                SizedBox(width: 8),
                                Text('Free Shipping'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: DiscountType.percentage,
                            child: Row(
                              children: [
                                Icon(Icons.percent, size: 18),
                                SizedBox(width: 8),
                                Text('Percentage'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: DiscountType.fixedAmount,
                            child: Row(
                              children: [
                                Icon(Icons.attach_money, size: 18),
                                SizedBox(width: 8),
                                Text('Fixed Amount'),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedType = value!;
                            if (_selectedType == DiscountType.freeShipping) {
                              _valueCtrl.text = '0';
                            } else {
                              _valueCtrl.clear();
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      _label('Value'),
                      TextFormField(
                        controller: _valueCtrl,
                        keyboardType: TextInputType.number,
                        enabled: _selectedType != DiscountType.freeShipping,
                        decoration: InputDecoration(
                          hintText: _getValueHintText(),
                          prefixText: _selectedType == DiscountType.fixedAmount
                              ? '\$'
                              : '',
                          suffixText: _selectedType == DiscountType.percentage
                              ? '%'
                              : '',
                        ),
                        validator: _validateValue,
                      ),
                      const SizedBox(height: 16),
                      _label('Max Use Count'),
                      TextFormField(
                        controller: _maxUseCountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'e.g., 100',
                        ),
                        validator: (v) {
                          final count = int.tryParse(v ?? '');
                          if (count == null || count <= 0) {
                            return 'Enter a valid use count';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _label('Status'),
                      DropdownButtonFormField<String>(
                        value: _status,
                        items: const [
                          DropdownMenuItem(
                              value: 'Active', child: Text('Active')),
                          DropdownMenuItem(
                              value: 'Inactive', child: Text('Inactive')),
                        ],
                        onChanged: (v) => setState(() => _status = v!),
                      ),
                      if (widget.discount.currentUseCount > 0) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: Colors.blue.shade600),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'This discount has been used ${widget.discount.currentUseCount} times.',
                                  style: TextStyle(color: Colors.blue.shade800),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _saving ? null : _updateDiscount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Update Discount'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
