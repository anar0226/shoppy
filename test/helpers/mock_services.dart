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
class MockCollectionReference extends Mock implements CollectionReference {
  @override
  DocumentReference<Object?> doc([String? path]) {
    return MockDocumentReference();
  }

  @override
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
    return MockQuery();
  }

  @override
  Query<Object?> orderBy(Object field, {bool descending = false}) {
    return MockQuery();
  }

  @override
  Query<Object?> limit(int limit) {
    return MockQuery();
  }
}

/// Mock document reference
class MockDocumentReference extends Mock implements DocumentReference<Object?> {
  @override
  String get id => 'mock_doc_id';

  @override
  CollectionReference<Object?> get parent => MockCollectionReference();

  @override
  Future<DocumentSnapshot<Object?>> get([GetOptions? options]) async {
    return MockDocumentSnapshot();
  }

  @override
  Future<void> set(Object? data, [SetOptions? options]) async {
    // Mock implementation
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    // Mock implementation
  }

  @override
  Future<void> delete() async {
    // Mock implementation
  }
}

/// Mock query
class MockQuery extends Mock implements Query<Object?> {
  @override
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
    return this;
  }

  @override
  Query<Object?> orderBy(Object field, {bool descending = false}) {
    return this;
  }

  @override
  Query<Object?> limit(int limit) {
    return this;
  }

  @override
  Query<Object?> startAfterDocument(DocumentSnapshot<Object?> document) {
    return this;
  }

  @override
  Future<QuerySnapshot<Object?>> get([GetOptions? options]) async {
    return MockQuerySnapshot();
  }
}

/// Mock document snapshot
class MockDocumentSnapshot extends Mock implements DocumentSnapshot<Object?> {
  @override
  String get id => 'mock_doc_id';

  @override
  bool get exists => true;

  @override
  Object? data() => <String, dynamic>{};
}

/// Mock query snapshot
class MockQuerySnapshot extends Mock implements QuerySnapshot<Object?> {
  @override
  List<QueryDocumentSnapshot<Object?>> get docs => [];

  @override
  int get size => 0;
}

/// Mock write batch
class MockWriteBatch extends Mock implements WriteBatch {
  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    // Mock implementation
  }

  @override
  void update(DocumentReference<Object?> document, Map<Object, Object?> data) {
    // Mock implementation
  }

  @override
  void delete(DocumentReference<Object?> document) {
    // Mock implementation
  }

  @override
  Future<void> commit() async {
    // Mock implementation
  }
}

/// Mock reference
class MockReference extends Mock implements Reference {
  @override
  UploadTask putData(Uint8List data, [SettableMetadata? metadata]) {
    return MockUploadTask();
  }

  @override
  UploadTask putFile(File file, [SettableMetadata? metadata]) {
    return MockUploadTask();
  }

  @override
  Future<String> getDownloadURL() async {
    return 'https://example.com/mock-url';
  }

  @override
  Future<void> delete() async {
    // Mock implementation
  }
}

/// Mock upload task
class MockUploadTask extends Mock implements UploadTask {
  @override
  Future<TaskSnapshot> get result async {
    return MockTaskSnapshot();
  }
}

/// Mock task snapshot
class MockTaskSnapshot extends Mock implements TaskSnapshot {
  @override
  Reference get ref => MockReference();
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
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return MockCollectionReference()
        as CollectionReference<Map<String, dynamic>>;
  }

  @override
  WriteBatch batch() {
    return MockWriteBatch();
  }
}

/// Mock Firebase Storage
class MockFirebaseStorage extends Mock implements FirebaseStorage {
  @override
  Reference ref([String? path]) {
    return MockReference();
  }

  @override
  Reference refFromURL(String url) {
    return MockReference();
  }
}
