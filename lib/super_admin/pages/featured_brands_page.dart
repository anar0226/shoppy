import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/error_handler_service.dart';

class FeaturedBrandsPage extends StatefulWidget {
  const FeaturedBrandsPage({super.key});

  @override
  State<FeaturedBrandsPage> createState() => _FeaturedBrandsPageState();
}

class _FeaturedBrandsPageState extends State<FeaturedBrandsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedCategory;
  String? _selectedSubcategory;
  String? _selectedLeafCategory;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _subcategories = [];
  List<Map<String, dynamic>> _leafCategories = [];
  List<Map<String, dynamic>> _allStores = [];
  List<Map<String, dynamic>> _featuredStores = [];
  List<String> _selectedStoreIds = [];

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkAuthenticationAndLoadData();
  }

  Future<void> _checkAuthenticationAndLoadData() async {
    try {
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

        // Also check if user is in the super_admins collection (alternative approach)
        if (!isSuperAdmin) {
          final superAdminsQuery = await _firestore
              .collection('super_admins')
              .where('userId', isEqualTo: user.uid)
              .limit(1)
              .get();
          if (superAdminsQuery.docs.isNotEmpty) {
            isSuperAdmin = true;
          }
        }

        // For development/testing, allow access if user email contains 'admin' or 'super'
        if (!isSuperAdmin &&
            (user.email?.contains('admin') == true ||
                user.email?.contains('super') == true)) {
          isSuperAdmin = true;
          debugPrint(
              'Development mode: Granting super admin access to ${user.email}');

          // Create super admin document if it doesn't exist
          try {
            await _firestore.collection('super_admins').doc(user.uid).set({
              'userId': user.uid,
              'email': user.email,
              'isActive': true,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            debugPrint('Created super admin document for ${user.email}');
          } catch (e) {
            debugPrint('Error creating super admin document: $e');
          }
        }
      } catch (e) {
        debugPrint('Error checking super admin status: $e');
        // For development, allow access if there's an error checking super admin status
        isSuperAdmin = true;
        debugPrint(
            'Development mode: Granting super admin access due to error in status check');
      }

      if (!isSuperAdmin) {
        setState(() {
          _error =
              'Super admin access required. Please contact the system administrator.';
          _isLoading = false;
        });
        return;
      }

      // Load initial data
      await _loadInitialData();
    } catch (e) {
      setState(() {
        _error = 'Error initializing: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadInitialData() async {
    try {
      await Future.wait([
        _loadCategories(),
        _loadAllStores(),
      ]);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categoriesSnapshot =
          await _firestore.collection('categories').get();

      if (categoriesSnapshot.docs.isEmpty) {
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
      } else {
        _categories = categoriesSnapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList();
      }
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        throw Exception(
            'Permission denied accessing categories. Please check Firestore rules for super admin access.');
      }
      rethrow;
    }
  }

  Future<void> _createSampleCategories() async {
    try {
      // Create all 10 categories from the main app
      final categories = [
        {'id': 'Эмэгтэй', 'name': 'Эмэгтэй'},
        {'id': 'Эрэгтэй', 'name': 'Эрэгтэй'},
        {'id': 'Гоо сайхан', 'name': 'Гоо сайхан'},
        {'id': 'Хоол хүнс, ундаа', 'name': 'Хоол хүнс, ундаа'},
        {'id': 'Гэр аxуй', 'name': 'Гэр аxуй'},
        {'id': 'Фитнесс', 'name': 'Фитнесс'},
        {'id': 'Аксессуары', 'name': 'Аксессуары'},
        {'id': 'Амьтдын бүтээгдэхүүн', 'name': 'Амьтдын бүтээгдэхүүн'},
        {'id': 'Тоглоомнууд', 'name': 'Тоглоомнууд'},
        {'id': 'Цахилгаан бараа', 'name': 'Цахилгаан бараа'},
      ];

      for (final category in categories) {
        await _firestore.collection('categories').doc(category['id']).set({
          'name': category['name'],
          'isActive': true,
          'sortOrder': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        throw Exception(
            'Permission denied creating categories. Please check Firestore write rules for super admin access.');
      }
      rethrow;
    }
  }

  Future<void> _loadAllStores() async {
    try {
      final storesSnapshot = await _firestore.collection('stores').get();

      _allStores = storesSnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();

      // Filter only active stores
      _allStores = _allStores
          .where((store) =>
              store['status'] == 'active' || store['isActive'] == true)
          .toList();
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        throw Exception(
            'Permission denied accessing stores. Please check Firestore rules for collection("stores") access.');
      }
      rethrow;
    }
  }

  Future<void> _loadSubcategories(String categoryId) async {
    try {
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

      // If no subcategories exist, create some sample ones for testing
      if (_subcategories.isEmpty) {
        await _createSampleSubcategories(categoryId);
        // Reload subcategories after creation
        final newSnapshot = await _firestore
            .collection('categories')
            .doc(categoryId)
            .collection('subcategories')
            .get();

        setState(() {
          _subcategories = newSnapshot.docs
              .map((doc) => {
                    'id': doc.id,
                    ...doc.data(),
                  })
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading subcategories: $e');
      setState(() {
        _subcategories = [];
        _selectedSubcategory = null;
        _selectedLeafCategory = null;
        _leafCategories = [];
      });
    }
  }

  Future<void> _createSampleSubcategories(String categoryId) async {
    try {
      // Create sample subcategories based on the main category
      List<Map<String, String>> subcategories = [];

      switch (categoryId) {
        case 'Эмэгтэй':
          subcategories = [
            {'id': 'Гадуур хувцас', 'name': 'Гадуур хувцас'},
            {'id': 'Гутал', 'name': 'Гутал'},
            {'id': 'Даашинз', 'name': 'Даашинз'},
            {'id': 'Өмд', 'name': 'Өмд'},
            {'id': 'Дотуур хувцас', 'name': 'Дотуур хувцас'},
            {'id': 'Спорт хувцас', 'name': 'Спорт хувцас'},
          ];
          break;
        case 'Эрэгтэй':
          subcategories = [
            {'id': 'Гутал', 'name': 'Гутал'},
            {'id': 'Гадуур хувцас', 'name': 'Гадуур хувцас'},
            {'id': 'Өмд', 'name': 'Өмд'},
            {'id': 'Футболк', 'name': 'Футболк'},
            {'id': 'Спорт хувцас', 'name': 'Спорт хувцас'},
          ];
          break;
        case 'Гоо сайхан':
          subcategories = [
            {'id': 'Нүүр будалт', 'name': 'Нүүр будалт'},
            {'id': 'Үсний бүтээгдэхүүн', 'name': 'Үсний бүтээгдэхүүн'},
            {'id': 'Арьс арчилгаа', 'name': 'Арьс арчилгаа'},
            {'id': 'Хумсны бүтээгдэхүүн', 'name': 'Хумсны бүтээгдэхүүн'},
            {'id': 'Сайхан үнэр', 'name': 'Сайхан үнэр'},
          ];
          break;
        case 'Аксессуары':
          subcategories = [
            {'id': 'Цүнх', 'name': 'Цүнх'},
            {'id': 'Ээмэг', 'name': 'Ээмэг'},
            {'id': 'Малгай', 'name': 'Малгай'},
            {'id': 'Нүдний шил', 'name': 'Нүдний шил'},
            {'id': 'Бүс', 'name': 'Бүс'},
          ];
          break;
        default:
          subcategories = [
            {'id': 'Ерөнхий', 'name': 'Ерөнхий'},
            {'id': 'Онцлох', 'name': 'Онцлох'},
          ];
      }

      for (final subcategory in subcategories) {
        await _firestore
            .collection('categories')
            .doc(categoryId)
            .collection('subcategories')
            .doc(subcategory['id'])
            .set({
          'name': subcategory['name'],
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error creating sample subcategories: $e');
    }
  }

  Future<void> _loadLeafCategories(
      String categoryId, String subcategoryId) async {
    try {
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

      // If no leaf categories exist, create some sample ones for testing
      if (_leafCategories.isEmpty) {
        await _createSampleLeafCategories(categoryId, subcategoryId);
        // Reload leaf categories after creation
        final newSnapshot = await _firestore
            .collection('categories')
            .doc(categoryId)
            .collection('subcategories')
            .doc(subcategoryId)
            .collection('leafCategories')
            .get();

        setState(() {
          _leafCategories = newSnapshot.docs
              .map((doc) => {
                    'id': doc.id,
                    ...doc.data(),
                  })
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading leaf categories: $e');
      setState(() {
        _leafCategories = [];
        _selectedLeafCategory = null;
      });
    }
  }

  Future<void> _createSampleLeafCategories(
      String categoryId, String subcategoryId) async {
    try {
      // Create sample leaf categories based on the subcategory
      List<Map<String, String>> leafCategories = [];

      if (categoryId == 'Эмэгтэй' && subcategoryId == 'Гадуур хувцас') {
        leafCategories = [
          {'id': 'Футболк', 'name': 'Футболк'},
          {'id': 'Малгайтай цамц', 'name': 'Малгайтай цамц'},
          {'id': 'Хувцас', 'name': 'Хувцас'},
        ];
      } else if (categoryId == 'Эмэгтэй' && subcategoryId == 'Гутал') {
        leafCategories = [
          {'id': 'Өндөр өсгийт', 'name': 'Өндөр өсгийт'},
          {'id': 'Шаахай', 'name': 'Шаахай'},
          {'id': 'Пүүз', 'name': 'Пүүз'},
          {'id': 'Спорт гутал', 'name': 'Спорт гутал'},
        ];
      } else if (categoryId == 'Эрэгтэй' && subcategoryId == 'Гутал') {
        leafCategories = [
          {'id': 'Пүүз', 'name': 'Пүүз'},
          {'id': 'Шаахай', 'name': 'Шаахай'},
          {'id': 'Гутал', 'name': 'Гутал'},
          {'id': 'Спорт гутал', 'name': 'Спорт гутал'},
        ];
      } else {
        leafCategories = [
          {'id': 'Ерөнхий', 'name': 'Ерөнхий'},
          {'id': 'Онцлох', 'name': 'Онцлох'},
        ];
      }

      for (final leafCategory in leafCategories) {
        await _firestore
            .collection('categories')
            .doc(categoryId)
            .collection('subcategories')
            .doc(subcategoryId)
            .collection('leafCategories')
            .doc(leafCategory['id'])
            .set({
          'name': leafCategory['name'],
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error creating sample leaf categories: $e');
    }
  }

  Future<void> _loadFeaturedBrands() async {
    if (_selectedCategory == null) {
      return;
    }

    String path = 'featured_brands/$_selectedCategory';
    if (_selectedSubcategory != null) {
      path += '_$_selectedSubcategory';
    }
    if (_selectedLeafCategory != null) {
      path += '_$_selectedLeafCategory';
    }

    try {
      final doc = await _firestore.doc(path).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _selectedStoreIds = List<String>.from(data['storeIds'] ?? []);
        _featuredStores = _allStores
            .where((store) => _selectedStoreIds.contains(store['id']))
            .toList();
      } else {
        _selectedStoreIds = [];
        _featuredStores = [];
      }
      setState(() {});
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        debugPrint('Featured brands document access DENIED');
      }
    }
  }

  Future<void> _saveFeaturedBrands() async {
    if (_selectedCategory == null) return;

    String path = 'featured_brands/$_selectedCategory';
    if (_selectedSubcategory != null) {
      path += '_$_selectedSubcategory';
    }
    if (_selectedLeafCategory != null) {
      path += '_$_selectedLeafCategory';
    }

    try {
      await _firestore.doc(path).set({
        'storeIds': _selectedStoreIds,
        'categoryId': _selectedCategory,
        'subcategoryId': _selectedSubcategory,
        'leafCategoryId': _selectedLeafCategory,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'super_admin',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Featured brands updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      await ErrorHandlerService.instance.handleError(
        operation: 'save_featured_brands',
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
            content: Text('Error saving featured brands: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleStoreSelection(String storeId) {
    setState(() {
      if (_selectedStoreIds.contains(storeId)) {
        _selectedStoreIds.remove(storeId);
      } else {
        if (_selectedStoreIds.length < 4) {
          _selectedStoreIds.add(storeId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You can only feature up to 4 brands per category'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      }

      // Update featured stores list
      _featuredStores = _allStores
          .where((store) => _selectedStoreIds.contains(store['id']))
          .toList();
    });
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _loadInitialData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
              const SizedBox(width: 16),
              if (_error!.contains('Super admin access required'))
                ElevatedButton.icon(
                  onPressed: _createSuperAdminDocument,
                  icon: const Icon(Icons.admin_panel_settings),
                  label: const Text('Create Super Admin'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _createSuperAdminDocument() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _firestore.collection('super_admins').doc(user.uid).set({
        'userId': user.uid,
        'email': user.email,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Super admin document created successfully! Please refresh.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating super admin document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Featured Brands Management',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select brands/stores to feature in specific categories for monetization',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 32),

          // Category Selection
          _buildCategorySelection(),
          const SizedBox(height: 24),

          // Action Buttons and Brands Lists
          if (_selectedCategory != null) ...[
            _buildActionButtons(),
            const SizedBox(height: 24),
            SizedBox(
              height: 600,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Available Brands
                  Expanded(
                    child: _buildAvailableBrands(),
                  ),
                  const SizedBox(width: 24),
                  // Featured Brands
                  Expanded(
                    child: _buildFeaturedBrands(),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
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
                      _loadFeaturedBrands();
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
                    _loadFeaturedBrands();
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
                    _loadFeaturedBrands();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _saveFeaturedBrands,
          icon: const Icon(Icons.save),
          label: const Text('Save Featured Brands'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          'Selected: ${_selectedStoreIds.length}/4 brands',
          style: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAvailableBrands() {
    final availableStores = _allStores
        .where((store) => !_selectedStoreIds.contains(store['id']))
        .toList();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.store, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Available Brands (${availableStores.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: availableStores.length,
              itemBuilder: (context, index) {
                final store = availableStores[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage:
                        store['logo'] != null && store['logo'].isNotEmpty
                            ? NetworkImage(store['logo'])
                            : null,
                    child: store['logo'] == null || store['logo'].isEmpty
                        ? Text(store['name'][0].toUpperCase())
                        : null,
                  ),
                  title: Text(store['name'] ?? 'Unknown Store'),
                  subtitle: Text(store['description'] ?? 'No description'),
                  trailing: IconButton(
                    icon: const Icon(Icons.add_circle_outline,
                        color: Colors.green),
                    onPressed: () => _toggleStoreSelection(store['id']),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedBrands() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.star, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Featured Brands (${_featuredStores.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _featuredStores.isEmpty
                ? const Center(
                    child: Text(
                      'No brands selected yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _featuredStores.length,
                    itemBuilder: (context, index) {
                      final store = _featuredStores[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                              store['logo'] != null && store['logo'].isNotEmpty
                                  ? NetworkImage(store['logo'])
                                  : null,
                          child: store['logo'] == null || store['logo'].isEmpty
                              ? Text(store['name'][0].toUpperCase())
                              : null,
                        ),
                        title: Text(store['name'] ?? 'Unknown Store'),
                        subtitle:
                            Text(store['description'] ?? 'No description'),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              color: Colors.red),
                          onPressed: () => _toggleStoreSelection(store['id']),
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
