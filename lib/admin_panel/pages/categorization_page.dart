import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/side_menu.dart';
import '../widgets/top_nav_bar.dart';
import '../../features/settings/themes/app_themes.dart';
import '../../features/categories/models/category_model.dart';
import '../../features/categories/services/category_service.dart';
import '../../features/products/services/product_service.dart';
import '../../features/products/models/product_model.dart';
import '../auth/auth_service.dart';

class CategorizationPage extends StatefulWidget {
  const CategorizationPage({super.key});

  @override
  State<CategorizationPage> createState() => _CategorizationPageState();
}

class _CategorizationPageState extends State<CategorizationPage> {
  final CategoryService _categoryService = CategoryService();
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
          SnackBar(content: Text(' Алдаа гарлаа: $e')),
        );
      }
    }
  }

  void _showCreateCategoryDialog() {
    if (_currentStoreId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddEditCategoryDialog(
        storeId: _currentStoreId!,
        onSave: () {
          setState(() {}); // Refresh the list
        },
      ),
    );
  }

  void _showEditCategoryDialog(CategoryModel category) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddEditCategoryDialog(
        storeId: _currentStoreId!,
        category: category,
        onSave: () {
          setState(() {}); // Refresh the list
        },
      ),
    );
  }

  void _showManageProductsDialog(CategoryModel category) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ManageProductsDialog(
        category: category,
        storeId: _currentStoreId!,
        onSave: () {
          setState(() {}); // Refresh the list
        },
      ),
    );
  }

  Future<int> _getProductCount(String categoryName) async {
    if (_currentStoreId == null) return 0;
    try {
      final products = await _productService
          .getProductsByCategory(_currentStoreId!, categoryName)
          .first;
      return products.length;
    } catch (e) {
      return 0;
    }
  }

  void _deleteCategory(CategoryModel category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${category.name}"?'),
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
        await _categoryService.deleteCategory(category.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting category: $e')),
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
          const SideMenu(selected: 'Categorization'),
          Expanded(
            child: Column(
              children: [
                const TopNavBar(title: 'Ангилалын бүртгэл'),
                Expanded(
                  child: _currentStoreId == null
                      ? const Center(child: CircularProgressIndicator())
                      : _buildCategorizationContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorizationContent() {
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
                      hintText: 'Ангилал оруулах...',
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
                onPressed: _showCreateCategoryDialog,
                icon: const Icon(Icons.add),
                label: const Text('Ангилал оруулах'),
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

          // Categories list
          Expanded(
            child: FutureBuilder<List<CategoryModel>>(
              future: _searchQuery.isEmpty
                  ? _categoryService.getStoreCategories(_currentStoreId!)
                  : _categoryService.searchCategories(
                      query: _searchQuery, storeId: _currentStoreId!),
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
                          'Ангилал оруулах үед алдаа гарлаа',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
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

                final categories = snapshot.data ?? [];

                if (categories.isEmpty) {
                  return _buildEmptyState();
                }

                return _buildCategoriesList(categories);
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
            Icons.category,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'Одоогоор ангилал алга'
                : 'Ангилал олдсонгүй',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Эхний ангилал оруулах'
                : 'Хайлтын үр дүн олдсонгүй',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade500,
                ),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showCreateCategoryDialog,
              icon: const Icon(Icons.add),
              label: const Text('Ангилал оруулах'),
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

  Widget _buildCategoriesList(List<CategoryModel> categories) {
    return ListView.separated(
      itemCount: categories.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final category = categories[index];
        return _buildCategoryCard(category);
      },
    );
  }

  Widget _buildCategoryCard(CategoryModel category) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppThemes.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.category,
                    color: AppThemes.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      if (category.description?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          category.description!,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                FutureBuilder<int>(
                  future: _getProductCount(category.name),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    return Text(
                      '$count products',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppThemes.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showManageProductsDialog(category),
                    icon: const Icon(Icons.inventory_2, size: 16),
                    label: const Text('Бүтээгдэхүүнүүд ангилах'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppThemes.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _showEditCategoryDialog(category),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Засварлах'),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () => _deleteCategory(category),
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Ангилал устгах',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Add/Edit Category Dialog
class AddEditCategoryDialog extends StatefulWidget {
  final String storeId;
  final CategoryModel? category;
  final VoidCallback onSave;

  const AddEditCategoryDialog({
    super.key,
    required this.storeId,
    this.category,
    required this.onSave,
  });

  @override
  State<AddEditCategoryDialog> createState() => _AddEditCategoryDialogState();
}

class _AddEditCategoryDialogState extends State<AddEditCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final CategoryService _categoryService = CategoryService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!.name;
      _descriptionController.text = widget.category!.description ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.category == null) {
        // Create new category
        await _categoryService.createCategory(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          storeId: widget.storeId,
        );
      } else {
        // Update existing category
        await _categoryService.updateCategory(
          categoryId: widget.category!.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
        );
      }

      widget.onSave();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.category == null
                ? 'Ангилал амжилттай орууллаа!'
                : 'Ангилал амжилттай засварлалаа!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ангилал оруулах үед алдаа гарлаа: $e')),
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
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.category == null ? 'Ангилал оруулах' : 'Ангилал засварлах',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category name
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Ангилалын нэр',
                      border: OutlineInputBorder(),
                      hintText: 'Жишээ нь: шинэ бүтээгдэхүүн',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ангилалын нэр оруулна уу';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Category description
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Тодорхойлолт (заавал биш)',
                      border: OutlineInputBorder(),
                      hintText: 'Ангилалын тодорхойлолт',
                    ),
                    maxLines: 3,
                  ),
                ],
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
                  onPressed: _isLoading ? null : _saveCategory,
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
                      : Text(widget.category == null ? 'Оруулах' : 'Засварлах'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Manage Products Dialog
class ManageProductsDialog extends StatefulWidget {
  final CategoryModel category;
  final String storeId;
  final VoidCallback onSave;

  const ManageProductsDialog({
    super.key,
    required this.category,
    required this.storeId,
    required this.onSave,
  });

  @override
  State<ManageProductsDialog> createState() => _ManageProductsDialogState();
}

class _ManageProductsDialogState extends State<ManageProductsDialog> {
  final ProductService _productService = ProductService();

  List<ProductModel> _availableProducts = [];
  Set<String> _selectedProductIds = {};
  bool _isLoading = false;
  bool _isLoadingProducts = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products =
          await _productService.getStoreProducts(widget.storeId).first;
      setState(() {
        _availableProducts = products;
        // Select products that currently have this category
        _selectedProductIds = products
            .where((product) => product.category == widget.category.name)
            .map((product) => product.id)
            .toSet();
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

  Future<void> _saveProductAssignments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Update each product's category field
      final batch = FirebaseFirestore.instance.batch();

      for (final product in _availableProducts) {
        final shouldHaveCategory = _selectedProductIds.contains(product.id);
        final currentlyHasCategory = product.category == widget.category.name;

        if (shouldHaveCategory && !currentlyHasCategory) {
          // Assign product to this category
          final productRef =
              FirebaseFirestore.instance.collection('products').doc(product.id);
          batch.update(productRef, {'category': widget.category.name});
        } else if (!shouldHaveCategory && currentlyHasCategory) {
          // Remove product from this category
          final productRef =
              FirebaseFirestore.instance.collection('products').doc(product.id);
          batch.update(productRef, {'category': ''});
        }
      }

      await batch.commit();

      widget.onSave();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Бүтээгдэхүүн ангилал амжилттай шинэчлэгдлээ!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ангилал шинэчлэх үед алдаа гарлаа: $e')),
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
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Бүтээгдэхүүнүүд ангилах - ${widget.category.name}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _isLoadingProducts
                  ? const Center(child: CircularProgressIndicator())
                  : _availableProducts.isEmpty
                      ? const Center(child: Text('Бүтээгдэхүүн байхгүй'))
                      : ListView.builder(
                          itemCount: _availableProducts.length,
                          itemBuilder: (context, index) {
                            final product = _availableProducts[index];
                            final isSelected =
                                _selectedProductIds.contains(product.id);

                            return CheckboxListTile(
                              title: Text(product.name),
                              subtitle:
                                  Text('₮${product.price.toStringAsFixed(2)}'),
                              secondary: product.images.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.network(
                                        product.images.first,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Container(
                                            width: 40,
                                            height: 40,
                                            color: Colors.grey.shade200,
                                            child: const Icon(Icons.image,
                                                size: 20),
                                          );
                                        },
                                      ),
                                    )
                                  : Container(
                                      width: 40,
                                      height: 40,
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.image, size: 20),
                                    ),
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
            const SizedBox(height: 16),
            Text(
              '${_selectedProductIds.length} бүтээгдэхүүн сонгогдлоо',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
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
                  onPressed: _isLoading ? null : _saveProductAssignments,
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
                      : const Text('Хадгалах'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
