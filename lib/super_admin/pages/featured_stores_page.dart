import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FeaturedStoresPage extends StatefulWidget {
  const FeaturedStoresPage({super.key});

  @override
  State<FeaturedStoresPage> createState() => _FeaturedStoresPageState();
}

class _FeaturedStoresPageState extends State<FeaturedStoresPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<String> _featuredStoreIds = [];
  List<StoreInfo> _allStores = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load current featured stores
      final featuredDoc = await _firestore
          .collection('platform_settings')
          .doc('featured_stores')
          .get();

      if (featuredDoc.exists) {
        _featuredStoreIds =
            List<String>.from(featuredDoc.data()?['storeIds'] ?? []);
      }

      // Load all stores
      final storesSnapshot = await _firestore.collection('stores').get();
      _allStores = storesSnapshot.docs.map((doc) {
        final data = doc.data();
        return StoreInfo(
          id: doc.id,
          name: data['name'] ?? '',
          logo: data['logo'] ?? '',
          banner: data['banner'] ?? '',
          isActive: data['isActive'] ?? true,
        );
      }).toList();

      // Sort stores - featured first, then alphabetically
      _allStores.sort((a, b) {
        final aFeatured = _featuredStoreIds.contains(a.id);
        final bFeatured = _featuredStoreIds.contains(b.id);
        if (aFeatured && !bFeatured) return -1;
        if (!aFeatured && bFeatured) return 1;
        return a.name.compareTo(b.name);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateFeaturedStores() async {
    try {
      await _firestore
          .collection('platform_settings')
          .doc('featured_stores')
          .set({
        'storeIds': _featuredStoreIds,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Featured stores updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating featured stores: $e')),
        );
      }
    }
  }

  void _toggleFeaturedStore(String storeId) {
    setState(() {
      if (_featuredStoreIds.contains(storeId)) {
        _featuredStoreIds.remove(storeId);
      } else {
        if (_featuredStoreIds.length < 2) {
          _featuredStoreIds.add(storeId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You can only feature up to 2 stores'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      }
    });

    // Resort the list
    _allStores.sort((a, b) {
      final aFeatured = _featuredStoreIds.contains(a.id);
      final bFeatured = _featuredStoreIds.contains(b.id);
      if (aFeatured && !bFeatured) return -1;
      if (!aFeatured && bFeatured) return 1;
      return a.name.compareTo(b.name);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Featured Stores Management'),
        backgroundColor: const Color(0xFF6A5AE0),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _updateFeaturedStores,
            child: const Text(
              'SAVE',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Info header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue.shade50,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Featured Stores Settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Select up to 2 stores to be featured on the home screen. Featured stores: ${_featuredStoreIds.length}/2',
                        style: TextStyle(color: Colors.blue.shade700),
                      ),
                    ],
                  ),
                ),

                // Store list
                Expanded(
                  child: ListView.builder(
                    itemCount: _allStores.length,
                    itemBuilder: (context, index) {
                      final store = _allStores[index];
                      final isFeatured = _featuredStoreIds.contains(store.id);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: store.logo.isNotEmpty
                                ? NetworkImage(store.logo)
                                : null,
                            child: store.logo.isEmpty
                                ? const Icon(Icons.store)
                                : null,
                          ),
                          title: Text(
                            store.name,
                            style: TextStyle(
                              fontWeight: isFeatured
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ID: ${store.id}'),
                              if (isFeatured)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'FEATURED',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: Switch(
                            value: isFeatured,
                            onChanged: store.isActive
                                ? (_) => _toggleFeaturedStore(store.id)
                                : null,
                            activeColor: Colors.green,
                          ),
                          enabled: store.isActive,
                          tileColor: isFeatured ? Colors.green.shade50 : null,
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

class StoreInfo {
  final String id;
  final String name;
  final String logo;
  final String banner;
  final bool isActive;

  StoreInfo({
    required this.id,
    required this.name,
    required this.logo,
    required this.banner,
    required this.isActive,
  });
}
