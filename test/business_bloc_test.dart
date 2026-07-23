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
        document: '11.222.333/0001-81',
      ),
    );
    final state = await bloc.stream.firstWhere(
      (item) => item.status == BusinessStatus.ready,
    );

    expect(state.business?.name, 'Studio Aurora');
    expect(state.business?.document, '11222333000181');
    expect(state.membership?.role, MembershipRole.owner);
  });

  test('bloqueia criação sem CNPJ válido', () async {
    final bloc = BusinessBloc(_FakeBusinessRepository());
    addTearDown(bloc.close);

    bloc.add(
      const BusinessCreated(
        name: 'Studio Sem Documento',
        type: BusinessType.beautySalon,
        document: '00.000.000/0000-00',
      ),
    );
    final state = await bloc.stream.firstWhere((item) => item.message != null);

    expect(state.status, BusinessStatus.requiresBusiness);
    expect(state.message, contains('CNPJ válido'));
  });

  test('envia código de indicação ao criar estabelecimento', () async {
    final repository = _FakeBusinessRepository();
    final bloc = BusinessBloc(repository);
    addTearDown(bloc.close);

    bloc.add(
      const BusinessCreated(
        name: 'Studio Indicado',
        type: BusinessType.spa,
        document: '11.222.333/0001-81',
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
  String lastDocument = '';

  @override
  Future<BusinessAccess> createBusiness({
    required String name,
    required BusinessType type,
    String document = '',
    String phone = '',
    String referralCode = '',
  }) async {
    lastReferralCode = referralCode;
    lastDocument = document;
    final createdAt = DateTime(2026, 7, 7);
    final access = BusinessAccess(
      business: BeautyBusiness(
        id: 'business-1',
        name: name,
        type: type,
        createdAt: createdAt,
        document: document,
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
