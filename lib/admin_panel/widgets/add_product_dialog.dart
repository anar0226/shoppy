import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../auth/auth_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/image_upload_service.dart';
import '../../core/services/upload_debug_service.dart';

class AddProductDialog extends StatefulWidget {
  const AddProductDialog({super.key});

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: '0.00');
  final _invCtrl = TextEditingController(text: '0');
  String _status = 'Active';
  XFile? _imageFile;
  final _picker = ImagePicker();
  String? _category;
  String? _subcategory;

  bool _isDiscounted = false;
  final _discountCtrl = TextEditingController(text: '0');

  bool _saving = false;

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
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _invCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  double _uploadProgress = 0.0;

  Future<void> _save() async {
    if (_saving) return; // prevent double-tap
    if (!_formKey.currentState!.validate()) return;

    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please choose an image')));
      return;
    }

    setState(() => _saving = true);

    try {
      debugPrint('ADD-PRODUCT: started');

      // 1. Get current user
      final uid = AuthService.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not signed in');

      // 2. Fetch active store for this owner
      final storeSnap = await FirebaseFirestore.instance
          .collection('stores')
          .where('ownerId', isEqualTo: uid)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (storeSnap.docs.isEmpty) {
        throw Exception('Active store not found. Complete store setup first.');
      }
      final storeId = storeSnap.docs.first.id;
      debugPrint('STEP 1: storeId=$storeId');

      // 3. Create product document reference
      final docRef = FirebaseFirestore.instance.collection('products').doc();
      debugPrint('STEP 2: productId=${docRef.id}');

      // 4. Run diagnostics first
      debugPrint('STEP 3: Running Firebase diagnostics...');
      final diagnostics = await UploadDebugService.runDiagnostics();
      UploadDebugService.printDiagnostics(diagnostics);

      // Check if there are any critical issues
      if (diagnostics.containsKey('error')) {
        throw Exception('Firebase diagnostics failed: ${diagnostics['error']}');
      }

      // 5. Upload image with progress tracking (try advanced method first)
      String imageUrl;
      try {
        debugPrint('STEP 4: Trying upload with progress tracking...');
        imageUrl = await ImageUploadService.uploadProductImage(
          imageFile: _imageFile!,
          storeId: storeId,
          productId: docRef.id,
          onProgress: (progress) {
            if (mounted) {
              setState(() => _uploadProgress = progress);
              debugPrint(
                  'Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
            }
          },
        );
        debugPrint('STEP 4a: Advanced upload successful - $imageUrl');
      } catch (e) {
        debugPrint('STEP 4a: Advanced upload failed: $e');
        debugPrint('STEP 4b: Trying simple upload fallback...');

        // Fallback to simple upload
        imageUrl = await ImageUploadService.uploadProductImageSimple(
          imageFile: _imageFile!,
          storeId: storeId,
          productId: docRef.id,
        );
        debugPrint('STEP 4b: Simple upload successful - $imageUrl');
      }

      // 6. Build product data
      final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
      final inventory = int.tryParse(_invCtrl.text.trim()) ?? 0;

      final data = {
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'price': price,
        'stock': inventory,
        'images': [imageUrl],
        'category': _category,
        'subcategory': _subcategory,
        'isActive': _status == 'Active',
        'storeId': storeId,
        'ownerId': uid,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'discount': {
          'isDiscounted': _isDiscounted,
          'percent': double.tryParse(_discountCtrl.text.trim()) ?? 0,
        },
        'review': {
          'numberOfReviews': 0,
          'stars': 0,
        },
      };

      // 7. Save product to Firestore
      await docRef.set(data);
      debugPrint('STEP 5: product saved to Firestore');

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product added successfully!')));
      }
    } catch (e) {
      debugPrint('ADD-PRODUCT ERROR: $e');
      if (mounted) {
        String errorMessage = 'Failed to add product';
        if (e.toString().contains('permission-denied')) {
          errorMessage = 'Permission denied. Check your Firebase rules.';
        } else if (e.toString().contains('network')) {
          errorMessage = 'Network error. Check your connection.';
        } else if (e.toString().contains('storage')) {
          errorMessage = 'Image upload failed. Try a smaller image.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _uploadProgress = 0.0;
        });
      }
    }
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
                      _label('Description'),
                      TextFormField(
                        controller: _descCtrl,
                        decoration: const InputDecoration(
                            hintText: 'Enter product description'),
                        maxLines: 3,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      _label('Price'),
                      TextFormField(
                        controller: _priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(hintText: '0.00'),
                        validator: (v) {
                          final p = double.tryParse(v ?? '');
                          if (p == null || p <= 0) return 'Enter valid price';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _label('Discount'),
                      Row(
                        children: [
                          Checkbox(
                              value: _isDiscounted,
                              onChanged: (val) => setState(() {
                                    _isDiscounted = val ?? false;
                                  })),
                          const Text('Apply Discount'),
                          const SizedBox(width: 16),
                          if (_isDiscounted)
                            Expanded(
                              child: TextFormField(
                                controller: _discountCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                    hintText: 'Percent e.g. 10'),
                                validator: (v) {
                                  if (!_isDiscounted) return null;
                                  final p = double.tryParse(v ?? '');
                                  if (p == null || p <= 0) {
                                    return 'Enter %';
                                  }
                                  return null;
                                },
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _label('Inventory'),
                      TextFormField(
                        controller: _invCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: '0'),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n < 0) return 'Enter inventory';
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
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      child: _saving
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                    value: _uploadProgress > 0
                                        ? _uploadProgress
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(_uploadProgress > 0
                                    ? 'Uploading ${(_uploadProgress * 100).toStringAsFixed(0)}%'
                                    : 'Saving...'),
                              ],
                            )
                          : const Text('Save'),
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
