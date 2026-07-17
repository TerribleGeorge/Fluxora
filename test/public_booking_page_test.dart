import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/domain/account.dart';
import 'package:fluxora/domain/public_booking.dart';
import 'package:fluxora/ui/public_booking_page.dart';

void main() {
  testWidgets('cliente agenda sem ver nível ou controle de desconto', (
    tester,
  ) async {
    final repository = _FakePublicBookingRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: PublicBookingPage(slug: 'studio-aurora', repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('public-booking-title')), findsOneWidget);
    await _completeBookingForm(tester, repository);

    expect(find.text('R\$ 90,00'), findsOneWidget);
    expect(find.textContaining('Premium'), findsNothing);
    expect(find.textContaining('nível'), findsNothing);
    expect(find.textContaining('desconto'), findsNothing);
    expect(repository.quoteCalls, 1);

    final confirmButton = find.byKey(
      const ValueKey('public-booking-confirm-button'),
    );
    await tester.ensureVisible(confirmButton);
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('public-booking-confirmation')),
      findsOneWidget,
    );
    expect(find.text('FX-ABC123'), findsOneWidget);
    expect(find.text('15/07/2026, 09:00–09:45'), findsOneWidget);
    expect(repository.createCalls, 1);
    expect(repository.bookingAttemptIds.single, isNotEmpty);
  });

  testWidgets('retry transitório reutiliza a mesma chave idempotente', (
    tester,
  ) async {
    final repository = _FakePublicBookingRepository(failFirstCreate: true);
    await tester.pumpWidget(
      MaterialApp(
        home: PublicBookingPage(slug: 'studio-aurora', repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    await _completeBookingForm(tester, repository);
    final confirmButton = find.byKey(
      const ValueKey('public-booking-confirm-button'),
    );
    await tester.ensureVisible(confirmButton);
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);
    expect(repository.bookingAttemptIds.single, isNotEmpty);
    final firstAttemptId = repository.bookingAttemptIds.single;
    expect(
      find.byKey(const ValueKey('public-booking-confirmation')),
      findsNothing,
    );

    await tester.ensureVisible(confirmButton);
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(repository.createCalls, 2);
    expect(repository.bookingAttemptIds, [firstAttemptId, firstAttemptId]);
    expect(repository.confirmationsReturned, 1);
    expect(
      find.byKey(const ValueKey('public-booking-confirmation')),
      findsOneWidget,
    );
  });
}

Future<void> _completeBookingForm(
  WidgetTester tester,
  _FakePublicBookingRepository repository,
) async {
  await tester.tap(
    find.byKey(const ValueKey('public-booking-service-service-1')),
  );
  await tester.pump();
  await tester.tap(
    find.byKey(const ValueKey('public-booking-professional-professional-1')),
  );
  await tester.pumpAndSettle();
  final slotChip = find.byKey(
    ValueKey(
      'public-booking-slot-${repository.slot.startsAt.millisecondsSinceEpoch}',
    ),
  );
  await tester.ensureVisible(slotChip);
  await tester.tap(slotChip);

  await tester.enterText(
    find.byKey(const ValueKey('public-booking-customer-name')),
    'Maria da Silva',
  );
  await tester.enterText(
    find.byKey(const ValueKey('public-booking-customer-email')),
    'maria@example.com',
  );
  await tester.enterText(
    find.byKey(const ValueKey('public-booking-customer-phone')),
    '11999999999',
  );
  final reviewButton = find.byKey(
    const ValueKey('public-booking-review-button'),
  );
  await tester.ensureVisible(reviewButton);
  await tester.tap(reviewButton);
  await tester.pumpAndSettle();
}

class _FakePublicBookingRepository implements PublicBookingRepository {
  _FakePublicBookingRepository({this.failFirstCreate = false});

  final bool failFirstCreate;
  final slot = PublicBookingSlot(
    startsAt: DateTime.utc(2026, 7, 15, 12),
    endsAt: DateTime.utc(2026, 7, 15, 12, 45),
    localTimeLabel: '09:00',
  );

  int quoteCalls = 0;
  int createCalls = 0;
  int confirmationsReturned = 0;
  final List<String> bookingAttemptIds = [];

  @override
  Future<PublicBookingCatalog> getCatalog(String slug) async {
    return PublicBookingCatalog(
      businessName: 'Studio Aurora',
      businessType: BusinessType.beautySalon,
      slug: slug,
      timeZone: 'America/Sao_Paulo',
      localToday: DateTime(2026, 7, 15),
      workingDays: const {1, 2, 3, 4, 5, 6, 7},
      maximumAdvanceDays: 2,
      services: const [
        PublicBookingService(
          id: 'service-1',
          name: 'Corte',
          category: 'Cabelo',
          price: 100,
          durationMinutes: 45,
        ),
      ],
      professionals: const [
        PublicBookingProfessional(
          id: 'professional-1',
          name: 'Ana',
          serviceIds: {'service-1'},
        ),
      ],
    );
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
  }) async => [slot];

  @override
  Future<PublicBookingQuote> getQuote({
    required String slug,
    required String serviceId,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
  }) async {
    quoteCalls++;
    return const PublicBookingQuote(basePrice: 100, finalPrice: 90);
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
  }) async {
    createCalls++;
    bookingAttemptIds.add(bookingAttemptId);
    if (failFirstCreate && createCalls == 1) {
      throw const PublicBookingFailure(
        'Falha temporária. Tente confirmar novamente.',
      );
    }
    confirmationsReturned++;
    return PublicBookingConfirmation(
      reference: 'FX-ABC123',
      startsAt: slot.startsAt,
      endsAt: slot.endsAt,
      finalPrice: 90,
      localDateTimeLabel: '15/07/2026, 09:00–09:45',
    );
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
