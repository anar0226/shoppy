import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryModel {
  final String id;
  final String name;
  final String? description;
  final String? backgroundImageUrl;
  final String? iconUrl;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? storeId; // For store-specific categories
  final Map<String, dynamic> metadata; // Additional custom fields

  CategoryModel({
    required this.id,
    required this.name,
    this.description,
    this.backgroundImageUrl,
    this.iconUrl,
    this.sortOrder = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.storeId,
    this.metadata = const {},
  });

  // Create from Firestore document
  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return CategoryModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      backgroundImageUrl: data['backgroundImageUrl'],
      iconUrl: data['iconUrl'],
      sortOrder: data['sortOrder'] ?? 0,
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      storeId: data['storeId'],
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  // Create from Map (for use with paginated queries)
  factory CategoryModel.fromMap(Map<String, dynamic> data) {
    return CategoryModel(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      description: data['description'],
      backgroundImageUrl: data['backgroundImageUrl'],
      iconUrl: data['iconUrl'],
      sortOrder: data['sortOrder'] ?? 0,
      isActive: data['isActive'] ?? true,
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
      storeId: data['storeId'],
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  // Parse timestamp from dynamic value
  static DateTime _parseTimestamp(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    if (ts is DateTime) return ts;
    return DateTime.now();
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'backgroundImageUrl': backgroundImageUrl,
      'iconUrl': iconUrl,
      'sortOrder': sortOrder,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'storeId': storeId,
      'metadata': metadata,
    };
  }

  // Create a copy with updated fields
  CategoryModel copyWith({
    String? name,
    String? description,
    String? backgroundImageUrl,
    String? iconUrl,
    int? sortOrder,
    bool? isActive,
    DateTime? updatedAt,
    String? storeId,
    Map<String, dynamic>? metadata,
  }) {
    return CategoryModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      backgroundImageUrl: backgroundImageUrl ?? this.backgroundImageUrl,
      iconUrl: iconUrl ?? this.iconUrl,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      storeId: storeId ?? this.storeId,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'CategoryModel(id: $id, name: $name, backgroundImageUrl: $backgroundImageUrl)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CategoryModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
