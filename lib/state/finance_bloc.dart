import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/finance_repository.dart';
import '../domain/id_generator.dart';
import '../domain/transaction.dart';
import 'finance_event.dart';
import 'finance_state.dart';

class FinanceBloc extends Bloc<FinanceEvent, FinanceState> {
  FinanceBloc(this._repository) : super(const FinanceState()) {
    on<FinanceStarted>(_onStarted);
    on<FinanceTransactionAdded>(_onAdded);
    on<FinanceTransactionDeleted>(_onDeleted);
    on<FinanceTransactionRestored>(_onRestored);
  }

  final FinanceRepository _repository;

  Future<void> _onStarted(
    FinanceStarted event,
    Emitter<FinanceState> emit,
  ) async {
    emit(state.copyWith(status: FinanceStatus.loading, clearError: true));
    await _reload(emit);
  }

  Future<void> _onAdded(
    FinanceTransactionAdded event,
    Emitter<FinanceState> emit,
  ) async {
    if (event.description.trim().length < 2 || event.amount <= 0) {
      emit(
        state.copyWith(
          status: FinanceStatus.failure,
          errorMessage: 'Revise a descrição e o valor do lançamento.',
        ),
      );
      return;
    }
    final transaction = FinanceTransaction(
      id: createUuid(),
      description: event.description.trim(),
      amount: event.amount,
      category: event.category.trim().isEmpty
          ? 'Outros'
          : event.category.trim(),
      date: DateTime.now(),
      type: event.type,
      notes: event.notes.trim(),
      kind:
          event.kind ??
          (event.type == TransactionType.income
              ? FinancialEntryKind.otherIncome
              : FinancialEntryKind.operatingExpense),
      paymentSource: event.paymentSource,
    );
    try {
      await _repository.saveTransaction(transaction);
      await _reload(emit);
    } on Exception {
      emit(
        state.copyWith(
          status: FinanceStatus.failure,
          errorMessage: 'Não foi possível salvar o lançamento.',
        ),
      );
    }
  }

  Future<void> _onDeleted(
    FinanceTransactionDeleted event,
    Emitter<FinanceState> emit,
  ) async {
    try {
      await _repository.deleteTransaction(event.transaction.id);
      await _reload(emit);
    } on Exception {
      emit(
        state.copyWith(
          status: FinanceStatus.failure,
          errorMessage: 'Não foi possível excluir o lançamento.',
        ),
      );
    }
  }

  Future<void> _onRestored(
    FinanceTransactionRestored event,
    Emitter<FinanceState> emit,
  ) async {
    try {
      await _repository.replaceTransaction(event.transaction);
      await _reload(emit);
    } on Exception {
      emit(
        state.copyWith(
          status: FinanceStatus.failure,
          errorMessage: 'Não foi possível restaurar o lançamento.',
        ),
      );
    }
  }

  Future<void> _reload(Emitter<FinanceState> emit) async {
    try {
      final transactions = await _repository.getTransactions();
      emit(
        FinanceState(
          status: FinanceStatus.success,
          transactions: List.unmodifiable(transactions),
        ),
      );
    } on Exception {
      emit(
        state.copyWith(
          status: FinanceStatus.failure,
          errorMessage: 'Não foi possível carregar seus dados.',
        ),
      );
    }
  }
}
