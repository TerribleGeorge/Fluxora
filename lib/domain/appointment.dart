import 'customer.dart';

enum AppointmentStatus { scheduled, confirmed, completed, cancelled, noShow }

enum AppointmentSource { internal, publicBooking, whatsapp, imported }

class Appointment {
  const Appointment({
    required this.id,
    required this.businessId,
    required this.professionalId,
    required this.serviceId,
    required this.customerName,
    required this.customerPhone,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.source,
    required this.createdAt,
    this.customerId,
    this.customerEmail = '',
    this.loyaltyTierApplied = CustomerLoyaltyTier.newCustomer,
    this.serviceBasePrice = 0,
    this.discountPercentApplied = 0,
    this.discountAmount = 0,
    this.serviceFinalPrice = 0,
    this.pricingLockedAt,
    this.notes = '',
    this.cancelledAt,
    this.updatedAt,
  });

  final String id;
  final String businessId;
  final String professionalId;
  final String serviceId;
  final String? customerId;
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final DateTime startsAt;
  final DateTime endsAt;
  final AppointmentStatus status;
  final AppointmentSource source;
  final CustomerLoyaltyTier loyaltyTierApplied;
  final double serviceBasePrice;
  final double discountPercentApplied;
  final double discountAmount;
  final double serviceFinalPrice;
  final DateTime? pricingLockedAt;
  final String notes;
  final DateTime createdAt;
  final DateTime? cancelledAt;
  final DateTime? updatedAt;

  Duration get duration => endsAt.difference(startsAt);

  bool get active =>
      status != AppointmentStatus.cancelled &&
      status != AppointmentStatus.noShow;

  bool overlaps(Appointment other) {
    if (!active || !other.active) return false;
    if (businessId != other.businessId ||
        professionalId != other.professionalId) {
      return false;
    }
    return startsAt.isBefore(other.endsAt) && endsAt.isAfter(other.startsAt);
  }

  Appointment copyWith({
    AppointmentStatus? status,
    DateTime? cancelledAt,
    DateTime? updatedAt,
    String? customerId,
    CustomerLoyaltyTier? loyaltyTierApplied,
    double? serviceBasePrice,
    double? discountPercentApplied,
    double? discountAmount,
    double? serviceFinalPrice,
    DateTime? pricingLockedAt,
  }) {
    return Appointment(
      id: id,
      businessId: businessId,
      professionalId: professionalId,
      serviceId: serviceId,
      customerId: customerId ?? this.customerId,
      customerName: customerName,
      customerEmail: customerEmail,
      customerPhone: customerPhone,
      startsAt: startsAt,
      endsAt: endsAt,
      status: status ?? this.status,
      source: source,
      loyaltyTierApplied: loyaltyTierApplied ?? this.loyaltyTierApplied,
      serviceBasePrice: serviceBasePrice ?? this.serviceBasePrice,
      discountPercentApplied:
          discountPercentApplied ?? this.discountPercentApplied,
      discountAmount: discountAmount ?? this.discountAmount,
      serviceFinalPrice: serviceFinalPrice ?? this.serviceFinalPrice,
      pricingLockedAt: pricingLockedAt ?? this.pricingLockedAt,
      notes: notes,
      createdAt: createdAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'businessId': businessId,
    'professionalId': professionalId,
    'serviceId': serviceId,
    'customerId': customerId,
    'customerName': customerName,
    'customerEmail': customerEmail,
    'customerPhone': customerPhone,
    'startsAt': startsAt.toIso8601String(),
    'endsAt': endsAt.toIso8601String(),
    'status': status.name,
    'source': source.name,
    'loyaltyTierApplied': loyaltyTierApplied.storageName,
    'serviceBasePrice': serviceBasePrice,
    'discountPercentApplied': discountPercentApplied,
    'discountAmount': discountAmount,
    'serviceFinalPrice': serviceFinalPrice,
    'pricingLockedAt': pricingLockedAt?.toIso8601String(),
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'cancelledAt': cancelledAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'] as String,
      businessId: json['businessId'] as String,
      professionalId: json['professionalId'] as String,
      serviceId: json['serviceId'] as String,
      customerId: json['customerId'] as String?,
      customerName: json['customerName'] as String,
      customerEmail: json['customerEmail'] as String? ?? '',
      customerPhone: json['customerPhone'] as String? ?? '',
      startsAt: DateTime.parse(json['startsAt'] as String),
      endsAt: DateTime.parse(json['endsAt'] as String),
      status: AppointmentStatus.values.byName(
        json['status'] as String? ?? AppointmentStatus.scheduled.name,
      ),
      source: AppointmentSource.values.byName(
        json['source'] as String? ?? AppointmentSource.internal.name,
      ),
      loyaltyTierApplied: CustomerLoyaltyTierStorage.fromStorage(
        json['loyaltyTierApplied'] as String?,
      ),
      serviceBasePrice: (json['serviceBasePrice'] as num?)?.toDouble() ?? 0,
      discountPercentApplied:
          (json['discountPercentApplied'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0,
      serviceFinalPrice: (json['serviceFinalPrice'] as num?)?.toDouble() ?? 0,
      pricingLockedAt: DateTime.tryParse(
        json['pricingLockedAt'] as String? ?? '',
      ),
      notes: json['notes'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      cancelledAt: DateTime.tryParse(json['cancelledAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}

class AppointmentValidation {
  const AppointmentValidation._();

  static String? validate(Appointment appointment) {
    if (appointment.businessId.trim().isEmpty ||
        appointment.professionalId.trim().isEmpty ||
        appointment.serviceId.trim().isEmpty) {
      return 'Escolha estabelecimento, profissional e serviço.';
    }
    if (appointment.customerName.trim().length < 2) {
      return 'Informe o nome do cliente.';
    }
    if (!appointment.endsAt.isAfter(appointment.startsAt)) {
      return 'O horário final precisa ser depois do início.';
    }
    if (appointment.duration.inMinutes < 5) {
      return 'O atendimento precisa ter pelo menos 5 minutos.';
    }
    return null;
  }

  static bool hasConflict(Appointment appointment, Iterable<Appointment> all) {
    return all.any(
      (other) => other.id != appointment.id && appointment.overlaps(other),
    );
  }
}
