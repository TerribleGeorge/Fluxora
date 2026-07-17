import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/app/theme.dart';
import 'package:fluxora/domain/account.dart';

void main() {
  test('personaliza a paleta conforme o tipo de estabelecimento', () {
    final barbershop = FluxoraTheme.businessDark(BusinessType.barbershop)
        .colorScheme
        .primary;
    final nailStudio = FluxoraTheme.businessDark(BusinessType.nailStudio)
        .colorScheme
        .primary;
    final beautySalon = FluxoraTheme.businessDark(BusinessType.beautySalon)
        .colorScheme
        .primary;

    expect(barbershop, isNot(nailStudio));
    expect(nailStudio, isNot(beautySalon));
    expect(barbershop, isNot(beautySalon));
  });
}
