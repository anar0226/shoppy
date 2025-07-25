import 'package:cloud_firestore/cloud_firestore.dart';

/// Mongolian banks supported for payouts
enum MongolianBank {
  khanBank('Khan Bank', 'Хаан банк'),
  tdb('TDB', 'Худалдаа хөгжлийн банк'),
  stateBank('State Bank', 'Төрийн банк'),
  xacBank('Xac Bank', 'Хас банк'),
  capitronBank('Capitron Bank', 'Капитрон банк'),
  bogdBank('Bogd Bank', 'Богд банк'),
  transBank('Trans Bank', 'Транс банк'),
  mBank('M Bank', 'М банк'),
  arigBank('Arig Bank', 'Ариг банк');

  const MongolianBank(this.englishName, this.mongolianName);

  final String englishName;
  final String mongolianName;

  String get displayName => '$englishName ($mongolianName)';
}

/// Payout method preferences
enum PayoutMethod {
  bankTransfer('Bank Transfer', 'Банкны шилжүүлэг');

  const PayoutMethod(this.englishName, this.mongolianName);

  final String englishName;
  final String mongolianName;

  String get displayName => '$englishName ($mongolianName)';
}

/// KYC verification status
enum KYCStatus {
  notSubmitted('Not Submitted', 'Илгээгээгүй'),
  pending('Pending', 'Хүлээгдэж буй'),
  approved('Approved', 'Зөвшөөрөгдсөн'),
  rejected('Rejected', 'Татгалзсан');

  const KYCStatus(this.englishName, this.mongolianName);

  final String englishName;
  final String mongolianName;

  String get displayName => '$englishName ($mongolianName)';
}

/// Payout frequency options
enum PayoutFrequency {
  daily('Daily', 'Өдөр бүр'),
  weekly('Weekly', 'Долоо хоног бүр'),
  biweekly('Bi-weekly', '2 долоо хоног бүр'),
  monthly('Monthly', 'Сар бүр'),
  manual('Manual', 'Гараар');

  const PayoutFrequency(this.englishName, this.mongolianName);

  final String englishName;
  final String mongolianName;

  String get displayName => '$englishName ($mongolianName)';
}

/// Subscription status for monthly fees
enum SubscriptionStatus {
  active('Active', 'Идэвхтэй'),
  expired('Expired', 'Хугацаа дууссан'),
  pending('Pending', 'Хүлээгдэж буй'),
  cancelled('Cancelled', 'Цуцлагдсан'),
  gracePeriod('Grace Period', 'Хүлээлтийн хугацаа');

  const SubscriptionStatus(this.englishName, this.mongolianName);

  final String englishName;
  final String mongolianName;

  String get displayName => '$englishName ($mongolianName)';
}

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

  // Contact information fields
  final String phone;
  final String facebook;
  final String instagram;
  final String refundPolicy;

  // **PAYOUT INFORMATION - NEW FIELDS**

  // Bank Account Details
  final MongolianBank? selectedBank;
  final String? bankAccountNumber;
  final String? bankAccountHolderName;

  // Payout Preferences
  final PayoutMethod preferredPayoutMethod;
  final PayoutFrequency payoutFrequency;
  final double minimumPayoutAmount;
  final bool autoPayoutEnabled;

  // KYC Documents
  final String? idCardFrontImage;
  final String? idCardBackImage;
  final KYCStatus kycStatus;
  final String? kycRejectionReason;
  final DateTime? kycSubmittedAt;
  final DateTime? kycApprovedAt;

  // Payout Status
  final bool payoutSetupCompleted;
  final DateTime? payoutSetupCompletedAt;
  final String? payoutSetupNotes;

  // **SUBSCRIPTION INFORMATION - NEW FIELDS**

  // Subscription Status
  final SubscriptionStatus subscriptionStatus;
  final DateTime? subscriptionStartDate;
  final DateTime? subscriptionEndDate;
  final DateTime? lastPaymentDate;
  final DateTime? nextPaymentDate;
  final List<Map<String, dynamic>> paymentHistory;

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
    // Payout fields with defaults
    this.selectedBank,
    this.bankAccountNumber,
    this.bankAccountHolderName,
    this.preferredPayoutMethod = PayoutMethod.bankTransfer,
    this.payoutFrequency = PayoutFrequency.weekly,
    this.minimumPayoutAmount = 50000.0, // 50,000 MNT default
    this.autoPayoutEnabled = false,
    this.idCardFrontImage,
    this.idCardBackImage,
    this.kycStatus = KYCStatus.notSubmitted,
    this.kycRejectionReason,
    this.kycSubmittedAt,
    this.kycApprovedAt,
    this.payoutSetupCompleted = false,
    this.payoutSetupCompletedAt,
    this.payoutSetupNotes,
    // Subscription fields with defaults
    this.subscriptionStatus = SubscriptionStatus.pending,
    this.subscriptionStartDate,
    this.subscriptionEndDate,
    this.lastPaymentDate,
    this.nextPaymentDate,
    this.paymentHistory = const [],
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
      // Payout fields
      selectedBank: data['selectedBank'] != null
          ? MongolianBank.values.firstWhere(
              (bank) => bank.name == data['selectedBank'],
              orElse: () => MongolianBank.khanBank,
            )
          : null,
      bankAccountNumber: data['bankAccountNumber'],
      bankAccountHolderName: data['bankAccountHolderName'],
      preferredPayoutMethod: PayoutMethod.values.firstWhere(
        (method) => method.name == data['preferredPayoutMethod'],
        orElse: () => PayoutMethod.bankTransfer,
      ),
      payoutFrequency: PayoutFrequency.values.firstWhere(
        (frequency) => frequency.name == data['payoutFrequency'],
        orElse: () => PayoutFrequency.weekly,
      ),
      minimumPayoutAmount: (data['minimumPayoutAmount'] ?? 50000.0).toDouble(),
      autoPayoutEnabled: data['autoPayoutEnabled'] ?? false,
      idCardFrontImage: data['idCardFrontImage'],
      idCardBackImage: data['idCardBackImage'],
      kycStatus: KYCStatus.values.firstWhere(
        (status) => status.name == data['kycStatus'],
        orElse: () => KYCStatus.notSubmitted,
      ),
      kycRejectionReason: data['kycRejectionReason'],
      kycSubmittedAt: data['kycSubmittedAt'] != null
          ? _parseTimestamp(data['kycSubmittedAt'])
          : null,
      kycApprovedAt: data['kycApprovedAt'] != null
          ? _parseTimestamp(data['kycApprovedAt'])
          : null,
      payoutSetupCompleted: data['payoutSetupCompleted'] ?? false,
      payoutSetupCompletedAt: data['payoutSetupCompletedAt'] != null
          ? _parseTimestamp(data['payoutSetupCompletedAt'])
          : null,
      payoutSetupNotes: data['payoutSetupNotes'],
      // Subscription fields
      subscriptionStatus: SubscriptionStatus.values.firstWhere(
        (status) => status.name == data['subscriptionStatus'],
        orElse: () => SubscriptionStatus.pending,
      ),
      subscriptionStartDate: data['subscriptionStartDate'] != null
          ? _parseTimestamp(data['subscriptionStartDate'])
          : null,
      subscriptionEndDate: data['subscriptionEndDate'] != null
          ? _parseTimestamp(data['subscriptionEndDate'])
          : null,
      lastPaymentDate: data['lastPaymentDate'] != null
          ? _parseTimestamp(data['lastPaymentDate'])
          : null,
      nextPaymentDate: data['nextPaymentDate'] != null
          ? _parseTimestamp(data['nextPaymentDate'])
          : null,
      paymentHistory:
          List<Map<String, dynamic>>.from(data['paymentHistory'] ?? []),
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
      // Payout fields
      'selectedBank': selectedBank?.name,
      'bankAccountNumber': bankAccountNumber,
      'bankAccountHolderName': bankAccountHolderName,
      'preferredPayoutMethod': preferredPayoutMethod.name,
      'payoutFrequency': payoutFrequency.name,
      'minimumPayoutAmount': minimumPayoutAmount,
      'autoPayoutEnabled': autoPayoutEnabled,
      'idCardFrontImage': idCardFrontImage,
      'idCardBackImage': idCardBackImage,
      'kycStatus': kycStatus.name,
      'kycRejectionReason': kycRejectionReason,
      'kycSubmittedAt':
          kycSubmittedAt != null ? Timestamp.fromDate(kycSubmittedAt!) : null,
      'kycApprovedAt':
          kycApprovedAt != null ? Timestamp.fromDate(kycApprovedAt!) : null,
      'payoutSetupCompleted': payoutSetupCompleted,
      'payoutSetupCompletedAt': payoutSetupCompletedAt != null
          ? Timestamp.fromDate(payoutSetupCompletedAt!)
          : null,
      'payoutSetupNotes': payoutSetupNotes,
      // Subscription fields
      'subscriptionStatus': subscriptionStatus.name,
      'subscriptionStartDate': subscriptionStartDate != null
          ? Timestamp.fromDate(subscriptionStartDate!)
          : null,
      'subscriptionEndDate': subscriptionEndDate != null
          ? Timestamp.fromDate(subscriptionEndDate!)
          : null,
      'lastPaymentDate':
          lastPaymentDate != null ? Timestamp.fromDate(lastPaymentDate!) : null,
      'nextPaymentDate':
          nextPaymentDate != null ? Timestamp.fromDate(nextPaymentDate!) : null,
      'paymentHistory': paymentHistory,
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
    // Payout fields
    MongolianBank? selectedBank,
    String? bankAccountNumber,
    String? bankAccountHolderName,
    PayoutMethod? preferredPayoutMethod,
    PayoutFrequency? payoutFrequency,
    double? minimumPayoutAmount,
    bool? autoPayoutEnabled,
    String? idCardFrontImage,
    String? idCardBackImage,
    KYCStatus? kycStatus,
    String? kycRejectionReason,
    DateTime? kycSubmittedAt,
    DateTime? kycApprovedAt,
    bool? payoutSetupCompleted,
    DateTime? payoutSetupCompletedAt,
    String? payoutSetupNotes,
    // Subscription fields
    SubscriptionStatus? subscriptionStatus,
    DateTime? subscriptionStartDate,
    DateTime? subscriptionEndDate,
    DateTime? lastPaymentDate,
    DateTime? nextPaymentDate,
    List<Map<String, dynamic>>? paymentHistory,
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
      // Payout fields
      selectedBank: selectedBank ?? this.selectedBank,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankAccountHolderName:
          bankAccountHolderName ?? this.bankAccountHolderName,
      preferredPayoutMethod:
          preferredPayoutMethod ?? this.preferredPayoutMethod,
      payoutFrequency: payoutFrequency ?? this.payoutFrequency,
      minimumPayoutAmount: minimumPayoutAmount ?? this.minimumPayoutAmount,
      autoPayoutEnabled: autoPayoutEnabled ?? this.autoPayoutEnabled,
      idCardFrontImage: idCardFrontImage ?? this.idCardFrontImage,
      idCardBackImage: idCardBackImage ?? this.idCardBackImage,
      kycStatus: kycStatus ?? this.kycStatus,
      kycRejectionReason: kycRejectionReason ?? this.kycRejectionReason,
      kycSubmittedAt: kycSubmittedAt ?? this.kycSubmittedAt,
      kycApprovedAt: kycApprovedAt ?? this.kycApprovedAt,
      payoutSetupCompleted: payoutSetupCompleted ?? this.payoutSetupCompleted,
      payoutSetupCompletedAt:
          payoutSetupCompletedAt ?? this.payoutSetupCompletedAt,
      payoutSetupNotes: payoutSetupNotes ?? this.payoutSetupNotes,
      // Subscription fields
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionStartDate:
          subscriptionStartDate ?? this.subscriptionStartDate,
      subscriptionEndDate: subscriptionEndDate ?? this.subscriptionEndDate,
      lastPaymentDate: lastPaymentDate ?? this.lastPaymentDate,
      nextPaymentDate: nextPaymentDate ?? this.nextPaymentDate,
      paymentHistory: paymentHistory ?? this.paymentHistory,
    );
  }

  // **EXISTING VALIDATION METHODS**

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

  // **NEW PAYOUT VALIDATION METHODS**

  /// Check if bank account details are complete
  bool get hasCompleteBankDetails {
    return selectedBank != null &&
        bankAccountNumber != null &&
        bankAccountNumber!.isNotEmpty &&
        bankAccountHolderName != null &&
        bankAccountHolderName!.isNotEmpty;
  }

  /// Check if KYC documents are uploaded
  bool get hasKYCDocuments {
    return idCardFrontImage != null &&
        idCardFrontImage!.isNotEmpty &&
        idCardBackImage != null &&
        idCardBackImage!.isNotEmpty;
  }

  /// Check if payout setup is complete
  bool get isPayoutSetupComplete {
    return hasCompleteBankDetails && kycStatus == KYCStatus.approved;
  }

  /// Validate payout setup
  String? validatePayoutSetup() {
    if (!hasKYCDocuments) {
      return 'Иргэний үнэмлэхний зургийг заавал оруулна уу (урд болон ард тал)';
    }

    if (kycStatus == KYCStatus.rejected) {
      return 'KYC баталгаажуулалт татгалзсан: ${kycRejectionReason ?? 'Unknown reason'}';
    }

    if (kycStatus != KYCStatus.approved) {
      return 'KYC баталгаажуулалт хүлээгдэж буй эсвэл илгээгээгүй байна';
    }

    if (!hasCompleteBankDetails) {
      return 'Банкны дансны мэдээлэл бүрэн бөглөөгүй байна';
    }

    return null;
  }

  /// Get payout setup progress percentage
  double get payoutSetupProgress {
    int completedSteps = 0;
    int totalSteps = 2; // KYC + Bank + Completion

    if (hasKYCDocuments) completedSteps++;
    if (kycStatus == KYCStatus.approved) completedSteps++;
    if (hasCompleteBankDetails) completedSteps++;

    if (payoutSetupCompleted) completedSteps++;

    return (completedSteps / totalSteps) * 100;
  }

  /// Get bank display information
  String? get bankDisplayInfo {
    if (!hasCompleteBankDetails) return null;
    return '${selectedBank!.displayName} - $bankAccountNumber - $bankAccountHolderName';
  }

  // **NEW SUBSCRIPTION VALIDATION METHODS**

  /// Check if subscription is active
  bool get isSubscriptionActive {
    return subscriptionStatus == SubscriptionStatus.active;
  }

  /// Check if subscription is expired
  bool get isSubscriptionExpired {
    return subscriptionStatus == SubscriptionStatus.expired;
  }

  /// Check if subscription is in grace period
  bool get isInGracePeriod {
    return subscriptionStatus == SubscriptionStatus.gracePeriod;
  }

  /// Get days until subscription expires
  int? get daysUntilExpiry {
    if (subscriptionEndDate == null) return null;
    final now = DateTime.now();
    final expiry = subscriptionEndDate!;
    return expiry.difference(now).inDays;
  }

  /// Get subscription status display text
  String get subscriptionStatusDisplay {
    switch (subscriptionStatus) {
      case SubscriptionStatus.active:
        return 'Идэвхтэй';
      case SubscriptionStatus.expired:
        return 'Хугацаа дууссан';
      case SubscriptionStatus.pending:
        return 'Төлбөр хүлээгдэж буй';
      case SubscriptionStatus.cancelled:
        return 'Цуцлагдсан';
      case SubscriptionStatus.gracePeriod:
        return 'Хүлээлтийн хугацаа';
    }
  }

  /// Get next payment date display
  String? get nextPaymentDisplay {
    if (nextPaymentDate == null) return null;
    final now = DateTime.now();
    final nextPayment = nextPaymentDate!;
    final daysUntil = nextPayment.difference(now).inDays;

    if (daysUntil < 0) {
      return 'Хугацаа дууссан';
    } else if (daysUntil == 0) {
      return 'Өнөөдөр';
    } else if (daysUntil == 1) {
      return 'Маргааш';
    } else {
      return '$daysUntil хоногийн дараа';
    }
  }

  /// Validate subscription status
  String? validateSubscription() {
    if (subscriptionStatus == SubscriptionStatus.pending) {
      return 'Сарын төлбөр төлөөгүй байна';
    }

    if (subscriptionStatus == SubscriptionStatus.expired) {
      return 'Сарын төлбөрийн хугацаа дууссан';
    }

    if (subscriptionStatus == SubscriptionStatus.cancelled) {
      return 'Захиалга цуцлагдсан';
    }

    return null;
  }

  static DateTime _parseTimestamp(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    return DateTime.now();
  }
}
