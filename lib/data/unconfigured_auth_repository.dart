import '../domain/auth_repository.dart';

class UnconfiguredAuthRepository implements AuthRepository {
  static const _message =
      'Configure SUPABASE_URL e SUPABASE_PUBLISHABLE_KEY para habilitar o acesso.';

  @override
  AuthIdentity? get currentIdentity => null;

  @override
  Stream<AuthSessionChange> get sessionChanges => const Stream.empty();

  Never _unavailable() => throw const AuthFailure(_message);

  @override
  Future<void> requestPasswordReset(String email) async => _unavailable();

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async => _unavailable();

  @override
  Future<void> signOut() async => _unavailable();

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async => _unavailable();

  @override
  Future<void> updatePassword(String password) async => _unavailable();
}
