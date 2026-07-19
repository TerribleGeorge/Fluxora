import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/domain/auth_repository.dart';
import 'package:fluxora/state/auth_bloc.dart';
import 'package:fluxora/state/auth_state.dart';
import 'package:fluxora/ui/password_recovery_page.dart';

void main() {
  testWidgets('senhas diferentes não solicitam atualização', (tester) async {
    final repository = _FakeAuthRepository(identity: _identity);
    final bloc = AuthBloc(repository, initialPasswordRecovery: true);
    addTearDown(bloc.close);

    await tester.pumpWidget(_recoveryApp(bloc));
    repository.emit(_verifiedRecovery);
    await tester.pump();

    await tester.enterText(find.byType(TextField).at(0), 'novaSenha123');
    await tester.enterText(find.byType(TextField).at(1), 'outraSenha123');
    await tester.tap(find.text('Alterar senha'));
    await tester.pump();

    expect(find.text('As senhas não são iguais.'), findsOneWidget);
    expect(repository.updatedPasswords, isEmpty);
    expect(bloc.state.status, AuthStatus.recovery);
  });

  testWidgets('senhas iguais solicitam uma única atualização', (tester) async {
    final repository = _FakeAuthRepository(identity: _identity);
    final bloc = AuthBloc(repository, initialPasswordRecovery: true);
    addTearDown(bloc.close);

    await tester.pumpWidget(_recoveryApp(bloc));
    repository.emit(_verifiedRecovery);
    await tester.pump();

    await tester.enterText(find.byType(TextField).at(0), 'novaSenha123');
    await tester.enterText(find.byType(TextField).at(1), 'novaSenha123');
    await tester.tap(find.text('Alterar senha'));
    await tester.pumpAndSettle();

    expect(repository.updatedPasswords, ['novaSenha123']);
    expect(bloc.state.status, AuthStatus.authenticated);
  });

  testWidgets(
    'callback sem identidade mostra validação e permite solicitar novo link',
    (tester) async {
      final repository = _FakeAuthRepository();
      final bloc = AuthBloc(repository, initialPasswordRecovery: true);
      addTearDown(bloc.close);

      await tester.pumpWidget(_recoveryApp(bloc));

      expect(find.textContaining('Validando seu link seguro'), findsOneWidget);
      expect(
        find.textContaining(
          'o link expirou ou foi aberto fora do mesmo app ou perfil de navegador',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Solicitar um novo link'));
      await tester.pump();

      expect(bloc.state.status, AuthStatus.unauthenticated);
      expect(repository.updatedPasswords, isEmpty);
    },
  );
}

const _identity = AuthIdentity(id: 'user-1', email: 'ana@example.com');
const _verifiedRecovery = AuthSessionChange(
  AuthSessionEvent.passwordRecovery,
  _identity,
);

Widget _recoveryApp(AuthBloc bloc) {
  return MaterialApp(
    home: BlocProvider<AuthBloc>.value(
      value: bloc,
      child: const PasswordRecoveryPage(),
    ),
  );
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({AuthIdentity? identity}) : _identity = identity;

  final _controller = StreamController<AuthSessionChange>.broadcast();
  final AuthIdentity? _identity;
  final List<String> updatedPasswords = [];

  void emit(AuthSessionChange change) => _controller.add(change);

  @override
  Future<void> close() => _controller.close();

  @override
  AuthIdentity? get currentIdentity => _identity;

  @override
  Stream<AuthSessionChange> get sessionChanges => _controller.stream;

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signInEmployee({
    required String businessEmail,
    required String professionalName,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> updatePassword(String password) async {
    updatedPasswords.add(password);
  }
}
