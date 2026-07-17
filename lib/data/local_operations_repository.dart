import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/operations.dart';
import '../domain/operations_repository.dart';

class LocalOperationsRepository implements OperationsRepository {
  LocalOperationsRepository(this._preferences, String businessId)
    : _payoutsKey = 'fluxora.payouts.$businessId.v1',
      _cashKey = 'fluxora.cash_sessions.$businessId.v1';

  final SharedPreferences _preferences;
  final String _payoutsKey;
  final String _cashKey;

  @override
  Future<List<CommissionPayout>> getPayouts() async =>
      _read(_payoutsKey, CommissionPayout.fromJson);

  @override
  Future<List<CashSession>> getCashSessions() async =>
      _read(_cashKey, CashSession.fromJson);

  @override
  Future<void> savePayout(CommissionPayout payout) async {
    final items = await getPayouts();
    items.removeWhere((item) => item.id == payout.id);
    items.add(payout);
    await overwritePayouts(items);
  }

  @override
  Future<void> saveCashSession(CashSession session) async {
    final items = await getCashSessions();
    items.removeWhere((item) => item.id == session.id);
    items.add(session);
    await overwriteCashSessions(items);
  }

  List<T> _read<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final raw = _preferences.getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((item) => fromJson(item as Map<String, dynamic>))
          .toList();
    } on Object {
      return [];
    }
  }

  Future<void> overwritePayouts(List<CommissionPayout> items) =>
      _write(_payoutsKey, items.map((item) => item.toJson()).toList());

  Future<void> overwriteCashSessions(List<CashSession> items) =>
      _write(_cashKey, items.map((item) => item.toJson()).toList());

  Future<void> _write(String key, List<Map<String, Object?>> items) =>
      _preferences.setString(key, jsonEncode(items));
}
