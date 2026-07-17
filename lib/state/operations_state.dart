import '../domain/operations.dart';

enum OperationsStatus { initial, loading, success, failure }

class OperationsState {
  const OperationsState({
    this.status = OperationsStatus.initial,
    this.payouts = const [],
    this.cashSessions = const [],
    this.commissionBalances = const {},
    this.expectedCash = 0,
    this.message,
  });

  final OperationsStatus status;
  final List<CommissionPayout> payouts;
  final List<CashSession> cashSessions;
  final Map<String, double> commissionBalances;
  final double expectedCash;
  final String? message;

  CashSession? get openCash => cashSessions
      .where((item) => item.status == CashSessionStatus.open)
      .firstOrNull;
  bool get loading => status == OperationsStatus.loading;
}
