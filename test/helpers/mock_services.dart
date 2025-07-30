import 'dart:typed_data';
import 'dart:io';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_storage/firebase_storage.dart';

/// Simple mock service provider for testing
class MockServiceProvider {
  static final MockServiceProvider _instance = MockServiceProvider._internal();
  factory MockServiceProvider() => _instance;
  MockServiceProvider._internal();

  /// Initialize mock services
  void initialize() {
    // This will be implemented when we generate mocks
  }

  /// Reset all mocks
  void reset() {
    // This will be implemented when we generate mocks
  }

  /// Setup common mock behaviors
  void setupCommonMocks() {
    // This will be implemented when we generate mocks
  }
}

/// Mock collection reference
class MockCollectionReference extends Mock {
  DocumentReference<Object?> doc([String? path]) {
    return MockDocumentReference() as DocumentReference<Object?>;
  }

  Query<Object?> where(Object field,
      {Object? isEqualTo,
      Object? isNotEqualTo,
      Object? isLessThan,
      Object? isLessThanOrEqualTo,
      Object? isGreaterThan,
      Object? isGreaterThanOrEqualTo,
      Object? arrayContains,
      Iterable<Object?>? arrayContainsAny,
      Iterable<Object?>? whereIn,
      Iterable<Object?>? whereNotIn,
      bool? isNull}) {
    return MockQuery() as Query<Object?>;
  }

  Query<Object?> orderBy(Object field, {bool descending = false}) {
    return MockQuery() as Query<Object?>;
  }

  Query<Object?> limit(int limit) {
    return MockQuery() as Query<Object?>;
  }
}

/// Mock document reference
class MockDocumentReference extends Mock {
  final String id = 'mock_doc_id';

  CollectionReference<Object?> get parent =>
      MockCollectionReference() as CollectionReference<Object?>;

  Future<DocumentSnapshot<Object?>> get([GetOptions? options]) async {
    return MockDocumentSnapshot() as DocumentSnapshot<Object?>;
  }

  Future<void> set(Object? data, [SetOptions? options]) async {
    // Mock implementation
  }

  Future<void> update(Map<Object, Object?> data) async {
    // Mock implementation
  }

  Future<void> delete() async {
    // Mock implementation
  }
}

/// Mock query
class MockQuery extends Mock {
  Query<Object?> where(Object field,
      {Object? isEqualTo,
      Object? isNotEqualTo,
      Object? isLessThan,
      Object? isLessThanOrEqualTo,
      Object? isGreaterThan,
      Object? isGreaterThanOrEqualTo,
      Object? arrayContains,
      Iterable<Object?>? arrayContainsAny,
      Iterable<Object?>? whereIn,
      Iterable<Object?>? whereNotIn,
      bool? isNull}) {
    return this as Query<Object?>;
  }

  Query<Object?> orderBy(Object field, {bool descending = false}) {
    return this as Query<Object?>;
  }

  Query<Object?> limit(int limit) {
    return this as Query<Object?>;
  }

  Query<Object?> startAfterDocument(DocumentSnapshot<Object?> document) {
    return this as Query<Object?>;
  }

  Future<QuerySnapshot<Object?>> get([GetOptions? options]) async {
    return MockQuerySnapshot() as QuerySnapshot<Object?>;
  }
}

/// Mock document snapshot
class MockDocumentSnapshot extends Mock {
  final String id = 'mock_doc_id';

  final bool exists = true;

  Object? data() => <String, dynamic>{};
}

/// Mock query snapshot
class MockQuerySnapshot extends Mock {
  final List<QueryDocumentSnapshot<Object?>> docs = [];

  final int size = 0;
}

/// Mock write batch
class MockWriteBatch extends Mock {
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    // Mock implementation
  }

  void update(DocumentReference<Object?> document, Map<Object, Object?> data) {
    // Mock implementation
  }

  void delete(DocumentReference<Object?> document) {
    // Mock implementation
  }

  Future<void> commit() async {
    // Mock implementation
  }
}

/// Mock reference
class MockReference extends Mock {
  UploadTask putData(Uint8List data, [SettableMetadata? metadata]) {
    return MockUploadTask() as UploadTask;
  }

  UploadTask putFile(File file, [SettableMetadata? metadata]) {
    return MockUploadTask() as UploadTask;
  }

  Future<String> getDownloadURL() async {
    return 'https://example.com/mock-url';
  }

  Future<void> delete() async {
    // Mock implementation
  }
}

/// Mock upload task
class MockUploadTask extends Mock {
  Future<TaskSnapshot> get result async {
    return MockTaskSnapshot() as TaskSnapshot;
  }
}

/// Mock task snapshot
class MockTaskSnapshot extends Mock {
  Reference get ref => MockReference() as Reference;
}

/// Mock user
class MockUser extends Mock implements auth.User {
  @override
  String get uid => 'mock_user_id';

  @override
  String? get email => 'mock@example.com';

  @override
  String? get displayName => 'Mock User';

  @override
  String? get photoURL => 'https://example.com/mock-photo.jpg';

  @override
  bool get emailVerified => true;
}

/// Mock user credential
class MockUserCredential extends Mock implements auth.UserCredential {
  @override
  auth.User? get user => MockUser();
}

/// Mock Firebase Auth
class MockFirebaseAuth extends Mock implements auth.FirebaseAuth {
  @override
  auth.User? get currentUser => null;

  @override
  Stream<auth.User?> authStateChanges() => Stream.value(null);
}

/// Mock Firebase Firestore
class MockFirebaseFirestore extends Mock {
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return MockCollectionReference()
        as CollectionReference<Map<String, dynamic>>;
  }

  WriteBatch batch() {
    return MockWriteBatch() as WriteBatch;
  }
}

/// Mock Firebase Storage
class MockFirebaseStorage extends Mock {
  Reference ref([String? path]) {
    return MockReference() as Reference;
  }

  Reference refFromURL(String url) {
    return MockReference() as Reference;
  }
}
