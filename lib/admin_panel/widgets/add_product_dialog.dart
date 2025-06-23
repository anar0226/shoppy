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
import '../../core/services/direct_upload_service.dart';

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

      // 1. Get current user and verify permissions
      final uid = AuthService.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not signed in');

      final user = FirebaseAuth.instance.currentUser;
      debugPrint('STEP 1a: User email: ${user?.email}');
      debugPrint('STEP 1b: Email verified: ${user?.emailVerified}');
      debugPrint('STEP 1c: User UID: $uid');

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

      // 4. Run quick diagnostics (with timeout)
      debugPrint('STEP 3: Running Firebase diagnostics...');
      try {
        final diagnostics = await UploadDebugService.runDiagnostics().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint(
                '⚠️ Diagnostics timed out, proceeding with upload anyway');
            return <String, dynamic>{'timeout': true};
          },
        );

        if (diagnostics.containsKey('timeout')) {
          debugPrint('STEP 3a: Diagnostics skipped due to timeout');
        } else {
          UploadDebugService.printDiagnostics(diagnostics);
          debugPrint('STEP 3a: Diagnostics completed');
        }
      } catch (e) {
        debugPrint('STEP 3a: Diagnostics failed: $e (proceeding anyway)');
      }

      // 5. Upload image - Skip broken Firebase SDK, use direct HTTP
      String imageUrl;
      debugPrint('STEP 4: Starting image upload (direct HTTP method)...');

      try {
        final imageBytes = await _imageFile!.readAsBytes();
        final fileName = ImageUploadService.generateFileName(_imageFile!.name);

        debugPrint(
            'STEP 4a: Using direct HTTP upload (bypassing Firebase SDK)...');
        imageUrl = await DirectUploadService.uploadImageDirect(
          imageBytes: imageBytes,
          storeId: storeId,
          productId: docRef.id,
          fileName: fileName,
        );
        debugPrint('STEP 4a: Direct upload successful - $imageUrl');

        // Update progress to 100% since upload completed
        if (mounted) {
          setState(() => _uploadProgress = 1.0);
        }
      } catch (e) {
        debugPrint('STEP 4a: Direct upload failed: $e');
        throw Exception('Direct HTTP upload failed: $e');
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
      debugPrint('STEP 5: Attempting to save product to Firestore...');
      debugPrint('STEP 5a: User UID: $uid');
      debugPrint('STEP 5b: Product data: $data');
      debugPrint('STEP 5c: Document path: ${docRef.path}');

      try {
        await docRef.set(data);
        debugPrint('STEP 5d: product saved to Firestore successfully');
      } catch (firestoreError) {
        debugPrint('STEP 5d: Firestore save failed: $firestoreError');

        // Try to get current user token info
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final token = await user.getIdToken();
          debugPrint('STEP 5e: User token length: ${token?.length ?? 0}');
          debugPrint('STEP 5f: User email verified: ${user.emailVerified}');

          // Try a simple test write to see if auth works at all
          try {
            await FirebaseFirestore.instance
                .collection('test')
                .doc('auth-test')
                .set({
              'timestamp': Timestamp.now(),
              'uid': uid,
              'test': 'permission test'
            });
            debugPrint('STEP 5g: Test write succeeded - rules are working');
          } catch (testError) {
            debugPrint('STEP 5g: Test write also failed: $testError');
          }
        }

        rethrow;
      }

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

                      // DEBUG: Temporary test buttons
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                if (_imageFile == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Choose an image first!')),
                                  );
                                  return;
                                }

                                debugPrint('🚀 TESTING DIRECT HTTP UPLOAD...');
                                try {
                                  final uid =
                                      AuthService.instance.currentUser?.uid;
                                  if (uid == null)
                                    throw Exception('Not signed in');

                                  final imageBytes =
                                      await _imageFile!.readAsBytes();
                                  final fileName =
                                      ImageUploadService.generateFileName(
                                          _imageFile!.name);

                                  final url = await DirectUploadService
                                      .uploadImageDirect(
                                    imageBytes: imageBytes,
                                    storeId: 'test',
                                    productId: 'test-product',
                                    fileName: fileName,
                                  );

                                  debugPrint('🚀 TEST UPLOAD SUCCESSFUL: $url');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            '✅ Direct upload works! Check console')),
                                  );
                                } catch (e) {
                                  debugPrint('🚀 TEST UPLOAD FAILED: $e');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('❌ Test failed: $e')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.upload, size: 16),
                              label: const Text('Test Direct Upload'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade100,
                                foregroundColor: Colors.green.shade800,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                debugPrint(
                                    '🔍 MANUAL DIAGNOSTICS TEST STARTED');
                                try {
                                  final results =
                                      await UploadDebugService.runDiagnostics();
                                  UploadDebugService.printDiagnostics(results);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Check console for diagnostics results')),
                                  );
                                } catch (e) {
                                  debugPrint(
                                      '🔍 MANUAL DIAGNOSTICS FAILED: $e');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text('Diagnostics failed: $e')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.bug_report, size: 16),
                              label: const Text('Test Connection'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade100,
                                foregroundColor: Colors.blue.shade800,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
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
