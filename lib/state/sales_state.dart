import '../domain/sale.dart';

enum SalesStatus { initial, loading, success, failure }

class SalesState {
  const SalesState({
    this.status = SalesStatus.initial,
    this.sales = const [],
    this.message,
  });

  final SalesStatus status;
  final List<Sale> sales;
  final String? message;
  bool get loading => status == SalesStatus.loading;
}
