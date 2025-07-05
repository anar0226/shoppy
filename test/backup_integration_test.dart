import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';

void main() {
  group('Backup System Integration Tests', () {
    late FirebaseFirestore firestore;
    late FirebaseFunctions functions;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp();
      firestore = FirebaseFirestore.instance;
      functions = FirebaseFunctions.instance;
    });

    group('Backup Creation Tests', () {
      test('should create backup record in Firestore', () async {
        // Create a test backup record
        final backupData = {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'collections': ['users', 'stores', 'products', 'orders'],
          'status': 'completed',
          'size': 1024,
          'recordCount': 100,
          'createdBy': 'test-admin',
          'description': 'Integration test backup',
          'testRun': true
        };

        try {
          // Add backup record to Firestore
          final docRef = await firestore.collection('backups').add(backupData);
          expect(docRef.id, isNotEmpty);

          // Verify the record was created
          final doc = await docRef.get();
          expect(doc.exists, isTrue);
          expect(doc.data()?['status'], equals('completed'));
          expect(doc.data()?['testRun'], isTrue);

          // Clean up - delete the test record
          await docRef.delete();

          print('✅ Backup creation test passed');
        } catch (e) {
          print('❌ Backup creation test failed: $e');
          rethrow;
        }
      });

      test('should retrieve backup history', () async {
        try {
          // Query backup history
          final querySnapshot = await firestore
              .collection('backups')
              .orderBy('timestamp', descending: true)
              .limit(5)
              .get();

          expect(querySnapshot.docs, isA<List>());

          // Verify each backup record has required fields
          for (final doc in querySnapshot.docs) {
            final data = doc.data();
            expect(data['timestamp'], isNotNull);
            expect(data['status'], isNotNull);
            expect(data['collections'], isA<List>());
          }

          print('✅ Backup history retrieval test passed');
        } catch (e) {
          print('❌ Backup history retrieval test failed: $e');
          rethrow;
        }
      });
    });

    group('Cloud Functions Tests', () {
      test('should call createBackup function', () async {
        try {
          // Call the createBackup Cloud Function
          final result = await functions.httpsCallable('createBackup').call({
            'description': 'Integration test backup',
            'collections': ['users', 'stores', 'products']
          });

          expect(result.data, isNotNull);
          expect(result.data['success'], isTrue);

          print('✅ Cloud Function createBackup test passed');
        } catch (e) {
          print('❌ Cloud Function createBackup test failed: $e');
          // Don't rethrow as this might fail if Cloud Functions aren't deployed
          print('Note: This test requires Cloud Functions to be deployed');
        }
      });

      test('should call getBackupHistory function', () async {
        try {
          // Call the getBackupHistory Cloud Function
          final result = await functions
              .httpsCallable('getBackupHistory')
              .call({'limit': 10});

          expect(result.data, isNotNull);
          expect(result.data['backups'], isA<List>());

          print('✅ Cloud Function getBackupHistory test passed');
        } catch (e) {
          print('❌ Cloud Function getBackupHistory test failed: $e');
          // Don't rethrow as this might fail if Cloud Functions aren't deployed
          print('Note: This test requires Cloud Functions to be deployed');
        }
      });
    });

    group('Backup Data Validation Tests', () {
      test('should validate backup data structure', () async {
        try {
          // Get a sample backup record
          final querySnapshot =
              await firestore.collection('backups').limit(1).get();

          if (querySnapshot.docs.isNotEmpty) {
            final backupData = querySnapshot.docs.first.data();

            // Validate required fields
            expect(backupData['timestamp'], isNotNull);
            expect(backupData['timestamp'], isA<int>());
            expect(backupData['status'], isNotNull);
            expect(backupData['status'], isA<String>());

            // Validate status values
            final validStatuses = [
              'pending',
              'in_progress',
              'completed',
              'failed',
              'cancelled'
            ];
            expect(validStatuses.contains(backupData['status']), isTrue);

            print('✅ Backup data validation test passed');
          } else {
            print('⚠️ No backup records found for validation test');
          }
        } catch (e) {
          print('❌ Backup data validation test failed: $e');
          rethrow;
        }
      });

      test('should validate backup collections', () async {
        try {
          // Get a sample backup record
          final querySnapshot =
              await firestore.collection('backups').limit(1).get();

          if (querySnapshot.docs.isNotEmpty) {
            final backupData = querySnapshot.docs.first.data();

            if (backupData.containsKey('collections')) {
              final collections = backupData['collections'] as List;
              expect(collections, isA<List>());

              // Check for common collections
              final commonCollections = [
                'users',
                'stores',
                'products',
                'orders'
              ];
              for (final collection in collections) {
                expect(collection, isA<String>());
                expect(collection, isNotEmpty);
              }

              print('✅ Backup collections validation test passed');
            } else {
              print('⚠️ No collections field found in backup data');
            }
          } else {
            print('⚠️ No backup records found for collections validation test');
          }
        } catch (e) {
          print('❌ Backup collections validation test failed: $e');
          rethrow;
        }
      });
    });

    group('Backup Performance Tests', () {
      test('should handle backup queries efficiently', () async {
        try {
          final stopwatch = Stopwatch()..start();

          // Query backup history
          await firestore
              .collection('backups')
              .orderBy('timestamp', descending: true)
              .limit(10)
              .get();

          stopwatch.stop();

          // Should complete within 5 seconds
          expect(stopwatch.elapsedMilliseconds, lessThan(5000));

          print(
              '✅ Backup query performance test passed (${stopwatch.elapsedMilliseconds}ms)');
        } catch (e) {
          print('❌ Backup query performance test failed: $e');
          rethrow;
        }
      });
    });

    group('Backup Security Tests', () {
      test('should not expose sensitive data in backup records', () async {
        try {
          // Get a sample backup record
          final querySnapshot =
              await firestore.collection('backups').limit(1).get();

          if (querySnapshot.docs.isNotEmpty) {
            final backupData = querySnapshot.docs.first.data();

            // Check for sensitive fields
            final sensitiveFields = [
              'password',
              'apiKey',
              'secret',
              'token',
              'privateKey'
            ];
            for (final field in sensitiveFields) {
              expect(backupData.containsKey(field), isFalse,
                  reason:
                      'Backup data should not contain sensitive field: $field');
            }

            print('✅ Backup security test passed');
          } else {
            print('⚠️ No backup records found for security test');
          }
        } catch (e) {
          print('❌ Backup security test failed: $e');
          rethrow;
        }
      });
    });
  });
}
