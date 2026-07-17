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
    final repository = _FakeAuthRepository(
      identity: const AuthIdentity(id: 'user-1', email: 'ana@example.com'),
    );
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

  test(
    'marcador inicial aguarda evento validado antes de liberar recovery',
    () async {
      final repository = _FakeAuthRepository(
        identity: const AuthIdentity(id: 'user-1', email: 'ana@example.com'),
      );

      final bloc = AuthBloc(repository, initialPasswordRecovery: true);
      addTearDown(bloc.close);

      expect(bloc.state.status, AuthStatus.recoveryPending);
      expect(bloc.state.identity, isNull);

      repository.emit(
        const AuthSessionChange(
          AuthSessionEvent.signedIn,
          AuthIdentity(id: 'user-1', email: 'ana@example.com'),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.status, AuthStatus.recoveryPending);

      repository.emit(
        const AuthSessionChange(
          AuthSessionEvent.passwordRecovery,
          AuthIdentity(id: 'user-1', email: 'ana@example.com'),
        ),
      );
      final verifiedState = await bloc.stream.firstWhere(
        (item) => item.status == AuthStatus.recovery,
      );
      expect(verifiedState.identity?.id, 'user-1');
    },
  );

  test('solicita reset com o e-mail normalizado', () async {
    final repository = _FakeAuthRepository();
    final bloc = AuthBloc(repository);
    addTearDown(bloc.close);

    bloc.add(const AuthPasswordResetRequested('  ana@example.com  '));
    final state = await bloc.stream.firstWhere(
      (item) => item.message?.contains('instruções de recuperação') ?? false,
    );

    expect(state.status, AuthStatus.unauthenticated);
    expect(repository.passwordResetEmails, ['ana@example.com']);
  });

  test('atualiza a senha e encerra o modo recovery', () async {
    final repository = _FakeAuthRepository(
      identity: const AuthIdentity(id: 'user-1', email: 'ana@example.com'),
    );
    final bloc = AuthBloc(repository, initialPasswordRecovery: true);
    addTearDown(bloc.close);

    repository.emit(
      const AuthSessionChange(
        AuthSessionEvent.passwordRecovery,
        AuthIdentity(id: 'user-1', email: 'ana@example.com'),
      ),
    );
    await bloc.stream.firstWhere((item) => item.status == AuthStatus.recovery);

    bloc.add(const AuthPasswordUpdated('novaSenha123'));
    final state = await bloc.stream.firstWhere(
      (item) => item.message == 'Senha alterada com sucesso.',
    );

    expect(state.status, AuthStatus.authenticated);
    expect(state.identity?.id, 'user-1');
    expect(repository.updatedPasswords, ['novaSenha123']);
  });

  test('não altera senha enquanto o callback ainda não foi validado', () async {
    final repository = _FakeAuthRepository(
      identity: const AuthIdentity(id: 'user-1', email: 'ana@example.com'),
    );
    final bloc = AuthBloc(repository, initialPasswordRecovery: true);
    addTearDown(bloc.close);

    bloc.add(const AuthPasswordUpdated('novaSenha123'));
    final state = await bloc.stream.firstWhere((item) => item.message != null);

    expect(state.status, AuthStatus.recoveryPending);
    expect(repository.updatedPasswords, isEmpty);
  });

  test('não altera senha se a sessão mudou de usuário', () async {
    final repository = _FakeAuthRepository(
      identity: const AuthIdentity(id: 'user-1', email: 'ana@example.com'),
    );
    final bloc = AuthBloc(repository, initialPasswordRecovery: true);
    addTearDown(bloc.close);

    repository.emit(
      const AuthSessionChange(
        AuthSessionEvent.passwordRecovery,
        AuthIdentity(id: 'user-1', email: 'ana@example.com'),
      ),
    );
    await bloc.stream.firstWhere((item) => item.status == AuthStatus.recovery);
    repository.setIdentity(
      const AuthIdentity(id: 'user-2', email: 'bia@example.com'),
    );

    bloc.add(const AuthPasswordUpdated('novaSenha123'));
    final state = await bloc.stream.firstWhere(
      (item) => item.message?.contains('sessão mudou') ?? false,
    );

    expect(state.status, AuthStatus.authenticated);
    expect(state.identity?.id, 'user-2');
    expect(repository.updatedPasswords, isEmpty);
  });

  test('mantém a tela de recovery em renovação da mesma sessão', () async {
    final repository = _FakeAuthRepository(
      identity: const AuthIdentity(id: 'user-1', email: 'ana@example.com'),
    );
    final bloc = AuthBloc(repository, initialPasswordRecovery: true);
    addTearDown(bloc.close);

    repository.emit(
      const AuthSessionChange(
        AuthSessionEvent.passwordRecovery,
        AuthIdentity(id: 'user-1', email: 'ana@example.com'),
      ),
    );
    await bloc.stream.firstWhere((item) => item.status == AuthStatus.recovery);
    repository.emit(
      const AuthSessionChange(
        AuthSessionEvent.initial,
        AuthIdentity(id: 'user-1', email: 'ana@example.com'),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.status, AuthStatus.recovery);
    expect(bloc.state.identity?.id, 'user-1');
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({AuthIdentity? identity}) : _identity = identity;

  final _controller = StreamController<AuthSessionChange>.broadcast();
  AuthIdentity? _identity;
  int signInCalls = 0;
  final List<String> passwordResetEmails = [];
  final List<String> updatedPasswords = [];

  void emit(AuthSessionChange change) => _controller.add(change);

  void setIdentity(AuthIdentity? identity) => _identity = identity;

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
  Future<void> requestPasswordReset(String email) async {
    passwordResetEmails.add(email);
  }

  @override
  Future<void> updatePassword(String password) async {
    updatedPasswords.add(password);
  }

  @override
  Future<void> signOut() async {
    _identity = null;
  }

  @override
  Future<void> close() => _controller.close();
}
