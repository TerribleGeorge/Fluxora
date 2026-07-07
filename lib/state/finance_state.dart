import '../domain/transaction.dart';

enum FinanceStatus { initial, loading, success, failure }

class FinanceState {
  const FinanceState({
    this.status = FinanceStatus.initial,
    this.transactions = const [],
    this.errorMessage,
  });

  final FinanceStatus status;
  final List<FinanceTransaction> transactions;
  final String? errorMessage;

  bool get loading => status == FinanceStatus.loading;
  double get income => _sum(TransactionType.income);
  double get expenses => _sum(TransactionType.expense);
  double get balance => income - expenses;

  double _sum(TransactionType type) => transactions
      .where((item) => item.type == type)
      .fold(0, (total, item) => total + item.amount);

  FinanceState copyWith({
    FinanceStatus? status,
    List<FinanceTransaction>? transactions,
    String? errorMessage,
    bool clearError = false,
  }) {
    return FinanceState(
      status: status ?? this.status,
      transactions: transactions ?? this.transactions,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
