import '../domain/appointment.dart';

sealed class AppointmentEvent {
  const AppointmentEvent();
}

final class AppointmentsStarted extends AppointmentEvent {
  const AppointmentsStarted({this.day});
  final DateTime? day;
}

final class AppointmentDayChanged extends AppointmentEvent {
  const AppointmentDayChanged(this.day);
  final DateTime day;
}

final class AppointmentCreated extends AppointmentEvent {
  const AppointmentCreated({
    required this.professionalId,
    required this.serviceId,
    required this.customerName,
    required this.customerPhone,
    required this.startsAt,
    required this.durationMinutes,
    this.notes = '',
    this.source = AppointmentSource.internal,
  });

  final String professionalId;
  final String serviceId;
  final String customerName;
  final String customerPhone;
  final DateTime startsAt;
  final int durationMinutes;
  final String notes;
  final AppointmentSource source;
}

final class AppointmentStatusChanged extends AppointmentEvent {
  const AppointmentStatusChanged(this.id, this.status);
  final String id;
  final AppointmentStatus status;
}
