import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/catalog.dart';
import '../domain/catalog_repository.dart';
import 'local_catalog_repository.dart';

class OfflineFirstCatalogRepository implements CatalogRepository {
  OfflineFirstCatalogRepository({
    required LocalCatalogRepository local,
    required CatalogRepository remote,
    required SharedPreferences preferences,
    required String businessId,
  }) : _local = local,
       _remote = remote,
       _preferences = preferences,
       _queueKey = 'fluxora.catalog_sync.$businessId.v1';

  final LocalCatalogRepository _local;
  final CatalogRepository _remote;
  final SharedPreferences _preferences;
  final String _queueKey;

  @override
  Future<List<Professional>> getProfessionals() async {
    await _flush();
    final local = await _local.getProfessionals();
    try {
      final remote = await _remote.getProfessionals();
      final pending = _pendingIds(_CatalogEntity.professional);
      final merged = {for (final item in remote) item.id: item};
      for (final item in local) {
        if (pending.contains(item.id)) merged[item.id] = item;
      }
      final result = merged.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      await _local.overwriteProfessionals(result);
      return result;
    } on Exception {
      return local;
    }
  }

  @override
  Future<List<BeautyService>> getServices() async {
    await _flush();
    final local = await _local.getServices();
    try {
      final remote = await _remote.getServices();
      final pending = _pendingIds(_CatalogEntity.service);
      final merged = {for (final item in remote) item.id: item};
      for (final item in local) {
        if (pending.contains(item.id)) merged[item.id] = item;
      }
      final result = merged.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      await _local.overwriteServices(result);
      return result;
    } on Exception {
      return local;
    }
  }

  @override
  Future<void> saveProfessional(Professional professional) async {
    await _local.saveProfessional(professional);
    await _sendOrQueue(_CatalogOperation.professional(professional));
  }

  @override
  Future<void> saveService(BeautyService service) async {
    await _local.saveService(service);
    await _sendOrQueue(_CatalogOperation.service(service));
  }

  @override
  Future<void> setProfessionalActive(String id, bool active) async {
    await _local.setProfessionalActive(id, active);
    final item = (await _local.getProfessionals()).firstWhere(
      (professional) => professional.id == id,
    );
    await _sendOrQueue(_CatalogOperation.professional(item));
  }

  @override
  Future<void> setServiceActive(String id, bool active) async {
    await _local.setServiceActive(id, active);
    final item = (await _local.getServices()).firstWhere(
      (service) => service.id == id,
    );
    await _sendOrQueue(_CatalogOperation.service(item));
  }

  Set<String> _pendingIds(_CatalogEntity entity) => _readQueue()
      .where((item) => item.entity == entity)
      .map((item) => item.id)
      .toSet();

  Future<void> _sendOrQueue(_CatalogOperation operation) async {
    try {
      await _send(operation);
    } on Exception {
      final queue = _readQueue()
        ..removeWhere(
          (item) => item.entity == operation.entity && item.id == operation.id,
        )
        ..add(operation);
      await _writeQueue(queue);
    }
  }

  Future<void> _flush() async {
    final queue = _readQueue();
    if (queue.isEmpty) return;
    final remaining = <_CatalogOperation>[];
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

  Future<void> _send(_CatalogOperation operation) => switch (operation.entity) {
    _CatalogEntity.professional => _remote.saveProfessional(
      operation.professional!,
    ),
    _CatalogEntity.service => _remote.saveService(operation.service!),
  };

  List<_CatalogOperation> _readQueue() {
    final raw = _preferences.getString(_queueKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map(
            (item) => _CatalogOperation.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } on Object {
      return [];
    }
  }

  Future<void> _writeQueue(List<_CatalogOperation> queue) =>
      _preferences.setString(
        _queueKey,
        jsonEncode(queue.map((item) => item.toJson()).toList()),
      );
}

enum _CatalogEntity { professional, service }

class _CatalogOperation {
  const _CatalogOperation._(
    this.entity,
    this.id,
    this.professional,
    this.service,
  );

  factory _CatalogOperation.professional(Professional item) =>
      _CatalogOperation._(_CatalogEntity.professional, item.id, item, null);

  factory _CatalogOperation.service(BeautyService item) =>
      _CatalogOperation._(_CatalogEntity.service, item.id, null, item);

  final _CatalogEntity entity;
  final String id;
  final Professional? professional;
  final BeautyService? service;

  Map<String, Object?> toJson() => {
    'entity': entity.name,
    'id': id,
    'professional': professional?.toJson(),
    'service': service?.toJson(),
  };

  factory _CatalogOperation.fromJson(Map<String, dynamic> json) {
    final entity = _CatalogEntity.values.byName(json['entity'] as String);
    return _CatalogOperation._(
      entity,
      json['id'] as String,
      json['professional'] is Map<String, dynamic>
          ? Professional.fromJson(json['professional'] as Map<String, dynamic>)
          : null,
      json['service'] is Map<String, dynamic>
          ? BeautyService.fromJson(json['service'] as Map<String, dynamic>)
          : null,
    );
  }
}
