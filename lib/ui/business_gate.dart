import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../domain/appointment_repository.dart';
import '../domain/business_repository.dart';
import '../domain/catalog_repository.dart';
import '../domain/customer_repository.dart';
import '../domain/finance_repository.dart';
import '../domain/product_repository.dart';
import '../domain/checkout_repository.dart';
import '../domain/sales_repository.dart';
import '../domain/operations_repository.dart';
import '../domain/subscription_repository.dart';
import '../state/auth_bloc.dart';
import '../state/appointment_bloc.dart';
import '../state/appointment_event.dart';
import '../state/business_bloc.dart';
import '../state/business_event.dart';
import '../state/business_state.dart';
import '../state/catalog_bloc.dart';
import '../state/catalog_event.dart';
import '../state/finance_bloc.dart';
import '../state/finance_event.dart';
import '../state/customer_bloc.dart';
import '../state/customer_event.dart';
import '../state/sales_bloc.dart';
import '../state/sales_event.dart';
import '../state/operations_bloc.dart';
import '../state/operations_event.dart';
import '../state/product_bloc.dart';
import '../state/product_event.dart';
import '../state/subscription_bloc.dart';
import '../state/subscription_event.dart';
import 'subscription_shell.dart';
import 'business_setup_page.dart';

class BusinessGate extends StatelessWidget {
  const BusinessGate({
    super.key,
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
  });

  final BusinessRepository businessRepository;
  final FinanceRepository Function(BusinessAccess access)
  financeRepositoryFactory;
  final AppointmentRepository Function(BusinessAccess access)
  appointmentRepositoryFactory;
  final CatalogRepository Function(BusinessAccess access)
  catalogRepositoryFactory;
  final CustomerRepository Function(BusinessAccess access)
  customerRepositoryFactory;
  final ProductRepository Function(BusinessAccess access) productRepositoryFactory;
  final CheckoutRepository Function(BusinessAccess access)
  checkoutRepositoryFactory;
  final SalesRepository Function(BusinessAccess access) salesRepositoryFactory;
  final OperationsRepository Function(BusinessAccess access)
  operationsRepositoryFactory;
  final SubscriptionRepository Function(BusinessAccess access)
  subscriptionRepositoryFactory;

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
            appointmentRepository: appointmentRepositoryFactory(
              state.selected!,
            ),
            catalogRepository: catalogRepositoryFactory(state.selected!),
            customerRepository: customerRepositoryFactory(state.selected!),
            productRepository: productRepositoryFactory(state.selected!),
            checkoutRepository: checkoutRepositoryFactory(state.selected!),
            salesRepository: salesRepositoryFactory(state.selected!),
            operationsRepository: operationsRepositoryFactory(state.selected!),
            subscriptionRepository: subscriptionRepositoryFactory(
              state.selected!,
            ),
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
    required this.appointmentRepository,
    required this.catalogRepository,
    required this.customerRepository,
    required this.productRepository,
    required this.checkoutRepository,
    required this.salesRepository,
    required this.operationsRepository,
    required this.subscriptionRepository,
  });

  final BusinessAccess access;
  final FinanceRepository repository;
  final AppointmentRepository appointmentRepository;
  final CatalogRepository catalogRepository;
  final CustomerRepository customerRepository;
  final ProductRepository productRepository;
  final CheckoutRepository checkoutRepository;
  final SalesRepository salesRepository;
  final OperationsRepository operationsRepository;
  final SubscriptionRepository subscriptionRepository;

  @override
  Widget build(BuildContext context) {
    return Provider<BusinessAccess>.value(
      value: access,
      child: MultiProvider(
        providers: [
          Provider<FinanceRepository>.value(value: repository),
          Provider<CheckoutRepository>.value(value: checkoutRepository),
        ],
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
              create: (_) =>
                  CustomerBloc(customerRepository)..add(const CustomerStarted()),
            ),
            BlocProvider(
              create: (_) => ProductBloc(
                productRepository,
                businessId: access.business.id,
                businessType: access.business.type,
              )..add(const ProductStarted()),
            ),
            BlocProvider(
              create: (context) {
                final userId = context.read<AuthBloc>().state.identity!.id;
                return AppointmentBloc(
                  appointmentRepository,
                  businessId: access.business.id,
                  userId: userId,
                )..add(const AppointmentsStarted());
              },
            ),
            BlocProvider(
              create: (context) => SalesBloc(
                salesRepository,
                catalogRepository: catalogRepository,
                businessId: access.business.id,
                userId: context.read<AuthBloc>().state.identity!.id,
              )..add(const SalesStarted()),
            ),
            BlocProvider(
              create: (context) => OperationsBloc(
                operationsRepository,
                salesRepository,
                financeRepository: repository,
                businessId: access.business.id,
                userId: context.read<AuthBloc>().state.identity!.id,
              )..add(const OperationsStarted()),
            ),
            BlocProvider(
              create: (_) =>
                  SubscriptionBloc(subscriptionRepository)
                    ..add(const SubscriptionStarted()),
            ),
          ],
          child: Theme(
            data: FluxoraTheme.businessDark(access.business.type),
            child: const SubscriptionShell(),
          ),
        ),
      ),
    );
  }
}
