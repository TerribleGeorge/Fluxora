import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/catalog.dart';
import '../domain/catalog_repository.dart';

class SupabaseCatalogRepository implements CatalogRepository {
  SupabaseCatalogRepository(this._client, this.businessId);

  final SupabaseClient _client;
  final String businessId;

  @override
  Future<List<Professional>> getProfessionals() async {
    final rows = await _client
        .from('professionals')
        .select()
        .eq('business_id', businessId)
        .order('name');
    return rows.map(_professionalFromRow).toList(growable: false);
  }

  @override
  Future<List<BeautyService>> getServices() async {
    final rows = await _client
        .from('beauty_services')
        .select()
        .eq('business_id', businessId)
        .order('name');
    return rows.map(_serviceFromRow).toList(growable: false);
  }

  @override
  Future<void> saveProfessional(Professional professional) async {
    await _client.from('professionals').upsert({
      'id': professional.id,
      'business_id': businessId,
      'user_id': professional.userId,
      'name': professional.name,
      'phone': professional.phone,
      'email': professional.email,
      'default_commission_percent': professional.defaultCommissionPercent,
      'active': professional.active,
      'login_enabled': professional.loginEnabled,
      'login_name': professional.loginName,
    });
  }

  @override
  Future<void> configureProfessionalLogin({
    required String professionalId,
    required String loginName,
    required String password,
  }) async {
    final response = await _client.functions.invoke(
      'configure-employee-login',
      body: {
        'businessId': businessId,
        'professionalId': professionalId,
        'loginName': loginName,
        'password': password,
      },
    );
    if (response.status < 200 || response.status >= 300) {
      throw Exception('Unable to configure professional login');
    }
  }

  @override
  Future<void> saveService(BeautyService service) async {
    await _client.from('beauty_services').upsert({
      'id': service.id,
      'business_id': businessId,
      'name': service.name,
      'category': service.category,
      'price': service.price,
      'duration_minutes': service.durationMinutes,
      'commission_type': service.commissionType.name,
      'commission_value': service.commissionValue,
      'active': service.active,
    });
  }

  @override
  Future<void> setProfessionalActive(String id, bool active) async {
    await _client
        .from('professionals')
        .update({'active': active})
        .eq('business_id', businessId)
        .eq('id', id);
  }

  @override
  Future<void> setServiceActive(String id, bool active) async {
    await _client
        .from('beauty_services')
        .update({'active': active})
        .eq('business_id', businessId)
        .eq('id', id);
  }

  Professional _professionalFromRow(Map<String, dynamic> row) => Professional(
    id: row['id'] as String,
    businessId: row['business_id'] as String,
    userId: row['user_id'] as String?,
    name: row['name'] as String,
    phone: row['phone'] as String? ?? '',
    email: row['email'] as String? ?? '',
    defaultCommissionPercent: (row['default_commission_percent'] as num)
        .toDouble(),
    active: row['active'] as bool,
    loginEnabled: row['login_enabled'] as bool? ?? false,
    loginName: row['login_name'] as String? ?? '',
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
  );

  BeautyService _serviceFromRow(Map<String, dynamic> row) => BeautyService(
    id: row['id'] as String,
    businessId: row['business_id'] as String,
    name: row['name'] as String,
    category: row['category'] as String,
    price: (row['price'] as num).toDouble(),
    durationMinutes: row['duration_minutes'] as int,
    commissionType: ServiceCommissionType.values.byName(
      row['commission_type'] as String,
    ),
    commissionValue: (row['commission_value'] as num).toDouble(),
    active: row['active'] as bool,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
  );
}
