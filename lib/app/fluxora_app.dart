import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../domain/auth_repository.dart';
import '../domain/billing_repository.dart';
import '../domain/business_repository.dart';
import '../domain/appointment_repository.dart';
import '../domain/catalog_repository.dart';
import '../domain/customer_repository.dart';
import '../domain/finance_repository.dart';
import '../domain/product_repository.dart';
import '../domain/checkout_repository.dart';
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
    required this.appointmentRepositoryFactory,
    required this.catalogRepositoryFactory,
    required this.customerRepositoryFactory,
    required this.productRepositoryFactory,
    required this.checkoutRepositoryFactory,
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
  final AppointmentRepository Function(BusinessAccess access)?
  appointmentRepositoryFactory;
  final CatalogRepository Function(BusinessAccess access)?
  catalogRepositoryFactory;
  final CustomerRepository Function(BusinessAccess access)?
  customerRepositoryFactory;
  final ProductRepository Function(BusinessAccess access)? productRepositoryFactory;
  final CheckoutRepository Function(BusinessAccess access)?
  checkoutRepositoryFactory;
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
              appointmentRepositoryFactory: appointmentRepositoryFactory,
              catalogRepositoryFactory: catalogRepositoryFactory,
              customerRepositoryFactory: customerRepositoryFactory,
              productRepositoryFactory: productRepositoryFactory,
              checkoutRepositoryFactory: checkoutRepositoryFactory,
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
