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
