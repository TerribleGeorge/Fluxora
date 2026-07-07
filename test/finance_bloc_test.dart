import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/data/in_memory_finance_repository.dart';
import 'package:fluxora/domain/transaction.dart';
import 'package:fluxora/state/finance_bloc.dart';
import 'package:fluxora/state/finance_event.dart';
import 'package:fluxora/state/finance_state.dart';

void main() {
  test('carrega, calcula saldo e adiciona lançamento', () async {
    final bloc = FinanceBloc(InMemoryFinanceRepository(seed: false));
    addTearDown(bloc.close);

    bloc.add(const FinanceStarted());
    await bloc.stream.firstWhere(
      (state) => state.status == FinanceStatus.success,
    );
    bloc.add(
      const FinanceTransactionAdded(
        description: 'Nova venda',
        amount: 100,
        category: 'Vendas',
        type: TransactionType.income,
      ),
    );
    final state = await bloc.stream.firstWhere(
      (state) => state.transactions.length == 1,
    );

    expect(state.balance, 100);
    expect(state.income, 100);
    expect(state.expenses, 0);
  });

  test('remove e restaura um lançamento', () async {
    final repository = InMemoryFinanceRepository(seed: false);
    final bloc = FinanceBloc(repository);
    addTearDown(bloc.close);
    final transaction = FinanceTransaction(
      id: 'tx-1',
      description: 'Internet',
      amount: 120,
      category: 'Contas',
      date: DateTime(2026, 7, 7),
      type: TransactionType.expense,
    );
    await repository.saveTransaction(transaction);
    bloc.add(const FinanceStarted());
    await bloc.stream.firstWhere((state) => state.transactions.length == 1);

    bloc.add(FinanceTransactionDeleted(transaction));
    await bloc.stream.firstWhere(
      (state) =>
          state.status == FinanceStatus.success && state.transactions.isEmpty,
    );
    bloc.add(FinanceTransactionRestored(transaction));
    final restored = await bloc.stream.firstWhere(
      (state) => state.transactions.length == 1,
    );

    expect(restored.balance, -120);
    expect(restored.transactions.single.description, 'Internet');
  });

  test('rejeita evento de lançamento inválido', () async {
    final bloc = FinanceBloc(InMemoryFinanceRepository(seed: false));
    addTearDown(bloc.close);

    bloc.add(
      const FinanceTransactionAdded(
        description: '',
        amount: 0,
        category: '',
        type: TransactionType.expense,
      ),
    );
    final state = await bloc.stream.firstWhere(
      (state) => state.status == FinanceStatus.failure,
    );

    expect(state.transactions, isEmpty);
    expect(state.errorMessage, isNotEmpty);
  });

  test('serializa e recupera um lançamento', () {
    final original = FinanceTransaction(
      id: 'tx-1',
      description: 'Consultoria',
      amount: 980.50,
      category: 'Serviços',
      date: DateTime(2026, 7, 7),
      type: TransactionType.income,
      notes: 'Pagamento confirmado',
    );

    final restored = FinanceTransaction.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.amount, original.amount);
    expect(restored.type, TransactionType.income);
    expect(restored.notes, 'Pagamento confirmado');
  });
}
