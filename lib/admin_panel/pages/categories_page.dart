import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/side_menu.dart';
import '../widgets/top_nav_bar.dart';
import '../../features/settings/themes/app_themes.dart';
import '../auth/auth_service.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  String? _currentStoreId;
  final List<String> _categories = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
        final storeId = storeSnapshot.docs.first.id;
        setState(() {
          _currentStoreId = storeId;
        });
        await _loadCategories();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading store: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCategories() async {
    if (_currentStoreId == null) return;

    try {
      final productSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('storeId', isEqualTo: _currentStoreId)
          .get();

      final categorySet = <String>{};
      for (final doc in productSnapshot.docs) {
        final category = doc.data()['category'] as String?;
        if (category != null && category.isNotEmpty) {
          categorySet.add(category);
        }
      }

      setState(() {
        _categories.clear();
        _categories.addAll(categorySet.toList()..sort());
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading categories: $e')),
        );
      }
    }
  }

  void _showCreateCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => _CreateCategoryDialog(
        onCategoryCreated: (category) async {
          await _loadCategories();
        },
      ),
    );
  }

  void _showRenameCategoryDialog(String currentCategory) {
    showDialog(
      context: context,
      builder: (context) => _RenameCategoryDialog(
        currentCategory: currentCategory,
        storeId: _currentStoreId!,
        onCategoryRenamed: () async {
          await _loadCategories();
        },
      ),
    );
  }

  void _deleteCategory(String category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "$category"?'),
            const SizedBox(height: 8),
            const Text(
              'All products in this category will be set to "Uncategorized".',
              style:
                  TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
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
        // Update all products in this category to "Uncategorized"
        final batch = FirebaseFirestore.instance.batch();
        final productsSnapshot = await FirebaseFirestore.instance
            .collection('products')
            .where('storeId', isEqualTo: _currentStoreId)
            .where('category', isEqualTo: category)
            .get();

        for (final doc in productsSnapshot.docs) {
          batch.update(doc.reference, {'category': 'Uncategorized'});
        }

        await batch.commit();
        await _loadCategories();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Category "$category" deleted successfully')),
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

  List<String> _getFilteredCategories() {
    if (_searchQuery.isEmpty) {
      return _categories;
    }
    return _categories
        .where((category) =>
            category.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemes.getBackgroundColor(context),
      body: Row(
        children: [
          const SideMenu(selected: 'Categories'),
          Expanded(
            child: Column(
              children: [
                const TopNavBar(title: 'Categories Management'),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildCategoriesContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesContent() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Categories are automatically created when you assign them to products.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _buildCategoriesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesList() {
    if (_categories.isEmpty) {
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
              'No categories yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Categories will appear here when you assign them to products',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade500,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _categories.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final category = _categories[index];
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppThemes.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.category,
                color: AppThemes.primaryColor,
                size: 20,
              ),
            ),
            title: Text(
              category,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: FutureBuilder<int>(
              future: _getProductCount(category),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                return Text('$count products');
              },
            ),
          ),
        );
      },
    );
  }

  Future<int> _getProductCount(String category) async {
    if (_currentStoreId == null) return 0;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('storeId', isEqualTo: _currentStoreId)
          .where('category', isEqualTo: category)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }
}

// Create Category Dialog
class _CreateCategoryDialog extends StatefulWidget {
  final Function(String) onCategoryCreated;

  const _CreateCategoryDialog({required this.onCategoryCreated});

  @override
  State<_CreateCategoryDialog> createState() => __CreateCategoryDialogState();
}

class __CreateCategoryDialogState extends State<_CreateCategoryDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Category'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            border: OutlineInputBorder(),
            hintText: 'e.g., New Arrivals, Best Sellers',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a category name';
            }
            return null;
          },
          autofocus: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final categoryName = _controller.text.trim();
              widget.onCategoryCreated(categoryName);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Category "$categoryName" will be available when you assign products to it'),
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppThemes.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Create'),
        ),
      ],
    );
  }
}

// Rename Category Dialog
class _RenameCategoryDialog extends StatefulWidget {
  final String currentCategory;
  final String storeId;
  final VoidCallback onCategoryRenamed;

  const _RenameCategoryDialog({
    required this.currentCategory,
    required this.storeId,
    required this.onCategoryRenamed,
  });

  @override
  State<_RenameCategoryDialog> createState() => __RenameCategoryDialogState();
}

class __RenameCategoryDialogState extends State<_RenameCategoryDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.currentCategory;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _renameCategory() async {
    if (!_formKey.currentState!.validate()) return;

    final newName = _controller.text.trim();
    if (newName == widget.currentCategory) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Update all products with the old category name to the new name
      final batch = FirebaseFirestore.instance.batch();
      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('storeId', isEqualTo: widget.storeId)
          .where('category', isEqualTo: widget.currentCategory)
          .get();

      for (final doc in productsSnapshot.docs) {
        batch.update(doc.reference, {'category': newName});
      }

      await batch.commit();
      widget.onCategoryRenamed();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Category renamed to "$newName" successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error renaming category: $e')),
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
    return AlertDialog(
      title: const Text('Rename Category'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a category name';
            }
            return null;
          },
          autofocus: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _renameCategory,
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
              : const Text('Rename'),
        ),
      ],
    );
  }
}
