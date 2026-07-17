import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:fluxora/l10n/supported_locales.dart';

void main() {
  test('inclui mercados prioritários para expansão internacional', () {
    expect(
      FluxoraSupportedLocales.supports(const Locale('pt', 'BR')),
      isTrue,
    );
    expect(
      FluxoraSupportedLocales.supports(const Locale('en', 'US')),
      isTrue,
    );
    expect(
      FluxoraSupportedLocales.supports(const Locale('es', 'MX')),
      isTrue,
    );
    expect(
      FluxoraSupportedLocales.supports(const Locale('fr', 'FR')),
      isTrue,
    );
    expect(
      FluxoraSupportedLocales.supports(const Locale('ar')),
      isTrue,
    );
    expect(
      FluxoraSupportedLocales.supports(const Locale('zh', 'CN')),
      isTrue,
    );
  });

  test('lista de locales não possui duplicatas', () {
    final keys = {
      for (final locale in FluxoraSupportedLocales.all)
        '${locale.languageCode}_${locale.countryCode ?? ''}',
    };

    expect(keys.length, FluxoraSupportedLocales.all.length);
  });
}
