import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/data/auth_redirect_configuration.dart';

void main() {
  group('AuthRedirectConfiguration', () {
    test('usa callbacks por custom scheme no aplicativo mobile', () {
      final configuration = AuthRedirectConfiguration.forPlatform(
        isWeb: false,
        webBaseUrl: 'https://example.com/fluxora/',
      );

      expect(
        configuration.passwordReset,
        AuthRedirectConfiguration.mobilePasswordReset,
      );
      expect(
        configuration.emailConfirmation,
        AuthRedirectConfiguration.mobileEmailConfirmation,
      );
    });

    test('gera callbacks HTTPS distintos para recuperação e confirmação', () {
      final configuration = AuthRedirectConfiguration.forPlatform(
        isWeb: true,
        webBaseUrl: 'https://example.com/fluxora/?source=test#old-fragment',
      );

      final passwordReset = Uri.parse(configuration.passwordReset);
      final emailConfirmation = Uri.parse(configuration.emailConfirmation);

      expect(passwordReset.scheme, 'https');
      expect(passwordReset.host, 'example.com');
      expect(passwordReset.path, '/fluxora/');
      expect(passwordReset.fragment, isEmpty);
      expect(passwordReset.queryParameters['source'], 'test');
      expect(
        passwordReset.queryParameters[AuthRedirectConfiguration
            .actionParameter],
        AuthRedirectConfiguration.passwordRecoveryAction,
      );
      expect(emailConfirmation.fragment, isEmpty);
      expect(emailConfirmation.queryParameters['source'], 'test');
      expect(
        emailConfirmation.queryParameters[AuthRedirectConfiguration
            .actionParameter],
        AuthRedirectConfiguration.emailConfirmationAction,
      );
    });
  });

  group('isPasswordRecoveryLocation', () {
    test('reconhece callback web de recuperação', () {
      final location = Uri.parse(
        'https://example.com/fluxora/?auth-action=password-recovery&code=abc',
      );

      expect(isPasswordRecoveryLocation(location), isTrue);
    });

    test('não reabre recuperação após o código Web ser removido', () {
      final refreshedLocation = Uri.parse(
        'https://example.com/fluxora/?auth-action=password-recovery',
      );

      expect(isPasswordRecoveryLocation(refreshedLocation), isFalse);
    });

    test('reconhece callback do custom scheme mobile', () {
      final location = Uri.parse(
        'dev.devvoid.fluxora://reset-password?code=abc',
      );

      expect(isPasswordRecoveryLocation(location), isTrue);
    });

    test('não confunde confirmação de e-mail com recuperação de senha', () {
      final webConfirmation = Uri.parse(
        'https://example.com/fluxora/?auth-action=email-confirmation',
      );
      final wrongCustomScheme = Uri.parse(
        'dev.devvoid.fluxora://auth-confirmation',
      );

      expect(isPasswordRecoveryLocation(webConfirmation), isFalse);
      expect(isPasswordRecoveryLocation(wrongCustomScheme), isFalse);
    });
  });
}
