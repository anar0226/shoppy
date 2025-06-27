import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/auth_service.dart';
import '../../features/discounts/models/discount_model.dart';
import '../../features/discounts/services/discount_service.dart';
import '../../core/utils/type_utils.dart';

class AddDiscountDialog extends StatefulWidget {
  const AddDiscountDialog({super.key});

  @override
  State<AddDiscountDialog> createState() => _AddDiscountDialogState();
}

class _AddDiscountDialogState extends State<AddDiscountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _discountService = DiscountService();

  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _maxUseCountCtrl = TextEditingController(text: '100');

  DiscountType _selectedType = DiscountType.percentage;
  String _status = 'Active';
  bool _saving = false;

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

  Future<void> _saveDiscount() async {
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

      // Check if code is unique
      final isUnique = await _discountService.isCodeUnique(storeId, code);
      if (!isUnique) {
        throw Exception('Discount code "$code" already exists');
      }

      // Get value based on type
      double value = 0.0;
      if (_selectedType != DiscountType.freeShipping) {
        value = double.parse(_valueCtrl.text);
      }

      final discount = DiscountModel(
        id: '', // Will be set by Firestore
        storeId: storeId,
        code: code,
        name: _nameCtrl.text.trim(),
        type: _selectedType,
        value: value,
        maxUseCount:
            TypeUtils.safeParseInt(_maxUseCountCtrl.text, defaultValue: 0),
        isActive: _status == 'Active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _discountService.createDiscount(discount);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Discount created successfully!')),
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
        constraints: const BoxConstraints(
          maxHeight: 650,
          minHeight: 400,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Create Discount',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Flexible(
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
                        items: [
                          DropdownMenuItem(
                            value: DiscountType.freeShipping,
                            child: Row(
                              children: const [
                                Icon(Icons.local_shipping_outlined, size: 18),
                                SizedBox(width: 8),
                                Text('Free Shipping'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: DiscountType.percentage,
                            child: Row(
                              children: const [
                                Icon(Icons.percent, size: 18),
                                SizedBox(width: 8),
                                Text('Percentage'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: DiscountType.fixedAmount,
                            child: Row(
                              children: const [
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
                            _valueCtrl.clear();
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
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _saving ? null : _saveDiscount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
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
                      : const Text('Create Discount'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
