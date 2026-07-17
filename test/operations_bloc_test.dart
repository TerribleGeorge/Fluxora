import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/data/local_operations_repository.dart';
import 'package:fluxora/data/local_sales_repository.dart';
import 'package:fluxora/data/in_memory_finance_repository.dart';
import 'package:fluxora/domain/sale.dart';
import 'package:fluxora/state/operations_bloc.dart';
import 'package:fluxora/state/operations_event.dart';
import 'package:fluxora/state/operations_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late LocalOperationsRepository operationsRepository;
  late LocalSalesRepository salesRepository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    operationsRepository = LocalOperationsRepository(preferences, 'business-1');
    salesRepository = LocalSalesRepository(preferences, 'business-1');
  });

  test('calcula comissão disponível e registra repasse', () async {
    await salesRepository.saveSale(_sale(commission: 40));
    final bloc = OperationsBloc(
      operationsRepository,
      salesRepository,
      financeRepository: InMemoryFinanceRepository(seed: false),
      businessId: 'business-1',
      userId: 'user-1',
    );
    addTearDown(bloc.close);

    bloc.add(const OperationsStarted());
    await bloc.stream.firstWhere(
      (state) => state.commissionBalances['professional-1'] == 40,
    );
    bloc.add(
      const CommissionPaid(
        professionalId: 'professional-1',
        amount: 25,
        method: PaymentMethod.pix,
      ),
    );
    final state = await bloc.stream.firstWhere(
      (item) => item.commissionBalances['professional-1'] == 15,
    );

    expect(state.payouts.single.amount, 25);
  });

  test('caixa considera somente vendas recebidas em dinheiro', () async {
    final bloc = OperationsBloc(
      operationsRepository,
      salesRepository,
      financeRepository: InMemoryFinanceRepository(seed: false),
      businessId: 'business-1',
      userId: 'user-1',
    );
    addTearDown(bloc.close);

    bloc.add(const CashOpened(50));
    await bloc.stream.firstWhere((state) => state.openCash != null);
    await salesRepository.saveSale(
      _sale(paymentMethod: PaymentMethod.cash, occurredAt: DateTime.now()),
    );
    bloc.add(const OperationsStarted());
    final openState = await bloc.stream.firstWhere(
      (state) => state.expectedCash == 150,
    );
    expect(openState.openCash, isNotNull);

    bloc.add(const CashClosed(countedBalance: 148));
    final closed = await bloc.stream.firstWhere(
      (state) =>
          state.cashSessions.isNotEmpty &&
          state.cashSessions.first.difference == -2,
    );
    expect(closed.openCash, isNull);
  });

  test('impede repasse acima do saldo disponível', () async {
    final bloc = OperationsBloc(
      operationsRepository,
      salesRepository,
      financeRepository: InMemoryFinanceRepository(seed: false),
      businessId: 'business-1',
      userId: 'user-1',
    );
    addTearDown(bloc.close);

    bloc.add(
      const CommissionPaid(
        professionalId: 'professional-1',
        amount: 10,
        method: PaymentMethod.pix,
      ),
    );
    final state = await bloc.stream.firstWhere(
      (item) => item.status == OperationsStatus.failure,
    );

    expect(state.payouts, isEmpty);
  });
}

Sale _sale({
  double commission = 0,
  PaymentMethod paymentMethod = PaymentMethod.pix,
  DateTime? occurredAt,
}) {
  final now = occurredAt ?? DateTime.now();
  return Sale(
    id: 'sale-${now.microsecondsSinceEpoch}',
    businessId: 'business-1',
    professionalId: 'professional-1',
    items: [
      SaleItem(
        id: 'item-1',
        type: SaleItemType.service,
        description: 'Corte',
        quantity: 1,
        unitPrice: 100,
        commissionAmount: commission,
      ),
    ],
    payment: SalePayment(method: paymentMethod, amount: 100),
    occurredAt: now,
    createdBy: 'user-1',
    createdAt: now,
  );
}
