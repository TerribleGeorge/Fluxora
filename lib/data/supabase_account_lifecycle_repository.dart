import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/account_lifecycle_repository.dart';
import '../domain/auth_repository.dart';

class SupabaseAccountLifecycleRepository implements AccountLifecycleRepository {
  SupabaseAccountLifecycleRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<void> deleteAccount() async {
    final response = await _client.functions.invoke('delete-account');
    if (response.status < 200 || response.status >= 300) {
      throw const AuthFailure(
        'Não foi possível excluir a conta. Fale com o suporte.',
      );
    }
    await _client.auth.signOut(scope: SignOutScope.local);
  }
}
