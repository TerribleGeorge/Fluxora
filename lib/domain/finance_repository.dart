import 'transaction.dart';

abstract interface class FinanceRepository {
  Future<List<FinanceTransaction>> getTransactions();
  Future<void> saveTransaction(FinanceTransaction transaction);
  Future<void> deleteTransaction(String id);
  Future<void> replaceTransaction(FinanceTransaction transaction);
}
