import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/business_repository.dart';
import '../domain/catalog_repository.dart';
import '../domain/finance_repository.dart';
import '../state/auth_bloc.dart';
import '../state/auth_state.dart';
import 'auth_page.dart';
import 'business_gate.dart';
import 'password_recovery_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.businessRepository,
    required this.financeRepositoryFactory,
    required this.catalogRepositoryFactory,
  });

  final BusinessRepository? businessRepository;
  final FinanceRepository Function(BusinessAccess access)?
  financeRepositoryFactory;
  final CatalogRepository Function(BusinessAccess access)?
  catalogRepositoryFactory;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (previous, current) => previous.status != current.status,
      builder: (context, state) => switch (state.status) {
        AuthStatus.authenticated =>
          businessRepository == null ||
                  financeRepositoryFactory == null ||
                  catalogRepositoryFactory == null
              ? const _ConfigurationError()
              : BusinessGate(
                  businessRepository: businessRepository!,
                  financeRepositoryFactory: financeRepositoryFactory!,
                  catalogRepositoryFactory: catalogRepositoryFactory!,
                ),
        AuthStatus.recovery => const PasswordRecoveryPage(),
        AuthStatus.unauthenticated || AuthStatus.loading => const AuthPage(),
      },
    );
  }
}

class _ConfigurationError extends StatelessWidget {
  const _ConfigurationError();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'O ambiente do Fluxora ainda não está conectado ao servidor.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
