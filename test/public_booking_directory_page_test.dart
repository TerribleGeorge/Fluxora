import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/domain/account.dart';
import 'package:fluxora/domain/public_booking.dart';
import 'package:fluxora/ui/public_booking_directory_page.dart';

void main() {
  testWidgets('cliente encontra estabelecimento e abre agendamento sem login', (
    tester,
  ) async {
    final repository = _DirectoryRepository();
    await tester.pumpWidget(
      MaterialApp(home: PublicBookingDirectoryPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Encontrar atendimento'), findsOneWidget);
    expect(find.text('Barbearia Central'), findsOneWidget);
    expect(find.textContaining('Centro, São Paulo, SP'), findsOneWidget);

    await tester.tap(find.text('Barbearia Central'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('public-booking-content')),
      findsOneWidget,
    );
    expect(find.text('Barbearia Central'), findsWidgets);
  });
}

class _DirectoryRepository implements PublicBookingRepository {
  @override
  Future<List<PublicBookingBusiness>> searchBusinesses({
    String query = '',
    String city = '',
    String state = '',
    String postalCode = '',
  }) async {
    return const [
      PublicBookingBusiness(
        name: 'Barbearia Central',
        businessType: BusinessType.barbershop,
        slug: 'barbearia-central',
        city: 'São Paulo',
        state: 'SP',
        district: 'Centro',
        serviceCount: 4,
        professionalCount: 2,
      ),
    ];
  }

  @override
  Future<PublicBookingCatalog> getCatalog(String slug) async {
    return PublicBookingCatalog(
      businessName: 'Barbearia Central',
      businessType: BusinessType.barbershop,
      slug: slug,
      timeZone: 'America/Sao_Paulo',
      localToday: DateTime(2026, 7, 17),
      workingDays: const {1, 2, 3, 4, 5, 6},
      maximumAdvanceDays: 7,
      services: const [
        PublicBookingService(
          id: 'service-1',
          name: 'Corte',
          category: 'Barbearia',
          price: 50,
          durationMinutes: 45,
        ),
      ],
      professionals: const [
        PublicBookingProfessional(
          id: 'professional-1',
          name: 'João',
          serviceIds: {'service-1'},
        ),
      ],
    );
  }

  @override
  Future<List<PublicBookingSlot>> getAvailableSlots({
    required String slug,
    required String professionalId,
    required String serviceId,
    required DateTime day,
  }) async {
    return const [];
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
