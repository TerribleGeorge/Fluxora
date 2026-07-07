import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/domain/auth_repository.dart';
import 'package:fluxora/state/auth_bloc.dart';
import 'package:fluxora/state/auth_event.dart';
import 'package:fluxora/state/auth_state.dart';

void main() {
  test('autentica usuário com dados válidos', () async {
    final repository = _FakeAuthRepository();
    final bloc = AuthBloc(repository);
    addTearDown(bloc.close);

    bloc.add(const AuthSignInRequested('ana@example.com', 'senha123'));
    final state = await bloc.stream.firstWhere(
      (item) => item.status == AuthStatus.authenticated,
    );

    expect(state.identity?.email, 'ana@example.com');
    expect(repository.signInCalls, 1);
  });

  test('não consulta servidor com credenciais inválidas', () async {
    final repository = _FakeAuthRepository();
    final bloc = AuthBloc(repository);
    addTearDown(bloc.close);

    bloc.add(const AuthSignInRequested('email-invalido', '123'));
    final state = await bloc.stream.firstWhere((item) => item.message != null);

    expect(state.status, AuthStatus.unauthenticated);
    expect(repository.signInCalls, 0);
  });

  test('entra no fluxo de criação de senha após link de recuperação', () async {
    final repository = _FakeAuthRepository();
    final bloc = AuthBloc(repository);
    addTearDown(bloc.close);

    repository.emit(
      const AuthSessionChange(
        AuthSessionEvent.passwordRecovery,
        AuthIdentity(id: 'user-1', email: 'ana@example.com'),
      ),
    );
    final state = await bloc.stream.firstWhere(
      (item) => item.status == AuthStatus.recovery,
    );

    expect(state.identity?.id, 'user-1');
  });
}

class _FakeAuthRepository implements AuthRepository {
  final _controller = StreamController<AuthSessionChange>.broadcast();
  AuthIdentity? _identity;
  int signInCalls = 0;

  void emit(AuthSessionChange change) => _controller.add(change);

  @override
  AuthIdentity? get currentIdentity => _identity;

  @override
  Stream<AuthSessionChange> get sessionChanges => _controller.stream;

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls++;
    _identity = AuthIdentity(id: 'user-1', email: email);
  }

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    _identity = AuthIdentity(id: 'user-1', email: email, name: name);
  }

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<void> updatePassword(String password) async {}

  @override
  Future<void> signOut() async {
    _identity = null;
  }
}
