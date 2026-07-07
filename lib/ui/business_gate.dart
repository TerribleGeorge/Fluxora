import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../domain/business_repository.dart';
import '../domain/finance_repository.dart';
import '../state/business_bloc.dart';
import '../state/business_event.dart';
import '../state/business_state.dart';
import '../state/finance_bloc.dart';
import '../state/finance_event.dart';
import 'app_shell.dart';
import 'business_setup_page.dart';

class BusinessGate extends StatelessWidget {
  const BusinessGate({
    super.key,
    required this.businessRepository,
    required this.financeRepositoryFactory,
  });

  final BusinessRepository businessRepository;
  final FinanceRepository Function(BusinessAccess access)
  financeRepositoryFactory;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          BusinessBloc(businessRepository)..add(const BusinessesStarted()),
      child: BlocBuilder<BusinessBloc, BusinessState>(
        builder: (context, state) => switch (state.status) {
          BusinessStatus.initial || BusinessStatus.loading => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          BusinessStatus.requiresBusiness => const BusinessSetupPage(),
          BusinessStatus.failure => Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  state.message ?? 'Não foi possível abrir o estabelecimento.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          BusinessStatus.ready => _BusinessWorkspace(
            key: ValueKey(state.selected!.business.id),
            access: state.selected!,
            repository: financeRepositoryFactory(state.selected!),
          ),
        },
      ),
    );
  }
}

class _BusinessWorkspace extends StatelessWidget {
  const _BusinessWorkspace({
    super.key,
    required this.access,
    required this.repository,
  });

  final BusinessAccess access;
  final FinanceRepository repository;

  @override
  Widget build(BuildContext context) {
    return Provider<BusinessAccess>.value(
      value: access,
      child: Provider<FinanceRepository>.value(
        value: repository,
        child: BlocProvider(
          create: (_) => FinanceBloc(repository)..add(const FinanceStarted()),
          child: const AppShell(),
        ),
      ),
    );
  }
}
