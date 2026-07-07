import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/data/local_finance_repository.dart';
import 'package:fluxora/data/offline_first_finance_repository.dart';
import 'package:fluxora/domain/finance_repository.dart';
import 'package:fluxora/domain/transaction.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('salva offline e envia a alteração quando a conexão retorna', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final local = LocalFinanceRepository(
      preferences,
      storageKey: 'test.business-1',
    );
    final remote = _ControllableRemoteRepository()..online = false;
    final repository = OfflineFirstFinanceRepository(
      local: local,
      remote: remote,
      preferences: preferences,
      businessId: 'business-1',
    );
    final transaction = FinanceTransaction(
      id: '4fe0c9cc-3af2-4b0b-a6e5-67586a440db3',
      description: 'Corte feminino',
      amount: 120,
      category: 'Serviços',
      date: DateTime(2026, 7, 7),
      type: TransactionType.income,
    );

    await repository.saveTransaction(transaction);
    expect(await local.getTransactions(), hasLength(1));
    expect(remote.items, isEmpty);

    remote.online = true;
    final synchronized = await repository.getTransactions();

    expect(synchronized, hasLength(1));
    expect(remote.items.single.id, transaction.id);
  });

  test('remoção offline também é repetida na nuvem', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final local = LocalFinanceRepository(
      preferences,
      storageKey: 'test.business-2',
    );
    final remote = _ControllableRemoteRepository();
    final transaction = FinanceTransaction(
      id: '88e027e1-65e4-4463-b771-720d4a3637dc',
      description: 'Manicure',
      amount: 60,
      category: 'Serviços',
      date: DateTime(2026, 7, 7),
      type: TransactionType.income,
    );
    await remote.saveTransaction(transaction);
    await local.saveTransaction(transaction);
    final repository = OfflineFirstFinanceRepository(
      local: local,
      remote: remote,
      preferences: preferences,
      businessId: 'business-2',
    );

    remote.online = false;
    await repository.deleteTransaction(transaction.id);
    remote.online = true;
    await repository.getTransactions();

    expect(remote.items, isEmpty);
    expect(await local.getTransactions(), isEmpty);
  });
}

class _ControllableRemoteRepository implements FinanceRepository {
  bool online = true;
  final List<FinanceTransaction> items = [];

  void _checkConnection() {
    if (!online) throw Exception('offline');
  }

  @override
  Future<void> deleteTransaction(String id) async {
    _checkConnection();
    items.removeWhere((item) => item.id == id);
  }

  @override
  Future<List<FinanceTransaction>> getTransactions() async {
    _checkConnection();
    return List.of(items);
  }

  @override
  Future<void> replaceTransaction(FinanceTransaction transaction) async {
    _checkConnection();
    items.removeWhere((item) => item.id == transaction.id);
    items.add(transaction);
  }

  @override
  Future<void> saveTransaction(FinanceTransaction transaction) {
    return replaceTransaction(transaction);
  }
}
