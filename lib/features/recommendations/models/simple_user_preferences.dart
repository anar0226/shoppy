import 'package:cloud_firestore/cloud_firestore.dart';

class SimpleUserPreferences {
  final String userId;
  final String? shoppingFor; // 'men', 'women', 'both'
  final List<String> interests; // Categories user is interested in
  final List<String>
      recentlyShownStores; // Track which stores were shown recently
  final DateTime createdAt;
  final DateTime updatedAt;

  SimpleUserPreferences({
    required this.userId,
    this.shoppingFor,
    this.interests = const [],
    this.recentlyShownStores = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory SimpleUserPreferences.fromMap(
      Map<String, dynamic> map, String userId) {
    return SimpleUserPreferences(
      userId: userId,
      shoppingFor: map['shoppingFor'],
      interests: List<String>.from(map['interests'] ?? []),
      recentlyShownStores: List<String>.from(map['recentlyShownStores'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shoppingFor': shoppingFor,
      'interests': interests,
      'recentlyShownStores': recentlyShownStores,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  SimpleUserPreferences copyWith({
    String? shoppingFor,
    List<String>? interests,
    List<String>? recentlyShownStores,
    DateTime? updatedAt,
  }) {
    return SimpleUserPreferences(
      userId: userId,
      shoppingFor: shoppingFor ?? this.shoppingFor,
      interests: interests ?? this.interests,
      recentlyShownStores: recentlyShownStores ?? this.recentlyShownStores,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
