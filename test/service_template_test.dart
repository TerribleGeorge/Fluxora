import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/domain/account.dart';
import 'package:fluxora/domain/service_template.dart';

void main() {
  test('sugere serviços específicos para barbearia', () {
    final templates = ServiceTemplateCatalog.forBusinessType(
      BusinessType.barbershop,
    );

    expect(templates.any((item) => item.name == 'Corte e barba'), isTrue);
    expect(
      templates.any((item) => item.name == 'Barba com toalha quente'),
      isTrue,
    );
  });

  test('busca ignora acentos e encontra categoria ou nome', () {
    const template = ServiceTemplate(
      name: 'Design de sobrancelhas',
      category: 'Sobrancelhas',
      durationMinutes: 30,
    );

    expect(template.matches('sobrancelha'), isTrue);
    expect(template.matches('design'), isTrue);
  });
}
