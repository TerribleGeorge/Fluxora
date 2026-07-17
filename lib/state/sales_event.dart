import '../domain/sale.dart';

sealed class SalesEvent {
  const SalesEvent();
}

final class SalesStarted extends SalesEvent {
  const SalesStarted();
}

final class SaleCreated extends SalesEvent {
  const SaleCreated({
    required this.professionalId,
    required this.items,
    required this.paymentMethod,
    required this.paymentFeePercent,
    required this.installments,
    this.customerName = '',
    this.notes = '',
  });
  final String professionalId;
  final List<SaleItem> items;
  final PaymentMethod paymentMethod;
  final double paymentFeePercent;
  final int installments;
  final String customerName;
  final String notes;
}

final class SaleCancelled extends SalesEvent {
  const SaleCancelled(this.id);
  final String id;
}
