import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/domain/appointment.dart';
import 'package:fluxora/domain/appointment_availability.dart';

void main() {
  test('remove horários que conflitam com agendamento existente', () {
    final day = DateTime(2026, 7, 10);
    final startsAt = DateTime(2026, 7, 10, 9);
    final slots = AppointmentAvailability.availableStarts(
      day: day,
      durationMinutes: 30,
      professionalId: 'professional-1',
      appointments: [
        Appointment(
          id: 'appointment-1',
          businessId: 'business-1',
          professionalId: 'professional-1',
          serviceId: 'service-1',
          customerName: 'Lucas',
          customerPhone: '',
          startsAt: startsAt,
          endsAt: startsAt.add(const Duration(minutes: 30)),
          status: AppointmentStatus.scheduled,
          source: AppointmentSource.internal,
          createdAt: day,
        ),
      ],
      openHour: 8,
      closeHour: 10,
      slotIntervalMinutes: 15,
    );

    expect(slots, isNot(contains(DateTime(2026, 7, 10, 8, 45))));
    expect(slots, isNot(contains(DateTime(2026, 7, 10, 9))));
    expect(slots, contains(DateTime(2026, 7, 10, 9, 30)));
  });
}
