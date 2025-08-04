import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Simple store model
class StoreInfo {
  final String id;
  final String name;
  final String logo;

  StoreInfo({required this.id, required this.name, required this.logo});
}

/// Unified Featured management page replicating the provided mock-ups.
class FeaturedManagementPage extends StatefulWidget {
  const FeaturedManagementPage({super.key});

  @override
  State<FeaturedManagementPage> createState() => _FeaturedManagementPageState();
}

class _FeaturedManagementPageState extends State<FeaturedManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // === STORES ===
  final TextEditingController _searchCtrl = TextEditingController();
  List<StoreInfo> _allStores = [];
  List<String> _featuredMain = []; // max 2 store ids

  // === CATEGORY TREE ===
  List<DocumentSnapshot<Map<String, dynamic>>> _categories = [];
  final Map<String, List<DocumentSnapshot<Map<String, dynamic>>>>
      _subcategories = {};
  final Map<String, List<DocumentSnapshot<Map<String, dynamic>>>>
      _leafCategories = {};

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() => _loading = true);

    // Load stores
    final storesSnap = await _firestore.collection('stores').get();
    _allStores = storesSnap.docs.map((d) {
      final data = d.data();
      return StoreInfo(
        id: d.id,
        name: data['name'] ?? 'Unnamed',
        logo: data['logo'] ?? '',
      );
    }).toList();

    // Load main featured doc
    final featuredDoc = await _firestore
        .collection('platform_settings')
        .doc('featured_stores')
        .get();
    if (featuredDoc.exists) {
      _featuredMain =
          List<String>.from(featuredDoc.data()!['storeIds'] ?? <String>[]);
    }

    // Categories
    final catSnap = await _firestore.collection('categories').get();
    _categories = catSnap.docs;

    // Only load subcategories for Women, Men, and Beauty
    final categoriesWithSubs = ['women', 'men', 'beauty'];

    for (final c in _categories) {
      final categoryId = c.id.toLowerCase();

      if (categoriesWithSubs.contains(categoryId)) {
        final subSnap = await c.reference.collection('subcategories').get();
        _subcategories[c.id] = subSnap.docs;

        // Load leaf categories only for specific subcategories
        for (final s in subSnap.docs) {
          final subId = s.id.toLowerCase();
          bool hasLeafCategories = false;

          if (categoryId == 'women') {
            // Women subcategories with leaf categories: shoes, intimates
            hasLeafCategories = ['shoes', 'intimates'].contains(subId);
          } else if (categoryId == 'men') {
            // Men subcategories with leaf categories: shoes, outerwear
            hasLeafCategories = ['shoes', 'outerwear'].contains(subId);
          }
          // Beauty has no leaf categories

          if (hasLeafCategories) {
            final leafSnap =
                await s.reference.collection('leafCategories').get();
            _leafCategories['${c.id}_${s.id}'] = leafSnap.docs;
          }
        }
      } else {
        // Categories without subcategories: electronics, foods_and_drinks, home, fitness, accessories, animal_products, games
        _subcategories[c.id] = [];
      }
    }

    setState(() => _loading = false);
  }

  // === HELPERS ===
  List<StoreInfo> get _filteredStores {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _allStores;
    return _allStores
        .where((s) => s.name.toLowerCase().contains(q) || s.id.contains(q))
        .toList();
  }

  StoreInfo? _storeById(String id) => _allStores.firstWhere((s) => s.id == id,
      orElse: () => StoreInfo(id: id, name: id, logo: ''));

  // === UI ===
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Set pure white background
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF4285F4),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.store,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Store Management',
              style: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT – AVAILABLE STORES
                Container(
                  width: 320,
                  height: double.infinity,
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(20),
                        child: const Text(
                          'Available Stores',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      // Search field
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.search,
                                color: Colors.grey[400], size: 20),
                            hintText: 'Filter stores...',
                            hintStyle: TextStyle(
                                color: Colors.grey[400], fontSize: 14),
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: Color(0xFF4285F4)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Store list
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: ListView.separated(
                            itemCount: _filteredStores.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, idx) {
                              final store = _filteredStores[idx];
                              return Draggable<String>(
                                data: store.id,
                                feedback: Material(
                                  elevation: 4,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 280,
                                    child: _StoreTile(
                                        store: store, draggable: true),
                                  ),
                                ),
                                childWhenDragging: Opacity(
                                  opacity: 0.3,
                                  child: _StoreTile(store: store),
                                ),
                                child: _StoreTile(store: store),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Divider
                Container(
                  width: 1,
                  height: double.infinity,
                  color: Colors.grey[200],
                ),

                // RIGHT – MANAGEMENT AREA
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMainFeaturedSection(),
                          const SizedBox(height: 32),
                          _buildCategoryManagementSection(),
                        ],
                      ),
                    ),
                  ),
                )
              ],
            ),
    );
  }

  // ==== MAIN PAGE FEATURED ====
  Widget _buildMainFeaturedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Main Page Featured Stores',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_featuredMain.length} of 2',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Maximum 2 stores can be featured on the main page',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: List.generate(2, (index) {
            final hasStore = index < _featuredMain.length;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: index == 0 ? 16 : 0),
                child: DragTarget<String>(
                  onWillAcceptWithDetails: (details) =>
                      !_featuredMain.contains(details.data),
                  onAcceptWithDetails: (details) {
                    final storeId = details.data;
                    setState(() {
                      if (hasStore) {
                        // Replace existing store
                        _featuredMain[index] = storeId;
                      } else if (_featuredMain.length < 2) {
                        // Add new store
                        if (index == 0 || _featuredMain.isNotEmpty) {
                          _featuredMain.insert(index, storeId);
                        } else {
                          _featuredMain.add(storeId);
                        }
                      }
                    });
                    _saveMainFeatured();
                  },
                  builder: (context, candidateData, rejectedData) {
                    final isHoveringValid = candidateData.isNotEmpty &&
                        !_featuredMain.contains(candidateData.first);

                    return Container(
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: hasStore
                              ? const Color(0xFF10B981)
                              : isHoveringValid
                                  ? const Color(0xFF4285F4)
                                  : Colors.grey[300]!,
                          width: hasStore || isHoveringValid ? 2 : 1,
                          style:
                              hasStore ? BorderStyle.solid : BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: hasStore
                            ? const Color(0xFF10B981).withValues(alpha: 0.05)
                            : isHoveringValid
                                ? const Color(0xFF4285F4)
                                    .withValues(alpha: 0.05)
                                : Colors.grey[50],
                      ),
                      child: hasStore
                          ? _buildFeaturedStoreContent(index)
                          : _buildEmptyFeaturedSlot(isHoveringValid),
                    );
                  },
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildFeaturedStoreContent(int index) {
    final store = _storeById(_featuredMain[index]);
    if (store == null) return const SizedBox();

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[100],
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.transparent,
                  backgroundImage:
                      store.logo.isNotEmpty ? NetworkImage(store.logo) : null,
                  child: store.logo.isEmpty
                      ? Icon(Icons.store, color: Colors.grey[600], size: 24)
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                store.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'ID: ${store.id}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Positioned(
          right: 8,
          top: 8,
          child: GestureDetector(
            onTap: () {
              setState(() => _featuredMain.removeAt(index));
              _saveMainFeatured();
            },
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyFeaturedSlot(bool isHovering) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isHovering
                  ? const Color(0xFF4285F4).withValues(alpha: 0.1)
                  : Colors.grey[100],
              border: Border.all(
                color: isHovering ? const Color(0xFF4285F4) : Colors.grey[300]!,
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            child: Icon(
              Icons.add,
              color: isHovering ? const Color(0xFF4285F4) : Colors.grey[400],
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isHovering
                ? 'Drop store here or click to assign'
                : 'Drop store here or click to assign',
            style: TextStyle(
              fontSize: 12,
              color: isHovering ? const Color(0xFF4285F4) : Colors.grey[600],
              fontWeight: isHovering ? FontWeight.w500 : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Future<void> _saveMainFeatured() async {
    await _firestore.collection('platform_settings').doc('featured_stores').set(
        {'storeIds': _featuredMain, 'updatedAt': FieldValue.serverTimestamp()});
  }

  // ===== CATEGORY MANAGEMENT =====
  Widget _buildCategoryManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category Management',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Manage featured stores for each category level',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 24),
        ..._buildExpandedCategoryList(),
      ],
    );
  }

  List<Widget> _buildExpandedCategoryList() {
    List<Widget> widgets = [];

    for (final catDoc in _categories) {
      final categoryName = catDoc.data()?['name'] ?? catDoc.id;
      final subDocs = _subcategories[catDoc.id] ?? [];
      final hasSubcategories = subDocs.isNotEmpty;

      // Category Header
      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Icon(hasSubcategories ? Icons.expand_more : Icons.store,
                  color: Colors.grey[600], size: 20),
              const SizedBox(width: 8),
              Text(
                categoryName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Category',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (!hasSubcategories) ...[
                const Spacer(),
                Text(
                  'No subcategories - Direct featured stores',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      );

      if (hasSubcategories) {
        // Categories with subcategories (Women, Men, Beauty)
        for (final subDoc in subDocs) {
          final subName = subDoc.data()?['name'] ?? subDoc.id;
          final leafDocs = _leafCategories['${catDoc.id}_${subDoc.id}'] ?? [];
          final hasLeafCategories = leafDocs.isNotEmpty;

          widgets.add(
            Container(
              margin: const EdgeInsets.only(left: 24, bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.subdirectory_arrow_right,
                      color: Colors.grey[500], size: 16),
                  const SizedBox(width: 8),
                  Text(
                    subName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Sub-category',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    hasLeafCategories
                        ? '${leafDocs.length} leaf categories'
                        : 'Direct featured stores',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: hasLeafCategories
                          ? FontStyle.normal
                          : FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          );

          // Featured store slots for subcategory (only if no leaf categories)
          if (!hasLeafCategories) {
            widgets.add(
              Container(
                margin: const EdgeInsets.only(left: 48, bottom: 16),
                child: _SubCategoryFeaturedSlots(
                  categoryId: catDoc.id,
                  subId: subDoc.id,
                  leafDoc: null, // null indicates this is for subcategory level
                  allStores: _allStores,
                ),
              ),
            );
          }

          // Leaf categories (only for Women's shoes & intimates, Men's shoes & outerwear)
          for (final leafDoc in leafDocs) {
            final leafName = leafDoc.data()?['name'] ?? leafDoc.id;

            widgets.add(
              Container(
                margin: const EdgeInsets.only(left: 48, bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.circle, color: Colors.grey[400], size: 8),
                    const SizedBox(width: 12),
                    Text(
                      leafName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Leaf',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );

            // Featured store slots for leaf category
            widgets.add(
              Container(
                margin: const EdgeInsets.only(left: 72, bottom: 20),
                child: _SubCategoryFeaturedSlots(
                  categoryId: catDoc.id,
                  subId: subDoc.id,
                  leafDoc: leafDoc,
                  allStores: _allStores,
                ),
              ),
            );
          }
        }
      } else {
        // Categories without subcategories (Electronics, Foods & Drinks, Home, Fitness, Accessories, Animal Products, Games)
        widgets.add(
          Container(
            margin: const EdgeInsets.only(left: 24, bottom: 16),
            child: _SubCategoryFeaturedSlots(
              categoryId: catDoc.id,
              subId:
                  'main', // Use 'main' as identifier for direct category featured stores
              leafDoc: null,
              allStores: _allStores,
            ),
          ),
        );
      }

      // Add separator between categories
      if (catDoc != _categories.last) {
        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 20),
            height: 1,
            color: Colors.grey[200],
          ),
        );
      }
    }

    return widgets;
  }
}

// ===== STORE TILE WIDGET =====
class _StoreTile extends StatelessWidget {
  final StoreInfo store;
  final bool draggable;
  const _StoreTile({required this.store, this.draggable = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        boxShadow: draggable
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[100],
              border: Border.all(color: Colors.grey[300]!, width: 1),
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.transparent,
              backgroundImage:
                  store.logo.isNotEmpty ? NetworkImage(store.logo) : null,
              child: store.logo.isEmpty
                  ? Icon(Icons.store, color: Colors.grey[600], size: 20)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  store.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  'ID: ${store.id}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===== SUB CATEGORY FEATURED SLOTS =====
class _SubCategoryFeaturedSlots extends StatefulWidget {
  final String categoryId;
  final String subId;
  final DocumentSnapshot<Map<String, dynamic>>?
      leafDoc; // null for subcategory level
  final List<StoreInfo> allStores;

  const _SubCategoryFeaturedSlots({
    required this.categoryId,
    required this.subId,
    required this.leafDoc,
    required this.allStores,
  });

  @override
  State<_SubCategoryFeaturedSlots> createState() =>
      _SubCategoryFeaturedSlotsState();
}

class _SubCategoryFeaturedSlotsState extends State<_SubCategoryFeaturedSlots> {
  List<String> _featured = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _docId {
    if (widget.leafDoc != null) {
      return '${widget.categoryId}_${widget.subId}_${widget.leafDoc!.id}';
    } else {
      return '${widget.categoryId}_${widget.subId}';
    }
  }

  Future<void> _load() async {
    final doc =
        await _firestore.collection('featured_by_category').doc(_docId).get();
    if (doc.exists) {
      _featured = List<String>.from(doc.data()!['storeIds'] ?? []);
      setState(() {});
    }
  }

  Future<void> _save() async {
    await _firestore.collection('featured_by_category').doc(_docId).set(
        {'storeIds': _featured, 'updatedAt': FieldValue.serverTimestamp()});
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: List.generate(4, (index) {
        final hasStore = index < _featured.length;
        return DragTarget<String>(
          onWillAcceptWithDetails: (details) =>
              !_featured.contains(details.data),
          onAcceptWithDetails: (details) {
            final storeId = details.data;
            setState(() {
              if (hasStore) {
                // Replace existing store
                _featured[index] = storeId;
              } else if (_featured.length < 4) {
                // Add new store
                _featured.add(storeId);
              }
            });
            _save();
          },
          builder: (context, candidateData, rejectedData) {
            final isHoveringValid = candidateData.isNotEmpty &&
                !_featured.contains(candidateData.first);

            return Container(
              width: 150,
              height: 100,
              decoration: BoxDecoration(
                border: Border.all(
                  color: hasStore
                      ? const Color(0xFF4285F4)
                      : isHoveringValid
                          ? const Color(0xFF4285F4)
                          : Colors.grey[300]!,
                  width: hasStore || isHoveringValid ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
                color: hasStore
                    ? const Color(0xFF4285F4).withValues(alpha: 0.05)
                    : isHoveringValid
                        ? const Color(0xFF4285F4).withValues(alpha: 0.05)
                        : Colors.grey[50],
              ),
              child: hasStore
                  ? _buildFeaturedCategoryStoreContent(index)
                  : _buildEmptyCategorySlot(isHoveringValid),
            );
          },
        );
      }),
    );
  }

  Widget _buildFeaturedCategoryStoreContent(int index) {
    final store = widget.allStores.firstWhere(
      (s) => s.id == _featured[index],
      orElse: () => StoreInfo(id: '', name: 'Unknown', logo: ''),
    );

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[100],
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                ),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.transparent,
                  backgroundImage:
                      store.logo.isNotEmpty ? NetworkImage(store.logo) : null,
                  child: store.logo.isEmpty
                      ? Icon(Icons.store, color: Colors.grey[600], size: 18)
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                store.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'ID: ${store.id}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Positioned(
          right: 6,
          top: 6,
          child: GestureDetector(
            onTap: () {
              setState(() => _featured.removeAt(index));
              _save();
            },
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCategorySlot(bool isHovering) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isHovering
                  ? const Color(0xFF4285F4).withValues(alpha: 0.1)
                  : Colors.grey[100],
              border: Border.all(
                color: isHovering ? const Color(0xFF4285F4) : Colors.grey[300]!,
                width: 1,
                style: BorderStyle.solid,
              ),
            ),
            child: Icon(
              Icons.add,
              color: isHovering ? const Color(0xFF4285F4) : Colors.grey[400],
              size: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isHovering ? 'Drop here' : '+',
            style: TextStyle(
              fontSize: 10,
              color: isHovering ? const Color(0xFF4285F4) : Colors.grey[600],
              fontWeight: isHovering ? FontWeight.w500 : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
