import '../domain/sale.dart';

sealed class OperationsEvent {
  const OperationsEvent();
}

final class OperationsStarted extends OperationsEvent {
  const OperationsStarted();
}

final class CashOpened extends OperationsEvent {
  const CashOpened(this.openingBalance);
  final double openingBalance;
}

final class CashClosed extends OperationsEvent {
  const CashClosed({required this.countedBalance, this.notes = ''});
  final double countedBalance;
  final String notes;
}

final class CommissionPaid extends OperationsEvent {
  const CommissionPaid({
    required this.professionalId,
    required this.amount,
    required this.method,
    this.notes = '',
  });
  final String professionalId;
  final double amount;
  final PaymentMethod method;
  final String notes;
}
