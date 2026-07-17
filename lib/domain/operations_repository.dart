import 'operations.dart';

abstract interface class OperationsRepository {
  Future<List<CommissionPayout>> getPayouts();
  Future<List<CashSession>> getCashSessions();
  Future<void> savePayout(CommissionPayout payout);
  Future<void> saveCashSession(CashSession session);
}
