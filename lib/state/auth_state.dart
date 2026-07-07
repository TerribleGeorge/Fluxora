import '../domain/auth_repository.dart';

enum AuthStatus { unauthenticated, authenticated, recovery, loading }

class AuthState {
  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.identity,
    this.message,
  });

  final AuthStatus status;
  final AuthIdentity? identity;
  final String? message;

  bool get loading => status == AuthStatus.loading;
}
