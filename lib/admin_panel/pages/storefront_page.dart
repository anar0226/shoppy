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
import '../../features/stores/presentation/store_screen.dart';
import '../../features/home/presentation/home_screen.dart';

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
  bool _isUploadingImage = false;
  bool _isSaving = false;
  double _storeRating = 0.0;
  int _reviewCount = 0;

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
          _errorMessage = 'User not authenticated';
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

        // Load real ratings from reviews
        double storeRating = 0.0;
        int reviewCount = 0;

        try {
          final reviewsSnapshot = await FirebaseFirestore.instance
              .collection('stores')
              .doc(store.id)
              .collection('reviews')
              .where('status', isEqualTo: 'active')
              .get();

          if (reviewsSnapshot.docs.isNotEmpty) {
            final reviews = reviewsSnapshot.docs;
            final totalRating = reviews.fold<double>(0, (sum, doc) {
              final data = doc.data();
              return sum + ((data['rating'] as num?)?.toDouble() ?? 0);
            });
            storeRating = totalRating / reviews.length;
            reviewCount = reviews.length;
          }
        } catch (reviewError) {
          print('⚠️ Error loading reviews for admin preview: $reviewError');
        }

        setState(() {
          _storeModel = store;
          _allProducts = products;
          _selectedProductIds = selectedProductIds;
          _backgroundImageUrl = backgroundImage;
          _storeRating = storeRating;
          _reviewCount = reviewCount;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'No store found for this user';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading store data: $e';
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

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Background image updated!')),
        );
      }
    } catch (e) {
      setState(() {
        _isUploadingImage = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Seller card settings saved successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving settings: $e')),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You can only select up to 4 products')),
        );
      }
    });
  }

  Future<void> _previewStoreScreen() async {
    if (_storeModel == null) return;

    try {
      // Load collections for this store
      final collectionsSnapshot = await FirebaseFirestore.instance
          .collection('collections')
          .where('storeId', isEqualTo: _storeModel!.id)
          .where('isActive', isEqualTo: true)
          .get();

      final collections = collectionsSnapshot.docs
          .map((doc) => StoreCollection(
                id: doc.id,
                name: doc.data()['name'] ?? '',
                imageUrl: doc.data()['backgroundImage'] ?? '',
              ))
          .toList();

      // Load managed categories for this store
      final categoriesSnapshot = await FirebaseFirestore.instance
          .collection('store_categories')
          .where('storeId', isEqualTo: _storeModel!.id)
          .where('isActive', isEqualTo: true)
          .orderBy('sortOrder', descending: false)
          .orderBy('createdAt', descending: false)
          .get();

      final categoryNames = <String>['All'];
      categoryNames.addAll(
        categoriesSnapshot.docs
            .map((doc) => doc.data()['name'] as String? ?? '')
            .where((name) => name.isNotEmpty),
      );

      // Build StoreData for the preview
      final storeData = StoreData(
        id: _storeModel!.id,
        name: _storeModel!.name,
        displayName: _storeModel!.name.toUpperCase(),
        heroImageUrl: _storeModel!.banner.isNotEmpty
            ? _storeModel!.banner
            : _storeModel!.logo,
        backgroundColor: const Color(0xFF01BCE7),
        rating: _storeRating > 0 ? _storeRating : 0.0,
        reviewCount: _reviewCount > 0 ? _reviewCount.toString() : '0',
        collections: collections,
        categories: categoryNames,
        productCount: _allProducts.length,
        products: _allProducts
            .map((p) => StoreProduct(
                  id: p.id,
                  name: p.name,
                  imageUrl: p.images.isNotEmpty ? p.images.first : '',
                  price: p.price,
                  category: _getProductCategory(p.id, categoriesSnapshot.docs),
                ))
            .toList(),
        showFollowButton: false, // Hide follow button in preview
        hasNotification: false,
      );

      // Navigate to store screen preview
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(
                title: Text('Store Preview - ${_storeModel!.name}'),
                backgroundColor: AppThemes.primaryColor,
                foregroundColor: Colors.white,
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.edit, color: Colors.white),
                    label: const Text(
                      'Back to Edit',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              body: StoreScreen(storeData: storeData),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading store preview: $e')),
        );
      }
    }
  }

  String _getProductCategory(
      String productId, List<QueryDocumentSnapshot> categoryDocs) {
    for (final doc in categoryDocs) {
      final data = doc.data() as Map<String, dynamic>?;
      final productIds = List<String>.from(data?['productIds'] ?? []);
      if (productIds.contains(productId)) {
        return data?['name'] as String? ?? '';
      }
    }
    return ''; // Product not in any category
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
                const TopNavBar(title: 'Seller Card Management'),
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
                'Storefront Management',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _previewStoreScreen,
                    icon: const Icon(Icons.preview),
                    label: const Text('Preview Store'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppThemes.primaryColor,
                      side: BorderSide(color: AppThemes.primaryColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveSellerCardSettings,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppThemes.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side - Previews
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Seller Card Preview',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        Tooltip(
                          message:
                              'This is how your store appears on the home screen',
                          child: Icon(
                            Icons.info_outline,
                            size: 20,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSellerCardPreview(),
                    const SizedBox(height: 24),
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(
                              Icons.preview,
                              size: 48,
                              color: AppThemes.primaryColor,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Full Store Preview',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'See how your complete store page looks to customers',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _previewStoreScreen,
                              icon: const Icon(Icons.launch),
                              label: const Text('Open Store Preview'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppThemes.primaryColor,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 32),

              // Right side - Customization options
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customization',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    _buildCustomizationOptions(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSellerCardPreview() {
    if (_storeModel == null) return const SizedBox();

    final selectedProducts = _allProducts
        .where((product) => _selectedProductIds.contains(product.id))
        .take(4)
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        image: _backgroundImageUrl != null
            ? DecorationImage(
                image: NetworkImage(_backgroundImageUrl!),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.white.withOpacity(0.7),
                  BlendMode.lighten,
                ),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Seller Info
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.black87,
                child: Text(
                  _storeModel!.name.isNotEmpty
                      ? _storeModel!.name[0].toUpperCase()
                      : 'S',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _storeModel!.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          _storeRating > 0
                              ? _storeRating.toStringAsFixed(1)
                              : '0.0',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.star, color: Colors.black87, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '($_reviewCount)',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.more_horiz,
                color: Colors.black54,
                size: 24,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Products Grid
          if (selectedProducts.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1,
              ),
              itemCount: selectedProducts.length,
              itemBuilder: (context, index) {
                return _buildPreviewProductCard(selectedProducts[index]);
              },
            )
          else
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.grey.shade300, style: BorderStyle.solid),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_shopping_cart, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      'Select up to 4 products\nto feature on your card',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 20),

          // Shop All Button
          const Row(
            children: [
              Text(
                'Shop all',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Spacer(),
              CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFFF0F0F0),
                child: Icon(
                  Icons.arrow_forward,
                  size: 20,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewProductCard(ProductModel product) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // Product Image
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              product.images.isNotEmpty ? product.images.first : '',
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.image, size: 50, color: Colors.grey),
                );
              },
            ),
          ),

          // Price Tag
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '\$${product.price.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.black87,
                ),
              ),
            ),
          ),

          // Heart Icon
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_border,
                size: 16,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
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
                  'Background Image',
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
                          ? 'Change Image'
                          : 'Upload Image'),
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
                        label: const Text('Remove',
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
                      'Featured Products',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Chip(
                      label: Text('${_selectedProductIds.length}/4'),
                      backgroundColor: AppThemes.primaryColor.withOpacity(0.1),
                      labelStyle: TextStyle(
                        color: AppThemes.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Select up to 4 products to feature on your seller card',
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
                        'No products found. Add some products to your store first.',
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
                                            decoration: BoxDecoration(
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
                                        '\$${product.price.toStringAsFixed(0)}',
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
