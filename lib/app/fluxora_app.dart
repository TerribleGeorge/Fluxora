import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../l10n/supported_locales.dart';
import '../data/auth_redirect_configuration.dart';
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
import '../domain/public_booking.dart';
import '../domain/subscription_repository.dart';
import '../domain/account_lifecycle_repository.dart';
import '../state/auth_bloc.dart';
import '../state/auth_state.dart';
import '../ui/auth_gate.dart';
import '../ui/public_booking_page.dart';
import '../ui/startup_splash_page.dart';
import 'theme.dart';

class FluxoraApp extends StatelessWidget {
  const FluxoraApp({
    super.key,
    required this.initialLocation,
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
    required this.publicBookingRepository,
  });

  final Uri initialLocation;
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
  final ProductRepository Function(BusinessAccess access)?
  productRepositoryFactory;
  final CheckoutRepository Function(BusinessAccess access)?
  checkoutRepositoryFactory;
  final SalesRepository Function(BusinessAccess access)? salesRepositoryFactory;
  final OperationsRepository Function(BusinessAccess access)?
  operationsRepositoryFactory;
  final SubscriptionRepository Function(BusinessAccess access)?
  subscriptionRepositoryFactory;
  final AccountLifecycleRepository accountLifecycleRepository;
  final BillingRepository billingRepository;
  final PublicBookingRepository? publicBookingRepository;

  @override
  Widget build(BuildContext context) {
    final initialPasswordRecovery = isPasswordRecoveryLocation(initialLocation);
    return MultiProvider(
      providers: [
        Provider<AccountLifecycleRepository>.value(
          value: accountLifecycleRepository,
        ),
        Provider<BillingRepository>.value(value: billingRepository),
        Provider<PublicBookingRepository?>.value(
          value: publicBookingRepository,
        ),
      ],
      child: BlocProvider(
        create: (_) => AuthBloc(
          authRepository,
          initialPasswordRecovery: initialPasswordRecovery,
        ),
        child: MaterialApp(
          title: 'Fluxora',
          debugShowCheckedModeBanner: false,
          supportedLocales: FluxoraSupportedLocales.all,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          theme: FluxoraTheme.light,
          darkTheme: FluxoraTheme.dark,
          themeMode: ThemeMode.dark,
          initialRoute: publicBookingRouteFromLocation(Uri.base) ?? '/',
          onGenerateRoute: (settings) {
            final slug = publicBookingSlugFromRoute(settings.name);
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => slug == null
                  ? _buildAuthenticatedHome(initialPasswordRecovery)
                  : publicBookingRepository == null
                  ? const _PublicBookingConfigurationError()
                  : PublicBookingPage(
                      slug: slug,
                      repository: publicBookingRepository!,
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAuthenticatedHome(bool initialPasswordRecovery) {
    return _RecoveryAwareSplash(
      skipInitially: initialPasswordRecovery,
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
    );
  }
}

class _RecoveryAwareSplash extends StatefulWidget {
  const _RecoveryAwareSplash({
    required this.child,
    required this.skipInitially,
  });

  final Widget child;
  final bool skipInitially;

  @override
  State<_RecoveryAwareSplash> createState() => _RecoveryAwareSplashState();
}

class _RecoveryAwareSplashState extends State<_RecoveryAwareSplash> {
  late bool _skipSplash;

  @override
  void initState() {
    super.initState();
    _skipSplash = widget.skipInitially;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          !_isRecoveryStatus(previous.status) &&
          _isRecoveryStatus(current.status),
      listener: (context, state) {
        if (!_skipSplash) setState(() => _skipSplash = true);
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        buildWhen: (previous, current) =>
            _isRecoveryStatus(previous.status) ||
            _isRecoveryStatus(current.status),
        builder: (context, state) {
          if (_skipSplash || _isRecoveryStatus(state.status)) {
            return widget.child;
          }
          return StartupSplashPage(child: widget.child);
        },
      ),
    );
  }

  bool _isRecoveryStatus(AuthStatus status) {
    return status == AuthStatus.recoveryPending ||
        status == AuthStatus.recovery;
  }
}

String? publicBookingRouteFromLocation(Uri location) {
  final fromFragment = publicBookingSlugFromRoute(location.fragment);
  if (fromFragment != null) return '/agendar/$fromFragment';
  final fromPath = publicBookingSlugFromRoute(location.path);
  if (fromPath != null) return '/agendar/$fromPath';
  final fromQuery = location.queryParameters['agendar']?.trim();
  if (fromQuery == null || fromQuery.isEmpty) return null;
  return '/agendar/${Uri.encodeComponent(fromQuery)}';
}

String? publicBookingSlugFromRoute(String? routeName) {
  if (routeName == null || routeName.isEmpty) return null;
  final normalized = routeName.startsWith('#')
      ? routeName.substring(1)
      : routeName;
  final uri = Uri.tryParse(normalized);
  if (uri == null) return null;
  final segments = uri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (segments.length != 2 || segments.first != 'agendar') return null;
  final slug = Uri.decodeComponent(segments.last).trim().toLowerCase();
  if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(slug)) return null;
  return slug;
}

class _PublicBookingConfigurationError extends StatelessWidget {
  const _PublicBookingConfigurationError();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Este link de agendamento ainda não está conectado ao servidor.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
