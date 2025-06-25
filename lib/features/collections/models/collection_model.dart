import 'package:cloud_firestore/cloud_firestore.dart';

class CollectionModel {
  final String id;
  final String name;
  final String storeId;
  final String backgroundImage;
  final List<String> productIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  CollectionModel({
    required this.id,
    required this.name,
    required this.storeId,
    required this.backgroundImage,
    required this.productIds,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  factory CollectionModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CollectionModel(
      id: doc.id,
      name: data['name'] ?? '',
      storeId: data['storeId'] ?? '',
      backgroundImage: data['backgroundImage'] ?? '',
      productIds: List<String>.from(data['productIds'] ?? []),
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'storeId': storeId,
      'backgroundImage': backgroundImage,
      'productIds': productIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
    };
  }

  CollectionModel copyWith({
    String? id,
    String? name,
    String? storeId,
    String? backgroundImage,
    List<String>? productIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return CollectionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      storeId: storeId ?? this.storeId,
      backgroundImage: backgroundImage ?? this.backgroundImage,
      productIds: productIds ?? this.productIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  static DateTime _parseTimestamp(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    return DateTime.now();
  }
}
