import 'account.dart';

class BusinessAccess {
  const BusinessAccess({required this.business, required this.membership});

  final BeautyBusiness business;
  final BusinessMembership membership;
}

abstract interface class BusinessRepository {
  Future<List<BusinessAccess>> getBusinesses();
  Future<BusinessAccess> createBusiness({
    required String name,
    required BusinessType type,
    String document,
    String phone,
  });
}
