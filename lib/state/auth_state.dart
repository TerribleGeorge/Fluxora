import '../domain/auth_repository.dart';

enum AuthStatus {
  unauthenticated,
  authenticated,
  recoveryPending,
  recovery,
  loading,
}

class AuthState {
  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.identity,
    this.message,
    this.processing = false,
  });

  final AuthStatus status;
  final AuthIdentity? identity;
  final String? message;
  final bool processing;

  bool get loading => processing || status == AuthStatus.loading;
}
