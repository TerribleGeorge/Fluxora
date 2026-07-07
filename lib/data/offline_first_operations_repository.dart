import 'package:shared_preferences/shared_preferences.dart';

import '../domain/operations.dart';
import '../domain/operations_repository.dart';
import 'local_operations_repository.dart';

class OfflineFirstOperationsRepository implements OperationsRepository {
  OfflineFirstOperationsRepository({
    required this.local,
    required this.remote,
    required this.preferences,
    required this.businessId,
  });

  final LocalOperationsRepository local;
  final OperationsRepository remote;
  final SharedPreferences preferences;
  final String businessId;

  String get _dirtyPayoutsKey => 'fluxora.dirty_payouts.$businessId.v1';
  String get _dirtyCashKey => 'fluxora.dirty_cash.$businessId.v1';

  @override
  Future<List<CommissionPayout>> getPayouts() async {
    await _flushPayouts();
    final localItems = await local.getPayouts();
    try {
      final remoteItems = await remote.getPayouts();
      final dirty = preferences.getStringList(_dirtyPayoutsKey)?.toSet() ?? {};
      final merged = {for (final item in remoteItems) item.id: item};
      for (final item in localItems) {
        if (dirty.contains(item.id)) merged[item.id] = item;
      }
      final result = merged.values.toList()
        ..sort((a, b) => b.paidAt.compareTo(a.paidAt));
      await local.overwritePayouts(result);
      return result;
    } on Exception {
      return localItems;
    }
  }

  @override
  Future<List<CashSession>> getCashSessions() async {
    await _flushCash();
    final localItems = await local.getCashSessions();
    try {
      final remoteItems = await remote.getCashSessions();
      final dirty = preferences.getStringList(_dirtyCashKey)?.toSet() ?? {};
      final merged = {for (final item in remoteItems) item.id: item};
      for (final item in localItems) {
        if (dirty.contains(item.id)) merged[item.id] = item;
      }
      final result = merged.values.toList()
        ..sort((a, b) => b.openedAt.compareTo(a.openedAt));
      await local.overwriteCashSessions(result);
      return result;
    } on Exception {
      return localItems;
    }
  }

  @override
  Future<void> savePayout(CommissionPayout payout) async {
    await local.savePayout(payout);
    try {
      await remote.savePayout(payout);
    } on Exception {
      await _markDirty(_dirtyPayoutsKey, payout.id);
    }
  }

  @override
  Future<void> saveCashSession(CashSession session) async {
    await local.saveCashSession(session);
    try {
      await remote.saveCashSession(session);
    } on Exception {
      await _markDirty(_dirtyCashKey, session.id);
    }
  }

  Future<void> _flushPayouts() async {
    final dirty = preferences.getStringList(_dirtyPayoutsKey) ?? [];
    if (dirty.isEmpty) return;
    final items = {for (final item in await local.getPayouts()) item.id: item};
    final remaining = <String>[];
    for (final id in dirty) {
      try {
        final item = items[id];
        if (item != null) await remote.savePayout(item);
      } on Exception {
        remaining.add(id);
      }
    }
    await preferences.setStringList(_dirtyPayoutsKey, remaining);
  }

  Future<void> _flushCash() async {
    final dirty = preferences.getStringList(_dirtyCashKey) ?? [];
    if (dirty.isEmpty) return;
    final items = {
      for (final item in await local.getCashSessions()) item.id: item,
    };
    final remaining = <String>[];
    for (final id in dirty) {
      try {
        final item = items[id];
        if (item != null) await remote.saveCashSession(item);
      } on Exception {
        remaining.add(id);
      }
    }
    await preferences.setStringList(_dirtyCashKey, remaining);
  }

  Future<void> _markDirty(String key, String id) async {
    final dirty = preferences.getStringList(key)?.toSet() ?? <String>{};
    dirty.add(id);
    await preferences.setStringList(key, dirty.toList());
  }
}
