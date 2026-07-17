import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/domain/public_booking.dart';
import 'package:fluxora/ui/public_booking_settings_page.dart';

void main() {
  testWidgets('dono ativa e salva o link público do estabelecimento', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _SettingsRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: PublicBookingSettingsPage(
          businessId: 'business-1',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Agendamento online'), findsOneWidget);
    expect(
      find.textContaining('aparecerá após a publicação do portal web'),
      findsOneWidget,
    );
    expect(find.text('Padrão para novos profissionais'), findsOneWidget);
    expect(
      find.textContaining('preenchem somente a agenda de profissionais'),
      findsOneWidget,
    );
    expect(find.text('Regras gerais do portal'), findsOneWidget);
    expect(find.text('Aparecer na busca pública'), findsOneWidget);
    expect(find.text('Localização pública'), findsOneWidget);
    expect(
      find.textContaining('valem para todos os profissionais'),
      findsOneWidget,
    );

    await tester.tap(find.text('Aceitar agendamentos pelo link'));
    final saveButton = find.text('Salvar configurações');
    await tester.scrollUntilVisible(
      saveButton,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repository.saved, isNotNull);
    expect(repository.saved!.enabled, isTrue);
    expect(repository.saved!.slug, 'studio-aurora');
  });
}

class _SettingsRepository implements PublicBookingRepository {
  PublicBookingSettings? saved;

  @override
  Future<PublicBookingSettings> getSettings(String businessId) async {
    return PublicBookingSettings(
      businessId: businessId,
      slug: 'studio-aurora',
      enabled: false,
    );
  }

  @override
  Future<void> saveSettings(PublicBookingSettings settings) async {
    saved = settings;
  }

  @override
  Future<PublicBookingCatalog> getCatalog(String slug) {
    throw UnimplementedError();
  }

  @override
  Future<List<PublicBookingBusiness>> searchBusinesses({
    String query = '',
    String city = '',
    String state = '',
    String postalCode = '',
  }) {
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

  @override
  Future<List<PublicBookingProfessional>> getBookingProfessionals(
    String businessId,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<ProfessionalBookingConfiguration> getProfessionalBookingConfiguration(
    String professionalId,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<ProfessionalBookingConfiguration> saveProfessionalBookingConfiguration(
    ProfessionalBookingConfiguration configuration,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<List<ProfessionalAvailabilityBlock>> listAvailabilityBlocks(
    String businessId, {
    String? professionalId,
    DateTime? rangeStart,
    DateTime? rangeEnd,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ProfessionalAvailabilityBlock> createAvailabilityBlock(
    ProfessionalAvailabilityBlock block,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteAvailabilityBlock(String blockId) {
    throw UnimplementedError();
  }
}
