import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shoppy/features/home/presentation/main_scaffold.dart';
import 'package:shoppy/features/products/presentation/product_page.dart';
import 'package:shoppy/features/products/models/product_model.dart';
import 'package:shoppy/features/stores/models/store_model.dart';

class FinalCategoryPage extends StatefulWidget {
  final String title;
  const FinalCategoryPage({super.key, required this.title});

  @override
  State<FinalCategoryPage> createState() => _FinalCategoryPageState();
}

class _FinalCategoryPageState extends State<FinalCategoryPage> {
  String? _placeholderImage;
  static const String _lalarStoreId = 'TLLb3tqzvU2TZSsNPol9';
  StoreModel? _lalarStore;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadPlaceholder();
    await _loadStore();
  }

  Future<void> _loadPlaceholder() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc('ComingSoon')
          .get();
      final data = doc.data();
      if (data != null) {
        final images = List<String>.from(data['images'] ?? []);
        if (images.isNotEmpty) {
          setState(() => _placeholderImage = images.first);
        }
      }
    } catch (_) {}
  }

  Future<void> _loadStore() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('stores')
          .doc(_lalarStoreId)
          .get();
      if (doc.exists) {
        setState(() => _lalarStore = StoreModel.fromFirestore(doc));
      }
    } catch (_) {}
  }

  void _openProduct() {
    final product = ProductModel(
      id: 'placeholder',
      storeId: _lalarStoreId,
      name: 'Coming Soon',
      description: 'Stay tuned – great products on the way!',
      price: 0,
      images: _placeholderImage != null ? [_placeholderImage!] : [],
      category: widget.title,
      stock: 0,
      variants: const [],
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductPage(
          product: product,
          storeName: _lalarStore?.name ?? '',
          storeLogoUrl: _lalarStore?.logo ?? '',
          storeRating: 0,
          storeRatingCount: 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      currentIndex: 0,
      showBackButton: true,
      onBack: () => Navigator.of(context).maybePop(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _buildSearchBar(),
              const SizedBox(height: 12),
              Text(widget.title,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildFiltersRow(),
              const SizedBox(height: 12),
              Expanded(child: _buildProductsGrid()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.grey.shade200,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none),
        ),
        onSubmitted: (value) {},
      ),
    );
  }

  Widget _buildFiltersRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          _filterChip('Offers'),
          _filterChip('Following'),
          _filterChip('On sale'),
          _filterChip('Ratings \u25BC'),
          _filterChip('Size'),
        ],
      ),
    );
  }

  Widget _filterChip(String label) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        onSelected: (_) {},
      ),
    );
  }

  Widget _buildProductsGrid() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.6,
      ),
      itemCount: 20,
      itemBuilder: (_, __) => _productCard(),
    );
  }

  Widget _productCard() {
    return GestureDetector(
      onTap: _openProduct,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _placeholderImage != null
                  ? Image.network(_placeholderImage!, fit: BoxFit.cover)
                  : Container(color: Colors.grey.shade300),
            ),
          ),
          const SizedBox(height: 6),
          const Text('Coming Soon',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          const Text(' 0', style: TextStyle(color: Colors.black45)),
        ],
      ),
    );
  }
}
