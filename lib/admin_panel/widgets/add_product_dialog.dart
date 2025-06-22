import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../auth/auth_service.dart';

class AddProductDialog extends StatefulWidget {
  const AddProductDialog({super.key});

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: '0.00');
  final _invCtrl = TextEditingController(text: '0');
  String _status = 'Active';
  XFile? _imageFile;
  final _picker = ImagePicker();
  String? _category;
  String? _subcategory;

  final _catMap = const {
    'Men': ['Shoes', 'Jackets & Tops', 'Pants', 'Accessories'],
    'Women': ['Shoes', 'Intimates', 'Activewear', 'Dresses'],
    'Beauty': ['Skincare', 'Makeup', 'Hair'],
    'Electronics': ['Phones', 'Laptops', 'Accessories'],
    'Home': ['Furniture', 'Decor', 'Kitchen'],
    'Sports': ['Fitness', 'Outdoor', 'Teams'],
    'Kids': ['Toys', 'Clothing'],
    'Other': ['Misc'],
  };

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _invCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    final inventory = int.tryParse(_invCtrl.text) ?? 0;

    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please choose an image')));
      return;
    }

    // Determine the store that belongs to the current admin (owner).
    String? ownerId = AuthService.instance.currentUser?.uid;
    String storeId = '';
    if (ownerId != null) {
      final storeSnap = await FirebaseFirestore.instance
          .collection('stores')
          .where('ownerId', isEqualTo: ownerId)
          .limit(1)
          .get();
      if (storeSnap.docs.isNotEmpty) {
        storeId = storeSnap.docs.first.id;
      }
    }

    // Create a new product document now so we can use its id for the image path.
    final docRef = FirebaseFirestore.instance.collection('products').doc();

    // Upload product image to Firebase Storage – keep images organised per-store.
    final storageRef = FirebaseStorage.instance.ref().child(storeId.isNotEmpty
        ? 'stores/$storeId/products/${docRef.id}.${_imageFile!.path.split('.').last}'
        : 'products/${docRef.id}.${_imageFile!.path.split('.').last}');
    await storageRef.putData(await _imageFile!.readAsBytes());
    final imageUrl = await storageRef.getDownloadURL();

    // Persist the product using the unified schema expected by the storefront.
    await docRef.set({
      'name': _nameCtrl.text.trim(),
      'description': '', // Placeholder until a description editor is added
      'price': price,
      'stock': inventory, // unified field name used across the app
      'inventory': inventory, // kept for backward compatibility
      'images': [imageUrl],
      'category': _category,
      'subcategory': _subcategory,
      'isActive': _status == 'Active',
      'status': _status, // original status field (legacy)
      'storeId': storeId,
      'ownerId': ownerId,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Add New Product',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Product Name'),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                            hintText: 'Enter product name'),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      _label('Product Image'),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              final picked = await _picker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 85);
                              if (picked != null) {
                                setState(() => _imageFile = picked);
                              }
                            },
                            icon: const Icon(Icons.attach_file_outlined,
                                size: 18),
                            label: const Text('Choose Image'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade200,
                              foregroundColor: Colors.black87,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (_imageFile != null)
                            Expanded(
                              child: Text(
                                _imageFile!.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _label('Price'),
                      TextFormField(
                        controller: _priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(hintText: '0.00'),
                      ),
                      const SizedBox(height: 16),
                      _label('Inventory'),
                      TextFormField(
                        controller: _invCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: '0'),
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
                      const SizedBox(height: 16),
                      _label('Category'),
                      DropdownButtonFormField<String>(
                        value: _category,
                        items: _catMap.keys
                            .map((c) =>
                                DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) => setState(() {
                          _category = v;
                          _subcategory = null;
                        }),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      _label('Sub-category'),
                      DropdownButtonFormField<String>(
                        value: _subcategory,
                        items: (_category != null)
                            ? _catMap[_category]!
                                .map((s) =>
                                    DropdownMenuItem(value: s, child: Text(s)))
                                .toList()
                            : const [],
                        onChanged: _category == null
                            ? null
                            : (v) => setState(() => _subcategory = v),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      );
}
