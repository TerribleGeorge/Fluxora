import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../domain/business_repository.dart';
import '../domain/catalog_repository.dart';
import '../domain/finance_repository.dart';
import '../domain/sales_repository.dart';
import '../state/auth_bloc.dart';
import '../state/business_bloc.dart';
import '../state/business_event.dart';
import '../state/business_state.dart';
import '../state/catalog_bloc.dart';
import '../state/catalog_event.dart';
import '../state/finance_bloc.dart';
import '../state/finance_event.dart';
import '../state/sales_bloc.dart';
import '../state/sales_event.dart';
import 'app_shell.dart';
import 'business_setup_page.dart';

class BusinessGate extends StatelessWidget {
  const BusinessGate({
    super.key,
    required this.businessRepository,
    required this.financeRepositoryFactory,
    required this.catalogRepositoryFactory,
    required this.salesRepositoryFactory,
  });

  final BusinessRepository businessRepository;
  final FinanceRepository Function(BusinessAccess access)
  financeRepositoryFactory;
  final CatalogRepository Function(BusinessAccess access)
  catalogRepositoryFactory;
  final SalesRepository Function(BusinessAccess access) salesRepositoryFactory;

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
            catalogRepository: catalogRepositoryFactory(state.selected!),
            salesRepository: salesRepositoryFactory(state.selected!),
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
    required this.catalogRepository,
    required this.salesRepository,
  });

  final BusinessAccess access;
  final FinanceRepository repository;
  final CatalogRepository catalogRepository;
  final SalesRepository salesRepository;

  @override
  Widget build(BuildContext context) {
    return Provider<BusinessAccess>.value(
      value: access,
      child: Provider<FinanceRepository>.value(
        value: repository,
        child: MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) =>
                  FinanceBloc(repository)..add(const FinanceStarted()),
            ),
            BlocProvider(
              create: (_) =>
                  CatalogBloc(catalogRepository, access.business.id)
                    ..add(const CatalogStarted()),
            ),
            BlocProvider(
              create: (context) => SalesBloc(
                salesRepository,
                businessId: access.business.id,
                userId: context.read<AuthBloc>().state.identity!.id,
              )..add(const SalesStarted()),
            ),
          ],
          child: const AppShell(),
        ),
      ),
    );
  }
}
