enum ServiceCommissionType { businessDefault, percentage, fixedAmount }

class Professional {
  const Professional({
    required this.id,
    required this.businessId,
    required this.name,
    required this.createdAt,
    this.phone = '',
    this.email = '',
    this.defaultCommissionPercent = 0,
    this.active = true,
    this.userId,
    this.loginEnabled = false,
    this.loginName = '',
    this.updatedAt,
  });

  final String id;
  final String businessId;
  final String name;
  final String phone;
  final String email;
  final double defaultCommissionPercent;
  final bool active;
  final String? userId;
  final bool loginEnabled;
  final String loginName;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Professional copyWith({bool? active}) => Professional(
    id: id,
    businessId: businessId,
    name: name,
    phone: phone,
    email: email,
    defaultCommissionPercent: defaultCommissionPercent,
    active: active ?? this.active,
    userId: userId,
    loginEnabled: loginEnabled,
    loginName: loginName,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'businessId': businessId,
    'name': name,
    'phone': phone,
    'email': email,
    'defaultCommissionPercent': defaultCommissionPercent,
    'active': active,
    'userId': userId,
    'loginEnabled': loginEnabled,
    'loginName': loginName,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory Professional.fromJson(Map<String, dynamic> json) => Professional(
    id: json['id'] as String,
    businessId: json['businessId'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String? ?? '',
    email: json['email'] as String? ?? '',
    defaultCommissionPercent:
        (json['defaultCommissionPercent'] as num?)?.toDouble() ?? 0,
    active: json['active'] as bool? ?? true,
    userId: json['userId'] as String?,
    loginEnabled: json['loginEnabled'] as bool? ?? false,
    loginName: json['loginName'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
  );
}

class BeautyService {
  const BeautyService({
    required this.id,
    required this.businessId,
    required this.name,
    required this.price,
    required this.durationMinutes,
    required this.createdAt,
    this.category = 'Serviços',
    this.commissionType = ServiceCommissionType.businessDefault,
    this.commissionValue = 0,
    this.active = true,
    this.updatedAt,
  });

  final String id;
  final String businessId;
  final String name;
  final String category;
  final double price;
  final int durationMinutes;
  final ServiceCommissionType commissionType;
  final double commissionValue;
  final bool active;
  final DateTime createdAt;
  final DateTime? updatedAt;

  BeautyService copyWith({bool? active}) => BeautyService(
    id: id,
    businessId: businessId,
    name: name,
    category: category,
    price: price,
    durationMinutes: durationMinutes,
    commissionType: commissionType,
    commissionValue: commissionValue,
    active: active ?? this.active,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'businessId': businessId,
    'name': name,
    'category': category,
    'price': price,
    'durationMinutes': durationMinutes,
    'commissionType': commissionType.name,
    'commissionValue': commissionValue,
    'active': active,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory BeautyService.fromJson(Map<String, dynamic> json) => BeautyService(
    id: json['id'] as String,
    businessId: json['businessId'] as String,
    name: json['name'] as String,
    category: json['category'] as String? ?? 'Serviços',
    price: (json['price'] as num).toDouble(),
    durationMinutes: json['durationMinutes'] as int,
    commissionType: ServiceCommissionType.values.byName(
      json['commissionType'] as String? ?? 'businessDefault',
    ),
    commissionValue: (json['commissionValue'] as num?)?.toDouble() ?? 0,
    active: json['active'] as bool? ?? true,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
  );
}
