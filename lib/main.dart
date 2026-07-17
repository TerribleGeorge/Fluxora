import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/fluxora_app.dart';
import 'data/local_catalog_repository.dart';
import 'data/local_appointment_repository.dart';
import 'data/local_finance_repository.dart';
import 'data/local_sales_repository.dart';
import 'data/local_operations_repository.dart';
import 'data/google_play_billing_repository.dart';
import 'data/offline_first_catalog_repository.dart';
import 'data/offline_first_appointment_repository.dart';
import 'data/offline_first_finance_repository.dart';
import 'data/offline_first_sales_repository.dart';
import 'data/offline_first_operations_repository.dart';
import 'data/supabase_auth_repository.dart';
import 'data/supabase_business_repository.dart';
import 'data/supabase_catalog_repository.dart';
import 'data/supabase_appointment_repository.dart';
import 'data/supabase_customer_repository.dart';
import 'data/supabase_finance_repository.dart';
import 'data/supabase_product_repository.dart';
import 'data/supabase_public_booking_repository.dart';
import 'data/supabase_checkout_repository.dart';
import 'data/supabase_sales_repository.dart';
import 'data/supabase_operations_repository.dart';
import 'data/cached_subscription_repository.dart';
import 'data/supabase_subscription_repository.dart';
import 'data/supabase_account_lifecycle_repository.dart';
import 'data/unavailable_account_lifecycle_repository.dart';
import 'data/unconfigured_auth_repository.dart';
import 'domain/auth_repository.dart';
import 'domain/appointment_repository.dart';
import 'domain/billing_repository.dart';
import 'domain/business_repository.dart';
import 'domain/catalog_repository.dart';
import 'domain/customer_repository.dart';
import 'domain/finance_repository.dart';
import 'domain/product_repository.dart';
import 'domain/public_booking.dart';
import 'domain/checkout_repository.dart';
import 'domain/sales_repository.dart';
import 'domain/operations_repository.dart';
import 'domain/subscription_repository.dart';
import 'domain/account_lifecycle_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final initialLocation = await _readInitialLocation();
  final dependencies = await _createDependencies();
  runApp(
    FluxoraApp(
      initialLocation: initialLocation,
      authRepository: dependencies.auth,
      businessRepository: dependencies.business,
      financeRepositoryFactory: dependencies.financeFactory,
      appointmentRepositoryFactory: dependencies.appointmentFactory,
      catalogRepositoryFactory: dependencies.catalogFactory,
      customerRepositoryFactory: dependencies.customerFactory,
      productRepositoryFactory: dependencies.productFactory,
      checkoutRepositoryFactory: dependencies.checkoutFactory,
      salesRepositoryFactory: dependencies.salesFactory,
      operationsRepositoryFactory: dependencies.operationsFactory,
      subscriptionRepositoryFactory: dependencies.subscriptionFactory,
      accountLifecycleRepository: dependencies.accountLifecycle,
      billingRepository: dependencies.billing,
      publicBookingRepository: dependencies.publicBooking,
    ),
  );
}

Future<Uri> _readInitialLocation() async {
  if (kIsWeb) return Uri.base;
  try {
    return await AppLinks().getInitialLink() ?? Uri.base;
  } on Exception {
    return Uri.base;
  }
}

typedef _Dependencies = ({
  AuthRepository auth,
  BusinessRepository? business,
  FinanceRepository Function(BusinessAccess access)? financeFactory,
  AppointmentRepository Function(BusinessAccess access)? appointmentFactory,
  CatalogRepository Function(BusinessAccess access)? catalogFactory,
  CustomerRepository Function(BusinessAccess access)? customerFactory,
  ProductRepository Function(BusinessAccess access)? productFactory,
  CheckoutRepository Function(BusinessAccess access)? checkoutFactory,
  SalesRepository Function(BusinessAccess access)? salesFactory,
  OperationsRepository Function(BusinessAccess access)? operationsFactory,
  SubscriptionRepository Function(BusinessAccess access)? subscriptionFactory,
  AccountLifecycleRepository accountLifecycle,
  BillingRepository billing,
  PublicBookingRepository? publicBooking,
});

Future<_Dependencies> _createDependencies() async {
  const url = String.fromEnvironment('SUPABASE_URL');
  const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  if (url.isEmpty || publishableKey.isEmpty) {
    return (
      auth: UnconfiguredAuthRepository(),
      business: null,
      financeFactory: null,
      appointmentFactory: null,
      catalogFactory: null,
      customerFactory: null,
      productFactory: null,
      checkoutFactory: null,
      salesFactory: null,
      operationsFactory: null,
      subscriptionFactory: null,
      accountLifecycle: UnavailableAccountLifecycleRepository(),
      billing: const UnavailableBillingRepository(),
      publicBooking: null,
    );
  }
  final initialization = Supabase.initialize(
    url: url,
    publishableKey: publishableKey,
  );
  final client = Supabase.instance.client;
  User? initialPasswordRecoveryUser;
  final bootstrapAuthSubscription = client.auth.onAuthStateChange.listen(
    (data) {
      final user = data.session?.user;
      if (data.event == AuthChangeEvent.passwordRecovery) {
        initialPasswordRecoveryUser = user;
      } else if (initialPasswordRecoveryUser != null &&
          user?.id != initialPasswordRecoveryUser?.id) {
        initialPasswordRecoveryUser = null;
      }
    },
    onError: (Object error, StackTrace stackTrace) {
      // The permanent repository listener handles the user-facing auth state.
    },
  );
  await initialization;
  await Future<void>.delayed(Duration.zero);
  final authRepository = SupabaseAuthRepository(
    client,
    initialPasswordRecoveryUser: initialPasswordRecoveryUser,
  );
  await bootstrapAuthSubscription.cancel();
  final preferences = await SharedPreferences.getInstance();
  return (
    auth: authRepository,
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
    catalogFactory: (access) {
      final businessId = access.business.id;
      return OfflineFirstCatalogRepository(
        local: LocalCatalogRepository(preferences, businessId),
        remote: SupabaseCatalogRepository(client, businessId),
        preferences: preferences,
        businessId: businessId,
      );
    },
    customerFactory: (access) {
      return SupabaseCustomerRepository(client, access.business.id);
    },
    productFactory: (access) {
      return SupabaseProductRepository(
        client,
        access.business.id,
        access.business.type,
      );
    },
    checkoutFactory: (_) => SupabaseCheckoutRepository(client),
    appointmentFactory: (access) {
      final businessId = access.business.id;
      return OfflineFirstAppointmentRepository(
        local: LocalAppointmentRepository(preferences, businessId),
        remote: SupabaseAppointmentRepository(
          client,
          businessId,
          client.auth.currentUser!.id,
        ),
        preferences: preferences,
        businessId: businessId,
      );
    },
    salesFactory: (access) {
      final businessId = access.business.id;
      return OfflineFirstSalesRepository(
        local: LocalSalesRepository(preferences, businessId),
        remote: SupabaseSalesRepository(client, businessId),
        preferences: preferences,
        businessId: businessId,
      );
    },
    operationsFactory: (access) {
      final businessId = access.business.id;
      return OfflineFirstOperationsRepository(
        local: LocalOperationsRepository(preferences, businessId),
        remote: SupabaseOperationsRepository(client, businessId),
        preferences: preferences,
        businessId: businessId,
      );
    },
    subscriptionFactory: (access) {
      final businessId = access.business.id;
      return CachedSubscriptionRepository(
        remote: SupabaseSubscriptionRepository(client, businessId),
        preferences: preferences,
        businessId: businessId,
      );
    },
    accountLifecycle: SupabaseAccountLifecycleRepository(client),
    billing: GooglePlayBillingRepository(),
    publicBooking: SupabasePublicBookingRepository(client),
  );
}
