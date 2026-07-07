import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/id_generator.dart';
import '../domain/operations.dart';
import '../domain/operations_repository.dart';
import '../domain/sale.dart';
import '../domain/sales_repository.dart';
import '../domain/finance_repository.dart';
import '../domain/transaction.dart';
import 'operations_event.dart';
import 'operations_state.dart';

class OperationsBloc extends Bloc<OperationsEvent, OperationsState> {
  OperationsBloc(
    this._repository,
    this._salesRepository, {
    required FinanceRepository financeRepository,
    required this.businessId,
    required this.userId,
  }) : _financeRepository = financeRepository,
       super(const OperationsState()) {
    on<OperationsStarted>(_onStarted);
    on<CashOpened>(_onCashOpened);
    on<CashClosed>(_onCashClosed);
    on<CommissionPaid>(_onCommissionPaid);
  }

  final OperationsRepository _repository;
  final SalesRepository _salesRepository;
  final FinanceRepository _financeRepository;
  final String businessId;
  final String userId;

  Future<void> _onStarted(
    OperationsStarted event,
    Emitter<OperationsState> emit,
  ) async {
    emit(OperationsState(status: OperationsStatus.loading));
    await _reload(emit);
  }

  Future<void> _onCashOpened(
    CashOpened event,
    Emitter<OperationsState> emit,
  ) async {
    if (event.openingBalance < 0 || state.openCash != null) {
      _failure(emit, 'Já existe um caixa aberto ou o saldo é inválido.');
      return;
    }
    final now = DateTime.now();
    await _run(
      emit,
      () => _repository.saveCashSession(
        CashSession(
          id: createUuid(),
          businessId: businessId,
          openingBalance: event.openingBalance,
          openedAt: now,
          openedBy: userId,
        ),
      ),
    );
  }

  Future<void> _onCashClosed(
    CashClosed event,
    Emitter<OperationsState> emit,
  ) async {
    final open = state.openCash;
    if (open == null || event.countedBalance < 0) {
      _failure(emit, 'Não há caixa aberto ou o valor contado é inválido.');
      return;
    }
    await _run(
      emit,
      () => _repository.saveCashSession(
        open.close(
          userId: userId,
          expected: state.expectedCash,
          counted: event.countedBalance,
          notes: event.notes,
        ),
      ),
    );
  }

  Future<void> _onCommissionPaid(
    CommissionPaid event,
    Emitter<OperationsState> emit,
  ) async {
    final available = state.commissionBalances[event.professionalId] ?? 0;
    if (event.amount <= 0 || event.amount > available + 0.005) {
      _failure(emit, 'O repasse não pode superar a comissão disponível.');
      return;
    }
    final now = DateTime.now();
    final sales = await _salesRepository.getSales();
    final professionalSales = sales
        .where(
          (sale) =>
              sale.professionalId == event.professionalId &&
              sale.status == SaleStatus.completed,
        )
        .toList();
    final periodStart = professionalSales.isEmpty
        ? now
        : professionalSales
              .map((sale) => sale.occurredAt)
              .reduce((a, b) => a.isBefore(b) ? a : b);
    await _run(
      emit,
      () => _repository.savePayout(
        CommissionPayout(
          id: createUuid(),
          businessId: businessId,
          professionalId: event.professionalId,
          amount: event.amount,
          periodStart: periodStart,
          periodEnd: now,
          paidAt: now,
          method: event.method,
          createdBy: userId,
          notes: event.notes.trim(),
        ),
      ),
    );
  }

  Future<void> _run(
    Emitter<OperationsState> emit,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      await _reload(emit);
    } on Exception {
      _failure(emit, 'Não foi possível salvar a operação.');
    }
  }

  Future<void> _reload(Emitter<OperationsState> emit) async {
    try {
      final results = await Future.wait([
        _repository.getPayouts(),
        _repository.getCashSessions(),
        _salesRepository.getSales(),
        _financeRepository.getTransactions(),
      ]);
      final payouts = results[0] as List<CommissionPayout>;
      final sessions = results[1] as List<CashSession>;
      final sales = results[2] as List<Sale>;
      final transactions = results[3] as List<FinanceTransaction>;
      final balances = <String, double>{};
      for (final sale in sales.where(
        (item) => item.status == SaleStatus.completed,
      )) {
        balances.update(
          sale.professionalId,
          (value) => value + sale.commissionTotal,
          ifAbsent: () => sale.commissionTotal,
        );
      }
      for (final payout in payouts) {
        balances.update(
          payout.professionalId,
          (value) => value - payout.amount,
          ifAbsent: () => -payout.amount,
        );
      }
      final open = sessions
          .where((item) => item.status == CashSessionStatus.open)
          .firstOrNull;
      var expected = open?.openingBalance ?? 0;
      if (open != null) {
        expected += sales
            .where(
              (sale) =>
                  sale.status == SaleStatus.completed &&
                  sale.payment.method == PaymentMethod.cash &&
                  !sale.occurredAt.isBefore(open.openedAt),
            )
            .fold(0, (sum, sale) => sum + sale.grossTotal);
        expected -= payouts
            .where(
              (payout) =>
                  payout.method == PaymentMethod.cash &&
                  !payout.paidAt.isBefore(open.openedAt),
            )
            .fold(0, (sum, payout) => sum + payout.amount);
        for (final transaction in transactions.where(
          (item) =>
              item.paymentSource == EntryPaymentSource.cash &&
              !item.date.isBefore(open.openedAt),
        )) {
          expected += transaction.type == TransactionType.income
              ? transaction.amount
              : -transaction.amount;
        }
      }
      emit(
        OperationsState(
          status: OperationsStatus.success,
          payouts: payouts,
          cashSessions: sessions,
          commissionBalances: balances,
          expectedCash: expected,
        ),
      );
    } on Exception {
      _failure(emit, 'Não foi possível carregar caixa e comissões.');
    }
  }

  void _failure(Emitter<OperationsState> emit, String message) {
    emit(
      OperationsState(
        status: OperationsStatus.failure,
        payouts: state.payouts,
        cashSessions: state.cashSessions,
        commissionBalances: state.commissionBalances,
        expectedCash: state.expectedCash,
        message: message,
      ),
    );
  }
}
