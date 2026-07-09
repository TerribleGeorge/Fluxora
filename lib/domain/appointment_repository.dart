import 'appointment.dart';

abstract interface class AppointmentRepository {
  Future<List<Appointment>> getAppointments({
    required DateTime from,
    required DateTime to,
    String? professionalId,
  });

  Future<void> saveAppointment(Appointment appointment);

  Future<void> updateStatus(String id, AppointmentStatus status);
}
