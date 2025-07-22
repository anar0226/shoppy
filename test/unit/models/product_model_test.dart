import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:avii/features/products/models/product_model.dart';
import '../../helpers/test_data_factory.dart';

void main() {
  group('ProductModel Tests', () {
    test('should create ProductModel from Firestore document', () {
      // Arrange
      final productData = TestDataFactory.createProductData();
      final documentSnapshot = FakeDocumentSnapshot(
        data: productData,
        id: productData['id'],
      );

      // Act
      final product = ProductModel.fromFirestore(documentSnapshot);

      // Assert
      expect(product.id, equals(productData['id']));
      expect(product.name, equals(productData['name']));
      expect(product.description, equals(productData['description']));
      expect(product.price, equals(productData['price']));
      expect(product.stock, equals(productData['stock']));
      expect(product.storeId, equals(productData['storeId']));
      expect(product.images, equals(productData['images']));
      expect(product.category, equals(productData['category']));
      expect(product.isActive, equals(productData['isActive']));
    });

    test('should convert ProductModel to map', () {
      // Arrange
      final productData = TestDataFactory.createProductData();
      final documentSnapshot = FakeDocumentSnapshot(
        data: productData,
        id: productData['id'] as String,
      );
      final product = ProductModel.fromFirestore(documentSnapshot);

      // Act
      final map = product.toMap();

      // Assert
      expect(map['name'], equals(product.name));
      expect(map['description'], equals(product.description));
      expect(map['price'], equals(product.price));
      expect(map['stock'], equals(product.stock));
      expect(map['storeId'], equals(product.storeId));
      expect(map['images'], equals(product.images));
      expect(map['category'], equals(product.category));
      expect(map['isActive'], equals(product.isActive));
      expect(map['discount']['isDiscounted'], equals(product.isDiscounted));
      expect(map['discount']['percent'], equals(product.discountPercent));
      expect(map['review']['numberOfReviews'], equals(product.reviewCount));
      expect(map['review']['stars'], equals(product.reviewStars));
    });

    test('should create ProductModel with factory method', () {
      // Arrange
      final productData = TestDataFactory.createProductData(
        id: 'test_product_123',
        name: 'Test Product',
        price: 1500.0,
        stock: 5,
      );

      // Act
      final product = TestDataFactory.createProductModel(
        id: 'test_product_123',
        name: 'Test Product',
        price: 1500.0,
        stock: 5,
      );

      // Assert
      expect(product.id, equals('test_product_123'));
      expect(product.name, equals('Test Product'));
      expect(product.price, equals(1500.0));
      expect(product.stock, equals(5));
    });

    test('should handle empty images list', () {
      // Arrange
      final productData = TestDataFactory.createProductData(images: []);
      final documentSnapshot = FakeDocumentSnapshot(
        data: productData,
        id: productData['id'],
      );

      // Act
      final product = ProductModel.fromFirestore(documentSnapshot);

      // Assert
      expect(product.images, isEmpty);
    });

    test('should handle null values gracefully', () {
      // Arrange
      final productData = {
        'id': 'test_product_123',
        'name': 'Test Product',
        'description': null,
        'price': 1000.0,
        'stock': 10,
        'storeId': 'test_store_456',
        'images': null,
        'category': 'Electronics',
        'isActive': true,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'variants': [],
        'discount': {
          'isDiscounted': false,
          'percent': 0,
        },
        'review': {
          'numberOfReviews': 5,
          'stars': 4.2,
        },
      };
      final documentSnapshot = FakeDocumentSnapshot(
        data: productData,
        id: productData['id'] as String,
      );

      // Act
      final product = ProductModel.fromFirestore(documentSnapshot);

      // Assert
      expect(product.id, equals('test_product_123'));
      expect(product.name, equals('Test Product'));
      expect(product.description, isEmpty);
      expect(product.images, isEmpty);
    });

    test('should validate required fields', () {
      // Arrange
      final productData = {
        'id': 'test_product_123',
        'name': '', // Empty name
        'description': 'Test description',
        'price': -100.0, // Negative price
        'stock': -5, // Negative stock
        'storeId': '', // Empty store ID
        'images': ['https://example.com/image.jpg'],
        'category': 'Electronics',
        'isActive': true,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'variants': [],
        'discount': {
          'isDiscounted': false,
          'percent': 0,
        },
        'review': {
          'numberOfReviews': 5,
          'stars': 4.2,
        },
      };
      final documentSnapshot = FakeDocumentSnapshot(
        data: productData,
        id: productData['id'] as String,
      );

      // Act
      final product = ProductModel.fromFirestore(documentSnapshot);

      // Assert
      expect(product.name, isEmpty);
      expect(product.price, equals(-100.0));
      expect(product.stock, equals(-5));
      expect(product.storeId, isEmpty);
    });

    test('should handle discount information', () {
      // Arrange
      final productData = {
        'id': 'test_product_123',
        'name': 'Test Product',
        'description': 'Test description',
        'price': 1000.0,
        'stock': 10,
        'storeId': 'test_store_456',
        'images': ['https://example.com/image.jpg'],
        'category': 'Electronics',
        'isActive': true,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'variants': [],
        'discount': {
          'isDiscounted': true,
          'percent': 20,
        },
        'review': {
          'numberOfReviews': 5,
          'stars': 4.2,
        },
      };
      final documentSnapshot = FakeDocumentSnapshot(
        data: productData,
        id: productData['id'] as String,
      );

      // Act
      final product = ProductModel.fromFirestore(documentSnapshot);

      // Assert
      expect(product.isDiscounted, isTrue);
      expect(product.discountPercent, equals(20));
    });

    test('should handle review information', () {
      // Arrange
      final productData = {
        'id': 'test_product_123',
        'name': 'Test Product',
        'description': 'Test description',
        'price': 1000.0,
        'stock': 10,
        'storeId': 'test_store_456',
        'images': ['https://example.com/image.jpg'],
        'category': 'Electronics',
        'isActive': true,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'variants': [],
        'discount': {
          'isDiscounted': false,
          'percent': 0,
        },
        'review': {
          'numberOfReviews': 10,
          'stars': 4.8,
        },
      };
      final documentSnapshot = FakeDocumentSnapshot(
        data: productData,
        id: productData['id'] as String,
      );

      // Act
      final product = ProductModel.fromFirestore(documentSnapshot);

      // Assert
      expect(product.reviewCount, equals(10));
      expect(product.reviewStars, equals(4.8));
    });
  });
}
