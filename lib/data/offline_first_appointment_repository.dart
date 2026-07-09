import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/appointment.dart';
import '../domain/appointment_repository.dart';
import 'local_appointment_repository.dart';

class OfflineFirstAppointmentRepository implements AppointmentRepository {
  OfflineFirstAppointmentRepository({
    required LocalAppointmentRepository local,
    required AppointmentRepository remote,
    required SharedPreferences preferences,
    required String businessId,
  }) : _local = local,
       _remote = remote,
       _preferences = preferences,
       _queueKey = 'fluxora.appointments_sync.$businessId.v1';

  final LocalAppointmentRepository _local;
  final AppointmentRepository _remote;
  final SharedPreferences _preferences;
  final String _queueKey;

  @override
  Future<List<Appointment>> getAppointments({
    required DateTime from,
    required DateTime to,
    String? professionalId,
  }) async {
    await _flush();
    final local = await _local.getAppointments(
      from: from,
      to: to,
      professionalId: professionalId,
    );
    try {
      final remote = await _remote.getAppointments(
        from: from,
        to: to,
        professionalId: professionalId,
      );
      final pending = _readQueue().map((item) => item.appointment.id).toSet();
      final merged = {for (final item in remote) item.id: item};
      for (final item in local) {
        if (pending.contains(item.id)) merged[item.id] = item;
      }
      final result = merged.values.toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      await _local.overwrite(result);
      return result;
    } on Exception {
      return local;
    }
  }

  @override
  Future<void> saveAppointment(Appointment appointment) async {
    await _local.saveAppointment(appointment);
    await _sendOrQueue(appointment);
  }

  @override
  Future<void> updateStatus(String id, AppointmentStatus status) async {
    await _local.updateStatus(id, status);
    final appointment = (await _local.getAppointments(
      from: DateTime(2000),
      to: DateTime(2100),
    )).firstWhere((item) => item.id == id);
    await _sendOrQueue(appointment);
  }

  Future<void> _sendOrQueue(Appointment appointment) async {
    try {
      await _remote.saveAppointment(appointment);
    } on Exception {
      final queue = _readQueue()
        ..removeWhere((item) => item.appointment.id == appointment.id)
        ..add(_PendingAppointment(appointment));
      await _writeQueue(queue);
    }
  }

  Future<void> _flush() async {
    final queue = _readQueue();
    if (queue.isEmpty) return;
    final remaining = <_PendingAppointment>[];
    for (var index = 0; index < queue.length; index++) {
      try {
        await _remote.saveAppointment(queue[index].appointment);
      } on Exception {
        remaining.addAll(queue.skip(index));
        break;
      }
    }
    await _writeQueue(remaining);
  }

  List<_PendingAppointment> _readQueue() {
    final raw = _preferences.getString(_queueKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map(
            (item) =>
                _PendingAppointment.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } on Object {
      return [];
    }
  }

  Future<void> _writeQueue(List<_PendingAppointment> queue) =>
      _preferences.setString(
        _queueKey,
        jsonEncode(queue.map((item) => item.toJson()).toList()),
      );
}

class _PendingAppointment {
  const _PendingAppointment(this.appointment);
  final Appointment appointment;
  Map<String, Object?> toJson() => appointment.toJson();
  factory _PendingAppointment.fromJson(Map<String, dynamic> json) =>
      _PendingAppointment(Appointment.fromJson(json));
}
