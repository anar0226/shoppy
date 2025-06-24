import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../auth/auth_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import '../../core/services/direct_upload_service.dart';

class EditProductDialog extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;

  const EditProductDialog({
    super.key,
    required this.productId,
    required this.productData,
  });

  @override
  State<EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<EditProductDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _invCtrl = TextEditingController();
  String _status = 'Active';
  XFile? _imageFile;
  final _picker = ImagePicker();
  String? _category;
  String? _subcategory;

  bool _isDiscounted = false;
  final _discountCtrl = TextEditingController();

  bool _saving = false;
  List<String> _existingImages = [];

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
  void initState() {
    super.initState();
    _loadProductData();
  }

  void _loadProductData() {
    final data = widget.productData;

    _nameCtrl.text = data['name'] ?? '';
    _descCtrl.text = data['description'] ?? '';
    _priceCtrl.text = (data['price'] ?? 0.0).toString();
    _invCtrl.text = (data['stock'] ?? data['inventory'] ?? 0).toString();
    _status = (data['isActive'] ?? true) ? 'Active' : 'Inactive';
    _category = data['category'];
    _subcategory = data['subcategory'];
    _existingImages = List<String>.from(data['images'] ?? []);

    // Handle discount data
    final discount = data['discount'];
    if (discount != null && discount is Map) {
      _isDiscounted = discount['isDiscounted'] ?? false;
      _discountCtrl.text = (discount['percent'] ?? 0.0).toString();
    }
  }

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

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _imageFile = pickedFile);
    }
  }

  void _removeImage() {
    setState(() => _imageFile = null);
  }

  void _removeExistingImage(int index) {
    setState(() => _existingImages.removeAt(index));
  }

  Future<void> _updateProduct() async {
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
      List<String> finalImages = List.from(_existingImages);

      // Upload new image if selected
      if (_imageFile != null) {
        final imageBytes = await _imageFile!.readAsBytes();
        final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';

        final imageUrl = await DirectUploadService.uploadImageDirect(
          imageBytes: imageBytes,
          storeId: storeId,
          productId: widget.productId,
          fileName: fileName,
        );

        finalImages.add(imageUrl);
      }

      // Prepare product data
      final productData = {
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'price': double.parse(_priceCtrl.text),
        'stock': int.parse(_invCtrl.text),
        'isActive': _status == 'Active',
        'category': _category,
        'subcategory': _subcategory,
        'images': finalImages,
        'updatedAt': Timestamp.now(),
        'discount': {
          'isDiscounted': _isDiscounted,
          'percent': _isDiscounted ? double.parse(_discountCtrl.text) : 0.0,
        },
      };

      // Update product in Firestore
      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .update(productData);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product updated successfully!')),
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
        width: 800,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Edit Product',
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Product Name'),
                                TextFormField(
                                  controller: _nameCtrl,
                                  decoration: const InputDecoration(
                                      hintText: 'Enter product name'),
                                  validator: (v) => v?.trim().isEmpty == true
                                      ? 'Name required'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                _label('Description'),
                                TextFormField(
                                  controller: _descCtrl,
                                  maxLines: 4,
                                  decoration: const InputDecoration(
                                      hintText: 'Enter product description'),
                                  validator: (v) => v?.trim().isEmpty == true
                                      ? 'Description required'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _label('Price (\$)'),
                                          TextFormField(
                                            controller: _priceCtrl,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                                hintText: '0.00'),
                                            validator: (v) {
                                              final price =
                                                  double.tryParse(v ?? '');
                                              if (price == null || price < 0) {
                                                return 'Enter valid price';
                                              }
                                              return null;
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _label('Inventory'),
                                          TextFormField(
                                            controller: _invCtrl,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                                hintText: '0'),
                                            validator: (v) {
                                              final n = int.tryParse(v ?? '');
                                              if (n == null || n < 0) {
                                                return 'Enter inventory';
                                              }
                                              return null;
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _label('Status'),
                                DropdownButtonFormField<String>(
                                  value: _status,
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'Active', child: Text('Active')),
                                    DropdownMenuItem(
                                        value: 'Inactive',
                                        child: Text('Inactive')),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _status = v!),
                                ),
                                const SizedBox(height: 16),
                                _label('Category'),
                                DropdownButtonFormField<String>(
                                  value: _category,
                                  items: _catMap.keys
                                      .map((c) => DropdownMenuItem(
                                          value: c, child: Text(c)))
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
                                  items: _category == null
                                      ? []
                                      : _catMap[_category]!
                                          .map((s) => DropdownMenuItem(
                                              value: s, child: Text(s)))
                                          .toList(),
                                  onChanged: (v) =>
                                      setState(() => _subcategory = v),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _isDiscounted,
                                      onChanged: (v) =>
                                          setState(() => _isDiscounted = v!),
                                    ),
                                    const Text('Discounted'),
                                  ],
                                ),
                                if (_isDiscounted) ...[
                                  const SizedBox(height: 8),
                                  _label('Discount (%)'),
                                  TextFormField(
                                    controller: _discountCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration:
                                        const InputDecoration(hintText: '0'),
                                    validator: (v) {
                                      if (_isDiscounted) {
                                        final d = double.tryParse(v ?? '');
                                        if (d == null || d < 0 || d > 100) {
                                          return 'Enter valid discount';
                                        }
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Product Images'),

                                // Show existing images
                                if (_existingImages.isNotEmpty) ...[
                                  const Text('Current Images:',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _existingImages
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      final index = entry.key;
                                      final imageUrl = entry.value;
                                      return Stack(
                                        children: [
                                          Container(
                                            width: 80,
                                            height: 80,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: Colors.grey.shade300),
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.network(
                                                imageUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                                  return Container(
                                                    color: Colors.grey.shade200,
                                                    child: const Icon(
                                                        Icons.image,
                                                        color: Colors.grey),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 4,
                                            right: 4,
                                            child: GestureDetector(
                                              onTap: () =>
                                                  _removeExistingImage(index),
                                              child: Container(
                                                width: 24,
                                                height: 24,
                                                decoration: const BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Add new image section
                                const Text('Add New Image:',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w500)),
                                const SizedBox(height: 8),

                                if (_imageFile != null)
                                  Stack(
                                    children: [
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: Colors.grey.shade300),
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: kIsWeb
                                              ? FutureBuilder<Uint8List>(
                                                  future:
                                                      _imageFile!.readAsBytes(),
                                                  builder: (context, snapshot) {
                                                    if (snapshot.hasData) {
                                                      return Image.memory(
                                                        snapshot.data!,
                                                        fit: BoxFit.cover,
                                                      );
                                                    }
                                                    return const CircularProgressIndicator();
                                                  },
                                                )
                                              : Image.network(
                                                  _imageFile!.path,
                                                  fit: BoxFit.cover,
                                                ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: _removeImage,
                                          child: Container(
                                            width: 24,
                                            height: 24,
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  GestureDetector(
                                    onTap: _pickImage,
                                    child: Container(
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.grey.shade300,
                                            style: BorderStyle.solid),
                                      ),
                                      child: const Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add_photo_alternate,
                                              size: 32, color: Colors.grey),
                                          SizedBox(height: 8),
                                          Text('Add Image',
                                              style: TextStyle(
                                                  color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                  ),

                                if (_saving && _uploadProgress > 0) ...[
                                  const SizedBox(height: 16),
                                  LinearProgressIndicator(
                                      value: _uploadProgress),
                                  const SizedBox(height: 8),
                                  Text(
                                      'Uploading... ${(_uploadProgress * 100).toInt()}%'),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
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
                  onPressed: _saving ? null : _updateProduct,
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
                      : const Text('Update Product'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
