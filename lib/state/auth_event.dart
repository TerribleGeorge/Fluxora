import '../domain/auth_repository.dart';

sealed class AuthEvent {
  const AuthEvent();
}

final class AuthSignInRequested extends AuthEvent {
  const AuthSignInRequested(this.email, this.password);
  final String email;
  final String password;
}

final class AuthSignUpRequested extends AuthEvent {
  const AuthSignUpRequested(this.name, this.email, this.password);
  final String name;
  final String email;
  final String password;
}

final class AuthPasswordResetRequested extends AuthEvent {
  const AuthPasswordResetRequested(this.email);
  final String email;
}

final class AuthPasswordUpdated extends AuthEvent {
  const AuthPasswordUpdated(this.password);
  final String password;
}

final class AuthRecoveryDismissed extends AuthEvent {
  const AuthRecoveryDismissed();
}

final class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}

final class AuthSessionChanged extends AuthEvent {
  const AuthSessionChanged(this.change);
  final AuthSessionChange change;
}
