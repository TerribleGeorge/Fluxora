import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/data/local_finance_repository.dart';
import 'package:fluxora/domain/transaction.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persiste lançamentos entre instâncias do repositório', () async {
    SharedPreferences.setMockInitialValues({});
    final first = await LocalFinanceRepository.create();
    final transaction = FinanceTransaction(
      id: 'persistent-1',
      description: 'Venda',
      amount: 250,
      category: 'Receitas',
      date: DateTime(2026, 7, 7),
      type: TransactionType.income,
    );
    await first.saveTransaction(transaction);

    final second = await LocalFinanceRepository.create();
    final restored = await second.getTransactions();

    expect(restored, hasLength(1));
    expect(restored.single.description, 'Venda');
    expect(restored.single.amount, 250);
  });
}
