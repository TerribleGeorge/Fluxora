import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/domain/appointment.dart';

void main() {
  Appointment appointment({
    String id = 'appointment-1',
    String professionalId = 'professional-1',
    DateTime? startsAt,
    DateTime? endsAt,
    AppointmentStatus status = AppointmentStatus.scheduled,
  }) {
    final start = startsAt ?? DateTime(2026, 7, 10, 9);
    return Appointment(
      id: id,
      businessId: 'business-1',
      professionalId: professionalId,
      serviceId: 'service-1',
      customerName: 'Lucas',
      customerPhone: '11999999999',
      startsAt: start,
      endsAt: endsAt ?? start.add(const Duration(minutes: 30)),
      status: status,
      source: AppointmentSource.internal,
      createdAt: DateTime(2026, 7, 9),
    );
  }

  test('detecta conflito de horário para o mesmo profissional', () {
    final existing = appointment();
    final candidate = appointment(
      id: 'appointment-2',
      startsAt: DateTime(2026, 7, 10, 9, 15),
      endsAt: DateTime(2026, 7, 10, 9, 45),
    );

    expect(AppointmentValidation.hasConflict(candidate, [existing]), isTrue);
  });

  test('não bloqueia profissionais diferentes no mesmo horário', () {
    final existing = appointment();
    final candidate = appointment(
      id: 'appointment-2',
      professionalId: 'professional-2',
      startsAt: DateTime(2026, 7, 10, 9, 15),
      endsAt: DateTime(2026, 7, 10, 9, 45),
    );

    expect(AppointmentValidation.hasConflict(candidate, [existing]), isFalse);
  });

  test('cancelados não bloqueiam a agenda', () {
    final existing = appointment(status: AppointmentStatus.cancelled);
    final candidate = appointment(
      id: 'appointment-2',
      startsAt: DateTime(2026, 7, 10, 9, 15),
      endsAt: DateTime(2026, 7, 10, 9, 45),
    );

    expect(AppointmentValidation.hasConflict(candidate, [existing]), isFalse);
  });

  test('valida dados mínimos do agendamento', () {
    final invalid = appointment(
      startsAt: DateTime(2026, 7, 10, 9),
      endsAt: DateTime(2026, 7, 10, 9, 1),
    );

    expect(AppointmentValidation.validate(invalid), isNotNull);
  });
}
