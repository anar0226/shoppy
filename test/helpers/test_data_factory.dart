import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:avii/features/products/models/product_model.dart';
import 'package:avii/features/stores/models/store_model.dart';

/// Factory class for creating test data
class TestDataFactory {
  static const String _testUserId = 'test_user_123';
  static const String _testStoreId = 'test_store_456';
  static const String _testProductId = 'test_product_789';

  /// Create a mock Firebase user
  static auth.User createMockUser({
    String? uid,
    String? email,
    String? displayName,
    String? photoURL,
  }) {
    // Note: In real tests, use firebase_auth_mocks package
    // This is a placeholder for the factory pattern
    throw UnimplementedError(
        'Use firebase_auth_mocks package for user mocking');
  }

  /// Create a mock user data map
  static Map<String, dynamic> createUserData({
    String? uid,
    String? email,
    String? displayName,
    String? phoneNumber,
    DateTime? createdAt,
  }) {
    return {
      'uid': uid ?? _testUserId,
      'email': email ?? 'test@example.com',
      'displayName': displayName ?? 'Test User',
      'phoneNumber': phoneNumber ?? '+97699999999',
      'createdAt': createdAt ?? Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'isEmailVerified': true,
      'followerStoreIds': <String>[],
      'notInterestedStoreIds': <String>[],
      'recentlyViewedProducts': <String>[],
    };
  }

  /// Create a mock store data map
  static Map<String, dynamic> createStoreData({
    String? id,
    String? name,
    String? description,
    String? ownerId,
    String? logo,
    String? banner,
    String? status,
    DateTime? createdAt,
  }) {
    return {
      'id': id ?? _testStoreId,
      'name': name ?? 'Test Store',
      'description': description ?? 'A test store for testing purposes',
      'ownerId': ownerId ?? _testUserId,
      'logo': logo ?? 'https://example.com/logo.jpg',
      'banner': banner ?? 'https://example.com/banner.jpg',
      'status': status ?? 'active',
      'createdAt': createdAt ?? Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'ratingAvg': 4.5,
      'reviewCount': 10,
      'followerCount': 25,
      'productCount': 50,
    };
  }

  /// Create a mock product data map
  static Map<String, dynamic> createProductData({
    String? id,
    String? name,
    String? description,
    double? price,
    int? stock,
    String? storeId,
    List<String>? images,
    String? category,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return {
      'id': id ?? _testProductId,
      'name': name ?? 'Test Product',
      'description': description ?? 'A test product for testing purposes',
      'price': price ?? 1000.0,
      'stock': stock ?? 10,
      'storeId': storeId ?? _testStoreId,
      'images': images ?? ['https://example.com/product1.jpg'],
      'category': category ?? 'Electronics',
      'isActive': isActive ?? true,
      'createdAt': createdAt ?? Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'hasVariants': false,
      'totalStock': stock ?? 10,
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
    };
  }

  /// Create a mock order data map
  static Map<String, dynamic> createOrderData({
    String? id,
    String? userId,
    String? storeId,
    List<Map<String, dynamic>>? items,
    double? total,
    String? status,
    DateTime? createdAt,
  }) {
    return {
      'id': id ?? 'test_order_123',
      'userId': userId ?? _testUserId,
      'storeId': storeId ?? _testStoreId,
      'items': items ??
          [
            {
              'productId': _testProductId,
              'name': 'Test Product',
              'price': 1000.0,
              'quantity': 1,
              'imageUrl': 'https://example.com/product1.jpg',
            }
          ],
      'total': total ?? 1000.0,
      'subtotal': total ?? 1000.0,
      'shippingCost': 0.0,
      'tax': 0.0,
      'status': status ?? 'placed',
      'createdAt': createdAt ?? Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'paymentMethod': 'QPay',
      'deliveryAddress': {
        'firstName': 'Test',
        'lastName': 'User',
        'phone': '+97699999999',
        'address': 'Test Address',
        'city': 'Ulaanbaatar',
        'postalCode': '12345',
      },
    };
  }

  /// Create a mock cart item data map
  static Map<String, dynamic> createCartItemData({
    String? productId,
    String? name,
    double? price,
    int? quantity,
    String? imageUrl,
    Map<String, String>? selectedVariants,
  }) {
    return {
      'productId': productId ?? _testProductId,
      'name': name ?? 'Test Product',
      'price': price ?? 1000.0,
      'quantity': quantity ?? 1,
      'imageUrl': imageUrl ?? 'https://example.com/product1.jpg',
      'selectedVariants': selectedVariants ?? {},
    };
  }

  /// Create a mock notification data map
  static Map<String, dynamic> createNotificationData({
    String? id,
    String? title,
    String? body,
    String? type,
    Map<String, dynamic>? data,
    bool? read,
    DateTime? createdAt,
  }) {
    return {
      'id': id ?? 'test_notification_123',
      'title': title ?? 'Test Notification',
      'body': body ?? 'This is a test notification',
      'type': type ?? 'general',
      'data': data ?? {},
      'read': read ?? false,
      'createdAt': createdAt ?? Timestamp.now(),
    };
  }

  /// Create a mock review data map
  static Map<String, dynamic> createReviewData({
    String? id,
    String? userId,
    String? storeId,
    double? rating,
    String? comment,
    List<String>? images,
    String? status,
    DateTime? createdAt,
  }) {
    return {
      'id': id ?? 'test_review_123',
      'userId': userId ?? _testUserId,
      'storeId': storeId ?? _testStoreId,
      'rating': rating ?? 4.5,
      'comment': comment ?? 'Great product!',
      'images': images ?? [],
      'status': status ?? 'active',
      'createdAt': createdAt ?? Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'likes': <String>[],
      'dislikes': <String>[],
    };
  }

  /// Create a ProductModel instance
  static ProductModel createProductModel({
    String? id,
    String? name,
    String? description,
    double? price,
    int? stock,
    String? storeId,
    List<String>? images,
    String? category,
    bool? isActive,
  }) {
    final data = createProductData(
      id: id,
      name: name,
      description: description,
      price: price,
      stock: stock,
      storeId: storeId,
      images: images,
      category: category,
      isActive: isActive,
    );

    // Create ProductModel directly instead of using fromFirestore
    return ProductModel(
      id: data['id'] as String,
      storeId: data['storeId'] as String,
      name: data['name'] as String,
      description: data['description'] as String,
      price: (data['price'] as num).toDouble(),
      images: List<String>.from(data['images'] as List),
      category: data['category'] as String,
      stock: data['stock'] as int,
      variants: <ProductVariant>[],
      isActive: data['isActive'] as bool,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Create a StoreModel instance
  static StoreModel createStoreModel({
    String? id,
    String? name,
    String? description,
    String? ownerId,
    String? logo,
    String? banner,
    String? status,
  }) {
    final data = createStoreData(
      id: id,
      name: name,
      description: description,
      ownerId: ownerId,
      logo: logo,
      banner: banner,
      status: status,
    );

    // Create StoreModel directly instead of using fromFirestore
    return StoreModel(
      id: data['id'] as String,
      name: data['name'] as String,
      description: data['description'] as String,
      logo: data['logo'] as String,
      banner: data['banner'] as String,
      ownerId: data['ownerId'] as String,
      status: data['status'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      settings: data['settings'] as Map<String, dynamic>? ?? {},
    );
  }
}
