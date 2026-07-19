import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/domain/account.dart';
import 'package:fluxora/domain/business_repository.dart';
import 'package:fluxora/state/business_bloc.dart';
import 'package:fluxora/state/business_event.dart';
import 'package:fluxora/state/business_state.dart';

void main() {
  test('solicita criação quando usuário ainda não possui negócio', () async {
    final bloc = BusinessBloc(_FakeBusinessRepository());
    addTearDown(bloc.close);

    bloc.add(const BusinessesStarted());
    final state = await bloc.stream.firstWhere(
      (item) => item.status == BusinessStatus.requiresBusiness,
    );

    expect(state.accesses, isEmpty);
  });

  test('cria e seleciona o primeiro estabelecimento', () async {
    final repository = _FakeBusinessRepository();
    final bloc = BusinessBloc(repository);
    addTearDown(bloc.close);

    bloc.add(
      const BusinessCreated(
        name: 'Studio Aurora',
        type: BusinessType.beautySalon,
      ),
    );
    final state = await bloc.stream.firstWhere(
      (item) => item.status == BusinessStatus.ready,
    );

    expect(state.business?.name, 'Studio Aurora');
    expect(state.membership?.role, MembershipRole.owner);
  });

  test('envia código de indicação ao criar estabelecimento', () async {
    final repository = _FakeBusinessRepository();
    final bloc = BusinessBloc(repository);
    addTearDown(bloc.close);

    bloc.add(
      const BusinessCreated(
        name: 'Studio Indicado',
        type: BusinessType.spa,
        referralCode: 'AB12CD',
      ),
    );
    await bloc.stream.firstWhere((item) => item.status == BusinessStatus.ready);

    expect(repository.lastReferralCode, 'AB12CD');
  });
}

class _FakeBusinessRepository implements BusinessRepository {
  final List<BusinessAccess> items = [];
  String lastReferralCode = '';

  @override
  Future<BusinessAccess> createBusiness({
    required String name,
    required BusinessType type,
    String document = '',
    String phone = '',
    String referralCode = '',
  }) async {
    lastReferralCode = referralCode;
    final createdAt = DateTime(2026, 7, 7);
    final access = BusinessAccess(
      business: BeautyBusiness(
        id: 'business-1',
        name: name,
        type: type,
        createdAt: createdAt,
      ),
      membership: BusinessMembership(
        id: 'membership-1',
        businessId: 'business-1',
        userId: 'user-1',
        role: MembershipRole.owner,
        createdAt: createdAt,
      ),
    );
    items.add(access);
    return access;
  }

  @override
  Future<List<BusinessAccess>> getBusinesses() async => List.of(items);
}
