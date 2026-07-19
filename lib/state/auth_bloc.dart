import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._repository, {bool initialPasswordRecovery = false})
    : super(
        initialPasswordRecovery
            ? const AuthState(status: AuthStatus.recoveryPending)
            : _repository.currentIdentity == null
            ? const AuthState()
            : AuthState(
                status: AuthStatus.authenticated,
                identity: _repository.currentIdentity,
              ),
      ) {
    on<AuthSignInRequested>(_onSignIn);
    on<AuthEmployeeSignInRequested>(_onEmployeeSignIn);
    on<AuthSignUpRequested>(_onSignUp);
    on<AuthPasswordResetRequested>(_onResetRequested);
    on<AuthPasswordUpdated>(_onPasswordUpdated);
    on<AuthRecoveryDismissed>(_onRecoveryDismissed);
    on<AuthSignOutRequested>(_onSignOut);
    on<AuthSessionChanged>(_onSessionChanged);
    _subscription = _repository.sessionChanges.listen(
      (change) => add(AuthSessionChanged(change)),
    );
  }

  final AuthRepository _repository;
  late final StreamSubscription<AuthSessionChange> _subscription;

  Future<void> _onSignIn(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (!_validEmail(event.email) || event.password.length < 8) {
      emit(const AuthState(message: 'Revise o e-mail e a senha.'));
      return;
    }
    await _run(emit, () async {
      await _repository.signIn(email: event.email, password: event.password);
      emit(
        AuthState(
          status: AuthStatus.authenticated,
          identity: _repository.currentIdentity,
        ),
      );
    });
  }

  Future<void> _onEmployeeSignIn(
    AuthEmployeeSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (!_validEmail(event.businessEmail) ||
        event.professionalName.trim().length < 2 ||
        event.password.length < 8) {
      emit(
        const AuthState(
          message:
              'Informe e-mail do estabelecimento, nome cadastrado e senha.',
        ),
      );
      return;
    }
    await _run(emit, () async {
      await _repository.signInEmployee(
        businessEmail: event.businessEmail.trim(),
        professionalName: event.professionalName.trim(),
        password: event.password,
      );
      emit(
        AuthState(
          status: AuthStatus.authenticated,
          identity: _repository.currentIdentity,
        ),
      );
    });
  }

  Future<void> _onSignUp(
    AuthSignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (event.name.trim().length < 2 ||
        !_validEmail(event.email) ||
        event.password.length < 8) {
      emit(
        const AuthState(
          message: 'Informe nome, e-mail válido e senha com 8 caracteres.',
        ),
      );
      return;
    }
    await _run(emit, () async {
      await _repository.signUp(
        name: event.name.trim(),
        email: event.email.trim(),
        password: event.password,
      );
      emit(
        AuthState(
          status: _repository.currentIdentity == null
              ? AuthStatus.unauthenticated
              : AuthStatus.authenticated,
          identity: _repository.currentIdentity,
          message: _repository.currentIdentity == null
              ? 'Conta criada. Confirme o acesso pelo e-mail enviado.'
              : null,
        ),
      );
    });
  }

  Future<void> _onResetRequested(
    AuthPasswordResetRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (!_validEmail(event.email)) {
      emit(const AuthState(message: 'Informe um e-mail válido.'));
      return;
    }
    await _run(emit, () async {
      await _repository.requestPasswordReset(event.email.trim());
      emit(
        const AuthState(
          message: 'Enviamos as instruções de recuperação para seu e-mail.',
        ),
      );
    });
  }

  Future<void> _onPasswordUpdated(
    AuthPasswordUpdated event,
    Emitter<AuthState> emit,
  ) async {
    final recoveryIdentity = state.identity;
    final currentIdentity = _repository.currentIdentity;
    if (state.status != AuthStatus.recovery || recoveryIdentity == null) {
      emit(
        const AuthState(
          status: AuthStatus.recoveryPending,
          message: 'Aguarde a validação do link antes de alterar a senha.',
        ),
      );
      return;
    }
    if (currentIdentity == null || currentIdentity.id != recoveryIdentity.id) {
      emit(
        currentIdentity == null
            ? const AuthState(
                message:
                    'A sessão expirou. Solicite um novo link de recuperação.',
              )
            : AuthState(
                status: AuthStatus.authenticated,
                identity: currentIdentity,
                message:
                    'A sessão mudou. Solicite um novo link de recuperação.',
              ),
      );
      return;
    }
    if (event.password.length < 8) {
      emit(
        AuthState(
          status: AuthStatus.recovery,
          identity: state.identity,
          message: 'A nova senha precisa ter pelo menos 8 caracteres.',
        ),
      );
      return;
    }
    emit(
      AuthState(
        status: AuthStatus.recovery,
        identity: state.identity,
        processing: true,
      ),
    );
    try {
      await _repository.updatePassword(event.password);
      emit(
        AuthState(
          status: AuthStatus.authenticated,
          identity: _repository.currentIdentity,
          message: 'Senha alterada com sucesso.',
        ),
      );
    } on AuthFailure catch (error) {
      emit(
        AuthState(
          status: AuthStatus.recovery,
          identity: state.identity,
          message: error.message,
        ),
      );
    }
  }

  void _onRecoveryDismissed(
    AuthRecoveryDismissed event,
    Emitter<AuthState> emit,
  ) {
    final identity = _repository.currentIdentity;
    emit(
      identity == null
          ? const AuthState()
          : AuthState(status: AuthStatus.authenticated, identity: identity),
    );
  }

  Future<void> _onSignOut(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _run(emit, () async {
      await _repository.signOut();
      emit(const AuthState());
    });
  }

  void _onSessionChanged(AuthSessionChanged event, Emitter<AuthState> emit) {
    final change = event.change;
    if (change.event == AuthSessionEvent.passwordRecovery) {
      final currentIdentity = _repository.currentIdentity;
      if (change.identity != null &&
          currentIdentity?.id == change.identity!.id) {
        emit(AuthState(status: AuthStatus.recovery, identity: change.identity));
      }
      return;
    }
    if (state.status == AuthStatus.recoveryPending) {
      if (change.event == AuthSessionEvent.signedOut) emit(const AuthState());
      return;
    }
    if (state.status == AuthStatus.recovery) {
      if (change.event == AuthSessionEvent.signedOut) {
        emit(const AuthState());
        return;
      }
      final recoveryIdentity = state.identity;
      final activeIdentity = change.identity ?? _repository.currentIdentity;
      if (recoveryIdentity != null &&
          activeIdentity != null &&
          recoveryIdentity.id == activeIdentity.id) {
        return;
      }
      if (activeIdentity != null) {
        emit(
          AuthState(
            status: AuthStatus.authenticated,
            identity: activeIdentity,
            message: 'A sessão mudou. Solicite um novo link de recuperação.',
          ),
        );
      } else {
        emit(const AuthState());
      }
      return;
    }
    if (change.identity != null) {
      emit(
        AuthState(status: AuthStatus.authenticated, identity: change.identity),
      );
    } else if (change.event == AuthSessionEvent.signedOut) {
      emit(const AuthState());
    }
  }

  Future<void> _run(
    Emitter<AuthState> emit,
    Future<void> Function() operation,
  ) async {
    final previous = state;
    emit(AuthState(status: AuthStatus.loading, identity: state.identity));
    try {
      await operation();
    } on AuthFailure catch (error) {
      emit(
        AuthState(
          status: previous.status,
          identity: previous.identity,
          message: error.message,
        ),
      );
    }
  }

  bool _validEmail(String value) {
    final email = value.trim();
    return email.contains('@') && email.split('@').last.contains('.');
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await _repository.close();
    return super.close();
  }
}
