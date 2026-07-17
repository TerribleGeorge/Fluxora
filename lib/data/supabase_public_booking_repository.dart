import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/account.dart';
import '../domain/public_booking.dart';

class SupabasePublicBookingRepository implements PublicBookingRepository {
  SupabasePublicBookingRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<PublicBookingSettings> getSettings(String businessId) {
    return _guard(
      fallbackMessage:
          'Não foi possível carregar as configurações de agendamento.',
      action: () async {
        final business = await _client
            .from('businesses')
            .select('id, public_slug')
            .eq('id', businessId)
            .single();
        final settings = await _client
            .from('public_booking_settings')
            .select()
            .eq('business_id', businessId)
            .maybeSingle();

        return SupabasePublicBookingResponseParser.settings(
          businessId: businessId,
          businessResponse: business,
          settingsResponse: settings,
        );
      },
    );
  }

  @override
  Future<void> saveSettings(PublicBookingSettings settings) {
    return _guard(
      fallbackMessage:
          'Não foi possível salvar as configurações de agendamento.',
      action: () async {
        final workingDays = settings.workingDays.toList()..sort();
        final response = await _client.rpc<dynamic>(
          'save_public_booking_settings',
          params: {
            'target_business_id': settings.businessId,
            'target_enabled': settings.enabled,
            'target_public_slug': settings.slug.trim(),
            'target_time_zone': settings.timeZone.trim(),
            'target_working_days': workingDays,
            'target_opening_time': _storageTime(settings.openingMinutes),
            'target_closing_time': _storageTime(settings.closingMinutes),
            'target_slot_interval_minutes': settings.slotIntervalMinutes,
            'target_minimum_notice_minutes': settings.minimumNoticeMinutes,
            'target_maximum_advance_days': settings.maximumAdvanceDays,
          },
        );
        SupabasePublicBookingResponseParser.savedSettings(
          response,
          fallback: settings,
        );
      },
    );
  }

  @override
  Future<List<PublicBookingProfessional>> getBookingProfessionals(
    String businessId,
  ) {
    return _guard(
      fallbackMessage: 'Não foi possível carregar os profissionais.',
      action: () async {
        final response = await _client
            .from('professionals')
            .select('id, name')
            .eq('business_id', businessId)
            .eq('active', true)
            .order('name');
        return SupabasePublicBookingResponseParser.professionals(response);
      },
    );
  }

  @override
  Future<ProfessionalBookingConfiguration> getProfessionalBookingConfiguration(
    String professionalId,
  ) {
    return _guard(
      fallbackMessage: 'Não foi possível carregar a agenda deste profissional.',
      action: () async {
        final response = await _client.rpc<dynamic>(
          'get_professional_booking_configuration',
          params: {'target_professional_id': professionalId},
        );
        return SupabasePublicBookingResponseParser.professionalConfiguration(
          response,
        );
      },
    );
  }

  @override
  Future<ProfessionalBookingConfiguration> saveProfessionalBookingConfiguration(
    ProfessionalBookingConfiguration configuration,
  ) {
    return _guard(
      fallbackMessage: 'Não foi possível salvar a agenda do profissional.',
      action: () async {
        final serviceIds = configuration.assignedServiceIds.toList()..sort();
        final workingHours = configuration.workingHours
            .map(
              (interval) => <String, Object?>{
                'iso_weekday': interval.isoWeekday,
                'start_time': _storageTime(interval.startMinutes),
                'end_time': _storageTime(interval.endMinutes),
                'active': interval.active,
              },
            )
            .toList(growable: false);
        final response = await _client.rpc<dynamic>(
          'save_professional_booking_configuration',
          params: {
            'target_professional_id': configuration.professionalId,
            'target_service_ids': serviceIds,
            'target_working_hours': workingHours,
          },
        );
        return SupabasePublicBookingResponseParser.professionalConfiguration(
          response,
        );
      },
    );
  }

  @override
  Future<List<ProfessionalAvailabilityBlock>> listAvailabilityBlocks(
    String businessId, {
    String? professionalId,
    DateTime? rangeStart,
    DateTime? rangeEnd,
  }) {
    return _guard(
      fallbackMessage: 'Não foi possível carregar as folgas e bloqueios.',
      action: () async {
        final params = <String, Object?>{
          'target_business_id': businessId,
          'target_professional_id': ?professionalId,
          if (rangeStart != null)
            'target_range_start': rangeStart.toUtc().toIso8601String(),
          if (rangeEnd != null)
            'target_range_end': rangeEnd.toUtc().toIso8601String(),
        };
        final response = await _client.rpc<dynamic>(
          'list_availability_blocks',
          params: params,
        );
        return SupabasePublicBookingResponseParser.availabilityBlocks(response);
      },
    );
  }

  @override
  Future<ProfessionalAvailabilityBlock> createAvailabilityBlock(
    ProfessionalAvailabilityBlock block,
  ) {
    return _guard(
      fallbackMessage: 'Não foi possível criar este bloqueio de agenda.',
      action: () async {
        final response = await _client.rpc<dynamic>(
          'create_availability_block',
          params: {
            'target_business_id': block.businessId,
            'target_professional_id': block.professionalId,
            'target_starts_at': block.startsAt.toUtc().toIso8601String(),
            'target_ends_at': block.endsAt.toUtc().toIso8601String(),
            'target_reason': block.reason.trim(),
          },
        );
        return SupabasePublicBookingResponseParser.availabilityBlock(response);
      },
    );
  }

  @override
  Future<void> deleteAvailabilityBlock(String blockId) {
    return _guard(
      fallbackMessage: 'Não foi possível remover este bloqueio de agenda.',
      action: () async {
        await _client.rpc<void>(
          'delete_availability_block',
          params: {'target_block_id': blockId},
        );
      },
    );
  }

  @override
  Future<PublicBookingCatalog> getCatalog(String slug) {
    return _guard(
      fallbackMessage: 'Não foi possível carregar esta página de agendamento.',
      action: () async {
        final response = await _client.rpc<dynamic>(
          'get_public_booking_page',
          params: {'target_slug': slug.trim()},
        );
        return SupabasePublicBookingResponseParser.catalog(response);
      },
    );
  }

  @override
  Future<List<PublicBookingSlot>> getAvailableSlots({
    required String slug,
    required String professionalId,
    required String serviceId,
    required DateTime day,
  }) {
    return _guard(
      fallbackMessage: 'Não foi possível consultar os horários disponíveis.',
      action: () async {
        final response = await _client.rpc<dynamic>(
          'get_public_available_slots',
          params: {
            'target_slug': slug.trim(),
            'target_professional_id': professionalId,
            'target_service_id': serviceId,
            'target_day': _storageDate(day),
          },
        );
        return SupabasePublicBookingResponseParser.slots(response);
      },
    );
  }

  @override
  Future<PublicBookingQuote> getQuote({
    required String slug,
    required String serviceId,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
  }) {
    return _guard(
      fallbackMessage: 'Não foi possível calcular o valor deste atendimento.',
      action: () async {
        final response = await _client.rpc<dynamic>(
          'quote_public_booking',
          params: {
            'target_slug': slug.trim(),
            'target_service_id': serviceId,
            'raw_name': customerName.trim(),
            'raw_email': customerEmail.trim(),
            'raw_phone': customerPhone.trim(),
          },
        );
        return SupabasePublicBookingResponseParser.quote(response);
      },
    );
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
    return _guard(
      fallbackMessage: 'Não foi possível confirmar o agendamento.',
      action: () async {
        final response = await _client.rpc<dynamic>(
          'create_public_booking_v3',
          params: {
            'target_slug': slug.trim(),
            'target_professional_id': professionalId,
            'target_service_id': serviceId,
            'raw_name': customerName.trim(),
            'raw_email': customerEmail.trim(),
            'raw_phone': customerPhone.trim(),
            'target_starts_at': startsAt.toUtc().toIso8601String(),
            'target_idempotency_key': bookingAttemptId,
            'target_notes': notes.trim(),
          },
        );
        return SupabasePublicBookingResponseParser.confirmation(response);
      },
    );
  }

  Future<T> _guard<T>({
    required String fallbackMessage,
    required Future<T> Function() action,
  }) async {
    try {
      return await action();
    } on PublicBookingFailure {
      rethrow;
    } on PostgrestException catch (error) {
      throw PublicBookingFailure(
        _friendlyPostgrestMessage(error, fallbackMessage),
      );
    } on Object {
      throw PublicBookingFailure(fallbackMessage);
    }
  }

  static String _friendlyPostgrestMessage(
    PostgrestException error,
    String fallback,
  ) {
    final details = '${error.message} ${error.details ?? ''}'.toLowerCase();
    if (error.code == '23505' && details.contains('slug')) {
      return 'Este link de agendamento já está em uso. Escolha outro.';
    }
    if (error.code == '42501' ||
        details.contains('permission') ||
        details.contains('permissão') ||
        details.contains('permissao')) {
      return 'Seu perfil não tem permissão para alterar esta agenda.';
    }
    if (error.code == '23514' ||
        details.contains('working hour') ||
        details.contains('expediente') ||
        details.contains('serviço vinculado') ||
        details.contains('servico vinculado')) {
      return 'Revise os serviços e horários configurados para este profissional.';
    }
    if (details.contains('rate limit') ||
        details.contains('muitas tentativas') ||
        details.contains('too many')) {
      return 'Foram feitas muitas tentativas. Aguarde um pouco e tente novamente.';
    }
    if (error.code == '23P01' ||
        details.contains('indispon') ||
        details.contains('unavailable') ||
        details.contains('conflit') ||
        details.contains('overlap')) {
      return 'Esse horário acabou de ficar indisponível. Escolha outro.';
    }
    if (details.contains('desativ') || details.contains('disabled')) {
      return 'Este estabelecimento não está recebendo agendamentos online no momento.';
    }
    if (details.contains('anteced') ||
        details.contains('notice') ||
        details.contains('advance')) {
      return 'Esse horário está fora do período permitido para agendamento.';
    }
    if (details.contains('not found') ||
        details.contains('não encontr') ||
        details.contains('nao encontr')) {
      return 'Não encontramos esta página de agendamento.';
    }
    return fallback;
  }

  static String _storageTime(int totalMinutes) {
    final hour = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final minute = (totalMinutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }

  static String _storageDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

/// Pure response conversion kept separate from the network client so Supabase
/// JSON contracts can be tested without a live project or SDK mocks.
class SupabasePublicBookingResponseParser {
  const SupabasePublicBookingResponseParser._();

  static PublicBookingSettings settings({
    required String businessId,
    required Object? businessResponse,
    required Object? settingsResponse,
  }) {
    final business = _singleMap(businessResponse, 'estabelecimento');
    final slug = _optionalString(business['public_slug']);
    if (settingsResponse == null) {
      return PublicBookingSettings(businessId: businessId, slug: slug);
    }

    final row = _singleMap(settingsResponse, 'configurações');
    return PublicBookingSettings(
      businessId: businessId,
      slug: slug,
      enabled: _optionalBool(row['enabled'], fallback: false),
      timeZone: _optionalString(
        row['time_zone'],
        fallback: 'America/Sao_Paulo',
      ),
      workingDays: _intSet(
        row['working_days'],
        fallback: const {1, 2, 3, 4, 5, 6},
      ),
      openingMinutes: _timeMinutes(row['opening_time'], fallback: 8 * 60),
      closingMinutes: _timeMinutes(row['closing_time'], fallback: 19 * 60),
      slotIntervalMinutes: _optionalInt(
        row['slot_interval_minutes'],
        fallback: 15,
      ),
      minimumNoticeMinutes: _optionalInt(
        row['minimum_notice_minutes'],
        fallback: 60,
      ),
      maximumAdvanceDays: _optionalInt(
        row['maximum_advance_days'],
        fallback: 60,
      ),
    );
  }

  static PublicBookingSettings savedSettings(
    Object? response, {
    required PublicBookingSettings fallback,
  }) {
    final row = _singleMap(response, 'configurações salvas');
    return PublicBookingSettings(
      businessId: _optionalString(
        row['business_id'],
        fallback: fallback.businessId,
      ),
      slug: _optionalString(row['public_slug'], fallback: fallback.slug),
      enabled: _optionalBool(row['enabled'], fallback: fallback.enabled),
      timeZone: _optionalString(row['time_zone'], fallback: fallback.timeZone),
      workingDays: _intSet(row['working_days'], fallback: fallback.workingDays),
      openingMinutes: _timeMinutes(
        row['opening_time'],
        fallback: fallback.openingMinutes,
      ),
      closingMinutes: _timeMinutes(
        row['closing_time'],
        fallback: fallback.closingMinutes,
      ),
      slotIntervalMinutes: _optionalInt(
        row['slot_interval_minutes'],
        fallback: fallback.slotIntervalMinutes,
      ),
      minimumNoticeMinutes: _optionalInt(
        row['minimum_notice_minutes'],
        fallback: fallback.minimumNoticeMinutes,
      ),
      maximumAdvanceDays: _optionalInt(
        row['maximum_advance_days'],
        fallback: fallback.maximumAdvanceDays,
      ),
    );
  }

  static List<PublicBookingProfessional> professionals(Object? response) {
    return _mapList(
      response,
      'profissionais',
    ).map(_professional).toList(growable: false);
  }

  static ProfessionalBookingConfiguration professionalConfiguration(
    Object? response,
  ) {
    final row = _singleMap(response, 'agenda profissional');
    return ProfessionalBookingConfiguration(
      professionalId: _requiredString(
        row['professional_id'],
        'professional_id',
      ),
      businessId: _requiredString(row['business_id'], 'business_id'),
      services: _mapList(row['services'], 'serviços do profissional')
          .map(
            (service) => ProfessionalBookingServiceOption(
              id: _requiredString(service['id'], 'service.id'),
              name: _requiredString(service['name'], 'service.name'),
              category: _optionalString(service['category']),
              active: _optionalBool(service['active'], fallback: true),
              assigned: _optionalBool(service['assigned'], fallback: false),
            ),
          )
          .toList(growable: false),
      workingHours: _mapList(
        row['working_hours'],
        'expediente profissional',
      ).map(_workingInterval).toList(growable: false),
    );
  }

  static List<ProfessionalAvailabilityBlock> availabilityBlocks(
    Object? response,
  ) {
    return _mapList(
      response,
      'bloqueios de agenda',
    ).map(_availabilityBlock).toList(growable: false);
  }

  static ProfessionalAvailabilityBlock availabilityBlock(Object? response) {
    return _availabilityBlock(_singleMap(response, 'bloqueio de agenda'));
  }

  static PublicBookingCatalog catalog(Object? response) {
    final row = _singleMap(response, 'catálogo');
    return PublicBookingCatalog(
      businessName: _requiredString(row['business_name'], 'business_name'),
      businessType: _businessType(row['business_type']),
      slug: _requiredString(row['slug'], 'slug'),
      timeZone: _optionalString(
        row['time_zone'],
        fallback: 'America/Sao_Paulo',
      ),
      localToday: _dateOnly(row['local_today']),
      workingDays: _intSet(
        row['working_days'],
        fallback: const {1, 2, 3, 4, 5, 6},
      ),
      maximumAdvanceDays: _optionalInt(
        row['maximum_advance_days'],
        fallback: 60,
      ),
      services: _mapList(
        row['services'],
        'serviços',
      ).map(_service).toList(growable: false),
      professionals: _mapList(
        row['professionals'],
        'profissionais',
      ).map(_professional).toList(growable: false),
    );
  }

  static List<PublicBookingSlot> slots(Object? response) {
    return _mapList(response, 'horários')
        .map(
          (row) => PublicBookingSlot(
            startsAt: _dateTime(row['starts_at'], 'starts_at'),
            endsAt: _dateTime(row['ends_at'], 'ends_at'),
            localTimeLabel: _requiredString(
              row['local_time_label'],
              'local_time_label',
            ),
          ),
        )
        .toList(growable: false);
  }

  static PublicBookingQuote quote(Object? response) {
    final row = _singleMap(response, 'cotação');
    return PublicBookingQuote(
      basePrice: _requiredDouble(row['base_price'], 'base_price'),
      finalPrice: _requiredDouble(row['final_price'], 'final_price'),
    );
  }

  static PublicBookingConfirmation confirmation(Object? response) {
    final row = _singleMap(response, 'confirmação');
    return PublicBookingConfirmation(
      reference: _requiredString(row['reference'], 'reference'),
      startsAt: _dateTime(row['starts_at'], 'starts_at'),
      endsAt: _dateTime(row['ends_at'], 'ends_at'),
      finalPrice: _requiredDouble(row['final_price'], 'final_price'),
      localDateTimeLabel: _optionalString(row['local_date_time_label']),
    );
  }

  static PublicBookingService _service(Map<String, dynamic> row) {
    return PublicBookingService(
      id: _requiredString(row['id'], 'service.id'),
      name: _requiredString(row['name'], 'service.name'),
      category: _optionalString(row['category']),
      price: _requiredDouble(row['price'], 'service.price'),
      durationMinutes: _requiredInt(
        row['duration_minutes'],
        'service.duration_minutes',
      ),
    );
  }

  static PublicBookingProfessional _professional(Map<String, dynamic> row) {
    return PublicBookingProfessional(
      id: _requiredString(row['id'], 'professional.id'),
      name: _requiredString(row['name'], 'professional.name'),
      serviceIds: _stringSet(row['service_ids']),
    );
  }

  static ProfessionalAvailabilityBlock _availabilityBlock(
    Map<String, dynamic> row,
  ) {
    return ProfessionalAvailabilityBlock(
      id: _requiredString(row['id'], 'availability_block.id'),
      businessId: _requiredString(
        row['business_id'],
        'availability_block.business_id',
      ),
      professionalId: _nullableString(row['professional_id']),
      startsAt: _dateTime(row['starts_at'], 'availability_block.starts_at'),
      endsAt: _dateTime(row['ends_at'], 'availability_block.ends_at'),
      reason: _optionalString(row['reason']),
    );
  }

  static ProfessionalWorkingInterval _workingInterval(
    Map<String, dynamic> row,
  ) {
    final startMinutes = _requiredTimeMinutes(row['start_time']);
    final endMinutes = _requiredTimeMinutes(row['end_time']);
    if (endMinutes <= startMinutes) {
      throw const FormatException(
        'O fim do expediente precisa ser posterior ao início.',
      );
    }
    return ProfessionalWorkingInterval(
      id: _optionalString(row['id']),
      isoWeekday: _boundedWeekday(row['iso_weekday']),
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      active: _optionalBool(row['active'], fallback: true),
    );
  }

  static Map<String, dynamic> _singleMap(Object? value, String label) {
    if (value is Map) return _stringMap(value, label);
    if (value is List && value.length == 1) {
      return _singleMap(value.single, label);
    }
    throw FormatException('Resposta de $label inválida.');
  }

  static List<Map<String, dynamic>> _mapList(Object? value, String label) {
    if (value is! List) {
      throw FormatException('Lista de $label inválida.');
    }
    return value.map((item) => _stringMap(item, label)).toList(growable: false);
  }

  static Map<String, dynamic> _stringMap(Object? value, String label) {
    if (value is! Map) throw FormatException('Item de $label inválido.');
    try {
      return Map<String, dynamic>.from(value);
    } on Object {
      throw FormatException('Item de $label inválido.');
    }
  }

  static String _requiredString(Object? value, String field) {
    final result = value is String ? value.trim() : '';
    if (result.isEmpty) throw FormatException('Campo $field inválido.');
    return result;
  }

  static String _optionalString(Object? value, {String fallback = ''}) {
    if (value == null) return fallback;
    final result = value is String ? value.trim() : '';
    return result.isEmpty ? fallback : result;
  }

  static String? _nullableString(Object? value) {
    final result = _optionalString(value);
    return result.isEmpty ? null : result;
  }

  static bool _optionalBool(Object? value, {required bool fallback}) {
    return value is bool ? value : fallback;
  }

  static int _requiredInt(Object? value, String field) {
    if (value is num) return value.toInt();
    final result = int.tryParse(value?.toString() ?? '');
    if (result == null) throw FormatException('Campo $field inválido.');
    return result;
  }

  static int _optionalInt(Object? value, {required int fallback}) {
    if (value == null) return fallback;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  static double _requiredDouble(Object? value, String field) {
    if (value is num) return value.toDouble();
    final result = double.tryParse(value?.toString() ?? '');
    if (result == null) throw FormatException('Campo $field inválido.');
    return result;
  }

  static DateTime _dateTime(Object? value, String field) {
    final result = DateTime.tryParse(value?.toString() ?? '');
    if (result == null) throw FormatException('Campo $field inválido.');
    return result;
  }

  static DateTime _dateOnly(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    final source = parsed ?? DateTime.now();
    return DateTime(source.year, source.month, source.day);
  }

  static BusinessType _businessType(Object? value) {
    final name = value?.toString() ?? '';
    final matches = BusinessType.values.where((item) => item.name == name);
    if (matches.isEmpty) {
      throw const FormatException('Tipo de estabelecimento inválido.');
    }
    return matches.single;
  }

  static Set<int> _intSet(Object? value, {required Set<int> fallback}) {
    if (value == null) return Set<int>.from(fallback);
    if (value is! List) {
      throw const FormatException('Dias de funcionamento inválidos.');
    }
    final days = value.map((item) => _requiredInt(item, 'working_days'));
    if (days.any((day) => day < 1 || day > 7)) {
      throw const FormatException('Dias de funcionamento inválidos.');
    }
    return days.toSet();
  }

  static Set<String> _stringSet(Object? value) {
    if (value == null) return const <String>{};
    if (value is! List) {
      throw const FormatException('Lista de serviços inválida.');
    }
    return value.map((item) => _requiredString(item, 'service_ids')).toSet();
  }

  static int _boundedWeekday(Object? value) {
    final weekday = _requiredInt(value, 'iso_weekday');
    if (weekday < 1 || weekday > 7) {
      throw const FormatException('Dia do expediente inválido.');
    }
    return weekday;
  }

  static int _timeMinutes(Object? value, {required int fallback}) {
    if (value == null) return fallback;
    if (value is num) return value.toInt();
    final parts = value.toString().split(':');
    if (parts.length < 2) {
      throw const FormatException('Horário de funcionamento inválido.');
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    final validHour = hour != null && hour >= 0 && hour <= 24;
    final validMinute = minute != null && minute >= 0 && minute < 60;
    if (!validHour || !validMinute || (hour == 24 && minute != 0)) {
      throw const FormatException('Horário de funcionamento inválido.');
    }
    return hour * 60 + minute;
  }

  static int _requiredTimeMinutes(Object? value) {
    if (value == null) {
      throw const FormatException('Horário de expediente inválido.');
    }
    return _timeMinutes(value, fallback: -1);
  }
}
