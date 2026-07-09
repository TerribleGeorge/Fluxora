import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/appointment.dart';
import '../domain/appointment_repository.dart';
import '../domain/id_generator.dart';
import 'appointment_event.dart';
import 'appointment_state.dart';

class AppointmentBloc extends Bloc<AppointmentEvent, AppointmentState> {
  AppointmentBloc(
    this._repository, {
    required this.businessId,
    required this.userId,
    String? visibleProfessionalId,
  }) : super(AppointmentState(visibleProfessionalId: visibleProfessionalId)) {
    on<AppointmentsStarted>(_onStarted);
    on<AppointmentDayChanged>(_onDayChanged);
    on<AppointmentCreated>(_onCreated);
    on<AppointmentStatusChanged>(_onStatusChanged);
  }

  final AppointmentRepository _repository;
  final String businessId;
  final String userId;

  Future<void> _onStarted(
    AppointmentsStarted event,
    Emitter<AppointmentState> emit,
  ) async {
    emit(state.copyWith(day: event.day ?? DateTime.now()));
    await _reload(emit);
  }

  Future<void> _onDayChanged(
    AppointmentDayChanged event,
    Emitter<AppointmentState> emit,
  ) async {
    emit(state.copyWith(day: event.day));
    await _reload(emit);
  }

  Future<void> _onCreated(
    AppointmentCreated event,
    Emitter<AppointmentState> emit,
  ) async {
    final now = DateTime.now();
    final appointment = Appointment(
      id: createUuid(),
      businessId: businessId,
      professionalId: event.professionalId,
      serviceId: event.serviceId,
      customerName: event.customerName.trim(),
      customerPhone: event.customerPhone.trim(),
      startsAt: event.startsAt,
      endsAt: event.startsAt.add(Duration(minutes: event.durationMinutes)),
      status: AppointmentStatus.scheduled,
      source: event.source,
      notes: event.notes.trim(),
      createdAt: now,
    );
    final validation = AppointmentValidation.validate(appointment);
    if (validation != null) {
      _failure(emit, validation);
      return;
    }
    final from = _dayStart(appointment.startsAt);
    final to = from.add(const Duration(days: 1));
    final appointments = await _repository.getAppointments(from: from, to: to);
    if (AppointmentValidation.hasConflict(appointment, appointments)) {
      _failure(emit, 'Este profissional já tem atendimento nesse horário.');
      return;
    }
    try {
      await _repository.saveAppointment(appointment);
      emit(state.copyWith(day: appointment.startsAt));
      await _reload(emit);
    } on Exception {
      _failure(emit, 'Não foi possível salvar o agendamento.');
    }
  }

  Future<void> _onStatusChanged(
    AppointmentStatusChanged event,
    Emitter<AppointmentState> emit,
  ) async {
    try {
      await _repository.updateStatus(event.id, event.status);
      await _reload(emit);
    } on Exception {
      _failure(emit, 'Não foi possível atualizar o agendamento.');
    }
  }

  Future<void> _reload(Emitter<AppointmentState> emit) async {
    final from = state.selectedDay;
    final to = from.add(const Duration(days: 1));
    emit(state.copyWith(status: AppointmentLoadStatus.loading, day: from));
    try {
      emit(
        state.copyWith(
          status: AppointmentLoadStatus.success,
          day: from,
          appointments: await _repository.getAppointments(
            from: from,
            to: to,
            professionalId: state.visibleProfessionalId,
          ),
        ),
      );
    } on Exception {
      _failure(emit, 'Não foi possível carregar a agenda.');
    }
  }

  void _failure(Emitter<AppointmentState> emit, String message) {
    emit(
      state.copyWith(
        status: AppointmentLoadStatus.failure,
        appointments: state.appointments,
        message: message,
      ),
    );
  }

  DateTime _dayStart(DateTime value) => DateTime(value.year, value.month, value.day);
}
