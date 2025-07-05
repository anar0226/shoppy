import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/side_menu.dart';
import '../widgets/top_nav_bar.dart';
import '../../features/settings/themes/app_themes.dart';
import '../auth/auth_service.dart';
import '../../features/categories/models/category_model.dart';
import '../../features/categories/services/category_service.dart';
import '../../core/utils/popup_utils.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  String? _currentStoreId;
  List<CategoryModel> _categories = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final CategoryService _categoryService = CategoryService();

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
    if (ownerId == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final storeSnapshot = await FirebaseFirestore.instance
          .collection('stores')
          .where('ownerId', isEqualTo: ownerId)
          .limit(1)
          .get();

      if (storeSnapshot.docs.isNotEmpty) {
        final storeId = storeSnapshot.docs.first.id;
        if (mounted) {
          setState(() {
            _currentStoreId = storeId;
          });
        }
        await _loadCategories();
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

  Future<void> _loadCategories() async {
    if (_currentStoreId == null) return;

    try {
      final categories =
          await _categoryService.getStoreCategories(_currentStoreId!);
      if (mounted) {
        setState(() {
          _categories = categories;
        });
      }
    } catch (e) {
      if (mounted) {
        PopupUtils.showError(
          context: context,
          message: 'Категориуд ачаалахад алдаа гарлаа: $e',
        );
      }
    }
  }

  void _showCreateCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => _CreateEditCategoryDialog(
        storeId: _currentStoreId!,
        onCategoryChanged: () async {
          await _loadCategories();
        },
      ),
    );
  }

  void _showEditCategoryDialog(CategoryModel category) {
    showDialog(
      context: context,
      builder: (context) => _CreateEditCategoryDialog(
        storeId: _currentStoreId!,
        category: category,
        onCategoryChanged: () async {
          await _loadCategories();
        },
      ),
    );
  }

  void _showDeleteCategoryDialog(CategoryModel category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Категорийг устгах'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"${category.name}" категорийг устгах уу?'),
            const SizedBox(height: 8),
            const Text(
              'Энэ үйлдлийг буцаах боломжгүй.',
              style:
                  TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Цуцлах'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success =
                  await _categoryService.deleteCategory(category.id);
              if (success && mounted) {
                PopupUtils.showSuccess(
                  context: context,
                  message: '"${category.name}" категорийг амжилттай устгалаа',
                );
                await _loadCategories();
              } else if (mounted) {
                PopupUtils.showError(
                  context: context,
                  message: 'Категорийг устгахад алдаа гарлаа',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Устгах'),
          ),
        ],
      ),
    );
  }

  void _deleteCategory(String category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Категорийн устгах'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"$category" категорийг устгах уу?'),
            const SizedBox(height: 8),
            const Text(
              'Энэ ангиллын бүх бүтээгдэхүүнийг "Ангилалгүй" гэж тохируулна.',
              style:
                  TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
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
            SnackBar(content: Text('"$category" ангиллыг амжилттай устгалаа')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Алдаа гарлаа: $e')),
          );
        }
      }
    }
  }

  List<CategoryModel> _getFilteredCategories() {
    if (_searchQuery.isEmpty) {
      return _categories;
    }
    return _categories
        .where((category) =>
            category.name.toLowerCase().contains(_searchQuery.toLowerCase()))
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
                const TopNavBar(title: 'Ангиллын хянах'),
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
          // Header with actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Категориуд',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppThemes.getTextColor(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Дэлгүүрийн категориуд болон тэдгээрийн зургуудыг удирдах',
                    style: TextStyle(
                      color: AppThemes.getSecondaryTextColor(context),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showCreateCategoryDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Шинэ категори'),
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

          // Search bar
          SizedBox(
            width: 400,
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: AppThemes.getTextColor(context)),
              decoration: InputDecoration(
                hintText: 'Категори хайх...',
                hintStyle:
                    TextStyle(color: AppThemes.getSecondaryTextColor(context)),
                prefixIcon: Icon(Icons.search,
                    color: AppThemes.getSecondaryTextColor(context)),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              onChanged: (value) {
                if (mounted) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                }
              },
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
    final filteredCategories = _getFilteredCategories();

    if (filteredCategories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'Категори байхгүй байна'
                  : 'Хайлтад тохирох категори олдсонгүй',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                  ? 'Эхний категорииг үүсгэхийн тулд "Шинэ категори" товчийг дарна уу'
                  : 'Хайлтын үгээ өөрчилж дахин оролдоно уу',
              style: TextStyle(
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _showCreateCategoryDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Анхны категорийг үүсгэх'),
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

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: filteredCategories.length,
      itemBuilder: (context, index) {
        final category = filteredCategories[index];
        return _buildCategoryCard(category);
      },
    );
  }

  Widget _buildCategoryCard(CategoryModel category) {
    return Container(
      decoration: BoxDecoration(
        color: AppThemes.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemes.getBorderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category background image
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                color: Colors.grey.shade100,
              ),
              child: category.backgroundImageUrl != null
                  ? ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(12)),
                      child: Stack(
                        children: [
                          Image.network(
                            category.backgroundImageUrl!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildPlaceholderImage();
                            },
                          ),
                          // Overlay for better text readability
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.3),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : _buildPlaceholderImage(),
            ),
          ),

          // Category info and actions
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category name
                  Text(
                    category.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppThemes.getTextColor(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (category.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      category.description!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppThemes.getSecondaryTextColor(context),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const Spacer(),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showEditCategoryDialog(category),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            side: const BorderSide(color: AppThemes.primaryColor),
                          ),
                          child: const Text(
                            'Засах',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppThemes.primaryColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _showDeleteCategoryDialog(category),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        style: IconButton.styleFrom(
                          foregroundColor: Colors.red,
                          backgroundColor: Colors.red.withOpacity(0.1),
                          padding: const EdgeInsets.all(8),
                        ),
                        tooltip: 'Устгах',
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
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
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
            'Зураг байхгүй',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
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
      title: const Text('Ангиллын үүсгэх'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          decoration: const InputDecoration(
            labelText: 'Ангиллын нэр',
            border: OutlineInputBorder(),
            hintText:
                'Жишээ нь, шинээр ирсэн бүтээгдэхүүнүүд, хамгийн сайн загвар',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Ангиллын нэр оруулна уу';
            }
            return null;
          },
          autofocus: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Цуцалгах'),
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
                      '"$categoryName" ангиллыг бүтээгдэхүүнүүдээс үүсгэсэн'),
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppThemes.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Үүсгэх'),
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
            content: Text('"$newName" ангиллыг амжилттай өөрчлөгдлөө'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Алдаа гарлаа: $e')),
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
      title: const Text('Ангиллын өөрчлөлт'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          decoration: const InputDecoration(
            labelText: 'Ангиллын нэр',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Ангиллын нэр оруулна уу';
            }
            return null;
          },
          autofocus: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Цуцалгах'),
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
              : const Text('Өөрчлөх'),
        ),
      ],
    );
  }
}

// Create/Edit Category Dialog with Image Management
class _CreateEditCategoryDialog extends StatefulWidget {
  final String storeId;
  final CategoryModel? category; // null for create, non-null for edit
  final VoidCallback onCategoryChanged;

  const _CreateEditCategoryDialog({
    required this.storeId,
    this.category,
    required this.onCategoryChanged,
  });

  @override
  State<_CreateEditCategoryDialog> createState() =>
      __CreateEditCategoryDialogState();
}

class __CreateEditCategoryDialogState extends State<_CreateEditCategoryDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final CategoryService _categoryService = CategoryService();

  bool _isLoading = false;
  XFile? _selectedBackgroundImage;
  XFile? _selectedIconImage;
  bool _removeBackgroundImage = false;
  bool _removeIcon = false;

  bool get isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
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

  Future<void> _pickBackgroundImage() async {
    try {
      final XFile? image = await _categoryService.pickImage();
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

  Future<void> _pickIconImage() async {
    try {
      final XFile? image = await _categoryService.pickImage();
      if (image != null) {
        // Validate file size (max 2MB for icons)
        final bytes = await image.readAsBytes();
        if (bytes.length > 2 * 1024 * 1024) {
          if (mounted) {
            PopupUtils.showError(
              context: context,
              message: 'Дүрс тэмдгийн хэмжээ 2MB-аас бага байх ёстой',
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
          _selectedIconImage = image;
          _removeIcon = false;
        });

        if (mounted) {
          PopupUtils.showSuccess(
            context: context,
            message: 'Дүрс тэмдэг амжилттай сонгогдлоо',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        PopupUtils.showError(
          context: context,
          message: 'Зураг сонгохд алдаа гарлаа: $e',
        );
      }
    }
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim();

      bool success;
      if (isEditing) {
        // Update existing category
        success = await _categoryService.updateCategory(
          categoryId: widget.category!.id,
          name: name,
          description: description.isEmpty ? null : description,
          newBackgroundImage: _selectedBackgroundImage,
          newIconImage: _selectedIconImage,
          removeBackgroundImage: _removeBackgroundImage,
          removeIcon: _removeIcon,
        );
      } else {
        // Create new category
        final categoryId = await _categoryService.createCategory(
          name: name,
          description: description.isEmpty ? null : description,
          storeId: widget.storeId,
          backgroundImage: _selectedBackgroundImage,
          iconImage: _selectedIconImage,
        );
        success = categoryId != null;
      }

      if (success && mounted) {
        Navigator.of(context).pop();
        PopupUtils.showSuccess(
          context: context,
          message: isEditing
              ? '"$name" категорийг амжилттай шинэчлэлээ'
              : '"$name" категорийг амжилттай үүсгэлээ',
        );
        widget.onCategoryChanged();
      } else if (mounted) {
        PopupUtils.showError(
          context: context,
          message: isEditing
              ? 'Категорийг шинэчлэхэд алдаа гарлаа'
              : 'Категори үүсгэхэд алдаа гарлаа',
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
        constraints: const BoxConstraints(maxHeight: 800),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              isEditing ? 'Категори засах' : 'Шинэ категори үүсгэх',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Form
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Категорийн нэр *',
                          border: OutlineInputBorder(),
                          hintText: 'Жишээ: Эрэгтэй хувцас, Гоо сайхан',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Категорийн нэр оруулна уу';
                          }
                          return null;
                        },
                        autofocus: true,
                      ),
                      const SizedBox(height: 16),

                      // Category description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Тайлбар (заавал биш)',
                          border: OutlineInputBorder(),
                          hintText: 'Категорийн тухай товч тайлбар',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 24),

                      // Background image section
                      _buildImageSection(
                        title: 'Арын зураг',
                        currentImageUrl: isEditing
                            ? widget.category!.backgroundImageUrl
                            : null,
                        selectedImage: _selectedBackgroundImage,
                        onPickImage: _pickBackgroundImage,
                        onRemoveImage: () {
                          setState(() {
                            _selectedBackgroundImage = null;
                            _removeBackgroundImage = true;
                          });
                        },
                        isRemoved: _removeBackgroundImage,
                      ),
                      const SizedBox(height: 24),

                      // Icon image section
                      _buildImageSection(
                        title: 'Дүрс тэмдэг',
                        currentImageUrl:
                            isEditing ? widget.category!.iconUrl : null,
                        selectedImage: _selectedIconImage,
                        onPickImage: _pickIconImage,
                        onRemoveImage: () {
                          setState(() {
                            _selectedIconImage = null;
                            _removeIcon = true;
                          });
                        },
                        isRemoved: _removeIcon,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Цуцлах'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveCategory,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemes.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isEditing ? 'Шинэчлэх' : 'Үүсгэх'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection({
    required String title,
    required String? currentImageUrl,
    required XFile? selectedImage,
    required VoidCallback onPickImage,
    required VoidCallback onRemoveImage,
    required bool isRemoved,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
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
                title.contains('Арын') ? 'Max 5MB' : 'Max 2MB',
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
              color: selectedImage != null
                  ? Colors.green.shade300
                  : Colors.grey.shade300,
              width: selectedImage != null ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: selectedImage != null
                ? Colors.green.shade50
                : Colors.grey.shade50,
          ),
          child: selectedImage != null
              ? _buildSelectedImagePreview(selectedImage)
              : currentImageUrl != null && !isRemoved
                  ? _buildCurrentImagePreview(currentImageUrl)
                  : _buildImagePlaceholder(),
        ),

        // File info for selected image
        if (selectedImage != null) ...[
          const SizedBox(height: 8),
          FutureBuilder<int>(
            future: selectedImage.readAsBytes().then((bytes) => bytes.length),
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
                        '${selectedImage.name} • ${sizeInMB}MB',
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
                onPressed: onPickImage,
                icon: Icon(
                  selectedImage != null ||
                          (currentImageUrl != null && !isRemoved)
                      ? Icons.swap_horiz
                      : Icons.cloud_upload,
                  size: 16,
                ),
                label: Text(
                  selectedImage != null ||
                          (currentImageUrl != null && !isRemoved)
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
            if (selectedImage != null ||
                (currentImageUrl != null && !isRemoved)) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onRemoveImage,
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
        Text(
          'JPG, PNG, WEBP файл дэмждэг',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
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
