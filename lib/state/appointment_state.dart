import '../domain/appointment.dart';

enum AppointmentLoadStatus { initial, loading, success, failure }

class AppointmentState {
  const AppointmentState({
    this.status = AppointmentLoadStatus.initial,
    this.day,
    this.appointments = const [],
    this.visibleProfessionalId,
    this.message,
  });

  final AppointmentLoadStatus status;
  final DateTime? day;
  final List<Appointment> appointments;
  final String? visibleProfessionalId;
  final String? message;

  bool get loading => status == AppointmentLoadStatus.loading;

  DateTime get selectedDay {
    final now = DateTime.now();
    final value = day ?? now;
    return DateTime(value.year, value.month, value.day);
  }

  AppointmentState copyWith({
    AppointmentLoadStatus? status,
    DateTime? day,
    List<Appointment>? appointments,
    String? visibleProfessionalId,
    String? message,
  }) {
    return AppointmentState(
      status: status ?? this.status,
      day: day ?? this.day,
      appointments: appointments ?? this.appointments,
      visibleProfessionalId: visibleProfessionalId ?? this.visibleProfessionalId,
      message: message,
    );
  }
}
