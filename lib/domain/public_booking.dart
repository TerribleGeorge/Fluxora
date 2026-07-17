import 'account.dart';

class PublicBookingSettings {
  const PublicBookingSettings({
    required this.businessId,
    required this.slug,
    this.enabled = false,
    this.timeZone = 'America/Sao_Paulo',
    this.workingDays = const {1, 2, 3, 4, 5, 6},
    this.openingMinutes = 8 * 60,
    this.closingMinutes = 19 * 60,
    this.slotIntervalMinutes = 15,
    this.minimumNoticeMinutes = 60,
    this.maximumAdvanceDays = 60,
  });

  final String businessId;
  final String slug;
  final bool enabled;
  final String timeZone;
  final Set<int> workingDays;
  final int openingMinutes;
  final int closingMinutes;
  final int slotIntervalMinutes;
  final int minimumNoticeMinutes;
  final int maximumAdvanceDays;

  PublicBookingSettings copyWith({
    String? slug,
    bool? enabled,
    String? timeZone,
    Set<int>? workingDays,
    int? openingMinutes,
    int? closingMinutes,
    int? slotIntervalMinutes,
    int? minimumNoticeMinutes,
    int? maximumAdvanceDays,
  }) {
    return PublicBookingSettings(
      businessId: businessId,
      slug: slug ?? this.slug,
      enabled: enabled ?? this.enabled,
      timeZone: timeZone ?? this.timeZone,
      workingDays: workingDays ?? this.workingDays,
      openingMinutes: openingMinutes ?? this.openingMinutes,
      closingMinutes: closingMinutes ?? this.closingMinutes,
      slotIntervalMinutes: slotIntervalMinutes ?? this.slotIntervalMinutes,
      minimumNoticeMinutes: minimumNoticeMinutes ?? this.minimumNoticeMinutes,
      maximumAdvanceDays: maximumAdvanceDays ?? this.maximumAdvanceDays,
    );
  }

  String get openingLabel => _timeLabel(openingMinutes);
  String get closingLabel => _timeLabel(closingMinutes);

  static String _timeLabel(int minutes) {
    final hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final minute = (minutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class PublicBookingCatalog {
  const PublicBookingCatalog({
    required this.businessName,
    required this.businessType,
    required this.slug,
    required this.timeZone,
    required this.localToday,
    required this.workingDays,
    required this.maximumAdvanceDays,
    required this.services,
    required this.professionals,
  });

  final String businessName;
  final BusinessType businessType;
  final String slug;
  final String timeZone;
  final DateTime localToday;
  final Set<int> workingDays;
  final int maximumAdvanceDays;
  final List<PublicBookingService> services;
  final List<PublicBookingProfessional> professionals;
}

class PublicBookingService {
  const PublicBookingService({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.durationMinutes,
  });

  final String id;
  final String name;
  final String category;
  final double price;
  final int durationMinutes;
}

class PublicBookingProfessional {
  const PublicBookingProfessional({
    required this.id,
    required this.name,
    this.serviceIds = const <String>{},
  });

  final String id;
  final String name;
  final Set<String> serviceIds;
}

class ProfessionalBookingServiceOption {
  const ProfessionalBookingServiceOption({
    required this.id,
    required this.name,
    required this.category,
    required this.active,
    required this.assigned,
  });

  final String id;
  final String name;
  final String category;
  final bool active;
  final bool assigned;

  ProfessionalBookingServiceOption copyWith({bool? assigned}) {
    return ProfessionalBookingServiceOption(
      id: id,
      name: name,
      category: category,
      active: active,
      assigned: assigned ?? this.assigned,
    );
  }
}

class ProfessionalWorkingInterval {
  const ProfessionalWorkingInterval({
    required this.isoWeekday,
    required this.startMinutes,
    required this.endMinutes,
    this.id = '',
    this.active = true,
  });

  final String id;
  final int isoWeekday;
  final int startMinutes;
  final int endMinutes;
  final bool active;

  String get startLabel => PublicBookingSettings._timeLabel(startMinutes);
  String get endLabel => PublicBookingSettings._timeLabel(endMinutes);

  ProfessionalWorkingInterval copyWith({
    String? id,
    int? isoWeekday,
    int? startMinutes,
    int? endMinutes,
    bool? active,
  }) {
    return ProfessionalWorkingInterval(
      id: id ?? this.id,
      isoWeekday: isoWeekday ?? this.isoWeekday,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      active: active ?? this.active,
    );
  }
}

class ProfessionalAvailabilityBlock {
  const ProfessionalAvailabilityBlock({
    required this.businessId,
    required this.startsAt,
    required this.endsAt,
    this.id = '',
    this.professionalId,
    this.reason = '',
  });

  final String id;
  final String businessId;
  final String? professionalId;
  final DateTime startsAt;
  final DateTime endsAt;
  final String reason;
}

class ProfessionalBookingConfiguration {
  const ProfessionalBookingConfiguration({
    required this.professionalId,
    required this.businessId,
    required this.services,
    required this.workingHours,
  });

  final String professionalId;
  final String businessId;
  final List<ProfessionalBookingServiceOption> services;
  final List<ProfessionalWorkingInterval> workingHours;

  Set<String> get assignedServiceIds => services
      .where((service) => service.active && service.assigned)
      .map((service) => service.id)
      .toSet();

  ProfessionalBookingConfiguration copyWith({
    List<ProfessionalBookingServiceOption>? services,
    List<ProfessionalWorkingInterval>? workingHours,
  }) {
    return ProfessionalBookingConfiguration(
      professionalId: professionalId,
      businessId: businessId,
      services: services ?? this.services,
      workingHours: workingHours ?? this.workingHours,
    );
  }
}

class PublicBookingSlot {
  const PublicBookingSlot({
    required this.startsAt,
    required this.endsAt,
    required this.localTimeLabel,
  });

  final DateTime startsAt;
  final DateTime endsAt;
  final String localTimeLabel;
}

class PublicBookingQuote {
  const PublicBookingQuote({required this.basePrice, required this.finalPrice});

  final double basePrice;
  final double finalPrice;
}

class PublicBookingConfirmation {
  const PublicBookingConfirmation({
    required this.reference,
    required this.startsAt,
    required this.endsAt,
    required this.finalPrice,
    this.localDateTimeLabel = '',
  });

  final String reference;
  final DateTime startsAt;
  final DateTime endsAt;
  final double finalPrice;
  final String localDateTimeLabel;
}

class PublicBookingFailure implements Exception {
  const PublicBookingFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class PublicBookingRepository {
  Future<PublicBookingSettings> getSettings(String businessId);

  Future<void> saveSettings(PublicBookingSettings settings);

  Future<List<PublicBookingProfessional>> getBookingProfessionals(
    String businessId,
  );

  Future<ProfessionalBookingConfiguration> getProfessionalBookingConfiguration(
    String professionalId,
  );

  Future<ProfessionalBookingConfiguration> saveProfessionalBookingConfiguration(
    ProfessionalBookingConfiguration configuration,
  );

  Future<List<ProfessionalAvailabilityBlock>> listAvailabilityBlocks(
    String businessId, {
    String? professionalId,
    DateTime? rangeStart,
    DateTime? rangeEnd,
  });

  Future<ProfessionalAvailabilityBlock> createAvailabilityBlock(
    ProfessionalAvailabilityBlock block,
  );

  Future<void> deleteAvailabilityBlock(String blockId);

  Future<PublicBookingCatalog> getCatalog(String slug);

  Future<List<PublicBookingSlot>> getAvailableSlots({
    required String slug,
    required String professionalId,
    required String serviceId,
    required DateTime day,
  });

  Future<PublicBookingQuote> getQuote({
    required String slug,
    required String serviceId,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
  });

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
  });
}
