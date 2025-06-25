import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../auth/auth_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:typed_data';
import '../../core/services/image_upload_service.dart';
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
}

class AddProductDialog extends StatefulWidget {
  const AddProductDialog({super.key});

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _invCtrl = TextEditingController(text: '0');
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
  String _variantType = 'Size'; // Size, Color, etc.
  List<ProductVariant> _variants = [];
  final _variantNameCtrl = TextEditingController();
  final _variantInventoryCtrl = TextEditingController();

  bool _saving = false;

  final _catMap = const {
    'Men': {
      'Shoes': ['Sneakers', 'Boots', 'Dress Shoes', 'Sandals', 'Slippers'],
      'Jackets & Tops': [
        'Hoodies',
        'Jackets',
        'Polo Shirts',
        'T-Shirts',
        'Tank Tops'
      ],
      'Pants': ['Jeans', 'Chinos', 'Shorts', 'Sweatpants', 'Dress Pants'],
      'Accessories': ['Watches', 'Belts', 'Hats', 'Bags', 'Sunglasses'],
    },
    'Women': {
      'Shoes': ['Heels', 'Flats', 'Sneakers', 'Boots', 'Sandals'],
      'Intimates': ['Bras', 'Lingerie', 'Shapewear', 'Underwear'],
      'Activewear': ['Sports Bras', 'Leggings', 'Tank Tops', 'Hoodies'],
      'Dresses': ['Casual', 'Formal', 'Cocktail', 'Maxi', 'Mini'],
    },
    'Beauty': {
      'Skincare': ['Cleansers', 'Moisturizers', 'Serums', 'Sunscreen'],
      'Makeup': ['Foundation', 'Lipstick', 'Eyeshadow', 'Mascara'],
      'Hair': ['Shampoo', 'Conditioner', 'Styling', 'Tools'],
    },
    'Electronics': {
      'Phones': ['Smartphones', 'Cases', 'Chargers', 'Screen Protectors'],
      'Laptops': ['Gaming', 'Business', 'Ultrabooks', 'Accessories'],
      'Accessories': ['Headphones', 'Speakers', 'Cables', 'Power Banks'],
    },
    'Home': {
      'Furniture': ['Chairs', 'Tables', 'Sofas', 'Storage'],
      'Decor': ['Wall Art', 'Candles', 'Plants', 'Mirrors'],
      'Kitchen': ['Cookware', 'Appliances', 'Utensils', 'Storage'],
    },
    'Sports': {
      'Fitness': ['Weights', 'Cardio', 'Yoga', 'Accessories'],
      'Outdoor': ['Camping', 'HIking', 'Water Sports', 'Winter Sports'],
      'Teams': ['Football', 'Basketball', 'Soccer', 'Baseball'],
    },
    'Kids': {
      'Toys': ['Educational', 'Action Figures', 'Dolls', 'Games'],
      'Clothing': ['Shirts', 'Pants', 'Dresses', 'Shoes'],
    },
    'Other': {
      'Misc': ['General', 'Unique', 'Custom'],
    },
  };

  @override
  void initState() {
    super.initState();
    _loadDiscounts();
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
      debugPrint('Error loading discounts: $e');
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

  double _uploadProgress = 0.0;

  void _addVariant() {
    final name = _variantNameCtrl.text.trim();
    final inventoryText = _variantInventoryCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter variant name')),
      );
      return;
    }

    final inventory = int.tryParse(inventoryText);
    if (inventory == null || inventory < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid inventory count')),
      );
      return;
    }

    // Check for duplicate variant names
    if (_variants.any((v) => v.name.toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Variant with this name already exists')),
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
                labelText: 'Variant Name',
                hintText: _variantType == 'Size' ? 'e.g., M' : 'e.g., Red',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: inventoryController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Stock',
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
                  const SnackBar(content: Text('Please enter variant name')),
                );
                return;
              }

              final inventory = int.tryParse(inventoryText);
              if (inventory == null || inventory < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please enter valid inventory count')),
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
                      content: Text('Variant with this name already exists')),
                );
                return;
              }

              setState(() {
                _variants[index] =
                    ProductVariant(name: name, inventory: inventory);
              });

              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return; // prevent double-tap
    if (!_formKey.currentState!.validate()) return;

    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please choose an image')));
      return;
    }

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

      // 3. Create product document reference
      final docRef = FirebaseFirestore.instance.collection('products').doc();

      // 4. Upload image

      // 4. Upload image
      String imageUrl;

      final imageBytes = await _imageFile!.readAsBytes();
      final fileName = ImageUploadService.generateFileName(_imageFile!.name);

      imageUrl = await DirectUploadService.uploadImageDirect(
        imageBytes: imageBytes,
        storeId: storeId,
        productId: docRef.id,
        fileName: fileName,
      );

      // Update progress to 100% since upload completed
      if (mounted) {
        setState(() => _uploadProgress = 1.0);
      }

      // 5. Build product data
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

      final data = {
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'price': price,
        'stock': _hasVariants
            ? 0
            : inventory, // Use 0 for variants, individual inventory for simple products
        'images': [imageUrl],
        'category': _category, // Optional now
        'subcategory': _subcategory, // Optional now
        'leafCategory': _leafCategory, // Optional now
        'isActive': _status == 'Active',
        'storeId': storeId,
        'ownerId': uid,
        'createdAt': Timestamp.now(),
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
        'review': {
          'numberOfReviews': 0,
          'stars': 0,
        },
      };

      // 6. Save product to Firestore
      await docRef.set(data);
      debugPrint('Product saved to Firestore successfully');

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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image picker button and file name
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
                                  label: const Text('Choose Image'),
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

                          // Image preview
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
                                            color:
                                                Colors.black.withOpacity(0.2),
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
                        decoration:
                            const InputDecoration(hintText: 'Enter price'),
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
                                    if (!_isDiscounted) {
                                      _selectedDiscountId = null;
                                    }
                                  })),
                          const Text('Apply Discount'),
                          const SizedBox(width: 16),
                          if (_isDiscounted) ...[
                            Expanded(
                              child: _discountsLoaded
                                  ? _availableDiscounts.isEmpty
                                      ? const Text(
                                          'No active discounts available',
                                          style: TextStyle(
                                            color: Colors.orange,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        )
                                      : DropdownButtonFormField<String>(
                                          value: _selectedDiscountId,
                                          hint: const Text('Select a discount'),
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
                                          validator: (v) {
                                            if (_isDiscounted && v == null) {
                                              return 'Please select a discount';
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
                      _label('Inventory'),
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
                              const Text(
                                  'This product has variants (sizes, colors, etc.)'),
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
                                          value: 'Size', child: Text('Size')),
                                      DropdownMenuItem(
                                          value: 'Color', child: Text('Color')),
                                      DropdownMenuItem(
                                          value: 'Material',
                                          child: Text('Material')),
                                      DropdownMenuItem(
                                          value: 'Style', child: Text('Style')),
                                      DropdownMenuItem(
                                          value: 'Other', child: Text('Other')),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _variantType = v!),
                                    decoration: const InputDecoration(
                                      labelText: 'Variant Type',
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
                                      labelText: 'Variant Name',
                                      hintText: _variantType == 'Size'
                                          ? 'e.g., M'
                                          : 'e.g., Red',
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
                                      labelText: 'Stock',
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
                                  child: const Text('Add'),
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
                                      'Variants (${_variants.length})',
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
                                                '${variant.name} (${variant.inventory} in stock)',
                                                style: const TextStyle(
                                                    fontSize: 14),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.edit,
                                                  color: Colors.blue, size: 18),
                                              onPressed: () =>
                                                  _editVariant(index),
                                              tooltip: 'Edit variant',
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete,
                                                  color: Colors.red, size: 18),
                                              onPressed: () =>
                                                  _removeVariant(index),
                                              tooltip: 'Remove variant',
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    const Divider(),
                                    Text(
                                      'Total Stock: ${_variants.fold<int>(0, (sum, v) => sum + v.inventory)}',
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
                                  hintText: 'Enter inventory count'),
                              validator: (v) {
                                if (!_hasVariants) {
                                  final n = int.tryParse(v ?? '');
                                  if (n == null || n < 0)
                                    return 'Enter valid inventory';
                                }
                                return null;
                              },
                            ),
                          ],
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
                              value: 'Inactive', child: Text('Inactive')),
                        ],
                        onChanged: (v) => setState(() => _status = v!),
                      ),
                      const SizedBox(height: 16),
                      _label('Category (Optional)'),
                      DropdownButtonFormField<String>(
                        value: _category,
                        items: _catMap.keys
                            .map((c) =>
                                DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) => setState(() {
                          _category = v;
                          _subcategory = null;
                          _leafCategory = null;
                        }),
                        decoration: const InputDecoration(
                          hintText: 'Select a category (optional)',
                        ),
                      ),
                      const SizedBox(height: 16),
                      _label('Sub-category (Optional)'),
                      DropdownButtonFormField<String>(
                        value: _subcategory,
                        items: (_category != null)
                            ? _catMap[_category]!
                                .keys
                                .map((s) =>
                                    DropdownMenuItem(value: s, child: Text(s)))
                                .toList()
                            : const [],
                        onChanged: _category == null
                            ? null
                            : (v) => setState(() {
                                  _subcategory = v;
                                  _leafCategory = null;
                                }),
                        decoration: const InputDecoration(
                          hintText: 'Select a sub-category (optional)',
                        ),
                      ),
                      const SizedBox(height: 16),
                      _label('Product Type (Optional)'),
                      DropdownButtonFormField<String>(
                        value: _leafCategory,
                        items: (_category != null && _subcategory != null)
                            ? _catMap[_category]![_subcategory]!
                                .map((leaf) => DropdownMenuItem(
                                    value: leaf, child: Text(leaf)))
                                .toList()
                            : const [],
                        onChanged: (_category == null || _subcategory == null)
                            ? null
                            : (v) => setState(() => _leafCategory = v),
                        decoration: const InputDecoration(
                          hintText: 'Select a product type (optional)',
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
