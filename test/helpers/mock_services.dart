import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:avii/core/services/auth_service.dart';
import 'package:avii/core/services/database_service.dart';
import 'package:avii/core/services/storage_service.dart';
import 'package:avii/features/orders/services/order_service.dart';
import 'package:avii/features/products/services/product_service.dart';
import 'package:avii/features/notifications/notification_service.dart';

// Generate mocks
@GenerateMocks([
  auth.FirebaseAuth,
  auth.User,
  auth.UserCredential,
  FirebaseFirestore,
  CollectionReference,
  DocumentReference,
  DocumentSnapshot,
  QuerySnapshot,
  QueryDocumentSnapshot,
  FirebaseStorage,
  Reference,
  UploadTask,
  TaskSnapshot,
  AuthService,
  DatabaseService,
  StorageService,
  OrderService,
  ProductService,
  NotificationService,
])
void main() {}

/// Mock service provider for testing
class MockServiceProvider {
  static final MockServiceProvider _instance = MockServiceProvider._internal();
  factory MockServiceProvider() => _instance;
  MockServiceProvider._internal();

  late MockFirebaseAuth _mockAuth;
  late MockFirebaseFirestore _mockFirestore;
  late MockFirebaseStorage _mockStorage;
  late MockAuthService _mockAuthService;
  late MockDatabaseService _mockDatabaseService;
  late MockStorageService _mockStorageService;
  late MockOrderService _mockOrderService;
  late MockProductService _mockProductService;
  late MockNotificationService _mockNotificationService;

  /// Initialize all mock services
  void initialize() {
    _mockAuth = MockFirebaseAuth();
    _mockFirestore = MockFirebaseFirestore();
    _mockStorage = MockFirebaseStorage();
    _mockAuthService = MockAuthService();
    _mockDatabaseService = MockDatabaseService();
    _mockStorageService = MockStorageService();
    _mockOrderService = MockOrderService();
    _mockProductService = MockProductService();
    _mockNotificationService = MockNotificationService();
  }

  /// Get mock Firebase Auth
  MockFirebaseAuth get auth => _mockAuth;

  /// Get mock Firestore
  MockFirebaseFirestore get firestore => _mockFirestore;

  /// Get mock Firebase Storage
  MockFirebaseStorage get storage => _mockStorage;

  /// Get mock Auth Service
  MockAuthService get authService => _mockAuthService;

  /// Get mock Database Service
  MockDatabaseService get databaseService => _mockDatabaseService;

  /// Get mock Storage Service
  MockStorageService get storageService => _mockStorageService;

  /// Get mock Order Service
  MockOrderService get orderService => _mockOrderService;

  /// Get mock Product Service
  MockProductService get productService => _mockProductService;

  /// Get mock Notification Service
  MockNotificationService get notificationService => _mockNotificationService;

  /// Reset all mocks
  void reset() {
    reset(_mockAuth);
    reset(_mockFirestore);
    reset(_mockStorage);
    reset(_mockAuthService);
    reset(_mockDatabaseService);
    reset(_mockStorageService);
    reset(_mockOrderService);
    reset(_mockProductService);
    reset(_mockNotificationService);
  }

  /// Setup common mock behaviors
  void setupCommonMocks() {
    // Setup auth mocks
    when(_mockAuth.currentUser).thenReturn(null);
    when(_mockAuth.authStateChanges()).thenAnswer((_) => Stream.value(null));

    // Setup firestore mocks
    when(_mockFirestore.collection(any)).thenReturn(MockCollectionReference());
    when(_mockFirestore.batch()).thenReturn(MockWriteBatch());

    // Setup storage mocks
    when(_mockStorage.ref()).thenReturn(MockReference());
    when(_mockStorage.refFromURL(any)).thenReturn(MockReference());
  }
}

/// Mock collection reference
class MockCollectionReference extends Mock implements CollectionReference {
  @override
  DocumentReference doc([String? path]) {
    return MockDocumentReference();
  }

  @override
  Query where(String field,
      {dynamic isEqualTo,
      dynamic isNotEqualTo,
      dynamic isLessThan,
      dynamic isLessThanOrEqualTo,
      dynamic isGreaterThan,
      dynamic isGreaterThanOrEqualTo,
      dynamic arrayContains,
      List<dynamic>? arrayContainsAny,
      List<dynamic>? whereIn,
      List<dynamic>? whereNotIn,
      bool? isNull}) {
    return MockQuery();
  }

  @override
  Query orderBy(String field, {bool descending = false}) {
    return MockQuery();
  }

  @override
  Query limit(int limit) {
    return MockQuery();
  }
}

/// Mock document reference
class MockDocumentReference extends Mock implements DocumentReference {
  @override
  String get id => 'mock_doc_id';

  @override
  CollectionReference get parent => MockCollectionReference();

  @override
  Future<DocumentSnapshot> get([GetOptions? options]) async {
    return MockDocumentSnapshot();
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    // Mock implementation
  }

  @override
  Future<void> update(Map<String, dynamic> data) async {
    // Mock implementation
  }

  @override
  Future<void> delete() async {
    // Mock implementation
  }
}

/// Mock query
class MockQuery extends Mock implements Query {
  @override
  Query where(String field,
      {dynamic isEqualTo,
      dynamic isNotEqualTo,
      dynamic isLessThan,
      dynamic isLessThanOrEqualTo,
      dynamic isGreaterThan,
      dynamic isGreaterThanOrEqualTo,
      dynamic arrayContains,
      List<dynamic>? arrayContainsAny,
      List<dynamic>? whereIn,
      List<dynamic>? whereNotIn,
      bool? isNull}) {
    return this;
  }

  @override
  Query orderBy(String field, {bool descending = false}) {
    return this;
  }

  @override
  Query limit(int limit) {
    return this;
  }

  @override
  Query startAfterDocument(DocumentSnapshot document) {
    return this;
  }

  @override
  Future<QuerySnapshot> get([GetOptions? options]) async {
    return MockQuerySnapshot();
  }
}

/// Mock document snapshot
class MockDocumentSnapshot extends Mock implements DocumentSnapshot {
  @override
  String get id => 'mock_doc_id';

  @override
  bool get exists => true;

  @override
  Map<String, dynamic> data() => <String, dynamic>{};
}

/// Mock query snapshot
class MockQuerySnapshot extends Mock implements QuerySnapshot {
  @override
  List<QueryDocumentSnapshot> get docs => [];

  @override
  int get size => 0;
}

/// Mock write batch
class MockWriteBatch extends Mock implements WriteBatch {
  @override
  void set(DocumentReference document, Map<String, dynamic> data,
      [SetOptions? options]) {
    // Mock implementation
  }

  @override
  void update(DocumentReference document, Map<String, dynamic> data) {
    // Mock implementation
  }

  @override
  void delete(DocumentReference document) {
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
