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

  // Inventory management methods

  /// Check if product has any stock available
  bool get hasStock {
    if (variants.isNotEmpty) {
      // For products with variants, check if any variant has stock
      return variants.any((variant) => variant.hasStock);
    }
    // For simple products, check main stock
    return stock > 0;
  }

  /// Get available stock for a specific variant option
  int getStockForVariant(String variantName, String option) {
    final variant = variants.firstWhere(
      (v) => v.name == variantName,
      orElse: () => ProductVariant(name: '', options: [], priceAdjustments: {}),
    );
    return variant.getStockForOption(option);
  }

  /// Check if a specific variant combination is in stock
  bool isVariantInStock(Map<String, String> selectedVariants) {
    if (variants.isEmpty) return stock > 0;

    for (final entry in selectedVariants.entries) {
      final variantName = entry.key;
      final selectedOption = entry.value;

      final variant = variants.firstWhere(
        (v) => v.name == variantName,
        orElse: () =>
            ProductVariant(name: '', options: [], priceAdjustments: {}),
      );

      if (variant.trackInventory &&
          variant.getStockForOption(selectedOption) <= 0) {
        return false;
      }
    }
    return true;
  }

  /// Get total available stock across all variants
  int get totalAvailableStock {
    if (variants.isNotEmpty) {
      return variants.fold(0, (sum, variant) => sum + variant.totalStock);
    }
    return stock;
  }

  /// Check if product should be hidden due to no stock
  bool get shouldHideFromListing {
    return !isActive || !hasStock;
  }
}

class ProductVariant {
  final String name;
  final List<String> options;
  final Map<String, double> priceAdjustments;
  final Map<String, int> stockByOption;
  final bool trackInventory;

  ProductVariant({
    required this.name,
    required this.options,
    required this.priceAdjustments,
    this.stockByOption = const {},
    this.trackInventory = false,
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
      stockByOption: _convertStockMap(map['stockByOption'] ?? {}),
      trackInventory: map['trackInventory'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'options': options,
      'priceAdjustments': priceAdjustments,
      'stockByOption': stockByOption,
      'trackInventory': trackInventory,
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

  static Map<String, int> _convertStockMap(dynamic raw) {
    final Map<String, int> result = {};
    if (raw is Map) {
      raw.forEach((key, value) {
        result[key.toString()] = (value as num?)?.toInt() ?? 0;
      });
    }
    return result;
  }

  int getStockForOption(String option) {
    if (!trackInventory) return 999;
    return stockByOption[option] ?? 0;
  }

  bool get hasStock {
    if (!trackInventory) return true;
    return stockByOption.values.any((stock) => stock > 0);
  }

  int get totalStock {
    if (!trackInventory) return 999;
    return stockByOption.values.fold(0, (sum, stock) => sum + stock);
  }
}
