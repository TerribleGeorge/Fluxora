enum BusinessType {
  barbershop,
  beautySalon,
  nailStudio,
  browAndLashStudio,
  makeupStudio,
  spa,
  aestheticClinic,
  otherBeauty,
}

enum MembershipRole { owner, manager, professional }

enum BusinessPermission {
  viewDashboard,
  manageBusiness,
  manageMembers,
  manageServices,
  manageAppointments,
  manageCash,
  manageExpenses,
  manageCommissions,
  viewAllReports,
  viewOwnSchedule,
  viewOwnCommissions,
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final DateTime createdAt;

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'createdAt': createdAt.toIso8601String(),
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    final id = (json['id'] as String? ?? '').trim();
    final name = (json['name'] as String? ?? '').trim();
    final email = (json['email'] as String? ?? '').trim();
    if (id.isEmpty || name.isEmpty || email.isEmpty || createdAt == null) {
      throw const FormatException('Perfil de usuário inválido.');
    }
    return UserProfile(id: id, name: name, email: email, createdAt: createdAt);
  }
}

class BeautyBusiness {
  const BeautyBusiness({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
    this.document = '',
    this.phone = '',
  });

  final String id;
  final String name;
  final BusinessType type;
  final DateTime createdAt;
  final String document;
  final String phone;

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'createdAt': createdAt.toIso8601String(),
    'document': document,
    'phone': phone,
  };

  factory BeautyBusiness.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as String? ?? '').trim();
    final name = (json['name'] as String? ?? '').trim();
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    final typeName = json['type'] as String?;
    if (id.isEmpty || name.isEmpty || createdAt == null || typeName == null) {
      throw const FormatException('Estabelecimento inválido.');
    }
    final type = BusinessType.values.where((item) => item.name == typeName);
    if (type.isEmpty) {
      throw const FormatException('Tipo de estabelecimento inválido.');
    }
    return BeautyBusiness(
      id: id,
      name: name,
      type: type.single,
      createdAt: createdAt,
      document: (json['document'] as String? ?? '').trim(),
      phone: (json['phone'] as String? ?? '').trim(),
    );
  }
}

class BusinessMembership {
  const BusinessMembership({
    required this.id,
    required this.businessId,
    required this.userId,
    required this.role,
    required this.createdAt,
    this.active = true,
  });

  final String id;
  final String businessId;
  final String userId;
  final MembershipRole role;
  final DateTime createdAt;
  final bool active;

  Set<BusinessPermission> get permissions => switch (role) {
    MembershipRole.owner => BusinessPermission.values.toSet(),
    MembershipRole.manager => {
      BusinessPermission.viewDashboard,
      BusinessPermission.manageMembers,
      BusinessPermission.manageServices,
      BusinessPermission.manageAppointments,
      BusinessPermission.manageCash,
      BusinessPermission.manageExpenses,
      BusinessPermission.manageCommissions,
      BusinessPermission.viewAllReports,
      BusinessPermission.viewOwnSchedule,
      BusinessPermission.viewOwnCommissions,
    },
    MembershipRole.professional => {
      BusinessPermission.viewOwnSchedule,
      BusinessPermission.viewOwnCommissions,
    },
  };

  bool can(BusinessPermission permission) {
    return active && permissions.contains(permission);
  }

  Map<String, Object> toJson() => {
    'id': id,
    'businessId': businessId,
    'userId': userId,
    'role': role.name,
    'createdAt': createdAt.toIso8601String(),
    'active': active,
  };

  factory BusinessMembership.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as String? ?? '').trim();
    final businessId = (json['businessId'] as String? ?? '').trim();
    final userId = (json['userId'] as String? ?? '').trim();
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    final roleName = json['role'] as String?;
    final roles = MembershipRole.values.where((item) => item.name == roleName);
    if (id.isEmpty ||
        businessId.isEmpty ||
        userId.isEmpty ||
        createdAt == null ||
        roles.isEmpty) {
      throw const FormatException('Vínculo com estabelecimento inválido.');
    }
    return BusinessMembership(
      id: id,
      businessId: businessId,
      userId: userId,
      role: roles.single,
      createdAt: createdAt,
      active: json['active'] as bool? ?? true,
    );
  }
}
