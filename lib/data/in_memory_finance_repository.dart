import '../domain/finance_repository.dart';
import '../domain/transaction.dart';

class InMemoryFinanceRepository implements FinanceRepository {
  InMemoryFinanceRepository({bool seed = true})
    : _items = seed ? _seedTransactions() : [];

  final List<FinanceTransaction> _items;

  static List<FinanceTransaction> _seedTransactions() => [
    FinanceTransaction(
      id: 'seed-1',
      description: 'Receita inicial',
      amount: 4850,
      category: 'Vendas',
      date: DateTime.now(),
      type: TransactionType.income,
    ),
    FinanceTransaction(
      id: 'seed-2',
      description: 'Custos operacionais',
      amount: 1380,
      category: 'Operação',
      date: DateTime.now().subtract(const Duration(days: 1)),
      type: TransactionType.expense,
    ),
  ];

  @override
  Future<List<FinanceTransaction>> getTransactions() async => List.of(_items);

  @override
  Future<void> saveTransaction(FinanceTransaction transaction) async {
    _items.insert(0, transaction);
  }

  @override
  Future<void> deleteTransaction(String id) async {
    _items.removeWhere((item) => item.id == id);
  }

  @override
  Future<void> replaceTransaction(FinanceTransaction transaction) async {
    final index = _items.indexWhere((item) => item.id == transaction.id);
    if (index < 0) {
      _items.insert(0, transaction);
    } else {
      _items[index] = transaction;
    }
  }
}
