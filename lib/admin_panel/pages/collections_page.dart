import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/side_menu.dart';
import '../widgets/top_nav_bar.dart';
import '../../features/settings/themes/app_themes.dart';
import '../../features/collections/models/collection_model.dart';
import '../../features/collections/services/collection_service.dart';
import '../../features/products/services/product_service.dart';
import '../../features/products/models/product_model.dart';
import '../../core/utils/popup_utils.dart';
import '../auth/auth_service.dart';

class CollectionsPage extends StatefulWidget {
  const CollectionsPage({super.key});

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  final CollectionService _collectionService = CollectionService();
  final ProductService _productService = ProductService();
  String? _currentStoreId;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrentStore();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentStore() async {
    final ownerId = AuthService.instance.currentUser?.uid;
    if (ownerId == null) return;

    try {
      final storeSnapshot = await FirebaseFirestore.instance
          .collection('stores')
          .where('ownerId', isEqualTo: ownerId)
          .limit(1)
          .get();

      if (storeSnapshot.docs.isNotEmpty) {
        setState(() {
          _currentStoreId = storeSnapshot.docs.first.id;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Алдаа гарлаа: $e')),
        );
      }
    }
  }

  void _showCreateCollectionDialog() {
    if (_currentStoreId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddEditCollectionDialog(
        storeId: _currentStoreId!,
        onSave: () {
          setState(() {}); // Refresh the list
        },
      ),
    );
  }

  void _showEditCollectionDialog(CollectionModel collection) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddEditCollectionDialog(
        storeId: _currentStoreId!,
        collection: collection,
        onSave: () {
          setState(() {}); // Refresh the list
        },
      ),
    );
  }

  void _deleteCollection(CollectionModel collection) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Коллекц устгах'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${collection.name} коллекцыг устгах уу?'),
            const SizedBox(height: 8),
            const Text(
              'Та итгэлтэй байна уу',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Цуцалгах'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Устгах'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success =
            await _collectionService.deleteCollectionWithImages(collection.id);
        if (success && mounted) {
          PopupUtils.showSuccess(
            context: context,
            message: '"${collection.name}" коллекцийг амжилттай устгалаа',
          );
        } else if (mounted) {
          PopupUtils.showError(
            context: context,
            message: 'Коллекц устгахад алдаа гарлаа',
          );
        }
      } catch (e) {
        if (mounted) {
          PopupUtils.showError(
            context: context,
            message: 'Коллекц устгах үед алдаа гарлаа: $e',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemes.getBackgroundColor(context),
      body: Row(
        children: [
          const SideMenu(selected: 'Коллекц'),
          Expanded(
            child: Column(
              children: [
                const TopNavBar(title: 'Коллекцүүд'),
                Expanded(
                  child: _currentStoreId == null
                      ? const Center(child: CircularProgressIndicator())
                      : _buildCollectionsContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionsContent() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with search and add button
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 45,
                  decoration: BoxDecoration(
                    color: AppThemes.getSurfaceColor(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Коллекцүүд хайх...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _showCreateCollectionDialog,
                icon: const Icon(Icons.add),
                label: const Text('Коллекц үүсгэх'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemes.primaryColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Collections list
          Expanded(
            child: _currentStoreId == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<List<CollectionModel>>(
                    stream: _searchQuery.isEmpty
                        ? _collectionService
                            .getStoreCollections(_currentStoreId!)
                        : _collectionService.searchCollections(
                            _currentStoreId!, _searchQuery),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
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
                                'Коллекц оруулах үед алдаа гарлаа',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${snapshot.error}',
                                style: Theme.of(context).textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      final collections = snapshot.data ?? [];

                      if (collections.isEmpty) {
                        return _buildEmptyState();
                      }

                      return _buildCollectionsList(collections);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.collections,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'Коллекц оруулаагүй байна'
                : 'Коллекц оруулаагүй байна',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Эхний коллекц оруулах'
                : 'Хайлтын тэмдэгтүүдийг өөрчлөх',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade500,
                ),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showCreateCollectionDialog,
              icon: const Icon(Icons.add),
              label: const Text('Коллекц үүсгэх'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemes.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCollectionsList(List<CollectionModel> collections) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: collections.length,
      itemBuilder: (context, index) {
        final collection = collections[index];
        return _buildCollectionCard(collection);
      },
    );
  }

  Widget _buildCollectionCard(CollectionModel collection) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collection image
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              clipBehavior: Clip.antiAlias,
              child: collection.backgroundImage.isNotEmpty
                  ? Image.network(
                      collection.backgroundImage,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholderImage();
                      },
                    )
                  : _buildPlaceholderImage(),
            ),
          ),

          // Collection info
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    collection.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${collection.productIds.length} products',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _showEditCollectionDialog(collection),
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Засварлах'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _deleteCollection(collection),
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Коллекц устгах',
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: Colors.grey.shade200,
      child: Icon(
        Icons.collections,
        size: 32,
        color: Colors.grey.shade400,
      ),
    );
  }
}

// Add/Edit Collection Dialog
class AddEditCollectionDialog extends StatefulWidget {
  final String storeId;
  final CollectionModel? collection;
  final VoidCallback onSave;

  const AddEditCollectionDialog({
    super.key,
    required this.storeId,
    this.collection,
    required this.onSave,
  });

  @override
  State<AddEditCollectionDialog> createState() =>
      _AddEditCollectionDialogState();
}

class _AddEditCollectionDialogState extends State<AddEditCollectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final CollectionService _collectionService = CollectionService();
  final ProductService _productService = ProductService();

  List<ProductModel> _availableProducts = [];
  List<String> _selectedProductIds = [];
  bool _isLoading = false;
  bool _isLoadingProducts = true;

  // Image upload variables
  XFile? _selectedBackgroundImage;
  bool _removeBackgroundImage = false;

  bool get isEditing => widget.collection != null;

  @override
  void initState() {
    super.initState();
    if (widget.collection != null) {
      _nameController.text = widget.collection!.name;
      _selectedProductIds = List.from(widget.collection!.productIds);
    }
    _loadProducts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final products =
          await _productService.getStoreProducts(widget.storeId).first;
      setState(() {
        _availableProducts = products;
        _isLoadingProducts = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingProducts = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Бүтээгдэхүүн оруулах үед алдаа гарлаа: $e')),
        );
      }
    }
  }

  Future<void> _pickBackgroundImage() async {
    try {
      final XFile? image = await _collectionService.pickImage();
      if (image != null) {
        // Validate file size (max 5MB)
        final bytes = await image.readAsBytes();
        if (bytes.length > 5 * 1024 * 1024) {
          if (mounted) {
            PopupUtils.showError(
              context: context,
              message: 'Зургийн хэмжээ 5MB-аас бага байх ёстой',
            );
          }
          return;
        }

        // Validate file type
        final fileName = image.name.toLowerCase();
        if (!fileName.endsWith('.jpg') &&
            !fileName.endsWith('.jpeg') &&
            !fileName.endsWith('.png') &&
            !fileName.endsWith('.webp')) {
          if (mounted) {
            PopupUtils.showError(
              context: context,
              message: 'Зөвхөн JPG, PNG, WEBP файл дэмждэг',
            );
          }
          return;
        }

        setState(() {
          _selectedBackgroundImage = image;
          _removeBackgroundImage = false;
        });

        if (mounted) {
          PopupUtils.showSuccess(
            context: context,
            message: 'Арын зураг амжилттай сонгогдлоо',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        PopupUtils.showError(
          context: context,
          message: 'Зураг сонгоход алдаа гарлаа: $e',
        );
      }
    }
  }

  Future<void> _saveCollection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final name = _nameController.text.trim();
      bool success;

      if (isEditing) {
        // Update existing collection
        success = await _collectionService.updateCollectionWithImage(
          collectionId: widget.collection!.id,
          name: name,
          productIds: _selectedProductIds,
          newBackgroundImage: _selectedBackgroundImage,
          removeBackgroundImage: _removeBackgroundImage,
        );
      } else {
        // Create new collection
        final collectionId = await _collectionService.createCollectionWithImage(
          name: name,
          storeId: widget.storeId,
          productIds: _selectedProductIds,
          backgroundImage: _selectedBackgroundImage,
        );
        success = collectionId != null;
      }

      if (success && mounted) {
        Navigator.of(context).pop();
        PopupUtils.showSuccess(
          context: context,
          message: isEditing
              ? '"$name" коллекцийг амжилттай шинэчлэлээ'
              : '"$name" коллекцийг амжилттай үүсгэлээ',
        );
        widget.onSave();
      } else if (mounted) {
        PopupUtils.showError(
          context: context,
          message: isEditing
              ? 'Коллекцийг шинэчлэхэд алдаа гарлаа'
              : 'Коллекц үүсгэхэд алдаа гарлаа',
        );
      }
    } catch (e) {
      if (mounted) {
        PopupUtils.showError(
          context: context,
          message: 'Алдаа гарлаа: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.collection == null
                  ? 'Коллекц үүсгэх'
                  : 'Коллекц засварлах',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Collection name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Коллекцын нэр',
                          border: OutlineInputBorder(),
                          hintText: 'Коллекцын нэр оруулна уу',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Коллекцын нэр оруулна уу';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Background image section
                      _buildImageSection(),
                      const SizedBox(height: 24),

                      // Products selection
                      Text(
                        'Бүтээгдэхүүнүүд сонгох',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 12),

                      if (_isLoadingProducts)
                        const Center(child: CircularProgressIndicator())
                      else if (_availableProducts.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Бүтээгдэхүүн оруулаагүй байна'),
                        )
                      else
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.builder(
                            itemCount: _availableProducts.length,
                            itemBuilder: (context, index) {
                              final product = _availableProducts[index];
                              final isSelected =
                                  _selectedProductIds.contains(product.id);

                              return CheckboxListTile(
                                title: Text(product.name),
                                subtitle: Text(
                                    '₮${product.price.toStringAsFixed(2)}'),
                                value: isSelected,
                                onChanged: (selected) {
                                  setState(() {
                                    if (selected == true) {
                                      _selectedProductIds.add(product.id);
                                    } else {
                                      _selectedProductIds.remove(product.id);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),

                      const SizedBox(height: 8),
                      Text(
                        '${_selectedProductIds.length} бүтээгдэхүүн сонгогдлоо',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Цуцалгах'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveCollection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemes.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          widget.collection == null ? 'Үүсгэх' : 'Засварлах'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Фон зураг',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                'Max 5MB',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        Container(
          width: double.infinity,
          height: 140,
          decoration: BoxDecoration(
            border: Border.all(
              color: _selectedBackgroundImage != null
                  ? Colors.green.shade300
                  : Colors.grey.shade300,
              width: _selectedBackgroundImage != null ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: _selectedBackgroundImage != null
                ? Colors.green.shade50
                : Colors.grey.shade50,
          ),
          child: _selectedBackgroundImage != null
              ? _buildSelectedImagePreview(_selectedBackgroundImage!)
              : (isEditing &&
                      widget.collection!.backgroundImage.isNotEmpty &&
                      !_removeBackgroundImage)
                  ? _buildCurrentImagePreview(
                      widget.collection!.backgroundImage)
                  : _buildImagePlaceholder(),
        ),

        // File info for selected image
        if (_selectedBackgroundImage != null) ...[
          const SizedBox(height: 8),
          FutureBuilder<int>(
            future: _selectedBackgroundImage!
                .readAsBytes()
                .then((bytes) => bytes.length),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final sizeInMB =
                    (snapshot.data! / (1024 * 1024)).toStringAsFixed(2);
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle,
                          size: 16, color: Colors.green.shade600),
                      const SizedBox(width: 6),
                      Text(
                        '${_selectedBackgroundImage!.name} • ${sizeInMB}MB',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ],

        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickBackgroundImage,
                icon: Icon(
                  _selectedBackgroundImage != null ||
                          (isEditing &&
                              widget.collection!.backgroundImage.isNotEmpty &&
                              !_removeBackgroundImage)
                      ? Icons.swap_horiz
                      : Icons.cloud_upload,
                  size: 16,
                ),
                label: Text(
                  _selectedBackgroundImage != null ||
                          (isEditing &&
                              widget.collection!.backgroundImage.isNotEmpty &&
                              !_removeBackgroundImage)
                      ? 'Зураг солих'
                      : 'Файл сонгох',
                ),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  side: const BorderSide(color: AppThemes.primaryColor),
                  foregroundColor: AppThemes.primaryColor,
                ),
              ),
            ),
            if (_selectedBackgroundImage != null ||
                (isEditing &&
                    widget.collection!.backgroundImage.isNotEmpty &&
                    !_removeBackgroundImage)) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedBackgroundImage = null;
                    _removeBackgroundImage = true;
                  });
                },
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Устгах'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red.shade300),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ],
        ),

        // Help text
        const SizedBox(height: 8),
        const Text(
          'JPG, PNG, WEBP файл дэмждэг',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedImagePreview(XFile image) {
    return FutureBuilder<Uint8List>(
      future: image.readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              snapshot.data!,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          );
        } else {
          return Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.grey.shade200,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 8),
                Text(
                  image.name,
                  style: const TextStyle(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildCurrentImagePreview(String imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.grey.shade200,
            child: const Icon(Icons.broken_image, color: Colors.grey),
          );
        },
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            size: 32,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 4),
          Text(
            'Зураг сонгоно уу',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
