import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../domain/auth_repository.dart';
import '../domain/billing_repository.dart';
import '../domain/business_repository.dart';
import '../domain/catalog_repository.dart';
import '../domain/finance_repository.dart';
import '../domain/sales_repository.dart';
import '../domain/operations_repository.dart';
import '../domain/subscription_repository.dart';
import '../domain/account_lifecycle_repository.dart';
import '../state/auth_bloc.dart';
import '../ui/auth_gate.dart';
import '../ui/startup_splash_page.dart';
import 'theme.dart';

class FluxoraApp extends StatelessWidget {
  const FluxoraApp({
    super.key,
    required this.authRepository,
    required this.businessRepository,
    required this.financeRepositoryFactory,
    required this.catalogRepositoryFactory,
    required this.salesRepositoryFactory,
    required this.operationsRepositoryFactory,
    required this.subscriptionRepositoryFactory,
    required this.accountLifecycleRepository,
    required this.billingRepository,
  });

  final AuthRepository authRepository;
  final BusinessRepository? businessRepository;
  final FinanceRepository Function(BusinessAccess access)?
  financeRepositoryFactory;
  final CatalogRepository Function(BusinessAccess access)?
  catalogRepositoryFactory;
  final SalesRepository Function(BusinessAccess access)? salesRepositoryFactory;
  final OperationsRepository Function(BusinessAccess access)?
  operationsRepositoryFactory;
  final SubscriptionRepository Function(BusinessAccess access)?
  subscriptionRepositoryFactory;
  final AccountLifecycleRepository accountLifecycleRepository;
  final BillingRepository billingRepository;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AccountLifecycleRepository>.value(
          value: accountLifecycleRepository,
        ),
        Provider<BillingRepository>.value(value: billingRepository),
      ],
      child: BlocProvider(
        create: (_) => AuthBloc(authRepository),
        child: MaterialApp(
          title: 'Fluxora',
          debugShowCheckedModeBanner: false,
          theme: FluxoraTheme.light,
          darkTheme: FluxoraTheme.dark,
          themeMode: ThemeMode.dark,
          home: StartupSplashPage(
            child: AuthGate(
              businessRepository: businessRepository,
              financeRepositoryFactory: financeRepositoryFactory,
              catalogRepositoryFactory: catalogRepositoryFactory,
              salesRepositoryFactory: salesRepositoryFactory,
              operationsRepositoryFactory: operationsRepositoryFactory,
              subscriptionRepositoryFactory: subscriptionRepositoryFactory,
            ),
          ),
        ),
      ),
    );
  }
}
