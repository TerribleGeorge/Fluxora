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
    this.notes = '',
    this.cancelledAt,
    this.updatedAt,
  });

  final String id;
  final String businessId;
  final String professionalId;
  final String serviceId;
  final String customerName;
  final String customerPhone;
  final DateTime startsAt;
  final DateTime endsAt;
  final AppointmentStatus status;
  final AppointmentSource source;
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
  }) {
    return Appointment(
      id: id,
      businessId: businessId,
      professionalId: professionalId,
      serviceId: serviceId,
      customerName: customerName,
      customerPhone: customerPhone,
      startsAt: startsAt,
      endsAt: endsAt,
      status: status ?? this.status,
      source: source,
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
    'customerName': customerName,
    'customerPhone': customerPhone,
    'startsAt': startsAt.toIso8601String(),
    'endsAt': endsAt.toIso8601String(),
    'status': status.name,
    'source': source.name,
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
      customerName: json['customerName'] as String,
      customerPhone: json['customerPhone'] as String? ?? '',
      startsAt: DateTime.parse(json['startsAt'] as String),
      endsAt: DateTime.parse(json['endsAt'] as String),
      status: AppointmentStatus.values.byName(
        json['status'] as String? ?? AppointmentStatus.scheduled.name,
      ),
      source: AppointmentSource.values.byName(
        json['source'] as String? ?? AppointmentSource.internal.name,
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
