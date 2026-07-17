import 'dart:async';

import '../domain/customer.dart';

sealed class CustomerEvent {
  const CustomerEvent();
}

final class CustomerStarted extends CustomerEvent {
  const CustomerStarted();
}

final class LoyaltySettingsSaved extends CustomerEvent {
  const LoyaltySettingsSaved(this.settings);

  final LoyaltySettings settings;
}

final class CustomerLinkedToAppointment extends CustomerEvent {
  CustomerLinkedToAppointment({
    required this.appointmentId,
    required this.customerId,
    required this.completer,
  });

  final String appointmentId;
  final String customerId;
  final Completer<bool> completer;
}

final class CustomerAssociationSearched extends CustomerEvent {
  const CustomerAssociationSearched({
    required this.appointmentId,
    required this.query,
  });

  final String appointmentId;
  final String query;
}
