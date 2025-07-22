import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/collection_model.dart';

class CollectionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();
  final String _collection = 'collections';

  // Create a new collection
  Future<String> createCollection(CollectionModel collection) async {
    DocumentReference docRef =
        await _firestore.collection(_collection).add(collection.toMap());
    return docRef.id;
  }

  // Get a collection by ID
  Future<CollectionModel?> getCollection(String collectionId) async {
    DocumentSnapshot doc =
        await _firestore.collection(_collection).doc(collectionId).get();
    if (doc.exists) {
      return CollectionModel.fromFirestore(doc);
    }
    return null;
  }

  // Get all collections for a store
  Stream<List<CollectionModel>> getStoreCollections(String storeId) {
    return _firestore
        .collection(_collection)
        .where('storeId', isEqualTo: storeId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CollectionModel.fromFirestore(doc))
            .toList());
  }

  // Update a collection
  Future<void> updateCollection(
      String collectionId, CollectionModel collection) async {
    await _firestore
        .collection(_collection)
        .doc(collectionId)
        .update(collection.toMap());
  }

  // Delete a collection (soft delete)
  Future<void> deleteCollection(String collectionId) async {
    await _firestore.collection(_collection).doc(collectionId).update({
      'isActive': false,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // Hard delete a collection
  Future<void> hardDeleteCollection(String collectionId) async {
    await _firestore.collection(_collection).doc(collectionId).delete();
  }

  // Get collection count for a store
  Future<int> getCollectionCount(String storeId) async {
    QuerySnapshot snapshot = await _firestore
        .collection(_collection)
        .where('storeId', isEqualTo: storeId)
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs.length;
  }

  // Search collections by name
  Stream<List<CollectionModel>> searchCollections(
      String storeId, String query) {
    return _firestore
        .collection(_collection)
        .where('storeId', isEqualTo: storeId)
        .where('isActive', isEqualTo: true)
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: '$query\uf8ff')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CollectionModel.fromFirestore(doc))
            .toList());
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
      // Error picking image
      return null;
    }
  }

  /// Upload an image to Firebase Storage
  Future<String?> uploadImage(XFile imageFile, String folder) async {
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

      return downloadUrl;
    } catch (e) {
      // Error uploading image
      return null;
    }
  }

  /// Delete an image from Firebase Storage
  Future<void> deleteImageFromUrl(String imageUrl) async {
    try {
      if (imageUrl.isNotEmpty) {
        final Reference ref = _storage.refFromURL(imageUrl);
        await ref.delete();
      }
    } catch (e) {
      // Error deleting image
      // Don't throw error as the main operation might still succeed
    }
  }

  /// Create a new collection with image upload
  Future<String?> createCollectionWithImage({
    required String name,
    required String storeId,
    required List<String> productIds,
    XFile? backgroundImage,
  }) async {
    try {
      // Upload background image if provided
      String backgroundImageUrl = '';
      if (backgroundImage != null) {
        final uploadedUrl = await uploadImage(
          backgroundImage,
          'collections/backgrounds',
        );
        if (uploadedUrl != null) {
          backgroundImageUrl = uploadedUrl;
        }
      }

      // Create collection document
      final collection = CollectionModel(
        id: '', // Will be set by Firestore
        name: name,
        storeId: storeId,
        backgroundImage: backgroundImageUrl,
        productIds: productIds,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final docRef =
          await _firestore.collection(_collection).add(collection.toMap());
      return docRef.id;
    } catch (e) {
      // Error creating collection
      return null;
    }
  }

  /// Update a collection with image management
  Future<bool> updateCollectionWithImage({
    required String collectionId,
    String? name,
    List<String>? productIds,
    XFile? newBackgroundImage,
    bool removeBackgroundImage = false,
  }) async {
    try {
      // Get current collection data
      final doc =
          await _firestore.collection(_collection).doc(collectionId).get();
      if (!doc.exists) {
        return false;
      }

      final currentCollection = CollectionModel.fromFirestore(doc);
      Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Update basic fields
      if (name != null) updates['name'] = name;
      if (productIds != null) updates['productIds'] = productIds;

      // Handle background image updates
      if (removeBackgroundImage) {
        // Remove existing background image
        if (currentCollection.backgroundImage.isNotEmpty) {
          await deleteImageFromUrl(currentCollection.backgroundImage);
        }
        updates['backgroundImage'] = '';
      } else if (newBackgroundImage != null) {
        // Upload new background image
        if (currentCollection.backgroundImage.isNotEmpty) {
          await deleteImageFromUrl(currentCollection.backgroundImage);
        }
        final newUrl = await uploadImage(
          newBackgroundImage,
          'collections/backgrounds',
        );
        if (newUrl != null) {
          updates['backgroundImage'] = newUrl;
        }
      }

      // Update the document
      await _firestore
          .collection(_collection)
          .doc(collectionId)
          .update(updates);
      return true;
    } catch (e) {
      // Error updating collection
      return false;
    }
  }

  /// Enhanced delete with image cleanup
  Future<bool> deleteCollectionWithImages(String collectionId) async {
    try {
      // Get collection data first to delete associated images
      final doc =
          await _firestore.collection(_collection).doc(collectionId).get();
      if (!doc.exists) {
        return false;
      }

      final collection = CollectionModel.fromFirestore(doc);

      // Delete associated background image
      if (collection.backgroundImage.isNotEmpty) {
        await deleteImageFromUrl(collection.backgroundImage);
      }

      // Delete the document (soft delete)
      await _firestore.collection(_collection).doc(collectionId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      // Error deleting collection
      return false;
    }
  }
}
