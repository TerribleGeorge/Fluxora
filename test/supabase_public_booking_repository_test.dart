import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/data/supabase_public_booking_repository.dart';
import 'package:fluxora/domain/account.dart';
import 'package:fluxora/domain/public_booking.dart';

void main() {
  group('SupabasePublicBookingResponseParser', () {
    test('converte catálogo JSON com serviços e profissionais', () {
      final catalog = SupabasePublicBookingResponseParser.catalog({
        'business_name': 'Studio Aurora',
        'business_type': 'beautySalon',
        'slug': 'studio-aurora',
        'time_zone': 'America/Sao_Paulo',
        'local_today': '2026-07-15',
        'working_days': [1, 2, 3, 4, 5, 6],
        'maximum_advance_days': 45,
        'services': [
          {
            'id': 'service-1',
            'name': 'Corte',
            'category': 'Cabelo',
            'price': 79.9,
            'duration_minutes': 50,
          },
        ],
        'professionals': [
          {
            'id': 'professional-1',
            'name': 'Ana',
            'service_ids': ['service-1'],
          },
        ],
      });

      expect(catalog.businessName, 'Studio Aurora');
      expect(catalog.businessType, BusinessType.beautySalon);
      expect(catalog.workingDays, {1, 2, 3, 4, 5, 6});
      expect(catalog.maximumAdvanceDays, 45);
      expect(catalog.localToday, DateTime(2026, 7, 15));
      expect(catalog.services.single.price, 79.9);
      expect(catalog.services.single.durationMinutes, 50);
      expect(catalog.professionals.single.name, 'Ana');
      expect(catalog.professionals.single.serviceIds, {'service-1'});
    });

    test('aceita catálogo encapsulado em lista de uma linha', () {
      final catalog = SupabasePublicBookingResponseParser.catalog([
        {
          'business_name': 'Barbearia Norte',
          'business_type': 'barbershop',
          'slug': 'barbearia-norte',
          'services': <Object?>[],
          'professionals': <Object?>[],
        },
      ]);

      expect(catalog.businessType, BusinessType.barbershop);
      expect(catalog.timeZone, 'America/Sao_Paulo');
      expect(catalog.maximumAdvanceDays, 60);
      expect(catalog.services, isEmpty);
    });

    test('converte horários retornados pelo PostgREST', () {
      final slots = SupabasePublicBookingResponseParser.slots([
        {
          'starts_at': '2026-07-15T12:00:00Z',
          'ends_at': '2026-07-15T12:45:00Z',
          'local_time_label': '09:00',
        },
        {
          'starts_at': '2026-07-15T13:00:00Z',
          'ends_at': '2026-07-15T13:45:00Z',
          'local_time_label': '10:00',
        },
      ]);

      expect(slots, hasLength(2));
      expect(slots.first.startsAt, DateTime.utc(2026, 7, 15, 12));
      expect(slots.first.localTimeLabel, '09:00');
      expect(slots.last.endsAt, DateTime.utc(2026, 7, 15, 13, 45));
    });

    test('converte cotação como mapa ou lista de uma linha', () {
      final mapQuote = SupabasePublicBookingResponseParser.quote({
        'base_price': 100,
        'final_price': 90.0,
      });
      final listQuote = SupabasePublicBookingResponseParser.quote([
        {'base_price': '80.50', 'final_price': '76.48'},
      ]);

      expect(mapQuote.basePrice, 100);
      expect(mapQuote.finalPrice, 90);
      expect(listQuote.basePrice, 80.5);
      expect(listQuote.finalPrice, 76.48);
    });

    test('converte confirmação como mapa ou lista de uma linha', () {
      final confirmation = SupabasePublicBookingResponseParser.confirmation([
        {
          'reference': 'FX-20260715-ABC123',
          'starts_at': '2026-07-15T12:00:00Z',
          'ends_at': '2026-07-15T12:45:00Z',
          'final_price': 90,
        },
      ]);

      expect(confirmation.reference, 'FX-20260715-ABC123');
      expect(confirmation.startsAt, DateTime.utc(2026, 7, 15, 12));
      expect(confirmation.finalPrice, 90);
    });

    test('combina slug do negócio com configuração autenticada', () {
      final settings = SupabasePublicBookingResponseParser.settings(
        businessId: 'business-1',
        businessResponse: {'id': 'business-1', 'public_slug': 'studio-aurora'},
        settingsResponse: {
          'business_id': 'business-1',
          'enabled': true,
          'time_zone': 'America/Manaus',
          'working_days': [2, 3, 4, 5, 6],
          'opening_time': '09:30:00',
          'closing_time': '20:15:00',
          'slot_interval_minutes': 30,
          'minimum_notice_minutes': 120,
          'maximum_advance_days': 90,
        },
      );

      expect(settings.slug, 'studio-aurora');
      expect(settings.enabled, isTrue);
      expect(settings.timeZone, 'America/Manaus');
      expect(settings.workingDays, {2, 3, 4, 5, 6});
      expect(settings.openingMinutes, 570);
      expect(settings.closingMinutes, 1215);
      expect(settings.slotIntervalMinutes, 30);
      expect(settings.minimumNoticeMinutes, 120);
      expect(settings.maximumAdvanceDays, 90);
    });

    test('usa padrões quando ainda não há linha de configuração', () {
      final settings = SupabasePublicBookingResponseParser.settings(
        businessId: 'business-1',
        businessResponse: {'public_slug': null},
        settingsResponse: null,
      );

      expect(settings.slug, isEmpty);
      expect(settings.enabled, isFalse);
      expect(settings.openingLabel, '08:00');
      expect(settings.closingLabel, '19:00');
      expect(settings.workingDays, {1, 2, 3, 4, 5, 6});
    });

    test('converte resposta atômica parcial preservando valores enviados', () {
      const fallback = PublicBookingSettings(
        businessId: 'business-1',
        slug: 'endereco-antigo',
        enabled: false,
        openingMinutes: 8 * 60,
        closingMinutes: 18 * 60,
        minimumNoticeMinutes: 90,
      );

      final settings = SupabasePublicBookingResponseParser.savedSettings({
        'business_id': 'business-1',
        'public_slug': 'studio-aurora',
        'enabled': true,
        'opening_time': '09:00:00',
        'closing_time': '19:30:00',
      }, fallback: fallback);

      expect(settings.slug, 'studio-aurora');
      expect(settings.enabled, isTrue);
      expect(settings.openingMinutes, 9 * 60);
      expect(settings.closingMinutes, 19 * 60 + 30);
      expect(settings.minimumNoticeMinutes, 90);
    });

    test('converte serviços e expediente da configuração profissional', () {
      final configuration =
          SupabasePublicBookingResponseParser.professionalConfiguration({
            'professional_id': 'professional-1',
            'business_id': 'business-1',
            'services': [
              {
                'id': 'service-1',
                'name': 'Corte',
                'category': 'Cabelo',
                'active': true,
                'assigned': true,
              },
              {
                'id': 'service-2',
                'name': 'Barba',
                'category': 'Barbearia',
                'active': true,
                'assigned': false,
              },
            ],
            'working_hours': [
              {
                'id': 'hours-1',
                'iso_weekday': 1,
                'start_time': '08:30:00',
                'end_time': '12:00:00',
                'active': true,
              },
              {
                'id': 'hours-2',
                'iso_weekday': 1,
                'start_time': '13:00:00',
                'end_time': '18:00:00',
                'active': true,
              },
            ],
          });

      expect(configuration.professionalId, 'professional-1');
      expect(configuration.assignedServiceIds, {'service-1'});
      expect(configuration.workingHours, hasLength(2));
      expect(configuration.workingHours.first.startMinutes, 510);
      expect(configuration.workingHours.first.startLabel, '08:30');
      expect(configuration.workingHours.last.endLabel, '18:00');
    });

    test('converte bloqueios globais e individuais', () {
      final blocks = SupabasePublicBookingResponseParser.availabilityBlocks([
        {
          'id': 'block-1',
          'business_id': 'business-1',
          'professional_id': null,
          'starts_at': '2026-12-24T12:00:00Z',
          'ends_at': '2026-12-26T12:00:00Z',
          'reason': 'Recesso',
        },
        {
          'id': 'block-2',
          'business_id': 'business-1',
          'professional_id': 'professional-1',
          'starts_at': '2026-08-10T11:00:00Z',
          'ends_at': '2026-08-10T15:00:00Z',
          'reason': 'Consulta',
        },
      ]);

      expect(blocks, hasLength(2));
      expect(blocks.first.professionalId, isNull);
      expect(blocks.first.reason, 'Recesso');
      expect(blocks.last.professionalId, 'professional-1');
      expect(blocks.last.startsAt, DateTime.utc(2026, 8, 10, 11));
    });

    test('rejeita contratos incompletos em vez de criar dados corrompidos', () {
      expect(
        () => SupabasePublicBookingResponseParser.catalog({
          'business_name': 'Studio Aurora',
          'business_type': 'beautySalon',
          'slug': 'studio-aurora',
          'services': [
            {'id': 'service-1', 'name': 'Corte'},
          ],
          'professionals': <Object?>[],
        }),
        throwsFormatException,
      );
      expect(
        () => SupabasePublicBookingResponseParser.quote(<Object?>[]),
        throwsFormatException,
      );
      expect(
        () => SupabasePublicBookingResponseParser.professionalConfiguration({
          'professional_id': 'professional-1',
          'business_id': 'business-1',
          'services': <Object?>[],
          'working_hours': [
            {
              'id': 'hours-1',
              'iso_weekday': 8,
              'start_time': '08:00:00',
              'end_time': '18:00:00',
            },
          ],
        }),
        throwsFormatException,
      );
    });
  });
}
