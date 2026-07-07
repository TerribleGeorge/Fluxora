import '../domain/account.dart';
import '../domain/business_repository.dart';

enum BusinessStatus { initial, loading, requiresBusiness, ready, failure }

class BusinessState {
  const BusinessState({
    this.status = BusinessStatus.initial,
    this.accesses = const [],
    this.selected,
    this.message,
  });

  final BusinessStatus status;
  final List<BusinessAccess> accesses;
  final BusinessAccess? selected;
  final String? message;

  bool get loading => status == BusinessStatus.loading;
  BeautyBusiness? get business => selected?.business;
  BusinessMembership? get membership => selected?.membership;
}
