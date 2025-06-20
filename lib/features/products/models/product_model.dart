import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final String storeId;
  final String name;
  final String description;
  final double price;
  final List<String> images;
  final String category;
  final int stock;
  final List<ProductVariant> variants;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDiscounted;
  final double discountPercent;
  final int reviewCount;
  final double reviewStars;

  ProductModel({
    required this.id,
    required this.storeId,
    required this.name,
    required this.description,
    required this.price,
    required this.images,
    required this.category,
    required this.stock,
    required this.variants,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.isDiscounted = false,
    this.discountPercent = 0,
    this.reviewCount = 0,
    this.reviewStars = 0,
  });

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ProductModel(
      id: doc.id,
      storeId: data['storeId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: _parsePrice(data['price']),
      images: List<String>.from(data['images'] ?? []),
      category: data['category'] ?? '',
      stock: data['stock'] ?? 0,
      variants: (data['variants'] as List<dynamic>? ?? [])
          .map((v) => ProductVariant.fromMap(v))
          .toList(),
      isActive: data['isActive'] ?? true,
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
      isDiscounted: (data['discount']?['isDiscounted']) ?? false,
      discountPercent: _parsePrice(data['discount']?['percent']),
      reviewCount: (data['review']?['numberOfReviews'] ?? 0).toInt(),
      reviewStars: _parsePrice(data['review']?['stars']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'storeId': storeId,
      'name': name,
      'description': description,
      'price': price,
      'images': images,
      'category': category,
      'stock': stock,
      'variants': variants.map((v) => v.toMap()).toList(),
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'discount': {
        'isDiscounted': isDiscounted,
        'percent': discountPercent,
      },
      'review': {
        'numberOfReviews': reviewCount,
        'stars': reviewStars,
      },
    };
  }

  static double _parsePrice(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  static DateTime _parseTimestamp(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    return DateTime.now();
  }
}

class ProductVariant {
  final String name;
  final List<String> options;
  final Map<String, double> priceAdjustments;

  ProductVariant({
    required this.name,
    required this.options,
    required this.priceAdjustments,
  });

  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    final nameKey = map.containsKey('name')
        ? 'name'
        : (map.containsKey('Name') ? 'Name' : '');
    final optionsKey = map.containsKey('options')
        ? 'options'
        : (map.containsKey('Options') ? 'Options' : '');

    List<String> opts = [];
    final rawOptions = map[optionsKey];
    if (rawOptions is List) {
      opts = List<String>.from(rawOptions);
    } else if (rawOptions is String) {
      opts = rawOptions.split(',').map((e) => e.trim()).toList();
    }

    return ProductVariant(
      name: map[nameKey] ?? '',
      options: opts,
      priceAdjustments: _convertPriceAdj(
          map['priceAdjustments'] ?? map['PriceAdjustments'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'options': options,
      'priceAdjustments': priceAdjustments,
    };
  }

  static Map<String, double> _convertPriceAdj(dynamic raw) {
    final Map<String, double> result = {};
    if (raw is Map) {
      raw.forEach((key, value) {
        result[key.toString()] = ProductModel._parsePrice(value);
      });
    }
    return result;
  }
}
