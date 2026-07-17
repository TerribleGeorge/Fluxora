import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/domain/automation_event.dart';

void main() {
  test('serializa evento de automação', () {
    final event = AutomationEvent(
      id: 'event-1',
      businessId: 'business-1',
      eventType: 'appointment.created',
      aggregateType: 'appointment',
      aggregateId: 'appointment-1',
      payload: const {'customerName': 'Lucas'},
      status: AutomationEventStatus.pending,
      createdAt: DateTime(2026, 7, 9),
    );

    final restored = AutomationEvent.fromJson(event.toJson());

    expect(restored.eventType, 'appointment.created');
    expect(restored.payload['customerName'], 'Lucas');
    expect(restored.done, isFalse);
  });
}
