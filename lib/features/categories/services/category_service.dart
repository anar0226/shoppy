import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/category_model.dart';

class CategoryService {
  static final CategoryService _instance = CategoryService._internal();
  factory CategoryService() => _instance;
  CategoryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

  /// Get all categories for a specific store
  Future<List<CategoryModel>> getStoreCategories(String storeId) async {
    try {
      // Simplified query to avoid requiring composite index
      final querySnapshot = await _firestore
          .collection('categories')
          .where('storeId', isEqualTo: storeId)
          .where('isActive', isEqualTo: true)
          .get();

      // Sort on client side to avoid complex index requirement
      final categories = querySnapshot.docs
          .map((doc) => CategoryModel.fromFirestore(doc))
          .toList();

      // Sort by sortOrder first, then by name
      categories.sort((a, b) {
        final sortOrderComparison = a.sortOrder.compareTo(b.sortOrder);
        if (sortOrderComparison != 0) {
          return sortOrderComparison;
        }
        return a.name.compareTo(b.name);
      });

      return categories;
    } catch (e) {
      debugPrint('Error getting store categories: $e');
      // Fallback: try with just storeId filter
      try {
        final fallbackQuery = await _firestore
            .collection('categories')
            .where('storeId', isEqualTo: storeId)
            .get();

        final categories = fallbackQuery.docs
            .map((doc) => CategoryModel.fromFirestore(doc))
            .where((category) => category.isActive) // Client-side filter
            .toList();

        categories.sort((a, b) {
          final sortOrderComparison = a.sortOrder.compareTo(b.sortOrder);
          if (sortOrderComparison != 0) {
            return sortOrderComparison;
          }
          return a.name.compareTo(b.name);
        });

        return categories;
      } catch (fallbackError) {
        debugPrint('Fallback query also failed: $fallbackError');
        return [];
      }
    }
  }

  /// Get all global/platform categories
  Future<List<CategoryModel>> getGlobalCategories() async {
    try {
      // Simplified query to avoid requiring composite index
      final querySnapshot = await _firestore
          .collection('categories')
          .where('storeId', isNull: true)
          .where('isActive', isEqualTo: true)
          .get();

      // Sort on client side to avoid complex index requirement
      final categories = querySnapshot.docs
          .map((doc) => CategoryModel.fromFirestore(doc))
          .toList();

      // Sort by sortOrder first, then by name
      categories.sort((a, b) {
        final sortOrderComparison = a.sortOrder.compareTo(b.sortOrder);
        if (sortOrderComparison != 0) {
          return sortOrderComparison;
        }
        return a.name.compareTo(b.name);
      });

      return categories;
    } catch (e) {
      debugPrint('Error getting global categories: $e');
      // Fallback: get all categories and filter client-side
      try {
        final fallbackQuery = await _firestore.collection('categories').get();

        final categories = fallbackQuery.docs
            .map((doc) => CategoryModel.fromFirestore(doc))
            .where((category) => category.storeId == null && category.isActive)
            .toList();

        categories.sort((a, b) {
          final sortOrderComparison = a.sortOrder.compareTo(b.sortOrder);
          if (sortOrderComparison != 0) {
            return sortOrderComparison;
          }
          return a.name.compareTo(b.name);
        });

        return categories;
      } catch (fallbackError) {
        debugPrint('Fallback query also failed: $fallbackError');
        return [];
      }
    }
  }

  /// Create a new category
  Future<String?> createCategory({
    required String name,
    String? description,
    String? storeId,
    XFile? backgroundImage,
    XFile? iconImage,
    int sortOrder = 0,
  }) async {
    try {
      // Upload images if provided
      String? backgroundImageUrl;
      String? iconUrl;

      if (backgroundImage != null) {
        backgroundImageUrl = await _uploadImage(
          backgroundImage,
          'categories/backgrounds',
        );
      }

      if (iconImage != null) {
        iconUrl = await _uploadImage(
          iconImage,
          'categories/icons',
        );
      }

      // Create category document
      final category = CategoryModel(
        id: '', // Will be set by Firestore
        name: name,
        description: description,
        backgroundImageUrl: backgroundImageUrl,
        iconUrl: iconUrl,
        sortOrder: sortOrder,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        storeId: storeId,
      );

      final docRef =
          await _firestore.collection('categories').add(category.toFirestore());

      debugPrint('Category created successfully: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating category: $e');
      return null;
    }
  }

  /// Update an existing category
  Future<bool> updateCategory({
    required String categoryId,
    String? name,
    String? description,
    XFile? newBackgroundImage,
    XFile? newIconImage,
    bool? removeBackgroundImage,
    bool? removeIcon,
    int? sortOrder,
    bool? isActive,
  }) async {
    try {
      // Get current category data
      final doc =
          await _firestore.collection('categories').doc(categoryId).get();
      if (!doc.exists) {
        debugPrint('Category not found: $categoryId');
        return false;
      }

      final currentCategory = CategoryModel.fromFirestore(doc);
      Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Update text fields
      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (sortOrder != null) updates['sortOrder'] = sortOrder;
      if (isActive != null) updates['isActive'] = isActive;

      // Handle background image updates
      if (removeBackgroundImage == true) {
        // Remove existing background image
        if (currentCategory.backgroundImageUrl != null) {
          await _deleteImageFromUrl(currentCategory.backgroundImageUrl!);
        }
        updates['backgroundImageUrl'] = FieldValue.delete();
      } else if (newBackgroundImage != null) {
        // Upload new background image
        if (currentCategory.backgroundImageUrl != null) {
          await _deleteImageFromUrl(currentCategory.backgroundImageUrl!);
        }
        final newUrl = await _uploadImage(
          newBackgroundImage,
          'categories/backgrounds',
        );
        if (newUrl != null) {
          updates['backgroundImageUrl'] = newUrl;
        }
      }

      // Handle icon updates
      if (removeIcon == true) {
        // Remove existing icon
        if (currentCategory.iconUrl != null) {
          await _deleteImageFromUrl(currentCategory.iconUrl!);
        }
        updates['iconUrl'] = FieldValue.delete();
      } else if (newIconImage != null) {
        // Upload new icon
        if (currentCategory.iconUrl != null) {
          await _deleteImageFromUrl(currentCategory.iconUrl!);
        }
        final newUrl = await _uploadImage(
          newIconImage,
          'categories/icons',
        );
        if (newUrl != null) {
          updates['iconUrl'] = newUrl;
        }
      }

      // Update the document
      await _firestore.collection('categories').doc(categoryId).update(updates);

      debugPrint('Category updated successfully: $categoryId');
      return true;
    } catch (e) {
      debugPrint('Error updating category: $e');
      return false;
    }
  }

  /// Delete a category
  Future<bool> deleteCategory(String categoryId) async {
    try {
      // Get category data first to delete associated images
      final doc =
          await _firestore.collection('categories').doc(categoryId).get();
      if (!doc.exists) {
        debugPrint('Category not found: $categoryId');
        return false;
      }

      final category = CategoryModel.fromFirestore(doc);

      // Delete associated images
      if (category.backgroundImageUrl != null) {
        await _deleteImageFromUrl(category.backgroundImageUrl!);
      }
      if (category.iconUrl != null) {
        await _deleteImageFromUrl(category.iconUrl!);
      }

      // Delete the document
      await _firestore.collection('categories').doc(categoryId).delete();

      debugPrint('Category deleted successfully: $categoryId');
      return true;
    } catch (e) {
      debugPrint('Error deleting category: $e');
      return false;
    }
  }

  /// Pick an image from gallery or camera
  Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      return image;
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  /// Upload an image to Firebase Storage
  Future<String?> _uploadImage(XFile imageFile, String folder) async {
    try {
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${imageFile.name}';
      final Reference ref = _storage.ref().child('$folder/$fileName');

      UploadTask uploadTask;
      if (kIsWeb) {
        // For web platform
        final bytes = await imageFile.readAsBytes();
        uploadTask = ref.putData(bytes);
      } else {
        // For mobile platforms
        final File file = File(imageFile.path);
        uploadTask = ref.putFile(file);
      }

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('Image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  /// Delete an image from Firebase Storage
  Future<void> _deleteImageFromUrl(String imageUrl) async {
    try {
      final Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      debugPrint('Image deleted successfully: $imageUrl');
    } catch (e) {
      debugPrint('Error deleting image: $e');
      // Don't throw error as the main operation might still succeed
    }
  }

  /// Get category by ID
  Future<CategoryModel?> getCategoryById(String categoryId) async {
    try {
      final doc =
          await _firestore.collection('categories').doc(categoryId).get();
      if (doc.exists) {
        return CategoryModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting category by ID: $e');
      return null;
    }
  }

  /// Search categories by name
  Future<List<CategoryModel>> searchCategories({
    required String query,
    String? storeId,
  }) async {
    try {
      Query baseQuery = _firestore.collection('categories');

      // Simplified query to avoid index issues - filter on client side
      if (storeId != null) {
        baseQuery = baseQuery.where('storeId', isEqualTo: storeId);
      }

      final querySnapshot = await baseQuery.get();

      // Filter and sort on client side to avoid complex index requirement
      final categories = querySnapshot.docs
          .map((doc) => CategoryModel.fromFirestore(doc))
          .where((category) =>
              category.isActive &&
              category.name.toLowerCase().contains(query.toLowerCase()))
          .toList();

      // Sort by name
      categories.sort((a, b) => a.name.compareTo(b.name));

      return categories;
    } catch (e) {
      debugPrint('Error searching categories: $e');
      // Fallback: get all categories and filter completely client-side
      try {
        final fallbackQuery = await _firestore.collection('categories').get();

        final categories = fallbackQuery.docs
            .map((doc) => CategoryModel.fromFirestore(doc))
            .where((category) =>
                category.isActive &&
                (storeId == null || category.storeId == storeId) &&
                category.name.toLowerCase().contains(query.toLowerCase()))
            .toList();

        categories.sort((a, b) => a.name.compareTo(b.name));

        return categories;
      } catch (fallbackError) {
        debugPrint('Fallback search also failed: $fallbackError');
        return [];
      }
    }
  }

  /// Reorder categories
  Future<bool> reorderCategories(List<String> categoryIds) async {
    try {
      final batch = _firestore.batch();

      for (int i = 0; i < categoryIds.length; i++) {
        final docRef = _firestore.collection('categories').doc(categoryIds[i]);
        batch.update(docRef, {
          'sortOrder': i,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      debugPrint('Categories reordered successfully');
      return true;
    } catch (e) {
      debugPrint('Error reordering categories: $e');
      return false;
    }
  }
}
