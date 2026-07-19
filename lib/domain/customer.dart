enum CustomerLoyaltyTier { newCustomer, standard, gold, premium }

extension CustomerLoyaltyTierStorage on CustomerLoyaltyTier {
  String get storageName => switch (this) {
    CustomerLoyaltyTier.newCustomer => 'new',
    CustomerLoyaltyTier.standard => 'standard',
    CustomerLoyaltyTier.gold => 'gold',
    CustomerLoyaltyTier.premium => 'premium',
  };

  String get label => switch (this) {
    CustomerLoyaltyTier.newCustomer => 'Cliente novo',
    CustomerLoyaltyTier.standard => 'Standard',
    CustomerLoyaltyTier.gold => 'Gold',
    CustomerLoyaltyTier.premium => 'Premium',
  };

  static CustomerLoyaltyTier fromStorage(String? value) => switch (value) {
    'standard' => CustomerLoyaltyTier.standard,
    'gold' => CustomerLoyaltyTier.gold,
    'premium' => CustomerLoyaltyTier.premium,
    _ => CustomerLoyaltyTier.newCustomer,
  };
}

class LoyaltySettings {
  const LoyaltySettings({
    required this.businessId,
    this.enabled = false,
    this.standardDiscountPercent = 0,
    this.goldDiscountPercent = 0,
    this.premiumDiscountPercent = 0,
    this.inactiveAfterDays = 90,
  });

  final String businessId;
  final bool enabled;
  final double standardDiscountPercent;
  final double goldDiscountPercent;
  final double premiumDiscountPercent;
  final int inactiveAfterDays;

  double discountFor(CustomerLoyaltyTier tier) {
    if (!enabled) return 0;
    return switch (tier) {
      CustomerLoyaltyTier.standard => standardDiscountPercent,
      CustomerLoyaltyTier.gold => goldDiscountPercent,
      CustomerLoyaltyTier.premium => premiumDiscountPercent,
      CustomerLoyaltyTier.newCustomer => 0,
    };
  }

  Map<String, Object> toJson() => {
    'businessId': businessId,
    'enabled': enabled,
    'standardDiscountPercent': standardDiscountPercent,
    'goldDiscountPercent': goldDiscountPercent,
    'premiumDiscountPercent': premiumDiscountPercent,
    'inactiveAfterDays': inactiveAfterDays,
  };

  factory LoyaltySettings.fromJson(Map<String, dynamic> json) =>
      LoyaltySettings(
        businessId: json['businessId'] as String,
        enabled: json['enabled'] as bool? ?? false,
        standardDiscountPercent:
            (json['standardDiscountPercent'] as num?)?.toDouble() ?? 0,
        goldDiscountPercent:
            (json['goldDiscountPercent'] as num?)?.toDouble() ?? 0,
        premiumDiscountPercent:
            (json['premiumDiscountPercent'] as num?)?.toDouble() ?? 0,
        inactiveAfterDays: json['inactiveAfterDays'] as int? ?? 90,
      );
}

class Customer {
  const Customer({
    required this.id,
    required this.businessId,
    required this.name,
    required this.createdAt,
    this.email = '',
    this.phone = '',
    this.loyaltyTier = CustomerLoyaltyTier.newCustomer,
    this.manualTierOverride,
    this.manualTierReason = '',
    this.relationshipStartedAt,
    this.lastCompletedAt,
    this.completedVisitsCount = 0,
    this.scheduledAppointmentsCount = 0,
    this.nextScheduledAt,
    this.updatedAt,
  });

  final String id;
  final String businessId;
  final String name;
  final String email;
  final String phone;
  final CustomerLoyaltyTier loyaltyTier;
  final CustomerLoyaltyTier? manualTierOverride;
  final String manualTierReason;
  final DateTime? relationshipStartedAt;
  final DateTime? lastCompletedAt;
  final int completedVisitsCount;
  final int scheduledAppointmentsCount;
  final DateTime? nextScheduledAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  bool get hasManualLoyalty => manualTierOverride != null;

  bool get hasHistory =>
      completedVisitsCount > 0 ||
      scheduledAppointmentsCount > 0 ||
      lastCompletedAt != null ||
      nextScheduledAt != null;

  CustomerLoyaltyTier effectiveTier({
    required LoyaltySettings settings,
    required DateTime now,
  }) {
    if (!settings.enabled) return CustomerLoyaltyTier.newCustomer;
    if (manualTierOverride != null) return manualTierOverride!;
    if (lastCompletedAt == null ||
        now.difference(lastCompletedAt!).inDays > settings.inactiveAfterDays) {
      return CustomerLoyaltyTier.newCustomer;
    }
    final startedAt = relationshipStartedAt ?? createdAt;
    final activeMonths = now.difference(startedAt).inDays / 30;
    if (activeMonths >= 12) return CustomerLoyaltyTier.premium;
    if (activeMonths >= 6) return CustomerLoyaltyTier.gold;
    if (activeMonths >= 3) return CustomerLoyaltyTier.standard;
    return CustomerLoyaltyTier.newCustomer;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'businessId': businessId,
    'name': name,
    'email': email,
    'phone': phone,
    'loyaltyTier': loyaltyTier.storageName,
    'manualTierOverride': manualTierOverride?.storageName,
    'manualTierReason': manualTierReason,
    'relationshipStartedAt': relationshipStartedAt?.toIso8601String(),
    'lastCompletedAt': lastCompletedAt?.toIso8601String(),
    'completedVisitsCount': completedVisitsCount,
    'scheduledAppointmentsCount': scheduledAppointmentsCount,
    'nextScheduledAt': nextScheduledAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: json['id'] as String,
    businessId: json['businessId'] as String,
    name: json['name'] as String,
    email: json['email'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    loyaltyTier: CustomerLoyaltyTierStorage.fromStorage(
      json['loyaltyTier'] as String?,
    ),
    manualTierOverride: json['manualTierOverride'] == null
        ? null
        : CustomerLoyaltyTierStorage.fromStorage(
            json['manualTierOverride'] as String?,
          ),
    manualTierReason: json['manualTierReason'] as String? ?? '',
    relationshipStartedAt: DateTime.tryParse(
      json['relationshipStartedAt'] as String? ?? '',
    ),
    lastCompletedAt: DateTime.tryParse(
      json['lastCompletedAt'] as String? ?? '',
    ),
    completedVisitsCount: json['completedVisitsCount'] as int? ?? 0,
    scheduledAppointmentsCount: json['scheduledAppointmentsCount'] as int? ?? 0,
    nextScheduledAt: DateTime.tryParse(
      json['nextScheduledAt'] as String? ?? '',
    ),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
  );
}

class BookingPriceQuote {
  const BookingPriceQuote({
    required this.customerId,
    required this.tier,
    required this.basePrice,
    required this.discountPercent,
    required this.discountAmount,
    required this.finalPrice,
  });

  final String customerId;
  final CustomerLoyaltyTier tier;
  final double basePrice;
  final double discountPercent;
  final double discountAmount;
  final double finalPrice;

  Map<String, Object> toJson() => {
    'customerId': customerId,
    'tier': tier.storageName,
    'basePrice': basePrice,
    'discountPercent': discountPercent,
    'discountAmount': discountAmount,
    'finalPrice': finalPrice,
  };

  factory BookingPriceQuote.fromJson(Map<String, dynamic> json) =>
      BookingPriceQuote(
        customerId: json['customerId'] as String,
        tier: CustomerLoyaltyTierStorage.fromStorage(json['tier'] as String?),
        basePrice: (json['basePrice'] as num).toDouble(),
        discountPercent: (json['discountPercent'] as num).toDouble(),
        discountAmount: (json['discountAmount'] as num).toDouble(),
        finalPrice: (json['finalPrice'] as num).toDouble(),
      );
}
