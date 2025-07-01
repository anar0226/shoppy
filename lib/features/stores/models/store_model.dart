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

  // New contact information fields
  final String phone;
  final String facebook;
  final String instagram;
  final String refundPolicy;

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
    this.phone = '',
    this.facebook = '',
    this.instagram = '',
    this.refundPolicy = '',
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
      phone: data['phone'] ?? '',
      facebook: data['facebook'] ?? '',
      instagram: data['instagram'] ?? '',
      refundPolicy: data['refundPolicy'] ?? '',
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
      'phone': phone,
      'facebook': facebook,
      'instagram': instagram,
      'refundPolicy': refundPolicy,
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
    String? phone,
    String? facebook,
    String? instagram,
    String? refundPolicy,
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
      phone: phone ?? this.phone,
      facebook: facebook ?? this.facebook,
      instagram: instagram ?? this.instagram,
      refundPolicy: refundPolicy ?? this.refundPolicy,
    );
  }

  // Validation methods
  bool get hasContactInfo =>
      phone.isNotEmpty || facebook.isNotEmpty || instagram.isNotEmpty;

  List<String> get availableContactMethods {
    List<String> methods = [];
    if (phone.isNotEmpty) methods.add('phone');
    if (facebook.isNotEmpty) methods.add('facebook');
    if (instagram.isNotEmpty) methods.add('instagram');
    return methods;
  }

  String? validateContactInfo() {
    if (!hasContactInfo) {
      return 'Дор хаяж нэг холбогдох арга заавал оруулна уу (утас, Facebook эсвэл Instagram)';
    }
    return null;
  }

  static DateTime _parseTimestamp(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    return DateTime.now();
  }
}
