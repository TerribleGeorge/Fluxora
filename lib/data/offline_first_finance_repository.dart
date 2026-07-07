import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/finance_repository.dart';
import '../domain/transaction.dart';
import 'local_finance_repository.dart';

class OfflineFirstFinanceRepository implements FinanceRepository {
  OfflineFirstFinanceRepository({
    required LocalFinanceRepository local,
    required FinanceRepository remote,
    required SharedPreferences preferences,
    required String businessId,
  }) : _local = local,
       _remote = remote,
       _preferences = preferences,
       _queueKey = 'fluxora.sync_queue.$businessId.v1';

  final LocalFinanceRepository _local;
  final FinanceRepository _remote;
  final SharedPreferences _preferences;
  final String _queueKey;

  @override
  Future<List<FinanceTransaction>> getTransactions() async {
    await _flushQueue();
    final localItems = await _local.getTransactions();
    try {
      final remoteItems = await _remote.getTransactions();
      final pendingIds = _readQueue().map((item) => item.id).toSet();
      final merged = <String, FinanceTransaction>{
        for (final item in remoteItems) item.id: item,
      };
      for (final item in localItems) {
        if (pendingIds.contains(item.id)) merged[item.id] = item;
      }
      final visible = merged.values.where((item) => !item.deleted).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      await _local.overwriteTransactions(visible);
      return visible;
    } on Exception {
      return localItems;
    }
  }

  @override
  Future<void> saveTransaction(FinanceTransaction transaction) async {
    await _local.saveTransaction(transaction);
    await _sendOrQueue(_SyncOperation.upsert(transaction));
  }

  @override
  Future<void> replaceTransaction(FinanceTransaction transaction) async {
    await _local.replaceTransaction(transaction);
    await _sendOrQueue(_SyncOperation.upsert(transaction));
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await _local.deleteTransaction(id);
    await _sendOrQueue(_SyncOperation.delete(id));
  }

  Future<void> _sendOrQueue(_SyncOperation operation) async {
    try {
      await _send(operation);
    } on Exception {
      final queue = _readQueue()
        ..removeWhere((item) => item.id == operation.id)
        ..add(operation);
      await _writeQueue(queue);
    }
  }

  Future<void> _flushQueue() async {
    final queue = _readQueue();
    if (queue.isEmpty) return;
    final remaining = <_SyncOperation>[];
    for (var index = 0; index < queue.length; index++) {
      try {
        await _send(queue[index]);
      } on Exception {
        remaining.addAll(queue.skip(index));
        break;
      }
    }
    await _writeQueue(remaining);
  }

  Future<void> _send(_SyncOperation operation) {
    return switch (operation.type) {
      _SyncOperationType.upsert => _remote.replaceTransaction(
        operation.transaction!,
      ),
      _SyncOperationType.delete => _remote.deleteTransaction(operation.id),
    };
  }

  List<_SyncOperation> _readQueue() {
    final raw = _preferences.getString(_queueKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => _SyncOperation.fromJson(item as Map<String, dynamic>))
          .toList();
    } on Object {
      return [];
    }
  }

  Future<void> _writeQueue(List<_SyncOperation> queue) {
    return _preferences.setString(
      _queueKey,
      jsonEncode(queue.map((item) => item.toJson()).toList()),
    );
  }
}

enum _SyncOperationType { upsert, delete }

class _SyncOperation {
  const _SyncOperation._(this.type, this.id, this.transaction);

  factory _SyncOperation.upsert(FinanceTransaction transaction) {
    return _SyncOperation._(
      _SyncOperationType.upsert,
      transaction.id,
      transaction,
    );
  }

  factory _SyncOperation.delete(String id) {
    return _SyncOperation._(_SyncOperationType.delete, id, null);
  }

  final _SyncOperationType type;
  final String id;
  final FinanceTransaction? transaction;

  Map<String, Object> toJson() => {
    'type': type.name,
    'id': id,
    if (transaction != null) 'transaction': transaction!.toJson(),
  };

  factory _SyncOperation.fromJson(Map<String, dynamic> json) {
    final type = _SyncOperationType.values.byName(json['type'] as String);
    final transactionJson = json['transaction'];
    return _SyncOperation._(
      type,
      json['id'] as String,
      transactionJson is Map<String, dynamic>
          ? FinanceTransaction.fromJson(transactionJson)
          : null,
    );
  }
}
