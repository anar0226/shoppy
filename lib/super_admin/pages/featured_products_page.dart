import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/error_handler_service.dart';

class FeaturedProductsPage extends StatefulWidget {
  const FeaturedProductsPage({super.key});

  @override
  State<FeaturedProductsPage> createState() => _FeaturedProductsPageState();
}

class _FeaturedProductsPageState extends State<FeaturedProductsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedCategory;
  String? _selectedSubcategory;
  String? _selectedLeafCategory;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _subcategories = [];
  List<Map<String, dynamic>> _leafCategories = [];
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _featuredProducts = [];
  List<String> _selectedProductIds = [];

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkAuthenticationAndLoadData();
  }

  Future<void> _checkAuthenticationAndLoadData() async {
    try {
      // Starting authentication and permission check

      // Check current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Authentication required. Please log in as a super admin.';
          _isLoading = false;
        });
        return;
      }

      // Check if user has super admin document
      bool isSuperAdmin = false;
      try {
        final superAdminDoc =
            await _firestore.collection('super_admins').doc(user.uid).get();
        if (superAdminDoc.exists) {
          isSuperAdmin = true;
        }
      } catch (e) {
        debugPrint('Error checking super admin status: $e');
      }

      if (!isSuperAdmin) {
        setState(() {
          _error = 'Insufficient permissions. Super admin access required.';
          _isLoading = false;
        });
        return;
      }

      // Now proceed with loading data
      await _loadInitialData();
    } catch (e) {
      // Error in authentication check
      setState(() {
        _error = 'Authentication check failed: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadInitialData() async {
    try {
      // Starting _loadInitialData()
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // About to load categories and products in parallel

      // Load them separately to better identify which one fails
      // Step 1 - Loading categories...
      await _loadCategories();
      // Categories loaded successfully

      // Step 2 - Loading all products...
      await _loadAllProducts();
      // All products loaded successfully

      // Successfully loaded all initial data
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      // Error in _loadInitialData()
      String errorMessage = 'Failed to load data: $e';
      if (e.toString().contains('permission-denied')) {
        errorMessage =
            'Permission denied. Please ensure you have super admin access and proper Firestore rules are configured.';
      }
      setState(() {
        _error = errorMessage;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCategories() async {
    try {
      // Starting _loadCategories()

      final categoriesSnapshot =
          await _firestore.collection('categories').get();

      // Successfully read categories collection

      if (categoriesSnapshot.docs.isEmpty) {
        // No categories found, creating sample categories
        // Create sample categories if none exist
        await _createSampleCategories();
        // Reload categories after creation
        final newSnapshot = await _firestore.collection('categories').get();
        _categories = newSnapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList();
        // Successfully loaded categories after creation
      } else {
        _categories = categoriesSnapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList();
        // Successfully loaded existing categories
      }
    } catch (e) {
      // Error in _loadCategories()
      if (e.toString().contains('permission-denied')) {
        throw Exception(
            'Permission denied accessing categories. Please check Firestore rules for super admin access.');
      }
      rethrow;
    }
  }

  Future<void> _createSampleCategories() async {
    try {
      // Starting _createSampleCategories()

      // Create basic categories
      final categories = [
        {'id': 'Эмэгтэй', 'name': 'Эмэгтэй'},
        {'id': 'Эрэгтэй', 'name': 'Эрэгтэй'},
        {'id': 'Electronics', 'name': 'Electronics'},
        {'id': 'Toys&games', 'name': 'Toys & games'},
        {'id': 'Accessories', 'name': 'Accessories'},
      ];

      // Creating sample categories

      for (final category in categories) {
        // Creating category
        await _firestore.collection('categories').doc(category['id']).set({
          'name': category['name'],
          'createdAt': FieldValue.serverTimestamp(),
        });
        // Successfully created category
      }

      // All sample categories created successfully
    } catch (e) {
      // Error in _createSampleCategories()
      if (e.toString().contains('permission-denied')) {
        throw Exception(
            'Permission denied creating categories. Please check Firestore write rules for super admin access.');
      }
      rethrow;
    }
  }

  Future<void> _loadAllProducts() async {
    try {
      // Starting _loadAllProducts()

      final productsSnapshot =
          await _firestore.collectionGroup('products').get();

      // Successfully executed collectionGroup query

      _allProducts = productsSnapshot.docs
          .map((doc) => {
                'id': doc.id,
                'storeId': doc.reference.parent.parent!.id,
                ...doc.data(),
              })
          .toList();

      // Successfully processed products

      // Show first few products
      if (_allProducts.isNotEmpty) {
        // Sample products loaded
        for (int i = 0; i < _allProducts.length && i < 3; i++) {
          // Product loaded
        }
      }
    } catch (e) {
      // Error in _loadAllProducts()
      if (e.toString().contains('permission-denied')) {
        throw Exception(
            'Permission denied accessing products. Please check Firestore rules for collectionGroup("products") access.');
      }
      rethrow;
    }
  }

  Future<void> _loadSubcategories(String categoryId) async {
    final subcategoriesSnapshot = await _firestore
        .collection('categories')
        .doc(categoryId)
        .collection('subcategories')
        .get();

    setState(() {
      _subcategories = subcategoriesSnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
      _selectedSubcategory = null;
      _selectedLeafCategory = null;
      _leafCategories = [];
    });
  }

  Future<void> _loadLeafCategories(
      String categoryId, String subcategoryId) async {
    final leafCategoriesSnapshot = await _firestore
        .collection('categories')
        .doc(categoryId)
        .collection('subcategories')
        .doc(subcategoryId)
        .collection('leafCategories')
        .get();

    setState(() {
      _leafCategories = leafCategoriesSnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
      _selectedLeafCategory = null;
    });
  }

  Future<void> _loadFeaturedProducts() async {
    if (_selectedCategory == null) {
      // _loadFeaturedProducts() called but no category selected
      return;
    }

    String path = 'featured_products/$_selectedCategory';
    if (_selectedSubcategory != null) {
      path += '_$_selectedSubcategory';
    }
    if (_selectedLeafCategory != null) {
      path += '_$_selectedLeafCategory';
    }

    try {
      // Starting _loadFeaturedProducts()

      final doc = await _firestore.doc(path).get();

      // Successfully read featured products document

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        // Featured products data loaded
        _selectedProductIds = List<String>.from(data['productIds'] ?? []);
        _featuredProducts = _allProducts
            .where((product) => _selectedProductIds.contains(product['id']))
            .toList();
        // Loaded featured products
      } else {
        // No featured products document found, starting with empty list
        _selectedProductIds = [];
        _featuredProducts = [];
      }
      setState(() {});
    } catch (e) {
      // Error in _loadFeaturedProducts()
      if (e.toString().contains('permission-denied')) {
        // Featured products document access DENIED
        // Check Firestore rules for featured_products collection
      }
    }
  }

  Future<void> _saveFeaturedProducts() async {
    if (_selectedCategory == null) return;

    String path = 'featured_products/$_selectedCategory';
    if (_selectedSubcategory != null) {
      path += '_$_selectedSubcategory';
    }
    if (_selectedLeafCategory != null) {
      path += '_$_selectedLeafCategory';
    }

    try {
      await _firestore.doc(path).set({
        'productIds': _selectedProductIds,
        'categoryId': _selectedCategory,
        'subcategoryId': _selectedSubcategory,
        'leafCategoryId': _selectedLeafCategory,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'super_admin',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Featured products updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      await ErrorHandlerService.instance.handleError(
        operation: 'save_featured_products',
        error: e,
        context: context,
        showUserMessage: true,
        logError: true,
        fallbackValue: null,
      );
      if (mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving featured products: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return _buildContent();
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'Error Loading Data',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadInitialData,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Featured Products Management',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select products from any store to feature in specific categories for monetization',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 32),

          // Category Selection
          _buildCategorySelection(),
          const SizedBox(height: 24),

          // Action Buttons and Products Lists
          if (_selectedCategory != null) ...[
            _buildActionButtons(),
            const SizedBox(height: 24),
            SizedBox(
              height: 600,
              child: Row(
                children: [
                  Expanded(
                    child: _buildAllProductsList(),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildFeaturedProductsList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategorySelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Category',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: _categories.map((category) {
                      return DropdownMenuItem<String>(
                        value: category['id'],
                        child: Text(category['name'] ?? category['id']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value;
                        _selectedSubcategory = null;
                        _selectedLeafCategory = null;
                        _subcategories = [];
                        _leafCategories = [];
                      });
                      if (value != null) {
                        _loadSubcategories(value);
                        _loadFeaturedProducts();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedSubcategory,
                    decoration: const InputDecoration(
                      labelText: 'Subcategory (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: _subcategories.map((subcategory) {
                      return DropdownMenuItem<String>(
                        value: subcategory['id'],
                        child: Text(subcategory['name'] ?? subcategory['id']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedSubcategory = value;
                        _selectedLeafCategory = null;
                        _leafCategories = [];
                      });
                      if (value != null && _selectedCategory != null) {
                        _loadLeafCategories(_selectedCategory!, value);
                      }
                      _loadFeaturedProducts();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedLeafCategory,
                    decoration: const InputDecoration(
                      labelText: 'Leaf Category (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: _leafCategories.map((leafCategory) {
                      return DropdownMenuItem<String>(
                        value: leafCategory['id'],
                        child: Text(leafCategory['name'] ?? leafCategory['id']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedLeafCategory = value;
                      });
                      _loadFeaturedProducts();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _saveFeaturedProducts,
          icon: const Icon(Icons.save),
          label: const Text('Save Featured Products'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(width: 16),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _selectedProductIds.clear();
              _featuredProducts.clear();
            });
          },
          icon: const Icon(Icons.clear),
          label: const Text('Clear All'),
        ),
        const Spacer(),
        Text(
          '${_allProducts.length} total products available',
          style: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAllProductsList() {
    return Card(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.inventory_2, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'All Products',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_allProducts.length} products',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _allProducts.length,
              itemBuilder: (context, index) {
                final product = _allProducts[index];
                final isSelected = _selectedProductIds.contains(product['id']);

                return ListTile(
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: (product['images'] as List?)?.isNotEmpty == true
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              product['images'][0],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.image_not_supported);
                              },
                            ),
                          )
                        : const Icon(Icons.inventory_2),
                  ),
                  title: Text(
                    product['name'] ?? 'Unnamed Product',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    'Store: ${product['storeId']} • ₮${product['price']?.toStringAsFixed(2) ?? '0.00'}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      isSelected ? Icons.remove_circle : Icons.add_circle,
                      color: isSelected ? Colors.red : Colors.green,
                    ),
                    onPressed: () {
                      setState(() {
                        if (isSelected) {
                          _selectedProductIds.remove(product['id']);
                          _featuredProducts
                              .removeWhere((p) => p['id'] == product['id']);
                        } else {
                          _selectedProductIds.add(product['id']);
                          _featuredProducts.add(product);
                        }
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedProductsList() {
    return Card(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.star, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Featured Products',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_featuredProducts.length} featured',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _featuredProducts.isEmpty
                ? const Center(
                    child: Text(
                      'No featured products selected',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _featuredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _featuredProducts[index];

                      return ListTile(
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: (product['images'] as List?)?.isNotEmpty ==
                                  true
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    product['images'][0],
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                          Icons.image_not_supported);
                                    },
                                  ),
                                )
                              : const Icon(Icons.inventory_2),
                        ),
                        title: Text(
                          product['name'] ?? 'Unnamed Product',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          'Store: ${product['storeId']} • ₮${product['price']?.toStringAsFixed(2) ?? '0.00'}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle,
                              color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _selectedProductIds.remove(product['id']);
                              _featuredProducts.removeAt(index);
                            });
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
