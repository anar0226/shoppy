import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'dart:async';

/// Test configuration for the Shoppy application
class TestConfig {
  static const String testUserId = 'test_user_123';
  static const String testStoreId = 'test_store_456';
  static const String testProductId = 'test_product_789';
  static const String testOrderId = 'test_order_123';

  /// Test environment setup
  static void setupTestEnvironment() {
    // Set up test-specific configurations
    TestWidgetsFlutterBinding.ensureInitialized();

    // Disable image loading in tests
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/image_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'ImageProvider.load') {
          return null;
        }
        return null;
      },
    );
  }

  /// Create a fake Firestore instance with test data
  static FakeFirebaseFirestore createFakeFirestore() {
    final fakeFirestore = FakeFirebaseFirestore();

    // Add test data
    _addTestData(fakeFirestore);

    return fakeFirestore;
  }

  /// Create a mock Firebase Auth instance
  static MockFirebaseAuth createMockAuth() {
    final mockAuth = MockFirebaseAuth();

    // Set up default user
    final mockUser = MockUser(
      isAnonymous: false,
      uid: testUserId,
      email: 'test@example.com',
      displayName: 'Test User',
    );

    mockAuth.mockUser = mockUser;

    return mockAuth;
  }

  /// Add test data to Firestore
  static void _addTestData(FakeFirebaseFirestore fakeFirestore) {
    // Add test user
    fakeFirestore.collection('users').doc(testUserId).set({
      'uid': testUserId,
      'email': 'test@example.com',
      'displayName': 'Test User',
      'phoneNumber': '+97699999999',
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
      'isEmailVerified': true,
      'followerStoreIds': <String>[],
      'notInterestedStoreIds': <String>[],
      'recentlyViewedProducts': <String>[],
    });

    // Add test store
    fakeFirestore.collection('stores').doc(testStoreId).set({
      'id': testStoreId,
      'name': 'Test Store',
      'description': 'A test store for testing purposes',
      'ownerId': testUserId,
      'logo': 'https://example.com/logo.jpg',
      'banner': 'https://example.com/banner.jpg',
      'status': 'active',
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
      'ratingAvg': 4.5,
      'reviewCount': 10,
      'followerCount': 25,
      'productCount': 50,
    });

    // Add test product
    fakeFirestore.collection('products').doc(testProductId).set({
      'id': testProductId,
      'name': 'Test Product',
      'description': 'A test product for testing purposes',
      'price': 1000.0,
      'stock': 10,
      'storeId': testStoreId,
      'images': ['https://example.com/product1.jpg'],
      'category': 'Electronics',
      'isActive': true,
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
      'hasVariants': false,
      'totalStock': 10,
      'discount': {
        'isDiscounted': false,
        'discountId': null,
        'discountCode': null,
        'percent': 0,
      },
      'review': {
        'numberOfReviews': 5,
        'stars': 4.2,
      },
    });

    // Add test order
    fakeFirestore.collection('orders').doc(testOrderId).set({
      'id': testOrderId,
      'userId': testUserId,
      'storeId': testStoreId,
      'items': [
        {
          'productId': testProductId,
          'name': 'Test Product',
          'price': 1000.0,
          'quantity': 1,
          'imageUrl': 'https://example.com/product1.jpg',
        }
      ],
      'total': 1000.0,
      'subtotal': 1000.0,
      'shippingCost': 0.0,
      'tax': 0.0,
      'status': 'placed',
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
      'paymentMethod': 'QPay',
      'deliveryAddress': {
        'firstName': 'Test',
        'lastName': 'User',
        'phone': '+97699999999',
        'address': 'Test Address',
        'city': 'Ulaanbaatar',
        'postalCode': '12345',
      },
    });

    // Add user's order
    fakeFirestore
        .collection('users')
        .doc(testUserId)
        .collection('orders')
        .doc(testOrderId)
        .set({
      'id': testOrderId,
      'userId': testUserId,
      'storeId': testStoreId,
      'items': [
        {
          'productId': testProductId,
          'name': 'Test Product',
          'price': 1000.0,
          'quantity': 1,
          'imageUrl': 'https://example.com/product1.jpg',
        }
      ],
      'total': 1000.0,
      'subtotal': 1000.0,
      'shippingCost': 0.0,
      'tax': 0.0,
      'status': 'placed',
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
      'paymentMethod': 'QPay',
      'deliveryAddress': {
        'firstName': 'Test',
        'lastName': 'User',
        'phone': '+97699999999',
        'address': 'Test Address',
        'city': 'Ulaanbaatar',
        'postalCode': '12345',
      },
    });
  }

  /// Clean up test environment
  static void cleanupTestEnvironment() {
    // Clean up any test-specific configurations
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/image_provider'),
      null,
    );
  }

  /// Test timeout configuration
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const Duration shortTimeout = Duration(seconds: 5);
  static const Duration longTimeout = Duration(seconds: 60);

  /// Test data constants
  static const Map<String, dynamic> testUserData = {
    'uid': testUserId,
    'email': 'test@example.com',
    'displayName': 'Test User',
    'phoneNumber': '+97699999999',
  };

  static const Map<String, dynamic> testStoreData = {
    'id': testStoreId,
    'name': 'Test Store',
    'description': 'A test store for testing purposes',
    'ownerId': testUserId,
    'status': 'active',
  };

  static const Map<String, dynamic> testProductData = {
    'id': testProductId,
    'name': 'Test Product',
    'description': 'A test product for testing purposes',
    'price': 1000.0,
    'stock': 10,
    'storeId': testStoreId,
    'isActive': true,
  };

  static const Map<String, dynamic> testOrderData = {
    'id': testOrderId,
    'userId': testUserId,
    'storeId': testStoreId,
    'total': 1000.0,
    'status': 'placed',
  };
}

/// Test utilities for common operations
class TestUtils {
  /// Wait for async operations with timeout
  static Future<void> waitForAsync(
    WidgetTester tester, {
    Duration timeout = TestConfig.defaultTimeout,
  }) async {
    await tester.pumpAndSettle(timeout);
  }

  /// Wait for specific condition
  static Future<void> waitForCondition(
    Future<bool> Function() condition, {
    Duration timeout = TestConfig.defaultTimeout,
    Duration interval = const Duration(milliseconds: 100),
  }) async {
    final endTime = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(endTime)) {
      if (await condition()) {
        return;
      }
      await Future.delayed(interval);
    }

    throw TimeoutException('Condition not met within timeout', timeout);
  }

  /// Create a test key
  static Key createTestKey(String name) {
    return Key('test_${name}_${DateTime.now().millisecondsSinceEpoch}');
  }

  /// Generate unique test ID
  static String generateTestId(String prefix) {
    return '${prefix}_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Create test image bytes
  static List<int> createTestImageBytes() {
    // Create a simple 1x1 pixel PNG image
    return [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
      0x00, 0x00, 0x00, 0x0D, // IHDR chunk length
      0x49, 0x48, 0x44, 0x52, // IHDR
      0x00, 0x00, 0x00, 0x01, // width: 1
      0x00, 0x00, 0x00, 0x01, // height: 1
      0x08, 0x02, 0x00, 0x00, 0x00, // bit depth, color type, etc.
      0x90, 0x77, 0x53, 0xDE, // CRC
      0x00, 0x00, 0x00, 0x0C, // IDAT chunk length
      0x49, 0x44, 0x41, 0x54, // IDAT
      0x08, 0x99, 0x01, 0x01, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0x00, 0x00,
      0x02, 0x00, 0x01, // compressed data
      0xE2, 0x21, 0xBC, 0x33, // CRC
      0x00, 0x00, 0x00, 0x00, // IEND chunk length
      0x49, 0x45, 0x4E, 0x44, // IEND
      0xAE, 0x42, 0x60, 0x82, // CRC
    ];
  }
}
