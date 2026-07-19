import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/catalog.dart';
import '../domain/catalog_repository.dart';

class LocalCatalogRepository implements CatalogRepository {
  LocalCatalogRepository(this._preferences, this.businessId)
    : _professionalsKey = 'fluxora.professionals.$businessId.v1',
      _servicesKey = 'fluxora.services.$businessId.v1';

  final SharedPreferences _preferences;
  final String businessId;
  final String _professionalsKey;
  final String _servicesKey;

  @override
  Future<List<Professional>> getProfessionals() async {
    final raw = _preferences.getString(_professionalsKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((item) => Professional.fromJson(item as Map<String, dynamic>))
          .toList();
    } on Object {
      return [];
    }
  }

  @override
  Future<List<BeautyService>> getServices() async {
    final raw = _preferences.getString(_servicesKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((item) => BeautyService.fromJson(item as Map<String, dynamic>))
          .toList();
    } on Object {
      return [];
    }
  }

  @override
  Future<void> saveProfessional(Professional professional) async {
    final items = await getProfessionals();
    final index = items.indexWhere((item) => item.id == professional.id);
    index < 0 ? items.add(professional) : items[index] = professional;
    await overwriteProfessionals(items);
  }

  @override
  Future<void> configureProfessionalLogin({
    required String professionalId,
    required String loginName,
    required String password,
  }) {
    throw UnsupportedError(
      'A criação de login de funcionário exige conexão com o servidor.',
    );
  }

  @override
  Future<void> saveService(BeautyService service) async {
    final items = await getServices();
    final index = items.indexWhere((item) => item.id == service.id);
    index < 0 ? items.add(service) : items[index] = service;
    await overwriteServices(items);
  }

  @override
  Future<void> setProfessionalActive(String id, bool active) async {
    final items = await getProfessionals();
    final index = items.indexWhere((item) => item.id == id);
    if (index >= 0) items[index] = items[index].copyWith(active: active);
    await overwriteProfessionals(items);
  }

  @override
  Future<void> setServiceActive(String id, bool active) async {
    final items = await getServices();
    final index = items.indexWhere((item) => item.id == id);
    if (index >= 0) items[index] = items[index].copyWith(active: active);
    await overwriteServices(items);
  }

  Future<void> overwriteProfessionals(List<Professional> items) {
    return _preferences.setString(
      _professionalsKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> overwriteServices(List<BeautyService> items) {
    return _preferences.setString(
      _servicesKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }
}
