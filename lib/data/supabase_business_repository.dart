import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/account.dart';
import '../domain/auth_repository.dart';
import '../domain/business_repository.dart';

class SupabaseBusinessRepository implements BusinessRepository {
  SupabaseBusinessRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<BusinessAccess>> getBusinesses() async {
    final userId = _requireUserId();
    try {
      final rows = await _client
          .from('memberships')
          .select('*, businesses(*)')
          .eq('user_id', userId)
          .eq('active', true);
      return rows.map(_fromMembershipRow).toList(growable: false);
    } on PostgrestException {
      throw const AuthFailure(
        'Não foi possível carregar seus estabelecimentos.',
      );
    }
  }

  @override
  Future<BusinessAccess> createBusiness({
    required String name,
    required BusinessType type,
    String document = '',
    String phone = '',
    String referralCode = '',
  }) async {
    try {
      final row = await _client.rpc<Map<String, dynamic>>(
        'create_business',
        params: {
          'business_name': name.trim(),
          'business_kind': type.name,
          'business_document': document.trim(),
          'business_phone': phone.trim(),
          'referral_code': referralCode.trim(),
        },
      );
      final business = _businessFromRow(row);
      final accesses = await getBusinesses();
      return accesses.firstWhere((item) => item.business.id == business.id);
    } on PostgrestException {
      throw const AuthFailure(
        'Não foi possível criar o estabelecimento. Tente novamente.',
      );
    }
  }

  BusinessAccess _fromMembershipRow(Map<String, dynamic> row) {
    final businessRow = row['businesses'];
    if (businessRow is! Map<String, dynamic>) {
      throw const FormatException('Estabelecimento ausente no vínculo.');
    }
    return BusinessAccess(
      business: _businessFromRow(businessRow),
      membership: BusinessMembership(
        id: row['id'] as String,
        businessId: row['business_id'] as String,
        userId: row['user_id'] as String,
        role: MembershipRole.values.byName(row['role'] as String),
        createdAt: DateTime.parse(row['created_at'] as String),
        active: row['active'] as bool? ?? true,
      ),
    );
  }

  BeautyBusiness _businessFromRow(Map<String, dynamic> row) {
    return BeautyBusiness(
      id: row['id'] as String,
      name: row['name'] as String,
      type: BusinessType.values.byName(row['type'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
      document: row['document'] as String? ?? '',
      phone: row['phone'] as String? ?? '',
      referralCode: row['referral_code'] as String? ?? '',
    );
  }

  String _requireUserId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AuthFailure('Acesso não autenticado.');
    return userId;
  }
}
