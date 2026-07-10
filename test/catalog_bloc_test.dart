import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/data/local_catalog_repository.dart';
import 'package:fluxora/domain/catalog.dart';
import 'package:fluxora/state/catalog_bloc.dart';
import 'package:fluxora/state/catalog_event.dart';
import 'package:fluxora/state/catalog_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late LocalCatalogRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = LocalCatalogRepository(
      await SharedPreferences.getInstance(),
      'business-1',
    );
  });

  test('cadastra profissional com comissão padrão', () async {
    final bloc = CatalogBloc(repository, 'business-1');
    addTearDown(bloc.close);

    bloc.add(
      const ProfessionalSaved(
        name: 'Marina Costa',
        phone: '11999999999',
        email: 'marina@example.com',
        commissionPercent: 45,
      ),
    );
    final state = await bloc.stream.firstWhere(
      (item) => item.status == CatalogStatus.success,
    );

    expect(state.professionals.single.name, 'Marina Costa');
    expect(state.professionals.single.defaultCommissionPercent, 45);
  });

  test('cadastra serviço com comissão específica', () async {
    final bloc = CatalogBloc(repository, 'business-1');
    addTearDown(bloc.close);

    bloc.add(
      const ServiceSaved(
        name: 'Corte e escova',
        category: 'Cabelo',
        price: 150,
        durationMinutes: 60,
        commissionType: ServiceCommissionType.percentage,
        commissionValue: 40,
      ),
    );
    final state = await bloc.stream.firstWhere(
      (item) => item.status == CatalogStatus.success,
    );

    expect(state.services.single.price, 150);
    expect(
      state.services.single.commissionType,
      ServiceCommissionType.percentage,
    );
  });

  test('rejeita comissão percentual acima de cem', () async {
    final bloc = CatalogBloc(repository, 'business-1');
    addTearDown(bloc.close);

    bloc.add(
      const ServiceSaved(
        name: 'Corte',
        category: 'Cabelo',
        price: 80,
        durationMinutes: 30,
        commissionType: ServiceCommissionType.percentage,
        commissionValue: 120,
      ),
    );
    final state = await bloc.stream.firstWhere(
      (item) => item.status == CatalogStatus.failure,
    );

    expect(state.services, isEmpty);
    expect(state.message, isNotEmpty);
  });

  test('persiste status inativo do profissional', () async {
    final createdAt = DateTime(2026, 7, 7);
    await repository.saveProfessional(
      Professional(
        id: 'professional-1',
        businessId: 'business-1',
        name: 'João',
        createdAt: createdAt,
      ),
    );
    await repository.setProfessionalActive('professional-1', false);

    expect((await repository.getProfessionals()).single.active, isFalse);
  });

  test('vincula profissional ao usuário do login', () async {
    final bloc = CatalogBloc(repository, 'business-1');
    addTearDown(bloc.close);

    bloc.add(
      const ProfessionalSaved(
        name: 'Ana Souza',
        phone: '11988887777',
        email: 'ana@example.com',
        commissionPercent: 35,
        userId: 'user-1',
      ),
    );
    final state = await bloc.stream.firstWhere(
      (item) => item.status == CatalogStatus.success,
    );

    expect(state.professionals.single.userId, 'user-1');
  });
}
