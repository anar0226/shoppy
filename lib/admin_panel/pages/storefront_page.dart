import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/side_menu.dart';
import '../widgets/top_nav_bar.dart';
import '../../features/settings/themes/app_themes.dart';
import '../../features/stores/models/store_model.dart';
import '../../features/products/services/product_service.dart';
import '../../features/products/models/product_model.dart';
import '../../core/services/image_upload_service.dart';
import '../auth/auth_service.dart';

class StorefrontPage extends StatefulWidget {
  const StorefrontPage({super.key});

  @override
  State<StorefrontPage> createState() => _StorefrontPageState();
}

class _StorefrontPageState extends State<StorefrontPage> {
  StoreModel? _storeModel;
  bool _isLoading = true;
  String _errorMessage = '';
  List<ProductModel> _allProducts = [];
  List<String> _selectedProductIds = [];
  String? _backgroundImageUrl;
  String? _profileImageUrl;
  bool _isUploadingImage = false;
  bool _isUploadingProfileImage = false;
  bool _isSaving = false;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadStoreData();
  }

  Future<void> _loadStoreData() async {
    try {
      final ownerId = AuthService.instance.currentUser?.uid;
      if (ownerId == null) {
        setState(() {
          _errorMessage = 'Хэрэглэгч олдсонгүй';
          _isLoading = false;
        });
        return;
      }

      final storeSnapshot = await FirebaseFirestore.instance
          .collection('stores')
          .where('ownerId', isEqualTo: ownerId)
          .limit(1)
          .get();

      if (storeSnapshot.docs.isNotEmpty) {
        final store = StoreModel.fromFirestore(storeSnapshot.docs.first);

        // Load products for this store
        final productService = ProductService();
        final productsStream = productService.getStoreProducts(store.id);
        final products = await productsStream.first;

        // Load existing seller card settings
        final sellerCardDoc = await FirebaseFirestore.instance
            .collection('seller_cards')
            .doc(store.id)
            .get();

        List<String> selectedProductIds = [];
        String? backgroundImage;

        if (sellerCardDoc.exists) {
          final data = sellerCardDoc.data()!;
          selectedProductIds =
              List<String>.from(data['featuredProductIds'] ?? []);
          backgroundImage = data['backgroundImageUrl'];
        }

        setState(() {
          _storeModel = store;
          _allProducts = products;
          _selectedProductIds = selectedProductIds;
          _backgroundImageUrl = backgroundImage;
          _profileImageUrl = store.logo;

          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Хэрэглэгчийн дэлгүүр олдсонгүй';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Алдаа гарлаа: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectBackgroundImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _isUploadingImage = true;
        });

        final imageUrl = await ImageUploadService.uploadImageFile(
          image,
          'seller_cards/${_storeModel!.id}/background_${DateTime.now().millisecondsSinceEpoch}',
        );

        setState(() {
          _backgroundImageUrl = imageUrl;
          _isUploadingImage = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Дэвсгэр зургийг амжилттай өөрчилсөн')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isUploadingImage = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Алдаа гарлаа: $e')),
        );
      }
    }
  }

  Future<void> _selectProfileImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _isUploadingProfileImage = true;
        });

        final imageUrl = await ImageUploadService.uploadImageFile(
          image,
          'stores/${_storeModel!.id}/profile_${DateTime.now().millisecondsSinceEpoch}',
        );

        // Update the store logo in Firestore
        await FirebaseFirestore.instance
            .collection('stores')
            .doc(_storeModel!.id)
            .update({'logo': imageUrl});

        setState(() {
          _profileImageUrl = imageUrl;
          _storeModel = _storeModel!.copyWith(logo: imageUrl);
          _isUploadingProfileImage = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Профайл зургийг амжилттай өөрчилсөн')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isUploadingProfileImage = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Алдаа гарлаа: $e')),
        );
      }
    }
  }

  Future<void> _saveSellerCardSettings() async {
    if (_storeModel == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('seller_cards')
          .doc(_storeModel!.id)
          .set({
        'storeId': _storeModel!.id,
        'featuredProductIds': _selectedProductIds,
        'backgroundImageUrl': _backgroundImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Тохиргоо амжилттай хадгалагдлаа')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Алдаа гарлаа: $e')),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _toggleProductSelection(String productId) {
    setState(() {
      if (_selectedProductIds.contains(productId)) {
        _selectedProductIds.remove(productId);
      } else if (_selectedProductIds.length < 4) {
        _selectedProductIds.add(productId);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Та 4 бараа сонгох боломжтой')),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemes.getBackgroundColor(context),
      body: Row(
        children: [
          const SideMenu(selected: 'Storefront'),
          Expanded(
            child: Column(
              children: [
                const TopNavBar(title: 'Дэлгүүрээ янзлаx'),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _errorMessage.isNotEmpty
                          ? _buildErrorView()
                          : _buildManagementView(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Дэлгүүрээ янзлаx',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveSellerCardSettings,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Хадгалаж байна...' : 'Хадгалах'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemes.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Single column layout with store settings
          _buildStoreSettings(),
        ],
      ),
    );
  }

  Widget _buildStoreSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile Picture Section
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Дэлгүүрээ янзлаx',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Энэ зураг нь таны дэлгүүрийн профайл зураг',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Current profile picture preview
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade200,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _profileImageUrl != null &&
                                _profileImageUrl!.isNotEmpty
                            ? Image.network(
                                _profileImageUrl!,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey.shade300,
                                    child: Icon(
                                      Icons.store,
                                      color: Colors.grey.shade600,
                                      size: 40,
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: Colors.grey.shade300,
                                child: Icon(
                                  Icons.store,
                                  color: Colors.grey.shade600,
                                  size: 40,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Upload buttons
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _isUploadingProfileImage
                                    ? null
                                    : _selectProfileImage,
                                icon: _isUploadingProfileImage
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.upload),
                                label: Text(_profileImageUrl != null &&
                                        _profileImageUrl!.isNotEmpty
                                    ? 'Зургийг өөрчлөх'
                                    : 'Зураг оруулах'),
                              ),
                              if (_profileImageUrl != null &&
                                  _profileImageUrl!.isNotEmpty) ...[
                                const SizedBox(width: 12),
                                TextButton.icon(
                                  onPressed: () async {
                                    try {
                                      // Remove profile picture by setting logo to empty string
                                      await FirebaseFirestore.instance
                                          .collection('stores')
                                          .doc(_storeModel!.id)
                                          .update({'logo': ''});

                                      setState(() {
                                        _profileImageUrl = '';
                                        _storeModel =
                                            _storeModel!.copyWith(logo: '');
                                      });

                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'Профайл зургийг устгалаа')),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content:
                                                  Text('Алдаа гарлаа: $e')),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  label: const Text('Устгах',
                                      style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '400x400 пиксел буюу түүнээс дээш хэмжээтэй зураг байршуулxийг зөвлөж байна. .',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildCustomizationOptions(),
      ],
    );
  }

  Widget _buildCustomizationOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Background Image Section
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Дэвсгэр зургийг янзлаx',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                if (_backgroundImageUrl != null) ...[
                  Container(
                    width: double.infinity,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage(_backgroundImageUrl!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed:
                          _isUploadingImage ? null : _selectBackgroundImage,
                      icon: _isUploadingImage
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload),
                      label: Text(_backgroundImageUrl != null
                          ? 'Зургийг өөрчлөх'
                          : 'Зураг оруулах'),
                    ),
                    if (_backgroundImageUrl != null) ...[
                      const SizedBox(width: 12),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _backgroundImageUrl = null;
                          });
                        },
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text('Устгах',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Featured Products Section
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Онцлох бүтээгдэхүүн',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Chip(
                      label: Text('${_selectedProductIds.length}/4'),
                      backgroundColor:
                          AppThemes.primaryColor.withValues(alpha: 0.1),
                      labelStyle: const TextStyle(
                        color: AppThemes.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Та 4-н онцлох бүтээгдэхүүн сонгох боломжтой',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
                const SizedBox(height: 16),
                if (_allProducts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Center(
                      child: Text(
                        'Бараа олдсонгүй. Эхлээд дэлгүүртээ бараа нэмэх хэрэгтэй.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 400,
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.8,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _allProducts.length,
                      itemBuilder: (context, index) {
                        final product = _allProducts[index];
                        final isSelected =
                            _selectedProductIds.contains(product.id);

                        return GestureDetector(
                          onTap: () => _toggleProductSelection(product.id),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? AppThemes.primaryColor
                                    : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                          top: Radius.circular(8),
                                        ),
                                        child: Image.network(
                                          product.images.isNotEmpty
                                              ? product.images.first
                                              : '',
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey[200],
                                              child: const Icon(
                                                Icons.image,
                                                size: 30,
                                                color: Colors.grey,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      if (isSelected)
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            decoration: const BoxDecoration(
                                              color: AppThemes.primaryColor,
                                              shape: BoxShape.circle,
                                            ),
                                            padding: const EdgeInsets.all(4),
                                            child: const Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '₮${product.price.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Error',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _errorMessage = '';
              });
              _loadStoreData();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
