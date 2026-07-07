import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/auth_repository.dart';
import '../domain/business_repository.dart';
import '../domain/catalog_repository.dart';
import '../domain/finance_repository.dart';
import '../state/auth_bloc.dart';
import '../ui/auth_gate.dart';
import 'theme.dart';

class FluxoraApp extends StatelessWidget {
  const FluxoraApp({
    super.key,
    required this.authRepository,
    required this.businessRepository,
    required this.financeRepositoryFactory,
    required this.catalogRepositoryFactory,
  });

  final AuthRepository authRepository;
  final BusinessRepository? businessRepository;
  final FinanceRepository Function(BusinessAccess access)?
  financeRepositoryFactory;
  final CatalogRepository Function(BusinessAccess access)?
  catalogRepositoryFactory;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthBloc(authRepository),
      child: MaterialApp(
        title: 'Fluxora',
        debugShowCheckedModeBanner: false,
        theme: FluxoraTheme.light,
        darkTheme: FluxoraTheme.dark,
        themeMode: ThemeMode.dark,
        home: AuthGate(
          businessRepository: businessRepository,
          financeRepositoryFactory: financeRepositoryFactory,
          catalogRepositoryFactory: catalogRepositoryFactory,
        ),
      ),
    );
  }
}
