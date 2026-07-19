import '../domain/catalog.dart';

sealed class CatalogEvent {
  const CatalogEvent();
}

final class CatalogStarted extends CatalogEvent {
  const CatalogStarted();
}

final class ProfessionalSaved extends CatalogEvent {
  const ProfessionalSaved({
    this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.commissionPercent,
    this.userId,
    this.enableEmployeeLogin = false,
    this.employeeLoginName = '',
    this.employeePassword = '',
  });
  final String? id;
  final String name;
  final String phone;
  final String email;
  final double commissionPercent;
  final String? userId;
  final bool enableEmployeeLogin;
  final String employeeLoginName;
  final String employeePassword;
}

final class ProfessionalActiveChanged extends CatalogEvent {
  const ProfessionalActiveChanged(this.id, this.active);
  final String id;
  final bool active;
}

final class ServiceSaved extends CatalogEvent {
  const ServiceSaved({
    this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.durationMinutes,
    required this.commissionType,
    required this.commissionValue,
  });
  final String? id;
  final String name;
  final String category;
  final double price;
  final int durationMinutes;
  final ServiceCommissionType commissionType;
  final double commissionValue;
}

final class ServiceActiveChanged extends CatalogEvent {
  const ServiceActiveChanged(this.id, this.active);
  final String id;
  final bool active;
}
