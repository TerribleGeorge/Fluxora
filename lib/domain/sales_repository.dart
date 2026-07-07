import 'sale.dart';

abstract interface class SalesRepository {
  Future<List<Sale>> getSales();
  Future<void> saveSale(Sale sale);
  Future<void> setSaleStatus(String id, SaleStatus status);
}
