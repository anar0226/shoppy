import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../auth/auth_service.dart';
import 'package:flutter/foundation.dart';
import '../../core/services/direct_upload_service.dart';
import '../../features/discounts/models/discount_model.dart';
import '../../features/discounts/services/discount_service.dart';

class ProductVariant {
  final String name;
  final int inventory;

  ProductVariant({
    required this.name,
    required this.inventory,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'inventory': inventory,
    };
  }

  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    return ProductVariant(
      name: map['name'] ?? '',
      inventory: map['inventory'] ?? 0,
    );
  }
}

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
  String? _leafCategory;

  bool _isDiscounted = false;
  String? _selectedDiscountId;
  List<DiscountModel> _availableDiscounts = [];
  bool _discountsLoaded = false;
  final _discountService = DiscountService();

  // Variant management
  bool _hasVariants = false;
  String _variantType = 'Size';
  List<ProductVariant> _variants = [];
  final _variantNameCtrl = TextEditingController();
  final _variantInventoryCtrl = TextEditingController();

  bool _saving = false;
  List<String> _existingImages = [];

  final _catMap = const {
    'Men': {
      'Гутал': ['Пүүз', 'Шаахай', 'Гутал', 'Спорт гутал'],
      'Гадуур хувцас': ['Куртка', 'Малгайтай цамц', 'Поло', 'Цамц'],
      'Бусад': ['Бусад'],
      'Өмд': ['Өмд'],
      'Футболк': ['Футболк'],
      'Спорт хувцас': ['Спорт хувцас'],
    },
    'Women': {
      'Гадуур хувцас & Футболк': ['Футболк', 'Малгайтай цамц'],
      'Гутал': ['Өндөр өсгийт', 'Шаахай', 'Пүүз', 'Бусад'],
      'Даашинз': ['Даашинз'],
      'Өмд': ['Өмд'],
      'Дотуур хувцас': ['Лифчик', 'Ланжери', 'Биеийн даруулга', 'Дотоож'],
      'Спорт хувцас': ['Актив хувцас'],
    },
    'Beauty': {},
    'Electronics': {},
    'Home': {},
    'Sports': {},
    'Kids': {},
    'Other': {},
  };

  @override
  void initState() {
    super.initState();
    _loadProductData();
    _loadDiscounts();
  }

  void _loadProductData() {
    final data = widget.productData;

    _nameCtrl.text = data['name'] ?? '';
    _descCtrl.text = data['description'] ?? '';
    _priceCtrl.text = (data['price'] ?? 0.0).toString();
    _status = (data['isActive'] ?? true) ? 'Active' : 'Inactive';
    _category = data['category'];
    _subcategory = data['subcategory'];
    _leafCategory = data['leafCategory'];
    _existingImages = List<String>.from(data['images'] ?? []);

    // Load variant data
    _hasVariants = data['hasVariants'] ?? false;
    _variantType = data['variantType'] ?? 'Size';

    if (_hasVariants && data['variants'] != null) {
      _variants = (data['variants'] as List)
          .map((v) => ProductVariant.fromMap(v as Map<String, dynamic>))
          .toList();
      _invCtrl.text = '0'; // For variants, individual inventory doesn't apply
    } else {
      _invCtrl.text = (data['stock'] ?? data['inventory'] ?? 0).toString();
    }

    // Handle discount data
    final discount = data['discount'];
    if (discount != null && discount is Map) {
      _isDiscounted = discount['isDiscounted'] ?? false;
      _selectedDiscountId = discount['discountId'];
    }
  }

  Future<void> _loadDiscounts() async {
    try {
      final uid = AuthService.instance.currentUser?.uid;
      if (uid == null) return;

      final storeSnap = await FirebaseFirestore.instance
          .collection('stores')
          .where('ownerId', isEqualTo: uid)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (storeSnap.docs.isEmpty) return;

      final storeId = storeSnap.docs.first.id;

      final discountsStream = _discountService.getStoreDiscounts(storeId);
      discountsStream.listen((discounts) {
        if (mounted) {
          setState(() {
            _availableDiscounts = discounts.where((d) => d.isActive).toList();
            _discountsLoaded = true;
          });
        }
      });
    } catch (e) {
      // Error loading discounts
      if (mounted) {
        setState(() => _discountsLoaded = true);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _invCtrl.dispose();
    _variantNameCtrl.dispose();
    _variantInventoryCtrl.dispose();
    super.dispose();
  }

  final double _uploadProgress = 0.0;

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

    // Validate variants if product has variants
    if (_hasVariants && _variants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please add at least one variant for this product')),
      );
      return;
    }

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

      // Prepare product data with new structure
      final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
      final inventory = int.tryParse(_invCtrl.text.trim()) ?? 0;

      // Find selected discount details
      DiscountModel? selectedDiscount;
      if (_isDiscounted && _selectedDiscountId != null) {
        selectedDiscount = _availableDiscounts.firstWhere(
          (d) => d.id == _selectedDiscountId,
          orElse: () => _availableDiscounts.first,
        );
      }

      final productData = {
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'price': price,
        'stock': _hasVariants
            ? 0
            : inventory, // Use 0 for variants, individual inventory for simple products
        'isActive': _status == 'Active',
        'category': _category, // Optional now
        'subcategory': _subcategory, // Optional now
        'leafCategory': _leafCategory, // Optional now
        'images': finalImages,
        'updatedAt': Timestamp.now(),
        'hasVariants': _hasVariants,
        'variantType': _hasVariants ? _variantType : null,
        'variants':
            _hasVariants ? _variants.map((v) => v.toMap()).toList() : null,
        'totalStock': _hasVariants
            ? _variants.fold<int>(0, (sum, variant) => sum + variant.inventory)
            : inventory,
        'discount': {
          'isDiscounted': _isDiscounted,
          'discountId': _isDiscounted ? _selectedDiscountId : null,
          'discountCode': _isDiscounted && selectedDiscount != null
              ? selectedDiscount.code
              : null,
          'percent': _isDiscounted && selectedDiscount != null
              ? selectedDiscount.value
              : 0,
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
        String errorMessage = 'Failed to update product';
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
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addVariant() {
    final name = _variantNameCtrl.text.trim();
    final inventoryText = _variantInventoryCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Хэмжээ, өнгө зэрэг нэр оруулна уу')),
      );
      return;
    }

    final inventory = int.tryParse(inventoryText);
    if (inventory == null || inventory < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нөөц оруулна уу')),
      );
      return;
    }

    // Check for duplicate variant names
    if (_variants.any((v) => v.name.toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Бүтээгдэхүүний төрөл нэгэнтэй адилхан байна')),
      );
      return;
    }

    setState(() {
      _variants.add(ProductVariant(name: name, inventory: inventory));
      _variantNameCtrl.clear();
      _variantInventoryCtrl.clear();
    });
  }

  void _removeVariant(int index) {
    setState(() {
      _variants.removeAt(index);
    });
  }

  void _editVariant(int index) {
    final variant = _variants[index];
    final nameController = TextEditingController(text: variant.name);
    final inventoryController =
        TextEditingController(text: variant.inventory.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Variant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Хэмжээ, өнгө зэрэг',
                hintText: _variantType == 'Size' ? 'Жишээ: M' : 'Жишээ: Улаан',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: inventoryController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Нөөц',
                hintText: '0',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final inventoryText = inventoryController.text.trim();

              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Хэмжээ, өнгө зэрэг нэр оруулна уу')),
                );
                return;
              }

              final inventory = int.tryParse(inventoryText);
              if (inventory == null || inventory < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Нөөц оруулна уу')),
                );
                return;
              }

              // Check for duplicate variant names (excluding current variant)
              final existingNames = _variants
                  .asMap()
                  .entries
                  .where((entry) => entry.key != index)
                  .map((entry) => entry.value.name.toLowerCase())
                  .toSet();

              if (existingNames.contains(name.toLowerCase())) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('Бүтээгдэхүүний төрөл нэгэнтэй адилхан байна')),
                );
                return;
              }

              setState(() {
                _variants[index] =
                    ProductVariant(name: name, inventory: inventory);
              });

              Navigator.of(context).pop();
            },
            child: const Text('Хадгалах'),
          ),
        ],
      ),
    );
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
                      child: Text('Бүтээгдэхүүн засах',
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
                      _label('Тодорхойлолт'),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                            hintText: 'Бүтээгдэхүүний нэр оруулна уу'),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Заавал оруулна уу'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _label('Бүтээгдэхүүний зураг'),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image picker button
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                  label: const Text('Зураг нэмэх'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey.shade200,
                                    foregroundColor: Colors.black87,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6)),
                                  ),
                                ),
                                if (_imageFile != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _imageFile!.name,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // New image preview
                          if (_imageFile != null) ...[
                            const SizedBox(width: 16),
                            Stack(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(7),
                                    child: kIsWeb
                                        ? Image.network(
                                            _imageFile!.path,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Container(
                                                color: Colors.grey.shade100,
                                                child: const Icon(
                                                  Icons.image,
                                                  color: Colors.grey,
                                                  size: 32,
                                                ),
                                              );
                                            },
                                          )
                                        : FutureBuilder<Uint8List>(
                                            future: _imageFile!.readAsBytes(),
                                            builder: (context, snapshot) {
                                              if (snapshot.hasData) {
                                                return Image.memory(
                                                  snapshot.data!,
                                                  fit: BoxFit.cover,
                                                );
                                              }
                                              return Container(
                                                color: Colors.grey.shade100,
                                                child: const Center(
                                                  child: SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                ),
                                // Remove button
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _imageFile = null),
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.2),
                                            blurRadius: 2,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),

                      // Existing images
                      if (_existingImages.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Current Images (${_existingImages.length})',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              _existingImages.asMap().entries.map((entry) {
                            final index = entry.key;
                            final imageUrl = entry.value;
                            return Stack(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(7),
                                    child: Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          color: Colors.grey.shade100,
                                          child: const Icon(
                                            Icons.image,
                                            color: Colors.grey,
                                            size: 24,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: GestureDetector(
                                    onTap: () => _removeExistingImage(index),
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.2),
                                            blurRadius: 2,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ],

                      const SizedBox(height: 16),
                      _label('Тодорхойлолт'),
                      TextFormField(
                        controller: _descCtrl,
                        decoration: const InputDecoration(
                            hintText: 'Бүтээгдэхүүний тодорхойлолт оруулна уу'),
                        maxLines: 3,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Заавал оруулна уу'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _label('Үнэ'),
                      TextFormField(
                        controller: _priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            hintText: 'Бүтээгдэхүүний үнэ оруулна уу'),
                        validator: (v) {
                          final p = double.tryParse(v ?? '');
                          if (p == null || p <= 0)
                            return 'Бүтээгдэхүүний үнэ оруулна уу';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _label('Хөнгөлөлт'),
                      Row(
                        children: [
                          Checkbox(
                              value: _isDiscounted,
                              onChanged: (val) => setState(() {
                                    _isDiscounted = val ?? false;
                                    if (!_isDiscounted) {
                                      _selectedDiscountId = null;
                                    }
                                  })),
                          const Text('Хөнгөлөлт нэмэх'),
                          const SizedBox(width: 16),
                          if (_isDiscounted) ...[
                            Expanded(
                              child: _discountsLoaded
                                  ? _availableDiscounts.isEmpty
                                      ? const Text(
                                          'Идэвхитэй хөнгөлөлт байхгүй байна',
                                          style: TextStyle(
                                            color: Colors.orange,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        )
                                      : DropdownButtonFormField<String>(
                                          value: _selectedDiscountId,
                                          hint: const Text('Хөнгөлөлт сонгох'),
                                          itemHeight: null,
                                          items: _availableDiscounts
                                              .map((discount) {
                                            return DropdownMenuItem<String>(
                                              value: discount.id,
                                              child: Row(
                                                children: [
                                                  Icon(discount.iconData,
                                                      size: 16),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          discount.name,
                                                          style: const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                        Text(
                                                          '${discount.code} - ${discount.valueDisplayText}',
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey,
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (value) => setState(() =>
                                              _selectedDiscountId = value),
                                          selectedItemBuilder: (context) {
                                            return _availableDiscounts
                                                .map<Widget>(
                                                    (d) => Text(d.name))
                                                .toList();
                                          },
                                          validator: (v) {
                                            if (_isDiscounted && v == null) {
                                              return 'Хөнгөлөлт сонгоно уу';
                                            }
                                            return null;
                                          },
                                          isExpanded: true,
                                        )
                                  : const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      _label('Нөөц'),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: _hasVariants,
                                onChanged: (val) => setState(() {
                                  _hasVariants = val ?? false;
                                  if (!_hasVariants) {
                                    _variants.clear();
                                  }
                                }),
                              ),
                              const Text('Бүтээгдэхүүний төрөл байгаа юу?'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_hasVariants) ...[
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<String>(
                                    value: _variantType,
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'Size', child: Text('Хэмжээ')),
                                      DropdownMenuItem(
                                          value: 'Color', child: Text('Өнгө')),
                                      DropdownMenuItem(
                                          value: 'Material',
                                          child: Text('Материал')),
                                      DropdownMenuItem(
                                          value: 'Style', child: Text('Үүрэг')),
                                      DropdownMenuItem(
                                          value: 'Other', child: Text('Бусад')),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _variantType = v!),
                                    decoration: const InputDecoration(
                                      labelText: 'Бүтээгдэхүүний төрөл',
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _variantNameCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'Бүтээгдэхүүний төрөл',
                                      hintText: _variantType == 'Size'
                                          ? 'Жишээ: M'
                                          : 'Жишээ: Улаан',
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _variantInventoryCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Нөөц',
                                      hintText: '0',
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _addVariant,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(60, 36),
                                  ),
                                  child: const Text('Нэмэх'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_variants.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Бүтээгдэхүүний төрөл (${_variants.length})',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 8),
                                    ..._variants.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final variant = entry.value;
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${variant.name} (${variant.inventory} нөөц)',
                                                style: const TextStyle(
                                                    fontSize: 14),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.edit,
                                                  color: Colors.blue, size: 18),
                                              onPressed: () =>
                                                  _editVariant(index),
                                              tooltip:
                                                  'Бүтээгдэхүүний төрөл засах',
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete,
                                                  color: Colors.red, size: 18),
                                              onPressed: () =>
                                                  _removeVariant(index),
                                              tooltip:
                                                  'Бүтээгдэхүүний төрөл устгах',
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    const Divider(),
                                    Text(
                                      'Нийт нөөц: ${_variants.fold<int>(0, (sum, v) => sum + v.inventory)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ] else ...[
                            TextFormField(
                              controller: _invCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  hintText: 'Нөөц оруулна уу'),
                              validator: (v) {
                                if (!_hasVariants) {
                                  final n = int.tryParse(v ?? '');
                                  if (n == null || n < 0) {
                                    return 'Нөөц оруулна уу';
                                  }
                                }
                                return null;
                              },
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      _label('Төлөв'),
                      DropdownButtonFormField<String>(
                        value: _status,
                        items: const [
                          DropdownMenuItem(
                              value: 'Active', child: Text('Идэвхитэй')),
                          DropdownMenuItem(
                              value: 'Inactive', child: Text('Идэвхигүй')),
                        ],
                        onChanged: (v) => setState(() => _status = v!),
                      ),
                      const SizedBox(height: 16),
                      _label('Ангилал (заавал биш)'),
                      DropdownButtonFormField<String>(
                        value: _category,
                        items: _catMap.keys
                            .map<DropdownMenuItem<String>>((c) =>
                                DropdownMenuItem<String>(
                                    value: c as String,
                                    child: Text(c as String)))
                            .toList(),
                        onChanged: (v) => setState(() {
                          _category = v;
                          _subcategory = null;
                          _leafCategory = null;
                        }),
                        decoration: const InputDecoration(
                          hintText: 'Ангилал сонгох (заавал биш)',
                        ),
                      ),
                      const SizedBox(height: 16),
                      _label('2 дугаар ангилал (заавал биш)'),
                      DropdownButtonFormField<String>(
                        value: _subcategory,
                        items: (_category != null)
                            ? _catMap[_category]!
                                .keys
                                .map<DropdownMenuItem<String>>((s) =>
                                    DropdownMenuItem<String>(
                                        value: s as String,
                                        child: Text(s as String)))
                                .toList()
                            : const [],
                        onChanged: _category == null
                            ? null
                            : (v) => setState(() {
                                  _subcategory = v;
                                  _leafCategory = null;
                                }),
                        decoration: const InputDecoration(
                          hintText: '2 дугаар ангилал сонгох (заавал биш)',
                        ),
                      ),
                      const SizedBox(height: 16),
                      _label('Бүтээгдэхүүний төрөл (заавал биш)'),
                      DropdownButtonFormField<String>(
                        value: _leafCategory,
                        items: (_category != null && _subcategory != null)
                            ? (_catMap[_category]![_subcategory]! as List)
                                .map<DropdownMenuItem<String>>((leaf) =>
                                    DropdownMenuItem<String>(
                                        value: leaf as String,
                                        child: Text(leaf as String)))
                                .toList()
                            : const [],
                        onChanged: (_category == null || _subcategory == null)
                            ? null
                            : (v) => setState(() => _leafCategory = v),
                        decoration: const InputDecoration(
                          hintText: 'Бүтээгдэхүүний төрөл сонгох (заавал биш)',
                        ),
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
                      onPressed: _saving ? null : _updateProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      child: _saving
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('Updating...'),
                              ],
                            )
                          : const Text('Шинэчлэх'),
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
}
