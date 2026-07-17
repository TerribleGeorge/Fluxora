import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/app/fluxora_app.dart';
import 'package:fluxora/domain/public_booking.dart';

void main() {
  group('rota pública de agendamento', () {
    test('reconhece link com hash compatível com hospedagem estática', () {
      final route = publicBookingRouteFromLocation(
        Uri.parse('https://fluxora.dev/#/agendar/salao-da-maria'),
      );

      expect(route, '/agendar/salao-da-maria');
      expect(publicBookingSlugFromRoute(route), 'salao-da-maria');
    });

    test('reconhece caminho direto e parâmetro de compatibilidade', () {
      expect(
        publicBookingRouteFromLocation(
          Uri.parse('https://fluxora.dev/agendar/barbearia-central'),
        ),
        '/agendar/barbearia-central',
      );
      expect(
        publicBookingRouteFromLocation(
          Uri.parse('https://fluxora.dev/?agendar=studio-ana'),
        ),
        '/agendar/studio-ana',
      );
    });

    test('rejeita slug que poderia alterar a rota', () {
      expect(publicBookingSlugFromRoute('/agendar/../admin'), isNull);
      expect(publicBookingSlugFromRoute('/agendar/Studio Ana'), isNull);
      expect(publicBookingSlugFromRoute('/outra-rota/studio-ana'), isNull);
    });
  });

  test('configuração apresenta horários sem depender de formatação da UI', () {
    const settings = PublicBookingSettings(
      businessId: 'business-1',
      slug: 'studio-ana',
      openingMinutes: 8 * 60 + 30,
      closingMinutes: 19 * 60 + 5,
    );

    expect(settings.openingLabel, '08:30');
    expect(settings.closingLabel, '19:05');
  });
}
