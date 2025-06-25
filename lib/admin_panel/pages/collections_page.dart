import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/side_menu.dart';
import '../widgets/top_nav_bar.dart';
import '../../features/settings/themes/app_themes.dart';
import '../../features/collections/models/collection_model.dart';
import '../../features/collections/services/collection_service.dart';
import '../../features/products/services/product_service.dart';
import '../../features/products/models/product_model.dart';
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
          SnackBar(content: Text('Error loading store: $e')),
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
        title: const Text('Delete Collection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${collection.name}"?'),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _collectionService.deleteCollection(collection.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Collection deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting collection: $e')),
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
          const SideMenu(selected: 'Collections'),
          Expanded(
            child: Column(
              children: [
                const TopNavBar(title: 'Collections Catalog'),
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
                      hintText: 'Search collections...',
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
                label: const Text('Create Collection'),
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
                                'Error loading collections',
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
                ? 'No collections yet'
                : 'No collections found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Create your first collection to organize your products'
                : 'Try adjusting your search terms',
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
              label: const Text('Create Collection'),
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
                          label: const Text('Edit'),
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
                        tooltip: 'Delete collection',
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
  final _imageController = TextEditingController();
  final CollectionService _collectionService = CollectionService();
  final ProductService _productService = ProductService();

  List<ProductModel> _availableProducts = [];
  List<String> _selectedProductIds = [];
  bool _isLoading = false;
  bool _isLoadingProducts = true;

  @override
  void initState() {
    super.initState();
    if (widget.collection != null) {
      _nameController.text = widget.collection!.name;
      _imageController.text = widget.collection!.backgroundImage;
      _selectedProductIds = List.from(widget.collection!.productIds);
    }
    _loadProducts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _imageController.dispose();
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
          SnackBar(content: Text('Error loading products: $e')),
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
      if (widget.collection == null) {
        // Create new collection
        final collection = CollectionModel(
          id: '',
          name: _nameController.text.trim(),
          storeId: widget.storeId,
          backgroundImage: _imageController.text.trim(),
          productIds: _selectedProductIds,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _collectionService.createCollection(collection);
      } else {
        // Update existing collection
        final updatedCollection = widget.collection!.copyWith(
          name: _nameController.text.trim(),
          backgroundImage: _imageController.text.trim(),
          productIds: _selectedProductIds,
          updatedAt: DateTime.now(),
        );
        await _collectionService.updateCollection(
            widget.collection!.id, updatedCollection);
      }

      widget.onSave();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.collection == null
                ? 'Collection created successfully!'
                : 'Collection updated successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving collection: $e')),
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
                  ? 'Create Collection'
                  : 'Edit Collection',
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
                          labelText: 'Collection Name',
                          border: OutlineInputBorder(),
                          hintText: 'Enter collection name',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a collection name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Background image
                      TextFormField(
                        controller: _imageController,
                        decoration: const InputDecoration(
                          labelText: 'Background Image URL',
                          border: OutlineInputBorder(),
                          hintText: 'Enter image URL (optional)',
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Products selection
                      Text(
                        'Select Products',
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
                          child: const Text('No products available'),
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
                                    '\$${product.price.toStringAsFixed(2)}'),
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
                        '${_selectedProductIds.length} products selected',
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
                  child: const Text('Cancel'),
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
                      : Text(widget.collection == null ? 'Create' : 'Update'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
