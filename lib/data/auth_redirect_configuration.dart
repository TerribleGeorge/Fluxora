import 'package:flutter/foundation.dart';

const _defaultWebRedirectBaseUrl = String.fromEnvironment(
  'AUTH_WEB_REDIRECT_BASE_URL',
  defaultValue: 'https://terriblegeorge.github.io/fluxora-agendamento/',
);

/// Keeps confirmation and password-recovery callbacks on the platform that
/// started the PKCE flow.
class AuthRedirectConfiguration {
  const AuthRedirectConfiguration({
    required this.passwordReset,
    required this.emailConfirmation,
  });

  static const mobilePasswordReset = 'dev.devvoid.fluxora://reset-password';
  static const mobileEmailConfirmation =
      'dev.devvoid.fluxora://auth-confirmation';
  static const actionParameter = 'auth-action';
  static const passwordRecoveryAction = 'password-recovery';
  static const emailConfirmationAction = 'email-confirmation';

  final String passwordReset;
  final String emailConfirmation;

  factory AuthRedirectConfiguration.current() {
    return AuthRedirectConfiguration.forPlatform(
      isWeb: kIsWeb,
      webBaseUrl: _defaultWebRedirectBaseUrl,
    );
  }

  @visibleForTesting
  factory AuthRedirectConfiguration.forPlatform({
    required bool isWeb,
    String webBaseUrl = _defaultWebRedirectBaseUrl,
  }) {
    if (!isWeb) {
      return const AuthRedirectConfiguration(
        passwordReset: mobilePasswordReset,
        emailConfirmation: mobileEmailConfirmation,
      );
    }

    final base = Uri.parse(webBaseUrl);
    return AuthRedirectConfiguration(
      passwordReset: _withAction(base, passwordRecoveryAction).toString(),
      emailConfirmation: _withAction(base, emailConfirmationAction).toString(),
    );
  }

  static Uri _withAction(Uri base, String action) {
    final query = Map<String, String>.from(base.queryParameters)
      ..[actionParameter] = action;
    return base.replace(queryParameters: query, fragment: '');
  }
}

bool isPasswordRecoveryLocation(Uri location) {
  if (location.scheme == 'dev.devvoid.fluxora' &&
      location.host == 'reset-password') {
    return true;
  }
  final isRecoveryAction =
      location.queryParameters[AuthRedirectConfiguration.actionParameter] ==
      AuthRedirectConfiguration.passwordRecoveryAction;
  if (!isRecoveryAction) return false;

  final fragmentParameters = Uri(query: location.fragment).queryParameters;
  const authResponseParameters = {
    'code',
    'access_token',
    'error',
    'error_code',
    'error_description',
  };
  return authResponseParameters.any(
    (parameter) =>
        location.queryParameters.containsKey(parameter) ||
        fragmentParameters.containsKey(parameter),
  );
}
