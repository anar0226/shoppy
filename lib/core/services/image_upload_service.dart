import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImageUploadService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Simple upload without progress tracking (fallback method)
  static Future<String> uploadProductImageSimple({
    required XFile imageFile,
    required String storeId,
    required String productId,
  }) async {
    try {
      debugPrint('Starting simple upload...');

      final Uint8List imageBytes = await imageFile.readAsBytes();
      debugPrint('Image bytes read: ${imageBytes.length}');

      final String fileName = generateFileName(imageFile.name);
      final Reference storageRef =
          _storage.ref().child('stores/$storeId/products/$productId/$fileName');

      debugPrint('Storage ref created: ${storageRef.fullPath}');

      // Simple upload without progress tracking
      debugPrint('Starting putData operation...');
      final TaskSnapshot snapshot =
          await storageRef.putData(imageBytes).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('putData operation timed out after 30 seconds');
        },
      );

      debugPrint('Upload completed, getting download URL...');
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('Simple upload successful: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('Simple upload failed: $e');
      rethrow;
    }
  }

  /// Upload a single image with compression and progress tracking
  static Future<String> uploadProductImage({
    required XFile imageFile,
    required String storeId,
    required String productId,
    Function(double)? onProgress,
  }) async {
    try {
      // Get optimized image bytes
      final Uint8List imageBytes = await _getOptimizedImageBytes(imageFile);

      // Create storage reference
      final String fileName = generateFileName(imageFile.name);
      final Reference storageRef =
          _storage.ref().child('stores/$storeId/products/$productId/$fileName');

      // Set metadata
      final SettableMetadata metadata = SettableMetadata(
        contentType: _getContentType(imageFile.name),
        customMetadata: {
          'uploadedAt': DateTime.now().toIso8601String(),
          'originalName': imageFile.name,
        },
      );

      // Upload with progress tracking
      final UploadTask uploadTask = storageRef.putData(imageBytes, metadata);

      debugPrint('Upload task created, file size: ${imageBytes.length} bytes');

      // Listen to progress if callback provided
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen(
          (TaskSnapshot snapshot) {
            debugPrint(
                'Upload snapshot: state=${snapshot.state}, bytes=${snapshot.bytesTransferred}/${snapshot.totalBytes}');
            if (snapshot.totalBytes > 0) {
              final double progress =
                  snapshot.bytesTransferred / snapshot.totalBytes;
              onProgress(progress);
            } else {
              debugPrint('Warning: totalBytes is 0, upload may be stuck');
            }
          },
          onError: (error) {
            debugPrint('Upload progress stream error: $error');
          },
          onDone: () {
            debugPrint('Upload progress stream completed');
          },
        );
      }

      // Wait for completion with timeout
      TaskSnapshot snapshot;
      try {
        snapshot = await uploadTask.timeout(
          const Duration(minutes: 2),
          onTimeout: () {
            throw Exception('Upload timed out after 2 minutes');
          },
        );
      } catch (e) {
        debugPrint('Upload task failed: $e');
        // Try to cancel the upload task
        try {
          await uploadTask.cancel();
        } catch (cancelError) {
          debugPrint('Failed to cancel upload: $cancelError');
        }
        rethrow;
      }

      // Get download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('Image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('Image upload failed: $e');
      rethrow;
    }
  }

  /// Upload multiple images
  static Future<List<String>> uploadMultipleImages({
    required List<XFile> imageFiles,
    required String storeId,
    required String productId,
    Function(int current, int total)? onProgress,
  }) async {
    final List<String> downloadUrls = [];

    for (int i = 0; i < imageFiles.length; i++) {
      onProgress?.call(i, imageFiles.length);

      final String url = await uploadProductImage(
        imageFile: imageFiles[i],
        storeId: storeId,
        productId: productId,
      );

      downloadUrls.add(url);
    }

    onProgress?.call(imageFiles.length, imageFiles.length);
    return downloadUrls;
  }

  /// Upload a general image file (for seller cards, banners, etc.)
  static Future<String> uploadImageFile(
    XFile imageFile,
    String storagePath, {
    Function(double)? onProgress,
  }) async {
    try {
      // Get optimized image bytes
      final Uint8List imageBytes = await _getOptimizedImageBytes(imageFile);

      // Create storage reference
      final String fileName = generateFileName(imageFile.name);
      final Reference storageRef =
          _storage.ref().child('$storagePath/$fileName');

      // Set metadata
      final SettableMetadata metadata = SettableMetadata(
        contentType: _getContentType(imageFile.name),
        customMetadata: {
          'uploadedAt': DateTime.now().toIso8601String(),
          'originalName': imageFile.name,
        },
      );

      // Upload with progress tracking
      final UploadTask uploadTask = storageRef.putData(imageBytes, metadata);

      debugPrint('Upload task created, file size: ${imageBytes.length} bytes');

      // Listen to progress if callback provided
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen(
          (TaskSnapshot snapshot) {
            debugPrint(
                'Upload snapshot: state=${snapshot.state}, bytes=${snapshot.bytesTransferred}/${snapshot.totalBytes}');
            if (snapshot.totalBytes > 0) {
              final double progress =
                  snapshot.bytesTransferred / snapshot.totalBytes;
              onProgress(progress);
            } else {
              debugPrint('Warning: totalBytes is 0, upload may be stuck');
            }
          },
          onError: (error) {
            debugPrint('Upload progress stream error: $error');
          },
          onDone: () {
            debugPrint('Upload progress stream completed');
          },
        );
      }

      // Wait for completion with timeout
      TaskSnapshot snapshot;
      try {
        snapshot = await uploadTask.timeout(
          const Duration(minutes: 2),
          onTimeout: () {
            throw Exception('Upload timed out after 2 minutes');
          },
        );
      } catch (e) {
        debugPrint('Upload task failed: $e');
        // Try to cancel the upload task
        try {
          await uploadTask.cancel();
        } catch (cancelError) {
          debugPrint('Failed to cancel upload: $cancelError');
        }
        rethrow;
      }

      // Get download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('Image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('Image upload failed: $e');
      rethrow;
    }
  }

  /// Get optimized image bytes with compression
  static Future<Uint8List> _getOptimizedImageBytes(XFile imageFile) async {
    try {
      // Get original file size
      final originalBytes = await imageFile.readAsBytes();
      final originalSize = originalBytes.length;

      debugPrint(
          'Original image size: ${(originalSize / 1024).toStringAsFixed(1)} KB');

      // If image is already small (< 500KB), return as-is
      if (originalSize < 500 * 1024) {
        debugPrint('Image is already small, skipping compression');
        return originalBytes;
      }

      // Compress the image
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        imageFile.path,
        quality: 85, // Good balance between quality and size
        minWidth: 1200, // Max width
        minHeight: 1200, // Max height
        format: CompressFormat.jpeg, // Always use JPEG for smaller sizes
      );

      if (compressedBytes != null) {
        final compressedSize = compressedBytes.length;
        final compressionRatio =
            ((originalSize - compressedSize) / originalSize * 100);

        debugPrint(
            'Compressed image size: ${(compressedSize / 1024).toStringAsFixed(1)} KB');
        debugPrint(
            'Compression ratio: ${compressionRatio.toStringAsFixed(1)}%');

        return compressedBytes;
      } else {
        debugPrint('Compression failed, using original image');
        return originalBytes;
      }
    } catch (e) {
      debugPrint('Image compression error: $e');
      // Fallback to original bytes if compression fails
      return await imageFile.readAsBytes();
    }
  }

  /// Generate a unique filename
  static String generateFileName(String originalName) {
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String extension = _getFileExtension(originalName);
    return 'image_$timestamp.$extension';
  }

  /// Get file extension
  static String _getFileExtension(String fileName) {
    if (fileName.contains('.')) {
      return fileName.split('.').last.toLowerCase();
    }
    return 'jpg'; // Default extension
  }

  /// Get content type for storage
  static String _getContentType(String fileName) {
    final String extension = _getFileExtension(fileName);
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  /// Delete an image from storage
  static Future<void> deleteImage(String imageUrl) async {
    try {
      final Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      debugPrint('Image deleted successfully: $imageUrl');
    } catch (e) {
      debugPrint('Failed to delete image: $e');
      // Don't rethrow - deletion failures shouldn't break the flow
    }
  }
}
