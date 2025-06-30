import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum DiscountType {
  freeShipping,
  percentage,
  fixedAmount,
}

class DiscountModel {
  final String id;
  final String storeId;
  final String code;
  final String name;
  final DiscountType type;
  final double value;
  final int maxUseCount;
  final int currentUseCount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  DiscountModel({
    required this.id,
    required this.storeId,
    required this.code,
    required this.name,
    required this.type,
    required this.value,
    required this.maxUseCount,
    this.currentUseCount = 0,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DiscountModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return DiscountModel(
      id: doc.id,
      storeId: data['storeId'] ?? '',
      code: data['code'] ?? '',
      name: data['name'] ?? '',
      type: _parseDiscountType(data['type']),
      value: _parseDouble(data['value']),
      maxUseCount: data['maxUseCount'] ?? 0,
      currentUseCount: data['currentUseCount'] ?? 0,
      isActive: data['isActive'] ?? true,
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'storeId': storeId,
      'code': code,
      'name': name,
      'type': type.name,
      'value': value,
      'maxUseCount': maxUseCount,
      'currentUseCount': currentUseCount,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  String get typeDisplayName {
    switch (type) {
      case DiscountType.freeShipping:
        return 'Free Shipping';
      case DiscountType.percentage:
        return 'Percentage';
      case DiscountType.fixedAmount:
        return 'Fixed Amount';
    }
  }

  String get valueDisplayText {
    switch (type) {
      case DiscountType.freeShipping:
        return 'Free Shipping';
      case DiscountType.percentage:
        return '${value.toStringAsFixed(1)}%';
      case DiscountType.fixedAmount:
        return '₮${value.toStringAsFixed(2)}';
    }
  }

  IconData get iconData {
    switch (type) {
      case DiscountType.freeShipping:
        return Icons.local_shipping_outlined;
      case DiscountType.percentage:
        return Icons.percent;
      case DiscountType.fixedAmount:
        return Icons.attach_money;
    }
  }

  static DiscountType _parseDiscountType(dynamic typeValue) {
    if (typeValue is String) {
      switch (typeValue) {
        case 'freeShipping':
          return DiscountType.freeShipping;
        case 'percentage':
          return DiscountType.percentage;
        case 'fixedAmount':
          return DiscountType.fixedAmount;
        default:
          return DiscountType.percentage;
      }
    }
    return DiscountType.percentage;
  }

  static double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    return DateTime.now();
  }
}
