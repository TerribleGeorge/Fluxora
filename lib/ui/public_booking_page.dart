import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../domain/id_generator.dart';
import '../domain/public_booking.dart';

class PublicBookingPage extends StatefulWidget {
  const PublicBookingPage({
    required this.slug,
    required this.repository,
    super.key,
  });

  final String slug;
  final PublicBookingRepository repository;

  @override
  State<PublicBookingPage> createState() => _PublicBookingPageState();
}

class _PublicBookingPageState extends State<PublicBookingPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  PublicBookingCatalog? _catalog;
  PublicBookingService? _selectedService;
  PublicBookingProfessional? _selectedProfessional;
  DateTime? _selectedDay;
  PublicBookingSlot? _selectedSlot;
  PublicBookingQuote? _quote;
  PublicBookingConfirmation? _confirmation;

  List<DateTime> _availableDays = const [];
  List<PublicBookingSlot> _slots = const [];

  bool _loadingCatalog = true;
  bool _loadingSlots = false;
  bool _loadingQuote = false;
  bool _creatingBooking = false;
  String? _catalogError;
  String? _slotError;
  String? _quoteError;
  String? _bookingError;
  int _slotRequestSequence = 0;
  int _quoteRequestSequence = 0;
  int _bookingRequestSequence = 0;
  String? _bookingAttemptId;

  bool get _interactionLocked => _loadingQuote || _creatingBooking;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loadingCatalog = true;
      _catalogError = null;
    });

    try {
      final catalog = await widget.repository.getCatalog(widget.slug.trim());
      if (!mounted) return;

      final days = _buildAvailableDays(catalog);
      setState(() {
        _catalog = catalog;
        _availableDays = days;
        _selectedDay = days.isEmpty ? null : days.first;
        _loadingCatalog = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingCatalog = false;
        _catalogError = _friendlyMessage(
          error,
          fallback: 'Não foi possível abrir esta página de agendamento.',
        );
      });
    }
  }

  List<DateTime> _buildAvailableDays(PublicBookingCatalog catalog) {
    final today = catalog.localToday;
    final maximumAdvanceDays = catalog.maximumAdvanceDays < 0
        ? 0
        : catalog.maximumAdvanceDays;
    final days = <DateTime>[];

    for (var offset = 0; offset <= maximumAdvanceDays; offset++) {
      final day = today.add(Duration(days: offset));
      if (catalog.workingDays.contains(day.weekday)) {
        days.add(day);
      }
    }
    return days;
  }

  void _selectService(PublicBookingService service) {
    if (_interactionLocked) return;
    if (_selectedService?.id == service.id) return;
    setState(() {
      _selectedService = service;
      if (_selectedProfessional != null &&
          !_selectedProfessional!.serviceIds.contains(service.id)) {
        _selectedProfessional = null;
      }
      _selectedSlot = null;
      _slots = const [];
      _slotError = null;
      _invalidateQuoteAndConfirmation();
    });
    _loadSlotsIfReady();
  }

  void _selectProfessional(PublicBookingProfessional professional) {
    if (_interactionLocked) return;
    if (_selectedProfessional?.id == professional.id) return;
    setState(() {
      _selectedProfessional = professional;
      _selectedSlot = null;
      _slots = const [];
      _slotError = null;
      _invalidateQuoteAndConfirmation();
    });
    _loadSlotsIfReady();
  }

  void _selectDay(DateTime? day) {
    if (_interactionLocked) return;
    if (day == null || _sameDay(_selectedDay, day)) return;
    setState(() {
      _selectedDay = day;
      _selectedSlot = null;
      _slots = const [];
      _slotError = null;
      _invalidateQuoteAndConfirmation();
    });
    _loadSlotsIfReady();
  }

  void _selectSlot(PublicBookingSlot slot) {
    if (_interactionLocked) return;
    if (_selectedSlot?.startsAt == slot.startsAt) return;
    setState(() {
      _selectedSlot = slot;
      _invalidateQuoteAndConfirmation();
    });
  }

  void _onCustomerIdentityChanged(String _) {
    if (_creatingBooking) return;
    setState(_invalidateQuoteAndConfirmation);
  }

  void _invalidateQuoteAndConfirmation() {
    _quoteRequestSequence++;
    _bookingRequestSequence++;
    _loadingQuote = false;
    _creatingBooking = false;
    _quote = null;
    _quoteError = null;
    _bookingError = null;
    _confirmation = null;
    _bookingAttemptId = null;
  }

  Future<void> _loadSlotsIfReady() async {
    final service = _selectedService;
    final professional = _selectedProfessional;
    final day = _selectedDay;
    if (service == null || professional == null || day == null) return;

    final requestSequence = ++_slotRequestSequence;
    setState(() {
      _loadingSlots = true;
      _slotError = null;
      _selectedSlot = null;
      _slots = const [];
    });

    try {
      final slots = await widget.repository.getAvailableSlots(
        slug: widget.slug.trim(),
        professionalId: professional.id,
        serviceId: service.id,
        day: day,
      );
      if (!mounted || requestSequence != _slotRequestSequence) return;
      setState(() {
        _loadingSlots = false;
        _slots = slots;
      });
    } catch (error) {
      if (!mounted || requestSequence != _slotRequestSequence) return;
      setState(() {
        _loadingSlots = false;
        _slotError = _friendlyMessage(
          error,
          fallback: 'Não foi possível consultar os horários disponíveis.',
        );
      });
    }
  }

  Future<void> _reviewBooking() async {
    if (_interactionLocked) return;
    FocusScope.of(context).unfocus();
    final service = _selectedService;
    final professional = _selectedProfessional;
    final slot = _selectedSlot;
    final isFormValid = _formKey.currentState?.validate() ?? false;

    if (service == null || professional == null || slot == null) {
      setState(() {
        _bookingError =
            'Escolha o serviço, o profissional e um horário para continuar.';
      });
      return;
    }
    if (!isFormValid) return;

    final requestSequence = ++_quoteRequestSequence;
    final customerName = _nameController.text.trim();
    final customerEmail = _emailController.text.trim();
    final customerPhone = _phoneController.text.trim();
    setState(() {
      _loadingQuote = true;
      _bookingAttemptId ??= createUuid();
      _quote = null;
      _quoteError = null;
      _bookingError = null;
    });

    try {
      final quote = await widget.repository.getQuote(
        slug: widget.slug.trim(),
        serviceId: service.id,
        customerName: customerName,
        customerEmail: customerEmail,
        customerPhone: customerPhone,
      );
      if (!mounted || requestSequence != _quoteRequestSequence) return;
      setState(() {
        _loadingQuote = false;
        _quote = quote;
      });
    } catch (error) {
      if (!mounted || requestSequence != _quoteRequestSequence) return;
      setState(() {
        _loadingQuote = false;
        _quoteError = _friendlyMessage(
          error,
          fallback: 'Não foi possível calcular o preço final.',
        );
      });
    }
  }

  Future<void> _confirmBooking() async {
    if (_interactionLocked) return;
    final service = _selectedService;
    final professional = _selectedProfessional;
    final slot = _selectedSlot;
    if (_quote == null ||
        service == null ||
        professional == null ||
        slot == null ||
        _bookingAttemptId == null) {
      return;
    }

    final requestSequence = ++_bookingRequestSequence;
    setState(() {
      _creatingBooking = true;
      _bookingError = null;
    });

    try {
      final confirmation = await widget.repository.createBooking(
        slug: widget.slug.trim(),
        professionalId: professional.id,
        serviceId: service.id,
        customerName: _nameController.text.trim(),
        customerEmail: _emailController.text.trim(),
        customerPhone: _phoneController.text.trim(),
        startsAt: slot.startsAt,
        bookingAttemptId: _bookingAttemptId!,
        notes: _notesController.text.trim(),
      );
      if (!mounted || requestSequence != _bookingRequestSequence) return;
      setState(() {
        _creatingBooking = false;
        _confirmation = confirmation;
      });
    } catch (error) {
      if (!mounted || requestSequence != _bookingRequestSequence) return;
      final message = _friendlyMessage(
        error,
        fallback: 'Não foi possível confirmar o agendamento.',
      );
      final occupied = _looksLikeOccupiedSlot(message);

      if (!occupied) {
        setState(() {
          _creatingBooking = false;
          _bookingError = message;
        });
        return;
      }

      setState(() {
        _creatingBooking = false;
        _quote = null;
        _selectedSlot = null;
        _bookingAttemptId = null;
        _bookingError =
            'Esse horário acabou de ser ocupado. Escolha outro horário.';
      });
      await _loadSlotsIfReady();
      if (!mounted || requestSequence != _bookingRequestSequence) return;
      setState(() {
        _bookingError =
            'Esse horário acabou de ser ocupado. Atualizamos os horários disponíveis para você.';
      });
    }
  }

  void _startAnotherBooking() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _notesController.clear();
    setState(() {
      _selectedService = null;
      _selectedProfessional = null;
      _selectedSlot = null;
      _slots = const [];
      _quote = null;
      _confirmation = null;
      _slotError = null;
      _quoteError = null;
      _bookingError = null;
      _bookingAttemptId = null;
      _selectedDay = _availableDays.isEmpty ? null : _availableDays.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingCatalog) {
      return const Scaffold(
        key: ValueKey('public-booking-loading'),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final catalog = _catalog;
    if (catalog == null) {
      return Scaffold(
        key: const ValueKey('public-booking-error'),
        body: _CatalogError(
          message:
              _catalogError ??
              'Esta página de agendamento não está disponível.',
          onRetry: _loadCatalog,
        ),
      );
    }

    final currentBrightness = Theme.of(context).brightness;
    final businessTheme = currentBrightness == Brightness.dark
        ? FluxoraTheme.businessDark(catalog.businessType)
        : FluxoraTheme.businessLight(catalog.businessType);

    return Theme(
      data: businessTheme,
      child: Builder(
        builder: (context) {
          if (_confirmation != null) {
            return _buildConfirmation(context, catalog, _confirmation!);
          }
          return _buildBookingPage(context, catalog);
        },
      ),
    );
  }

  Widget _buildBookingPage(BuildContext context, PublicBookingCatalog catalog) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      key: const ValueKey('public-booking-content'),
      appBar: AppBar(title: Text(catalog.businessName), centerTitle: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Agende seu horário',
                          key: const ValueKey('public-booking-title'),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Escolha o atendimento ideal e confirme em poucos passos.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: colorScheme.onPrimaryContainer),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 840;
                      final selection = _buildSelectionColumn(context, catalog);
                      final customer = _buildCustomerColumn(context);
                      if (!wide) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            selection,
                            const SizedBox(height: 20),
                            customer,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6, child: selection),
                          const SizedBox(width: 20),
                          Expanded(flex: 5, child: customer),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: Text(
                      'Agendamento seguro por Fluxora · DevVoid.dev',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionColumn(
    BuildContext context,
    PublicBookingCatalog catalog,
  ) {
    final selectedService = _selectedService;
    final eligibleProfessionals = selectedService == null
        ? const <PublicBookingProfessional>[]
        : catalog.professionals
              .where(
                (professional) =>
                    professional.serviceIds.contains(selectedService.id),
              )
              .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionCard(
          step: '1',
          title: 'Escolha o serviço',
          child: catalog.services.isEmpty
              ? const _EmptyMessage(
                  key: ValueKey('public-booking-no-services'),
                  icon: Icons.content_cut,
                  message: 'Nenhum serviço está disponível no momento.',
                )
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: catalog.services.map((service) {
                    final selected = _selectedService?.id == service.id;
                    return ChoiceChip(
                      key: ValueKey('public-booking-service-${service.id}'),
                      selected: selected,
                      onSelected: _interactionLocked
                          ? null
                          : (_) => _selectService(service),
                      avatar: const Icon(Icons.spa_outlined, size: 18),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              service.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${service.durationMinutes} min · ${service.category} · ${_money(service.price)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          step: '2',
          title: 'Escolha o profissional',
          child: selectedService == null
              ? const Text(
                  'Escolha primeiro o serviço para ver quem pode realizá-lo.',
                  key: ValueKey('public-booking-professionals-hint'),
                )
              : eligibleProfessionals.isEmpty
              ? const _EmptyMessage(
                  key: ValueKey('public-booking-no-professionals'),
                  icon: Icons.person_off_outlined,
                  message:
                      'Nenhum profissional está habilitado para este serviço.',
                )
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: eligibleProfessionals.map((professional) {
                    return ChoiceChip(
                      key: ValueKey(
                        'public-booking-professional-${professional.id}',
                      ),
                      selected: _selectedProfessional?.id == professional.id,
                      onSelected: _interactionLocked
                          ? null
                          : (_) => _selectProfessional(professional),
                      avatar: const Icon(Icons.person_outline, size: 18),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(professional.name),
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          step: '3',
          title: 'Escolha o dia e horário',
          child: _buildSchedulePicker(context),
        ),
      ],
    );
  }

  Widget _buildSchedulePicker(BuildContext context) {
    if (_availableDays.isEmpty) {
      return const _EmptyMessage(
        key: ValueKey('public-booking-no-days'),
        icon: Icons.event_busy_outlined,
        message: 'Não há dias abertos para agendamento neste período.',
      );
    }

    final canLoadSlots =
        _selectedService != null && _selectedProfessional != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<DateTime>(
          key: const ValueKey('public-booking-day'),
          initialValue: _selectedDay,
          decoration: const InputDecoration(
            labelText: 'Dia',
            prefixIcon: Icon(Icons.calendar_month_outlined),
          ),
          items: _availableDays
              .map(
                (day) => DropdownMenuItem<DateTime>(
                  key: ValueKey('public-booking-date-${_dateKey(day)}'),
                  value: day,
                  child: Text(_dayLabel(day)),
                ),
              )
              .toList(),
          onChanged: _interactionLocked ? null : _selectDay,
        ),
        const SizedBox(height: 16),
        if (!canLoadSlots)
          const Text(
            'Escolha um serviço e um profissional para consultar os horários.',
            key: ValueKey('public-booking-slots-hint'),
          )
        else if (_loadingSlots)
          const Padding(
            key: ValueKey('public-booking-slots-loading'),
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_slotError != null)
          _InlineError(
            key: const ValueKey('public-booking-slots-error'),
            message: _slotError!,
            buttonLabel: 'Tentar novamente',
            onPressed: _loadSlotsIfReady,
          )
        else if (_slots.isEmpty)
          const _EmptyMessage(
            key: ValueKey('public-booking-no-slots'),
            icon: Icons.schedule_outlined,
            message: 'Não há horários disponíveis neste dia.',
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _slots.map((slot) {
              return ChoiceChip(
                key: ValueKey(
                  'public-booking-slot-${slot.startsAt.millisecondsSinceEpoch}',
                ),
                selected: _selectedSlot?.startsAt == slot.startsAt,
                onSelected: _interactionLocked
                    ? null
                    : (_) => _selectSlot(slot),
                avatar: const Icon(Icons.schedule, size: 18),
                label: Text(slot.localTimeLabel),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildCustomerColumn(BuildContext context) {
    return _SectionCard(
      step: '4',
      title: 'Seus dados',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Usaremos estes dados somente para identificar e confirmar seu agendamento.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('public-booking-customer-name'),
              controller: _nameController,
              enabled: !_interactionLocked,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              onChanged: _onCustomerIdentityChanged,
              decoration: const InputDecoration(
                labelText: 'Nome completo',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) {
                if ((value ?? '').trim().length < 2) {
                  return 'Informe seu nome.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('public-booking-customer-email'),
              controller: _emailController,
              enabled: !_interactionLocked,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              onChanged: _onCustomerIdentityChanged,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (value) {
                final email = (value ?? '').trim();
                final separator = email.indexOf('@');
                if (separator <= 0 ||
                    separator == email.length - 1 ||
                    !email.substring(separator + 1).contains('.')) {
                  return 'Informe um e-mail válido.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('public-booking-customer-phone'),
              controller: _phoneController,
              enabled: !_interactionLocked,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
              onChanged: _onCustomerIdentityChanged,
              decoration: const InputDecoration(
                labelText: 'Telefone com DDD',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (value) {
                final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                if (digits.length < 8) {
                  return 'Informe um telefone válido.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('public-booking-notes'),
              controller: _notesController,
              enabled: !_interactionLocked,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              maxLines: 3,
              onChanged: _onCustomerIdentityChanged,
              decoration: const InputDecoration(
                labelText: 'Observações (opcional)',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 18),
            if (_bookingError != null) ...[
              _InlineError(
                key: const ValueKey('public-booking-confirm-error'),
                message: _bookingError!,
              ),
              const SizedBox(height: 12),
            ],
            if (_quoteError != null) ...[
              _InlineError(
                key: const ValueKey('public-booking-quote-error'),
                message: _quoteError!,
                buttonLabel: 'Tentar novamente',
                onPressed: _reviewBooking,
              ),
              const SizedBox(height: 12),
            ],
            if (_quote == null)
              FilledButton.icon(
                key: const ValueKey('public-booking-review-button'),
                onPressed: _loadingQuote ? null : _reviewBooking,
                icon: _loadingQuote
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.receipt_long_outlined),
                label: Text(
                  _loadingQuote ? 'Calculando...' : 'Revisar agendamento',
                ),
              )
            else
              _buildFinalReview(context, _quote!),
          ],
        ),
      ),
    );
  }

  Widget _buildFinalReview(BuildContext context, PublicBookingQuote quote) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('public-booking-review'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Preço final',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _money(quote.finalPrice),
            key: const ValueKey('public-booking-final-price'),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${_selectedService!.name}\n${_selectedProfessional!.name} · ${_dayLabel(_selectedDay!)} · ${_selectedSlot!.localTimeLabel}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const ValueKey('public-booking-confirm-button'),
            onPressed: _creatingBooking ? null : _confirmBooking,
            icon: _creatingBooking
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(
              _creatingBooking ? 'Confirmando...' : 'Confirmar agendamento',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmation(
    BuildContext context,
    PublicBookingCatalog catalog,
    PublicBookingConfirmation confirmation,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      key: const ValueKey('public-booking-confirmation'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: colorScheme.primaryContainer,
                        foregroundColor: colorScheme.onPrimaryContainer,
                        child: const Icon(Icons.check_rounded, size: 38),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Agendamento confirmado!',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        catalog.businessName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 24),
                      _ConfirmationLine(
                        icon: Icons.confirmation_number_outlined,
                        label: 'Referência',
                        value: confirmation.reference,
                        valueKey: const ValueKey(
                          'public-booking-confirmation-reference',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ConfirmationLine(
                        icon: Icons.event_available_outlined,
                        label: 'Horário',
                        value: _confirmationDateLabel(confirmation),
                        valueKey: const ValueKey(
                          'public-booking-confirmation-time',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ConfirmationLine(
                        icon: Icons.payments_outlined,
                        label: 'Preço final',
                        value: _money(confirmation.finalPrice),
                        valueKey: const ValueKey(
                          'public-booking-confirmation-price',
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Guarde a referência acima. O estabelecimento poderá usá-la para localizar seu atendimento.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        key: const ValueKey(
                          'public-booking-new-booking-button',
                        ),
                        onPressed: _startAnotherBooking,
                        icon: const Icon(Icons.add),
                        label: const Text('Fazer outro agendamento'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _friendlyMessage(Object error, {required String fallback}) {
    if (error is PublicBookingFailure && error.message.trim().isNotEmpty) {
      return error.message.trim();
    }
    return fallback;
  }

  static bool _looksLikeOccupiedSlot(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('ocupad') ||
        normalized.contains('indispon') ||
        normalized.contains('conflit') ||
        normalized.contains('horário já') ||
        normalized.contains('horario ja') ||
        normalized.contains('slot');
  }

  static bool _sameDay(DateTime? first, DateTime second) {
    return first != null &&
        first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  static String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static String _dayLabel(DateTime date) {
    const weekdays = [
      'segunda-feira',
      'terça-feira',
      'quarta-feira',
      'quinta-feira',
      'sexta-feira',
      'sábado',
      'domingo',
    ];
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '${weekdays[date.weekday - 1]}, $day/$month';
  }

  static String _confirmationDateLabel(PublicBookingConfirmation confirmation) {
    if (confirmation.localDateTimeLabel.isNotEmpty) {
      return confirmation.localDateTimeLabel;
    }
    final startsAt = confirmation.startsAt.toLocal();
    final endsAt = confirmation.endsAt.toLocal();
    final day = startsAt.day.toString().padLeft(2, '0');
    final month = startsAt.month.toString().padLeft(2, '0');
    return '$day/$month/${startsAt.year}, ${_timeLabel(startsAt)}–${_timeLabel(endsAt)}';
  }

  static String _timeLabel(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String _money(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.step,
    required this.title,
    required this.child,
  });

  final String step;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimaryContainer,
                  child: Text(
                    step,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.icon, required this.message, super.key});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({
    required this.message,
    this.buttonLabel,
    this.onPressed,
    super.key,
  });

  final String message;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
          if (buttonLabel != null && onPressed != null)
            TextButton(onPressed: onPressed, child: Text(buttonLabel!)),
        ],
      ),
    );
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link_off_outlined, size: 52),
                const SizedBox(height: 18),
                Text(
                  'Agendamento indisponível',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const ValueKey('public-booking-retry-catalog'),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmationLine extends StatelessWidget {
  const _ConfirmationLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueKey,
  });

  final IconData icon;
  final String label;
  final String value;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 2),
              Text(
                value,
                key: valueKey,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
