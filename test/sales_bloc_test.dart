import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/data/local_sales_repository.dart';
import 'package:fluxora/data/local_catalog_repository.dart';
import 'package:fluxora/domain/catalog.dart';
import 'package:fluxora/domain/sale.dart';
import 'package:fluxora/state/sales_bloc.dart';
import 'package:fluxora/state/sales_event.dart';
import 'package:fluxora/state/sales_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late LocalSalesRepository repository;
  late LocalCatalogRepository catalogRepository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    repository = LocalSalesRepository(preferences, 'business-1');
    catalogRepository = LocalCatalogRepository(preferences, 'business-1');
    await catalogRepository.saveProfessional(
      Professional(
        id: 'professional-1',
        businessId: 'business-1',
        name: 'Ana',
        defaultCommissionPercent: 40,
        createdAt: DateTime(2026, 7, 7),
      ),
    );
    await catalogRepository.saveService(
      BeautyService(
        id: 'service-1',
        businessId: 'business-1',
        name: 'Corte',
        price: 100,
        durationMinutes: 30,
        createdAt: DateTime(2026, 7, 7),
      ),
    );
  });

  test('registra venda e calcula taxa líquida', () async {
    final bloc = SalesBloc(
      repository,
      catalogRepository: catalogRepository,
      businessId: 'business-1',
      userId: 'user-1',
    );
    addTearDown(bloc.close);

    bloc.add(
      const SaleCreated(
        professionalId: 'professional-1',
        items: [
          SaleItem(
            id: 'item-1',
            type: SaleItemType.service,
            description: 'Corte',
            quantity: 1,
            unitPrice: 100,
            serviceId: 'service-1',
          ),
        ],
        paymentMethod: PaymentMethod.creditCard,
        paymentFeePercent: 4,
        installments: 2,
      ),
    );
    final state = await bloc.stream.firstWhere(
      (item) => item.status == SalesStatus.success,
    );

    expect(state.sales.single.grossTotal, 100);
    expect(state.sales.single.payment.feeAmount, 4);
    expect(state.sales.single.netTotal, 96);
    expect(state.sales.single.commissionTotal, 40);
  });

  test('cancela sem apagar o histórico da venda', () async {
    final now = DateTime(2026, 7, 7);
    await repository.saveSale(
      Sale(
        id: 'sale-1',
        businessId: 'business-1',
        professionalId: 'professional-1',
        items: const [
          SaleItem(
            id: 'item-1',
            type: SaleItemType.product,
            description: 'Pomada',
            quantity: 1,
            unitPrice: 40,
          ),
        ],
        payment: const SalePayment(method: PaymentMethod.pix, amount: 40),
        occurredAt: now,
        createdBy: 'user-1',
        createdAt: now,
      ),
    );
    final bloc = SalesBloc(
      repository,
      catalogRepository: catalogRepository,
      businessId: 'business-1',
      userId: 'user-1',
    );
    addTearDown(bloc.close);

    bloc.add(const SaleCancelled('sale-1'));
    final state = await bloc.stream.firstWhere(
      (item) =>
          item.status == SalesStatus.success &&
          item.sales.single.status == SaleStatus.cancelled,
    );

    expect(state.sales, hasLength(1));
  });

  test('rejeita venda sem profissional', () async {
    final bloc = SalesBloc(
      repository,
      catalogRepository: catalogRepository,
      businessId: 'business-1',
      userId: 'user-1',
    );
    addTearDown(bloc.close);

    bloc.add(
      const SaleCreated(
        professionalId: '',
        items: [],
        paymentMethod: PaymentMethod.pix,
        paymentFeePercent: 0,
        installments: 1,
      ),
    );
    final state = await bloc.stream.firstWhere(
      (item) => item.status == SalesStatus.failure,
    );

    expect(state.sales, isEmpty);
  });
}
