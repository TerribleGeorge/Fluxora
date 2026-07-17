import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/domain/public_booking.dart';
import 'package:fluxora/ui/professional_booking_configuration_page.dart';

void main() {
  testWidgets(
    'dono configura serviços e expediente com intervalo de almoço atomicamente',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _BookingConfigurationRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalBookingConfigurationPage(
            businessId: 'business-1',
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Agenda por profissional'), findsOneWidget);
      expect(find.text('08:00 – 12:00'), findsOneWidget);
      expect(find.text('13:00 – 18:00'), findsOneWidget);
      expect(find.text('Feriado municipal'), findsOneWidget);
      expect(find.textContaining('Toda a equipe'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('service-service-2')));
      await tester.tap(find.byKey(const ValueKey('remove-interval-1-780')));
      final save = find.byKey(const ValueKey('save-professional-booking'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(repository.savedConfiguration, isNotNull);
      expect(repository.savedConfiguration!.assignedServiceIds, {
        'service-1',
        'service-2',
      });
      expect(repository.savedConfiguration!.workingHours, hasLength(1));
      expect(find.text('Agenda do profissional atualizada.'), findsOneWidget);
    },
  );

  testWidgets('dono adiciona bloqueio global e remove bloqueio existente', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _BookingConfigurationRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: ProfessionalBookingConfigurationPage(
          businessId: 'business-1',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final addBlock = find.byKey(const ValueKey('add-availability-block'));
    await tester.ensureVisible(addBlock);
    await tester.tap(addBlock);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('block-reason')),
      'Férias coletivas',
    );
    await tester.tap(find.byKey(const ValueKey('business-wide-block')));
    await tester.tap(find.byKey(const ValueKey('confirm-availability-block')));
    await tester.pumpAndSettle();

    expect(repository.createdBlock?.reason, 'Férias coletivas');
    expect(repository.createdBlock?.professionalId, isNull);
    expect(find.text('Férias coletivas'), findsOneWidget);

    final delete = find.byKey(const ValueKey('delete-block-block-global'));
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-delete-block')));
    await tester.pumpAndSettle();

    expect(repository.deletedBlockId, 'block-global');
    expect(find.text('Feriado municipal'), findsNothing);
  });

  testWidgets(
    'cancelar troca com alterações pendentes restaura profissional selecionado',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _BookingConfigurationRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalBookingConfigurationPage(
            businessId: 'business-1',
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('service-service-2')));
      final selector = find.byType(DropdownButtonFormField<String>);
      final originalKey = tester.widget(selector).key;
      expect(
        tester.widget<DropdownButtonFormField<String>>(selector).initialValue,
        'professional-1',
      );

      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bruno').last);
      await tester.pumpAndSettle();
      expect(find.text('Descartar alterações?'), findsOneWidget);

      await tester.tap(find.text('Continuar editando'));
      await tester.pumpAndSettle();

      final restored = find.byType(DropdownButtonFormField<String>);
      expect(
        tester.widget<DropdownButtonFormField<String>>(restored).initialValue,
        'professional-1',
      );
      expect(tester.widget(restored).key, isNot(originalKey));
      expect(repository.configurationRequests, ['professional-1']);
      expect(find.text('Ana'), findsOneWidget);
    },
  );
}

class _BookingConfigurationRepository implements PublicBookingRepository {
  ProfessionalBookingConfiguration? savedConfiguration;
  ProfessionalAvailabilityBlock? createdBlock;
  String? deletedBlockId;
  final configurationRequests = <String>[];

  @override
  Future<List<PublicBookingProfessional>> getBookingProfessionals(
    String businessId,
  ) async {
    return const [
      PublicBookingProfessional(id: 'professional-1', name: 'Ana'),
      PublicBookingProfessional(id: 'professional-2', name: 'Bruno'),
    ];
  }

  @override
  Future<ProfessionalBookingConfiguration> getProfessionalBookingConfiguration(
    String professionalId,
  ) async {
    configurationRequests.add(professionalId);
    return ProfessionalBookingConfiguration(
      professionalId: professionalId,
      businessId: 'business-1',
      services: const [
        ProfessionalBookingServiceOption(
          id: 'service-1',
          name: 'Corte',
          category: 'Cabelo',
          active: true,
          assigned: true,
        ),
        ProfessionalBookingServiceOption(
          id: 'service-2',
          name: 'Barba',
          category: 'Barbearia',
          active: true,
          assigned: false,
        ),
      ],
      workingHours: const [
        ProfessionalWorkingInterval(
          id: 'morning',
          isoWeekday: 1,
          startMinutes: 8 * 60,
          endMinutes: 12 * 60,
        ),
        ProfessionalWorkingInterval(
          id: 'afternoon',
          isoWeekday: 1,
          startMinutes: 13 * 60,
          endMinutes: 18 * 60,
        ),
      ],
    );
  }

  @override
  Future<ProfessionalBookingConfiguration> saveProfessionalBookingConfiguration(
    ProfessionalBookingConfiguration configuration,
  ) async {
    savedConfiguration = configuration;
    return configuration;
  }

  @override
  Future<List<ProfessionalAvailabilityBlock>> listAvailabilityBlocks(
    String businessId, {
    String? professionalId,
    DateTime? rangeStart,
    DateTime? rangeEnd,
  }) async {
    return [
      ProfessionalAvailabilityBlock(
        id: 'block-global',
        businessId: businessId,
        startsAt: DateTime(2030, 1, 1, 8),
        endsAt: DateTime(2030, 1, 1, 18),
        reason: 'Feriado municipal',
      ),
      ProfessionalAvailabilityBlock(
        id: 'block-personal',
        businessId: businessId,
        professionalId: 'professional-1',
        startsAt: DateTime(2030, 2, 1, 8),
        endsAt: DateTime(2030, 2, 1, 12),
        reason: 'Curso',
      ),
    ];
  }

  @override
  Future<ProfessionalAvailabilityBlock> createAvailabilityBlock(
    ProfessionalAvailabilityBlock block,
  ) async {
    createdBlock = block;
    return ProfessionalAvailabilityBlock(
      id: 'block-new',
      businessId: block.businessId,
      professionalId: block.professionalId,
      startsAt: block.startsAt,
      endsAt: block.endsAt,
      reason: block.reason,
    );
  }

  @override
  Future<void> deleteAvailabilityBlock(String blockId) async {
    deletedBlockId = blockId;
  }

  @override
  Future<PublicBookingSettings> getSettings(String businessId) {
    throw UnimplementedError();
  }

  @override
  Future<void> saveSettings(PublicBookingSettings settings) {
    throw UnimplementedError();
  }

  @override
  Future<PublicBookingCatalog> getCatalog(String slug) {
    throw UnimplementedError();
  }

  @override
  Future<List<PublicBookingSlot>> getAvailableSlots({
    required String slug,
    required String professionalId,
    required String serviceId,
    required DateTime day,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PublicBookingQuote> getQuote({
    required String slug,
    required String serviceId,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PublicBookingConfirmation> createBooking({
    required String slug,
    required String professionalId,
    required String serviceId,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required DateTime startsAt,
    required String bookingAttemptId,
    String notes = '',
  }) {
    throw UnimplementedError();
  }
}
