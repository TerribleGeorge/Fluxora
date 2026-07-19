import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/auth_repository.dart';
import 'auth_redirect_configuration.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(
    this._client, {
    AuthRedirectConfiguration? redirects,
    User? initialPasswordRecoveryUser,
  }) : _redirects = redirects ?? AuthRedirectConfiguration.current() {
    if (initialPasswordRecoveryUser != null) {
      _pendingPasswordRecovery = AuthSessionChange(
        AuthSessionEvent.passwordRecovery,
        _identityFromUser(initialPasswordRecoveryUser),
      );
    }
    _sessionChangesController = StreamController<AuthSessionChange>.broadcast(
      sync: true,
      onListen: _replayPendingPasswordRecovery,
    );
    _authSubscription = _client.auth.onAuthStateChange.listen(
      (data) {
        final change = _sessionChangeFromAuthState(data);
        _invalidatePendingRecoveryWhenSessionChanges(change);
        if (change.event == AuthSessionEvent.passwordRecovery &&
            !_sessionChangesController.hasListener) {
          _pendingPasswordRecovery = change;
        }
        _sessionChangesController.add(change);
      },
      onError: (Object error, StackTrace stackTrace) {
        // Supabase already reports Auth stream errors. Keeping a handler here
        // prevents an expired or invalid link from becoming unhandled.
      },
    );
  }

  final SupabaseClient _client;
  final AuthRedirectConfiguration _redirects;
  late final StreamController<AuthSessionChange> _sessionChangesController;
  late final StreamSubscription<AuthState> _authSubscription;
  AuthSessionChange? _pendingPasswordRecovery;

  @override
  AuthIdentity? get currentIdentity =>
      _identityFromUser(_client.auth.currentUser);

  @override
  Stream<AuthSessionChange> get sessionChanges {
    return _sessionChangesController.stream;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _guard(
      () => _client.auth.signInWithPassword(email: email, password: password),
    );
  }

  @override
  Future<void> signInEmployee({
    required String businessEmail,
    required String professionalName,
    required String password,
  }) async {
    await _guard(() async {
      final response = await _client.rpc<dynamic>(
        'resolve_employee_login_email',
        params: {
          'business_owner_email': businessEmail.trim(),
          'professional_login_name': professionalName.trim(),
        },
      );
      final row = switch (response) {
        final List<dynamic> rows when rows.isNotEmpty =>
          rows.first as Map<String, dynamic>,
        final Map<String, dynamic> value => value,
        _ => throw const AuthFailure('Funcionário não encontrado.'),
      };
      final loginEmail = row['login_email'] as String? ?? '';
      if (loginEmail.trim().isEmpty) {
        throw const AuthFailure('Funcionário não encontrado.');
      }
      await _client.auth.signInWithPassword(
        email: loginEmail,
        password: password,
      );
    });
  }

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    await _guard(
      () => _client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
        emailRedirectTo: _redirects.emailConfirmation,
      ),
    );
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    await _guard(
      () => _client.auth.resetPasswordForEmail(
        email,
        redirectTo: _redirects.passwordReset,
      ),
    );
  }

  @override
  Future<void> updatePassword(String password) async {
    await _guard(
      () => _client.auth.updateUser(UserAttributes(password: password)),
    );
  }

  @override
  Future<void> signOut() async {
    await _guard(_client.auth.signOut);
  }

  @override
  Future<void> close() async {
    await _authSubscription.cancel();
    await _sessionChangesController.close();
  }

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on AuthFailure {
      rethrow;
    } on AuthException catch (error) {
      throw AuthFailure(_friendlyMessage(error));
    } on Exception {
      throw const AuthFailure(
        'Não foi possível acessar o servidor. Tente novamente.',
      );
    }
  }

  String _friendlyMessage(AuthException error) {
    return switch (error.code) {
      'invalid_credentials' => 'E-mail ou senha incorretos.',
      'email_not_confirmed' => 'Confirme seu e-mail antes de entrar.',
      'user_already_exists' => 'Já existe uma conta com este e-mail.',
      'weak_password' => 'Escolha uma senha mais segura.',
      'over_email_send_rate_limit' =>
        'Aguarde um pouco antes de solicitar outro e-mail.',
      'email_address_not_authorized' =>
        'O envio de recuperação ainda não está disponível para este e-mail. '
            'Fale com o suporte do Fluxora.',
      'otp_expired' || 'flow_state_expired' =>
        'Este link expirou. Solicite outro e abra-o no mesmo app ou perfil de navegador.',
      'bad_code_verifier' =>
        'Abra o novo link no mesmo app ou perfil de navegador usado para solicitar a recuperação.',
      'same_password' => 'Escolha uma senha diferente da senha atual.',
      _ => 'Não foi possível concluir o acesso. Tente novamente.',
    };
  }

  AuthSessionChange _sessionChangeFromAuthState(AuthState data) {
    final event = switch (data.event) {
      AuthChangeEvent.signedIn => AuthSessionEvent.signedIn,
      AuthChangeEvent.signedOut => AuthSessionEvent.signedOut,
      AuthChangeEvent.passwordRecovery => AuthSessionEvent.passwordRecovery,
      _ => AuthSessionEvent.initial,
    };
    return AuthSessionChange(event, _identityFromUser(data.session?.user));
  }

  void _replayPendingPasswordRecovery() {
    final pending = _pendingPasswordRecovery;
    _pendingPasswordRecovery = null;
    if (pending == null) return;
    scheduleMicrotask(() {
      if (_client.auth.currentUser?.id != pending.identity?.id ||
          _sessionChangesController.isClosed) {
        return;
      }
      _sessionChangesController.add(pending);
    });
  }

  void _invalidatePendingRecoveryWhenSessionChanges(AuthSessionChange change) {
    final pending = _pendingPasswordRecovery;
    if (pending == null || change.event == AuthSessionEvent.passwordRecovery) {
      return;
    }
    if (_client.auth.currentUser?.id != pending.identity?.id) {
      _pendingPasswordRecovery = null;
    }
  }

  AuthIdentity? _identityFromUser(User? user) {
    if (user == null) return null;
    return AuthIdentity(
      id: user.id,
      email: user.email ?? '',
      name: user.userMetadata?['name'] as String? ?? '',
    );
  }
}
