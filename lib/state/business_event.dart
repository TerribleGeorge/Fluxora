import '../domain/account.dart';
import '../domain/business_repository.dart';

sealed class BusinessEvent {
  const BusinessEvent();
}

final class BusinessesStarted extends BusinessEvent {
  const BusinessesStarted();
}

final class BusinessCreated extends BusinessEvent {
  const BusinessCreated({
    required this.name,
    required this.type,
    required this.document,
    this.referralCode = '',
  });
  final String name;
  final BusinessType type;
  final String document;
  final String referralCode;
}

final class BusinessSelected extends BusinessEvent {
  const BusinessSelected(this.access);
  final BusinessAccess access;
}
