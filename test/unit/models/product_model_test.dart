import 'package:flutter_test/flutter_test.dart';

import 'package:avii/features/products/models/product_model.dart';
import '../../helpers/test_data_factory.dart';

void main() {
  group('ProductModel Tests', () {
    test('should create ProductModel with factory method', () {
      // Arrange
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

    test('should convert ProductModel to map', () {
      // Arrange
      final product = TestDataFactory.createProductModel(
        id: 'test_product_123',
        name: 'Test Product',
        price: 1000.0,
        stock: 10,
      );

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

    test('should handle discount information', () {
      // Arrange
      final product = ProductModel(
        id: 'test_product_123',
        storeId: 'test_store_456',
        name: 'Test Product',
        description: 'Test description',
        price: 1000.0,
        images: ['https://example.com/image.jpg'],
        category: 'Electronics',
        stock: 10,
        variants: [],
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isDiscounted: true,
        discountPercent: 20,
        reviewCount: 5,
        reviewStars: 4.2,
      );

      // Assert
      expect(product.isDiscounted, isTrue);
      expect(product.discountPercent, equals(20));
    });

    test('should handle review information', () {
      // Arrange
      final product = ProductModel(
        id: 'test_product_123',
        storeId: 'test_store_456',
        name: 'Test Product',
        description: 'Test description',
        price: 1000.0,
        images: ['https://example.com/image.jpg'],
        category: 'Electronics',
        stock: 10,
        variants: [],
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isDiscounted: false,
        discountPercent: 0,
        reviewCount: 10,
        reviewStars: 4.8,
      );

      // Assert
      expect(product.reviewCount, equals(10));
      expect(product.reviewStars, equals(4.8));
    });

    test('should handle empty images list', () {
      // Arrange
      final product = ProductModel(
        id: 'test_product_123',
        storeId: 'test_store_456',
        name: 'Test Product',
        description: 'Test description',
        price: 1000.0,
        images: [],
        category: 'Electronics',
        stock: 10,
        variants: [],
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Assert
      expect(product.images, isEmpty);
    });

    test('should handle default values', () {
      // Arrange
      final product = ProductModel(
        id: 'test_product_123',
        storeId: 'test_store_456',
        name: 'Test Product',
        description: 'Test description',
        price: 1000.0,
        images: ['https://example.com/image.jpg'],
        category: 'Electronics',
        stock: 10,
        variants: [],
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Assert
      expect(product.isDiscounted, isFalse);
      expect(product.discountPercent, equals(0));
      expect(product.reviewCount, equals(0));
      expect(product.reviewStars, equals(0));
    });
  });
}
