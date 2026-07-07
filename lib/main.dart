import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/fluxora_app.dart';
import 'data/local_finance_repository.dart';
import 'data/offline_first_finance_repository.dart';
import 'data/supabase_auth_repository.dart';
import 'data/supabase_business_repository.dart';
import 'data/supabase_finance_repository.dart';
import 'data/unconfigured_auth_repository.dart';
import 'domain/auth_repository.dart';
import 'domain/business_repository.dart';
import 'domain/finance_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = await _createDependencies();
  runApp(
    FluxoraApp(
      authRepository: dependencies.auth,
      businessRepository: dependencies.business,
      financeRepositoryFactory: dependencies.financeFactory,
    ),
  );
}

typedef _Dependencies = ({
  AuthRepository auth,
  BusinessRepository? business,
  FinanceRepository Function(BusinessAccess access)? financeFactory,
});

Future<_Dependencies> _createDependencies() async {
  const url = String.fromEnvironment('SUPABASE_URL');
  const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  if (url.isEmpty || publishableKey.isEmpty) {
    return (
      auth: UnconfiguredAuthRepository(),
      business: null,
      financeFactory: null,
    );
  }
  await Supabase.initialize(url: url, publishableKey: publishableKey);
  final client = Supabase.instance.client;
  final preferences = await SharedPreferences.getInstance();
  return (
    auth: SupabaseAuthRepository(client),
    business: SupabaseBusinessRepository(client),
    financeFactory: (access) {
      final businessId = access.business.id;
      final local = LocalFinanceRepository(
        preferences,
        storageKey: 'fluxora.transactions.$businessId.v1',
      );
      final remote = SupabaseFinanceRepository(
        client: client,
        businessId: businessId,
        userId: client.auth.currentUser!.id,
      );
      return OfflineFirstFinanceRepository(
        local: local,
        remote: remote,
        preferences: preferences,
        businessId: businessId,
      );
    },
  );
}
