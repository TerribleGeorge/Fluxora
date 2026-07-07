import '../domain/transaction.dart';

sealed class FinanceEvent {
  const FinanceEvent();
}

final class FinanceStarted extends FinanceEvent {
  const FinanceStarted();
}

final class FinanceTransactionAdded extends FinanceEvent {
  const FinanceTransactionAdded({
    required this.description,
    required this.amount,
    required this.category,
    required this.type,
    this.notes = '',
    this.kind,
    this.paymentSource = EntryPaymentSource.bank,
  });

  final String description;
  final double amount;
  final String category;
  final TransactionType type;
  final String notes;
  final FinancialEntryKind? kind;
  final EntryPaymentSource paymentSource;
}

final class FinanceTransactionDeleted extends FinanceEvent {
  const FinanceTransactionDeleted(this.transaction);
  final FinanceTransaction transaction;
}

final class FinanceTransactionRestored extends FinanceEvent {
  const FinanceTransactionRestored(this.transaction);
  final FinanceTransaction transaction;
}
