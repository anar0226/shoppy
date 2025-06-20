import 'package:cloud_firestore/cloud_firestore.dart';

class StoreModel {
  final String id;
  final String name;
  final String description;
  final String logo;
  final String banner;
  final String ownerId;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> settings;

  StoreModel({
    required this.id,
    required this.name,
    required this.description,
    required this.logo,
    required this.banner,
    required this.ownerId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.settings,
  });

  factory StoreModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return StoreModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      logo: data['logo'] ?? '',
      banner: data['banner'] ?? '',
      ownerId: data['ownerId'] ?? '',
      status: data['status'] ?? 'inactive',
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
      settings: data['settings'] ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'logo': logo,
      'banner': banner,
      'ownerId': ownerId,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'settings': settings,
    };
  }

  StoreModel copyWith({
    String? id,
    String? name,
    String? description,
    String? logo,
    String? banner,
    String? ownerId,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? settings,
  }) {
    return StoreModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      logo: logo ?? this.logo,
      banner: banner ?? this.banner,
      ownerId: ownerId ?? this.ownerId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      settings: settings ?? this.settings,
    );
  }

  static DateTime _parseTimestamp(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    return DateTime.now();
  }
}
