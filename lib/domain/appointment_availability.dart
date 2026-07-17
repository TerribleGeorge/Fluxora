import 'appointment.dart';

class AppointmentAvailability {
  const AppointmentAvailability._();

  static List<DateTime> availableStarts({
    required DateTime day,
    required int durationMinutes,
    required Iterable<Appointment> appointments,
    required String professionalId,
    int openHour = 8,
    int closeHour = 20,
    int slotIntervalMinutes = 15,
  }) {
    if (durationMinutes < 5 || professionalId.trim().isEmpty) {
      return const [];
    }
    final start = DateTime(day.year, day.month, day.day, openHour);
    final close = DateTime(day.year, day.month, day.day, closeHour);
    final duration = Duration(minutes: durationMinutes);
    final interval = Duration(minutes: slotIntervalMinutes);
    final result = <DateTime>[];
    var cursor = start;
    while (!cursor.add(duration).isAfter(close)) {
      final candidate = Appointment(
        id: 'candidate',
        businessId: '__availability__',
        professionalId: professionalId,
        serviceId: 'service',
        customerName: 'Cliente',
        customerPhone: '',
        startsAt: cursor,
        endsAt: cursor.add(duration),
        status: AppointmentStatus.scheduled,
        source: AppointmentSource.internal,
        createdAt: cursor,
      );
      final hasConflict = appointments.any(
        (item) =>
            item.active &&
            item.professionalId == professionalId &&
            cursor.isBefore(item.endsAt) &&
            cursor.add(duration).isAfter(item.startsAt),
      );
      if (!hasConflict && candidate.endsAt.day == candidate.startsAt.day) {
        result.add(cursor);
      }
      cursor = cursor.add(interval);
    }
    return result;
  }
}
