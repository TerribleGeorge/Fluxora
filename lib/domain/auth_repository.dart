import 'dart:async';

class AuthIdentity {
  const AuthIdentity({required this.id, required this.email, this.name = ''});

  final String id;
  final String email;
  final String name;
}

enum AuthSessionEvent { initial, signedIn, signedOut, passwordRecovery }

class AuthSessionChange {
  const AuthSessionChange(this.event, this.identity);

  final AuthSessionEvent event;
  final AuthIdentity? identity;
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class AuthRepository {
  AuthIdentity? get currentIdentity;
  Stream<AuthSessionChange> get sessionChanges;

  Future<void> signIn({required String email, required String password});
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  });
  Future<void> requestPasswordReset(String email);
  Future<void> updatePassword(String password);
  Future<void> signOut();
}
