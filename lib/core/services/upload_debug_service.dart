import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UploadDebugService {
  /// Test Firebase connectivity and permissions
  static Future<Map<String, dynamic>> runDiagnostics() async {
    final results = <String, dynamic>{};

    try {
      // 1. Check authentication
      final user = FirebaseAuth.instance.currentUser;
      results['auth'] = {
        'isSignedIn': user != null,
        'uid': user?.uid,
        'email': user?.email,
        'emailVerified': user?.emailVerified,
      };

      if (user == null) {
        results['error'] = 'User not authenticated';
        return results;
      }

      // 2. Test Firestore read/write
      try {
        final testDoc =
            FirebaseFirestore.instance.collection('test').doc('diagnostic');
        await testDoc
            .set({'timestamp': FieldValue.serverTimestamp(), 'uid': user.uid});
        await testDoc.delete();
        results['firestore'] = 'OK - Read/Write successful';
      } catch (e) {
        results['firestore'] = 'ERROR: $e';
      }

      // 3. Test Storage upload
      try {
        debugPrint('🧪 Testing tiny file upload...');
        final testData = Uint8List.fromList([1, 2, 3, 4, 5]); // 5 bytes test
        final ref = FirebaseStorage.instance
            .ref()
            .child('test/${user.uid}/diagnostic.bin');

        debugPrint('🧪 Created test reference: ${ref.fullPath}');
        debugPrint('🧪 Starting putData...');

        final snapshot = await ref.putData(testData).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw Exception('Test upload timed out');
          },
        );

        debugPrint('🧪 Upload completed, getting URL...');
        final url = await snapshot.ref.getDownloadURL();
        debugPrint('🧪 Got URL: $url');

        debugPrint('🧪 Cleaning up...');
        await ref.delete(); // Cleanup

        results['storage'] = 'OK - Upload/Download successful';
        results['testUrl'] = url;
      } catch (e) {
        debugPrint('🧪 Storage test failed: $e');
        results['storage'] = 'ERROR: $e';
      }

      // 4. Test stores collection access
      try {
        final storeQuery = await FirebaseFirestore.instance
            .collection('stores')
            .where('ownerId', isEqualTo: user.uid)
            .limit(1)
            .get();
        results['stores'] = {
          'count': storeQuery.docs.length,
          'hasActiveStore':
              storeQuery.docs.any((doc) => doc.data()['status'] == 'active'),
        };
      } catch (e) {
        results['stores'] = 'ERROR: $e';
      }

      // 5. Network connectivity test
      try {
        final networkTest = await FirebaseStorage.instance
            .ref()
            .child('nonexistent')
            .getDownloadURL();
        results['network'] = 'Unexpected success';
      } catch (e) {
        if (e.toString().contains('object-not-found')) {
          results['network'] = 'OK - Network connectivity working';
        } else {
          results['network'] = 'ERROR: $e';
        }
      }
    } catch (e) {
      results['generalError'] = e.toString();
    }

    return results;
  }

  /// Print diagnostic results in a readable format
  static void printDiagnostics(Map<String, dynamic> results) {
    debugPrint('=== FIREBASE UPLOAD DIAGNOSTICS ===');

    if (results.containsKey('auth')) {
      final auth = results['auth'] as Map<String, dynamic>;
      debugPrint('🔐 Authentication:');
      debugPrint('   Signed In: ${auth['isSignedIn']}');
      if (auth['isSignedIn']) {
        debugPrint('   UID: ${auth['uid']}');
        debugPrint('   Email: ${auth['email']}');
        debugPrint('   Verified: ${auth['emailVerified']}');
      }
    }

    debugPrint('💾 Firestore: ${results['firestore']}');
    debugPrint('📁 Storage: ${results['storage']}');
    debugPrint('🏪 Stores: ${results['stores']}');
    debugPrint('🌐 Network: ${results['network']}');

    if (results.containsKey('error')) {
      debugPrint('❌ Main Error: ${results['error']}');
    }

    if (results.containsKey('generalError')) {
      debugPrint('❌ General Error: ${results['generalError']}');
    }

    debugPrint('=== END DIAGNOSTICS ===');
  }
}
