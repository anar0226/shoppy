import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DirectUploadService {
  /// Direct HTTP upload to Firebase Storage (bypasses SDK issues)
  static Future<String> uploadImageDirect({
    required Uint8List imageBytes,
    required String storeId,
    required String productId,
    required String fileName,
  }) async {
    try {
      debugPrint('🚀 Starting direct HTTP upload...');

      // Get auth token
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final token = await user.getIdToken();
      debugPrint('🚀 Got auth token');

      // Build upload URL
      final bucketName = 'shoppy-6d81f.firebasestorage.app';
      final filePath = 'stores/$storeId/products/$productId/$fileName';
      final uploadUrl =
          'https://firebasestorage.googleapis.com/v0/b/$bucketName/o?name=${Uri.encodeComponent(filePath)}';

      debugPrint('🚀 Upload URL: $uploadUrl');
      debugPrint('🚀 File size: ${imageBytes.length} bytes');

      // Determine content type
      String contentType = 'image/jpeg';
      if (fileName.toLowerCase().endsWith('.png')) {
        contentType = 'image/png';
      } else if (fileName.toLowerCase().endsWith('.gif')) {
        contentType = 'image/gif';
      }

      // Create request
      final request = http.Request('POST', Uri.parse(uploadUrl));
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Content-Type': contentType,
        'Content-Length': imageBytes.length.toString(),
      });
      request.bodyBytes = imageBytes;

      debugPrint('🚀 Sending request...');

      // Send request with timeout
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Direct upload timed out after 30 seconds');
        },
      );

      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('🚀 Response status: ${response.statusCode}');
      debugPrint('🚀 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final downloadToken = responseData['downloadTokens'];

        if (downloadToken != null) {
          final downloadUrl =
              'https://firebasestorage.googleapis.com/v0/b/$bucketName/o/${Uri.encodeComponent(filePath)}?alt=media&token=$downloadToken';
          debugPrint('🚀 Direct upload successful: $downloadUrl');
          return downloadUrl;
        } else {
          throw Exception('No download token in response');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('🚀 Direct upload failed: $e');
      rethrow;
    }
  }
}
