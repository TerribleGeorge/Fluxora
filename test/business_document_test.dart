import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/domain/business_document.dart';

void main() {
  group('BusinessDocument', () {
    test('normaliza e formata CNPJ tradicional', () {
      const raw = '11.222.333/0001-81';

      expect(BusinessDocument.normalize(raw), '11222333000181');
      expect(BusinessDocument.format(raw), '11.222.333/0001-81');
    });

    test('valida CNPJ numérico', () {
      expect(BusinessDocument.isValid('11.222.333/0001-81'), isTrue);
      expect(BusinessDocument.isValid('11.222.333/0001-80'), isFalse);
      expect(BusinessDocument.isValid('00.000.000/0000-00'), isFalse);
    });

    test('aceita CNPJ alfanumérico com dígitos verificadores válidos', () {
      expect(BusinessDocument.isValid('A1.B2C.D3E/F4G5-62'), isTrue);
      expect(
        BusinessDocument.normalize('A1.B2C.D3E/F4G5-62'),
        'A1B2CD3EF4G562',
      );
    });
  });
}
