import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/appointment.dart';
import '../domain/appointment_repository.dart';

class LocalAppointmentRepository implements AppointmentRepository {
  LocalAppointmentRepository(this._preferences, String businessId)
    : _key = 'fluxora.appointments.$businessId.v1';

  final SharedPreferences _preferences;
  final String _key;

  @override
  Future<List<Appointment>> getAppointments({
    required DateTime from,
    required DateTime to,
    String? professionalId,
  }) async {
    final raw = _preferences.getString(_key);
    if (raw == null) return [];
    try {
      final items = (jsonDecode(raw) as List<dynamic>)
          .map((item) => Appointment.fromJson(item as Map<String, dynamic>))
          .where(
            (item) =>
                item.startsAt.isBefore(to) &&
                item.endsAt.isAfter(from) &&
                (professionalId == null ||
                    item.professionalId == professionalId),
          )
          .toList();
      items.sort((a, b) => a.startsAt.compareTo(b.startsAt));
      return items;
    } on Object {
      return [];
    }
  }

  @override
  Future<void> saveAppointment(Appointment appointment) async {
    final items = await _all();
    final index = items.indexWhere((item) => item.id == appointment.id);
    index < 0 ? items.add(appointment) : items[index] = appointment;
    await overwrite(items);
  }

  @override
  Future<void> updateStatus(String id, AppointmentStatus status) async {
    final items = await _all();
    final index = items.indexWhere((item) => item.id == id);
    if (index >= 0) {
      final now = DateTime.now();
      items[index] = items[index].copyWith(
        status: status,
        cancelledAt: status == AppointmentStatus.cancelled ? now : null,
        updatedAt: now,
      );
    }
    await overwrite(items);
  }

  Future<List<Appointment>> _all() async {
    final raw = _preferences.getString(_key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((item) => Appointment.fromJson(item as Map<String, dynamic>))
          .toList();
    } on Object {
      return [];
    }
  }

  Future<void> overwrite(List<Appointment> items) {
    items.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return _preferences.setString(
      _key,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }
}
