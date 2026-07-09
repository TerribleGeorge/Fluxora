import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/domain/appointment.dart';
import 'package:fluxora/domain/appointment_repository.dart';
import 'package:fluxora/state/appointment_bloc.dart';
import 'package:fluxora/state/appointment_event.dart';
import 'package:fluxora/state/appointment_state.dart';

void main() {
  test('cria agendamento válido', () async {
    final repository = _FakeAppointmentRepository();
    final bloc = AppointmentBloc(
      repository,
      businessId: 'business-1',
      userId: 'user-1',
    );
    addTearDown(bloc.close);

    bloc.add(
      AppointmentCreated(
        professionalId: 'professional-1',
        serviceId: 'service-1',
        customerName: 'Lucas',
        customerPhone: '11999999999',
        startsAt: DateTime(2026, 7, 10, 9),
        durationMinutes: 30,
      ),
    );

    final state = await bloc.stream.firstWhere(
      (item) => item.status == AppointmentLoadStatus.success,
    );
    expect(state.appointments.single.customerName, 'Lucas');
  });

  test('bloqueia conflito para o mesmo profissional', () async {
    final repository = _FakeAppointmentRepository();
    final existingStart = DateTime(2026, 7, 10, 9);
    repository.items.add(
      Appointment(
        id: 'appointment-1',
        businessId: 'business-1',
        professionalId: 'professional-1',
        serviceId: 'service-1',
        customerName: 'Lucas',
        customerPhone: '',
        startsAt: existingStart,
        endsAt: existingStart.add(const Duration(minutes: 30)),
        status: AppointmentStatus.scheduled,
        source: AppointmentSource.internal,
        createdAt: DateTime(2026, 7, 9),
      ),
    );
    final bloc = AppointmentBloc(
      repository,
      businessId: 'business-1',
      userId: 'user-1',
    );
    addTearDown(bloc.close);

    bloc.add(
      AppointmentCreated(
        professionalId: 'professional-1',
        serviceId: 'service-1',
        customerName: 'Maria',
        customerPhone: '',
        startsAt: DateTime(2026, 7, 10, 9, 15),
        durationMinutes: 30,
      ),
    );

    final state = await bloc.stream.firstWhere(
      (item) => item.status == AppointmentLoadStatus.failure,
    );
    expect(state.message, contains('horário'));
    expect(repository.items.length, 1);
  });
}

class _FakeAppointmentRepository implements AppointmentRepository {
  final items = <Appointment>[];

  @override
  Future<List<Appointment>> getAppointments({
    required DateTime from,
    required DateTime to,
    String? professionalId,
  }) async {
    return items
        .where(
          (item) =>
              item.startsAt.isBefore(to) &&
              item.endsAt.isAfter(from) &&
              (professionalId == null || item.professionalId == professionalId),
        )
        .toList();
  }

  @override
  Future<void> saveAppointment(Appointment appointment) async {
    items.add(appointment);
  }

  @override
  Future<void> updateStatus(String id, AppointmentStatus status) async {
    final index = items.indexWhere((item) => item.id == id);
    if (index >= 0) items[index] = items[index].copyWith(status: status);
  }
}
