import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/finance_repository.dart';
import '../domain/transaction.dart';

class LocalFinanceRepository implements FinanceRepository {
  LocalFinanceRepository(
    this._preferences, {
    String storageKey = 'fluxora.transactions.v1',
  }) : _storageKey = storageKey;

  final String _storageKey;
  final SharedPreferences _preferences;

  static Future<LocalFinanceRepository> create({String? businessId}) async {
    return LocalFinanceRepository(
      await SharedPreferences.getInstance(),
      storageKey: businessId == null
          ? 'fluxora.transactions.v1'
          : 'fluxora.transactions.$businessId.v1',
    );
  }

  @override
  Future<List<FinanceTransaction>> getTransactions() async {
    final raw = _preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final items = decoded
          .map(
            (item) => FinanceTransaction.fromJson(item as Map<String, dynamic>),
          )
          .toList();
      items.sort((a, b) => b.date.compareTo(a.date));
      return items;
    } on FormatException {
      return [];
    } on TypeError {
      return [];
    }
  }

  @override
  Future<void> saveTransaction(FinanceTransaction transaction) async {
    final items = await getTransactions();
    items.insert(0, transaction);
    await _write(items);
  }

  @override
  Future<void> deleteTransaction(String id) async {
    final items = await getTransactions()
      ..removeWhere((item) => item.id == id);
    await _write(items);
  }

  @override
  Future<void> replaceTransaction(FinanceTransaction transaction) async {
    final items = await getTransactions();
    final index = items.indexWhere((item) => item.id == transaction.id);
    if (index < 0) {
      items.insert(0, transaction);
    } else {
      items[index] = transaction;
    }
    await _write(items);
  }

  Future<void> _write(List<FinanceTransaction> items) {
    return _preferences.setString(
      _storageKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> overwriteTransactions(List<FinanceTransaction> items) {
    return _write(items);
  }
}
