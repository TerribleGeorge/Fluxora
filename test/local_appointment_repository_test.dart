import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/data/local_appointment_repository.dart';
import 'package:fluxora/domain/appointment.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('persiste e filtra agendamentos por período', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = LocalAppointmentRepository(
      await SharedPreferences.getInstance(),
      'business-1',
    );
    final start = DateTime(2026, 7, 10, 9);
    await repository.saveAppointment(
      Appointment(
        id: 'appointment-1',
        businessId: 'business-1',
        professionalId: 'professional-1',
        serviceId: 'service-1',
        customerName: 'Lucas',
        customerPhone: '11999999999',
        startsAt: start,
        endsAt: start.add(const Duration(minutes: 30)),
        status: AppointmentStatus.scheduled,
        source: AppointmentSource.internal,
        createdAt: DateTime(2026, 7, 9),
      ),
    );

    final items = await repository.getAppointments(
      from: DateTime(2026, 7, 10),
      to: DateTime(2026, 7, 11),
    );

    expect(items.single.customerName, 'Lucas');
  });
}
