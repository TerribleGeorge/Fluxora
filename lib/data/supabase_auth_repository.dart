import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  static const passwordResetRedirect = 'dev.devvoid.fluxora://reset-password';

  final SupabaseClient _client;

  @override
  AuthIdentity? get currentIdentity =>
      _identityFromUser(_client.auth.currentUser);

  @override
  Stream<AuthSessionChange> get sessionChanges {
    return _client.auth.onAuthStateChange.map((data) {
      final event = switch (data.event) {
        AuthChangeEvent.signedIn => AuthSessionEvent.signedIn,
        AuthChangeEvent.signedOut => AuthSessionEvent.signedOut,
        AuthChangeEvent.passwordRecovery => AuthSessionEvent.passwordRecovery,
        _ => AuthSessionEvent.initial,
      };
      return AuthSessionChange(event, _identityFromUser(data.session?.user));
    });
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _guard(
      () => _client.auth.signInWithPassword(email: email, password: password),
    );
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
        emailRedirectTo: passwordResetRedirect,
      ),
    );
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    await _guard(
      () => _client.auth.resetPasswordForEmail(
        email,
        redirectTo: passwordResetRedirect,
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

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
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
      _ => 'Não foi possível concluir o acesso. Tente novamente.',
    };
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
