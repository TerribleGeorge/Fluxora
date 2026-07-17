import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/sale.dart';
import '../domain/sales_repository.dart';
import 'local_sales_repository.dart';

class OfflineFirstSalesRepository implements SalesRepository {
  OfflineFirstSalesRepository({
    required LocalSalesRepository local,
    required SalesRepository remote,
    required SharedPreferences preferences,
    required String businessId,
  }) : _local = local,
       _remote = remote,
       _preferences = preferences,
       _queueKey = 'fluxora.sales_sync.$businessId.v1';

  final LocalSalesRepository _local;
  final SalesRepository _remote;
  final SharedPreferences _preferences;
  final String _queueKey;

  @override
  Future<List<Sale>> getSales() async {
    await _flush();
    final local = await _local.getSales();
    try {
      final remote = await _remote.getSales();
      final pendingIds = _readQueue().map((item) => item.sale.id).toSet();
      final merged = {for (final item in remote) item.id: item};
      for (final item in local) {
        if (pendingIds.contains(item.id)) merged[item.id] = item;
      }
      final result = merged.values.toList()
        ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      await _local.overwrite(result);
      return result;
    } on Exception {
      return local;
    }
  }

  @override
  Future<void> saveSale(Sale sale) async {
    await _local.saveSale(sale);
    await _sendOrQueue(sale);
  }

  @override
  Future<void> setSaleStatus(String id, SaleStatus status) async {
    await _local.setSaleStatus(id, status);
    final sale = (await _local.getSales()).firstWhere((item) => item.id == id);
    await _sendOrQueue(sale);
  }

  Future<void> _sendOrQueue(Sale sale) async {
    try {
      await _remote.saveSale(sale);
    } on Exception {
      final queue = _readQueue()
        ..removeWhere((item) => item.sale.id == sale.id)
        ..add(_PendingSale(sale));
      await _writeQueue(queue);
    }
  }

  Future<void> _flush() async {
    final queue = _readQueue();
    if (queue.isEmpty) return;
    final remaining = <_PendingSale>[];
    for (var index = 0; index < queue.length; index++) {
      try {
        await _remote.saveSale(queue[index].sale);
      } on Exception {
        remaining.addAll(queue.skip(index));
        break;
      }
    }
    await _writeQueue(remaining);
  }

  List<_PendingSale> _readQueue() {
    final raw = _preferences.getString(_queueKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((item) => _PendingSale.fromJson(item as Map<String, dynamic>))
          .toList();
    } on Object {
      return [];
    }
  }

  Future<void> _writeQueue(List<_PendingSale> queue) => _preferences.setString(
    _queueKey,
    jsonEncode(queue.map((item) => item.toJson()).toList()),
  );
}

class _PendingSale {
  const _PendingSale(this.sale);
  final Sale sale;
  Map<String, Object?> toJson() => sale.toJson();
  factory _PendingSale.fromJson(Map<String, dynamic> json) =>
      _PendingSale(Sale.fromJson(json));
}
