import 'package:cloud_firestore/cloud_firestore.dart';

class UserStats {
  final int totalOrders;
  final double totalSpent;
  final DateTime? lastOrderDate;
  final int savedItems;
  final int reviewsCount;

  UserStats({
    this.totalOrders = 0,
    this.totalSpent = 0.0,
    this.lastOrderDate,
    this.savedItems = 0,
    this.reviewsCount = 0,
  });

  factory UserStats.fromMap(Map<String, dynamic> map) {
    return UserStats(
      totalOrders: map['totalOrders'] ?? 0,
      totalSpent: (map['totalSpent'] ?? 0).toDouble(),
      lastOrderDate: map['lastOrderDate'] != null
          ? (map['lastOrderDate'] as Timestamp).toDate()
          : null,
      savedItems: map['savedItems'] ?? 0,
      reviewsCount: map['reviewsCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalOrders': totalOrders,
      'totalSpent': totalSpent,
      'lastOrderDate':
          lastOrderDate != null ? Timestamp.fromDate(lastOrderDate!) : null,
      'savedItems': savedItems,
      'reviewsCount': reviewsCount,
    };
  }
}

class UserModel {
  final String id;
  final String email;
  final String? displayName;
  final String? phoneNumber;
  final String? photoURL;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final bool isActive;
  final String userType;
  final Map<String, dynamic>? profile;
  final List<String> addresses;
  final List<String> followerStoreIds;
  final UserStats stats;

  UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.phoneNumber,
    this.photoURL,
    required this.createdAt,
    this.lastLoginAt,
    this.isActive = true,
    this.userType = 'customer',
    this.profile,
    this.addresses = const [],
    this.followerStoreIds = const [],
    UserStats? stats,
  }) : stats = stats ?? UserStats();

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      email: map['email'] ?? '',
      displayName: map['displayName'],
      phoneNumber: map['phoneNumber'],
      photoURL: map['photoURL'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastLoginAt: map['lastLoginAt'] != null
          ? (map['lastLoginAt'] as Timestamp).toDate()
          : null,
      isActive: map['isActive'] ?? true,
      userType: map['userType'] ?? 'customer',
      profile: map['profile'],
      addresses: List<String>.from(map['addresses'] ?? []),
      followerStoreIds: List<String>.from(map['followerStoreIds'] ?? []),
      stats:
          map['stats'] != null ? UserStats.fromMap(map['stats']) : UserStats(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'photoURL': photoURL,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt':
          lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'isActive': isActive,
      'userType': userType,
      'profile': profile,
      'addresses': addresses,
      'followerStoreIds': followerStoreIds,
      'stats': stats.toMap(),
    };
  }

  UserModel copyWith({
    String? displayName,
    String? phoneNumber,
    String? photoURL,
    DateTime? lastLoginAt,
    bool? isActive,
    String? userType,
    Map<String, dynamic>? profile,
    List<String>? addresses,
    List<String>? followerStoreIds,
    UserStats? stats,
  }) {
    return UserModel(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoURL: photoURL ?? this.photoURL,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isActive: isActive ?? this.isActive,
      userType: userType ?? this.userType,
      profile: profile ?? this.profile,
      addresses: addresses ?? this.addresses,
      followerStoreIds: followerStoreIds ?? this.followerStoreIds,
      stats: stats ?? this.stats,
    );
  }

  String get displayNameOrEmail =>
      displayName?.isNotEmpty == true ? displayName! : email;

  String get statusText => isActive ? 'Active' : 'Inactive';

  String get formattedTotalSpent => '₮${stats.totalSpent.toStringAsFixed(2)}';

  bool get isRelevantUser =>
      stats.totalOrders > 0 || followerStoreIds.isNotEmpty;

  bool isFollowingStore(String storeId) => followerStoreIds.contains(storeId);

  String get followingStatusText => followerStoreIds.isEmpty
      ? 'Not following any stores'
      : 'Following ${followerStoreIds.length} store${followerStoreIds.length == 1 ? '' : 's'}';

  String get formattedCreatedAt {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year${difference.inDays > 730 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${difference.inDays > 60 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else {
      return 'Today';
    }
  }

  String get maskedEmail {
    final parts = email.split('@');
    if (parts.length != 2) return email;

    final username = parts[0];
    final domain = parts[1];

    if (username.length <= 2) return email;

    final maskedUsername = username[0] +
        '*' * (username.length - 2) +
        username[username.length - 1];
    return '$maskedUsername@$domain';
  }
}
