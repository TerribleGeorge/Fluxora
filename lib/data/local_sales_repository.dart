import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/sale.dart';
import '../domain/sales_repository.dart';

class LocalSalesRepository implements SalesRepository {
  LocalSalesRepository(this._preferences, String businessId)
    : _key = 'fluxora.sales.$businessId.v1';

  final SharedPreferences _preferences;
  final String _key;

  @override
  Future<List<Sale>> getSales() async {
    final raw = _preferences.getString(_key);
    if (raw == null) return [];
    try {
      final items = (jsonDecode(raw) as List<dynamic>)
          .map((item) => Sale.fromJson(item as Map<String, dynamic>))
          .toList();
      items.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      return items;
    } on Object {
      return [];
    }
  }

  @override
  Future<void> saveSale(Sale sale) async {
    final items = await getSales();
    final index = items.indexWhere((item) => item.id == sale.id);
    if (index < 0) {
      items.add(sale);
    } else {
      items[index] = sale;
    }
    await overwrite(items);
  }

  @override
  Future<void> setSaleStatus(String id, SaleStatus status) async {
    final items = await getSales();
    final index = items.indexWhere((item) => item.id == id);
    if (index >= 0) items[index] = items[index].copyWith(status: status);
    await overwrite(items);
  }

  Future<void> overwrite(List<Sale> items) => _preferences.setString(
    _key,
    jsonEncode(items.map((item) => item.toJson()).toList()),
  );
}
