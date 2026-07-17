import 'package:flutter/material.dart';

import '../domain/public_booking.dart';

class ProfessionalBookingConfigurationPage extends StatefulWidget {
  const ProfessionalBookingConfigurationPage({
    super.key,
    required this.businessId,
    required this.repository,
  });

  final String businessId;
  final PublicBookingRepository repository;

  @override
  State<ProfessionalBookingConfigurationPage> createState() =>
      _ProfessionalBookingConfigurationPageState();
}

class _ProfessionalBookingConfigurationPageState
    extends State<ProfessionalBookingConfigurationPage> {
  static const _dayLabels = <int, String>{
    1: 'Segunda-feira',
    2: 'Terça-feira',
    3: 'Quarta-feira',
    4: 'Quinta-feira',
    5: 'Sexta-feira',
    6: 'Sábado',
    7: 'Domingo',
  };

  List<PublicBookingProfessional> _professionals = const [];
  List<ProfessionalAvailabilityBlock> _blocks = const [];
  ProfessionalBookingConfiguration? _configuration;
  String? _selectedProfessionalId;
  String? _error;
  bool _loading = true;
  bool _loadingConfiguration = false;
  bool _saving = false;
  bool _dirty = false;
  int _professionalSelectorRevision = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final professionals = await widget.repository.getBookingProfessionals(
        widget.businessId,
      );
      final blocks = await widget.repository.listAvailabilityBlocks(
        widget.businessId,
      );
      final selectedId = professionals.isEmpty ? null : professionals.first.id;
      final configuration = selectedId == null
          ? null
          : await widget.repository.getProfessionalBookingConfiguration(
              selectedId,
            );
      if (!mounted) return;
      setState(() {
        _professionals = professionals;
        _blocks = blocks;
        _selectedProfessionalId = selectedId;
        _configuration = configuration;
        _dirty = false;
        _professionalSelectorRevision++;
        _loading = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !_dirty) return;
        if (await _confirmDiscard() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Agenda por profissional')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _ErrorView(message: _error!, onRetry: _load)
            : _professionals.isEmpty
            ? const _EmptyProfessionalsView()
            : LayoutBuilder(
                builder: (context, constraints) => Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: constraints.maxWidth > 960 ? 920 : null,
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _professionalSelector(),
                        const SizedBox(height: 16),
                        if (_loadingConfiguration)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          )
                        else if (_configuration != null) ...[
                          _servicesCard(),
                          const SizedBox(height: 16),
                          _workingHoursCard(),
                          const SizedBox(height: 16),
                          _blocksCard(),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            key: const ValueKey('save-professional-booking'),
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(
                              _saving
                                  ? 'Salvando...'
                                  : 'Salvar agenda do profissional',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _professionalSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: DropdownButtonFormField<String>(
          key: ValueKey('professional-selector-$_professionalSelectorRevision'),
          initialValue: _selectedProfessionalId,
          decoration: const InputDecoration(
            labelText: 'Profissional',
            helperText:
                'Cada profissional pode ter serviços e horários próprios.',
            prefixIcon: Icon(Icons.person_outline),
          ),
          items: _professionals
              .map(
                (professional) => DropdownMenuItem(
                  value: professional.id,
                  child: Text(professional.name),
                ),
              )
              .toList(growable: false),
          onChanged: _loadingConfiguration ? null : _selectProfessional,
        ),
      ),
    );
  }

  Widget _servicesCard() {
    final services = _configuration!.services;
    final activeServices = services.where((service) => service.active).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                'Serviços atendidos',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Somente os serviços marcados aparecerão para este profissional no site.',
              ),
            ),
            if (activeServices.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Nenhum serviço ativo foi cadastrado.'),
              )
            else
              for (final service in activeServices)
                SwitchListTile.adaptive(
                  key: ValueKey('service-${service.id}'),
                  title: Text(service.name),
                  subtitle: Text(service.category),
                  value: service.assigned,
                  onChanged: (assigned) => _toggleService(service.id, assigned),
                ),
          ],
        ),
      ),
    );
  }

  Widget _workingHoursCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Expediente semanal',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            const Text(
              'Adicione mais de um período no mesmo dia para separar almoço ou outros intervalos.',
            ),
            const SizedBox(height: 16),
            for (final day in _dayLabels.entries) ...[
              _daySchedule(day.key, day.value),
              if (day.key != 7) const Divider(height: 28),
            ],
          ],
        ),
      ),
    );
  }

  Widget _daySchedule(int isoWeekday, String label) {
    final intervals =
        _configuration!.workingHours
            .where(
              (interval) =>
                  interval.isoWeekday == isoWeekday && interval.active,
            )
            .toList()
          ..sort(
            (left, right) => left.startMinutes.compareTo(right.startMinutes),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              key: ValueKey('add-interval-$isoWeekday'),
              onPressed: () => _addInterval(isoWeekday),
              icon: const Icon(Icons.add),
              label: const Text('Período'),
            ),
          ],
        ),
        if (intervals.isEmpty)
          const Text('Folga', style: TextStyle(color: Colors.grey))
        else
          for (final interval in intervals)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_outlined),
              title: Text('${interval.startLabel} – ${interval.endLabel}'),
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: 'Editar período',
                    onPressed: () => _editInterval(interval),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    key: ValueKey(
                      'remove-interval-$isoWeekday-${interval.startMinutes}',
                    ),
                    tooltip: 'Remover período',
                    onPressed: () => _removeInterval(interval),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  Widget _blocksCard() {
    final professionalId = _selectedProfessionalId;
    final visible =
        _blocks
            .where(
              (block) =>
                  block.professionalId == null ||
                  block.professionalId == professionalId,
            )
            .toList()
          ..sort((left, right) => left.startsAt.compareTo(right.startsAt));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Folgas e bloqueios',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton.filledTonal(
                  key: const ValueKey('add-availability-block'),
                  tooltip: 'Adicionar bloqueio',
                  onPressed: _createBlock,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Bloqueios do estabelecimento fecham a agenda de toda a equipe.',
            ),
            const SizedBox(height: 12),
            if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Nenhum bloqueio cadastrado.'),
              )
            else
              for (final block in visible)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    child: Icon(
                      block.professionalId == null
                          ? Icons.groups_outlined
                          : Icons.person_off_outlined,
                    ),
                  ),
                  title: Text(
                    block.reason.trim().isEmpty ? 'Indisponível' : block.reason,
                  ),
                  subtitle: Text(
                    '${_dateTimeLabel(block.startsAt)} até ${_dateTimeLabel(block.endsAt)}\n'
                    '${block.professionalId == null ? 'Toda a equipe' : 'Somente este profissional'}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    key: ValueKey('delete-block-${block.id}'),
                    tooltip: 'Remover bloqueio',
                    onPressed: () => _deleteBlock(block),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  void _toggleService(String serviceId, bool assigned) {
    final configuration = _configuration!;
    setState(() {
      _configuration = configuration.copyWith(
        services: configuration.services
            .map(
              (service) => service.id == serviceId
                  ? service.copyWith(assigned: assigned)
                  : service,
            )
            .toList(growable: false),
      );
      _dirty = true;
    });
  }

  Future<void> _selectProfessional(String? professionalId) async {
    if (professionalId == null || professionalId == _selectedProfessionalId) {
      return;
    }
    if (_dirty && !await _confirmDiscard()) {
      if (mounted) {
        setState(() => _professionalSelectorRevision++);
      }
      return;
    }
    setState(() {
      _selectedProfessionalId = professionalId;
      _configuration = null;
      _loadingConfiguration = true;
      _dirty = false;
      _professionalSelectorRevision++;
    });
    try {
      final configuration = await widget.repository
          .getProfessionalBookingConfiguration(professionalId);
      if (!mounted || _selectedProfessionalId != professionalId) return;
      setState(() {
        _configuration = configuration;
        _loadingConfiguration = false;
      });
    } on Exception catch (error) {
      if (!mounted || _selectedProfessionalId != professionalId) return;
      setState(() {
        _loadingConfiguration = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _addInterval(int isoWeekday) async {
    final intervals = _configuration!.workingHours
        .where((interval) => interval.isoWeekday == isoWeekday)
        .toList();
    final latestEnd = intervals.fold<int>(
      8 * 60,
      (value, interval) =>
          interval.endMinutes > value ? interval.endMinutes : value,
    );
    final start = latestEnd >= 23 * 60 ? 8 * 60 : latestEnd;
    final draft = await _showIntervalDialog(
      startMinutes: start,
      endMinutes: (start + 4 * 60).clamp(0, 23 * 60 + 59),
    );
    if (draft == null || !mounted) return;
    final configuration = _configuration!;
    setState(() {
      _configuration = configuration.copyWith(
        workingHours: [
          ...configuration.workingHours,
          ProfessionalWorkingInterval(
            isoWeekday: isoWeekday,
            startMinutes: draft.startMinutes,
            endMinutes: draft.endMinutes,
          ),
        ],
      );
      _dirty = true;
    });
  }

  Future<void> _editInterval(ProfessionalWorkingInterval interval) async {
    final draft = await _showIntervalDialog(
      startMinutes: interval.startMinutes,
      endMinutes: interval.endMinutes,
    );
    if (draft == null || !mounted) return;
    final configuration = _configuration!;
    setState(() {
      _configuration = configuration.copyWith(
        workingHours: configuration.workingHours
            .map(
              (item) => identical(item, interval)
                  ? item.copyWith(
                      startMinutes: draft.startMinutes,
                      endMinutes: draft.endMinutes,
                    )
                  : item,
            )
            .toList(growable: false),
      );
      _dirty = true;
    });
  }

  void _removeInterval(ProfessionalWorkingInterval interval) {
    final configuration = _configuration!;
    setState(() {
      _configuration = configuration.copyWith(
        workingHours: configuration.workingHours
            .where((item) => !identical(item, interval))
            .toList(growable: false),
      );
      _dirty = true;
    });
  }

  Future<_IntervalDraft?> _showIntervalDialog({
    required int startMinutes,
    required int endMinutes,
  }) {
    return showDialog<_IntervalDraft>(
      context: context,
      builder: (context) =>
          _IntervalDialog(startMinutes: startMinutes, endMinutes: endMinutes),
    );
  }

  Future<void> _save() async {
    final configuration = _configuration!;
    final validation = _validate(configuration);
    if (validation != null) {
      _showMessage(validation);
      return;
    }
    setState(() => _saving = true);
    try {
      final normalized = await widget.repository
          .saveProfessionalBookingConfiguration(
            configuration.copyWith(
              workingHours: [...configuration.workingHours]
                ..sort((left, right) {
                  final day = left.isoWeekday.compareTo(right.isoWeekday);
                  return day != 0
                      ? day
                      : left.startMinutes.compareTo(right.startMinutes);
                }),
            ),
          );
      if (!mounted) return;
      setState(() {
        _configuration = normalized;
        _saving = false;
        _dirty = false;
      });
      _showMessage('Agenda do profissional atualizada.');
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage(error.toString());
    }
  }

  String? _validate(ProfessionalBookingConfiguration configuration) {
    for (final day in _dayLabels.keys) {
      final intervals =
          configuration.workingHours
              .where((item) => item.active && item.isoWeekday == day)
              .toList()
            ..sort(
              (left, right) => left.startMinutes.compareTo(right.startMinutes),
            );
      for (var index = 0; index < intervals.length; index++) {
        final interval = intervals[index];
        if (interval.startMinutes < 0 ||
            interval.endMinutes > 23 * 60 + 59 ||
            interval.endMinutes <= interval.startMinutes) {
          return 'Revise os horários de ${_dayLabels[day]}.';
        }
        if (index > 0 &&
            intervals[index - 1].endMinutes > interval.startMinutes) {
          return 'Existem períodos sobrepostos em ${_dayLabels[day]}.';
        }
      }
    }
    return null;
  }

  Future<void> _createBlock() async {
    final draft = await showDialog<_BlockDraft>(
      context: context,
      builder: (_) => const _BlockDialog(),
    );
    if (draft == null || !mounted) return;
    try {
      final created = await widget.repository.createAvailabilityBlock(
        ProfessionalAvailabilityBlock(
          businessId: widget.businessId,
          professionalId: draft.businessWide ? null : _selectedProfessionalId,
          startsAt: draft.startsAt,
          endsAt: draft.endsAt,
          reason: draft.reason,
        ),
      );
      if (!mounted) return;
      setState(() => _blocks = [..._blocks, created]);
      _showMessage('Bloqueio adicionado.');
    } on Exception catch (error) {
      if (mounted) _showMessage(error.toString());
    }
  }

  Future<void> _deleteBlock(ProfessionalAvailabilityBlock block) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover bloqueio?'),
        content: const Text(
          'Os horários desse período voltarão a ficar disponíveis para agendamento.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('confirm-delete-block'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository.deleteAvailabilityBlock(block.id);
      if (!mounted) return;
      setState(() {
        _blocks = _blocks.where((item) => item.id != block.id).toList();
      });
      _showMessage('Bloqueio removido.');
    } on Exception catch (error) {
      if (mounted) _showMessage(error.toString());
    }
  }

  Future<bool> _confirmDiscard() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Descartar alterações?'),
            content: const Text(
              'Os serviços e horários ainda não foram salvos.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Continuar editando'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Descartar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _dateTimeLabel(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} às $hour:$minute';
  }
}

class _IntervalDraft {
  const _IntervalDraft(this.startMinutes, this.endMinutes);

  final int startMinutes;
  final int endMinutes;
}

class _IntervalDialog extends StatefulWidget {
  const _IntervalDialog({required this.startMinutes, required this.endMinutes});

  final int startMinutes;
  final int endMinutes;

  @override
  State<_IntervalDialog> createState() => _IntervalDialogState();
}

class _IntervalDialogState extends State<_IntervalDialog> {
  late int _startMinutes = widget.startMinutes;
  late int _endMinutes = widget.endMinutes;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Período de trabalho'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DialogTimeButton(
            label: 'Início',
            minutes: _startMinutes,
            onChanged: (value) => setState(() => _startMinutes = value),
          ),
          const SizedBox(height: 12),
          _DialogTimeButton(
            label: 'Fim',
            minutes: _endMinutes,
            onChanged: (value) => setState(() => _endMinutes = value),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('confirm-interval'),
          onPressed: () {
            if (_endMinutes <= _startMinutes) {
              setState(() => _error = 'O fim precisa ser posterior ao início.');
              return;
            }
            Navigator.pop(context, _IntervalDraft(_startMinutes, _endMinutes));
          },
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}

class _DialogTimeButton extends StatelessWidget {
  const _DialogTimeButton({
    required this.label,
    required this.minutes,
    required this.onChanged,
  });

  final String label;
  final int minutes;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeMinutes = minutes.clamp(0, 23 * 60 + 59);
    final time = TimeOfDay(hour: safeMinutes ~/ 60, minute: safeMinutes % 60);
    final displayLabel = minutes == 24 * 60 ? '24:00' : time.format(context);
    return OutlinedButton(
      onPressed: () async {
        final result = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (result != null) onChanged(result.hour * 60 + result.minute);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(displayLabel)],
      ),
    );
  }
}

class _BlockDraft {
  const _BlockDraft({
    required this.startsAt,
    required this.endsAt,
    required this.reason,
    required this.businessWide,
  });

  final DateTime startsAt;
  final DateTime endsAt;
  final String reason;
  final bool businessWide;
}

class _BlockDialog extends StatefulWidget {
  const _BlockDialog();

  @override
  State<_BlockDialog> createState() => _BlockDialogState();
}

class _BlockDialogState extends State<_BlockDialog> {
  final _reasonController = TextEditingController();
  late DateTime _startsAt;
  late DateTime _endsAt;
  bool _businessWide = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startsAt = DateTime(now.year, now.month, now.day + 1, 8);
    _endsAt = DateTime(now.year, now.month, now.day + 1, 18);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Novo bloqueio'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('block-reason'),
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Motivo',
                  hintText: 'Folga, férias, feriado...',
                ),
              ),
              const SizedBox(height: 12),
              _DateTimeField(
                label: 'Início',
                value: _startsAt,
                onChanged: (value) => setState(() => _startsAt = value),
              ),
              const SizedBox(height: 12),
              _DateTimeField(
                label: 'Fim',
                value: _endsAt,
                onChanged: (value) => setState(() => _endsAt = value),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                key: const ValueKey('business-wide-block'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Bloquear toda a equipe'),
                subtitle: const Text(
                  'Use para feriados ou fechamento do estabelecimento.',
                ),
                value: _businessWide,
                onChanged: (value) => setState(() => _businessWide = value),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('confirm-availability-block'),
          onPressed: () {
            if (!_endsAt.isAfter(_startsAt)) {
              setState(() => _error = 'O fim precisa ser posterior ao início.');
              return;
            }
            Navigator.pop(
              context,
              _BlockDraft(
                startsAt: _startsAt,
                endsAt: _endsAt,
                reason: _reasonController.text.trim(),
                businessWide: _businessWide,
              ),
            );
          },
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: value,
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 730)),
              );
              if (date == null) return;
              onChanged(
                DateTime(
                  date.year,
                  date.month,
                  date.day,
                  value.hour,
                  value.minute,
                ),
              );
            },
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(
              '${value.day.toString().padLeft(2, '0')}/'
              '${value.month.toString().padLeft(2, '0')}/${value.year}',
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(value),
              );
              if (time == null) return;
              onChanged(
                DateTime(
                  value.year,
                  value.month,
                  value.day,
                  time.hour,
                  time.minute,
                ),
              );
            },
            icon: const Icon(Icons.schedule_outlined),
            label: Text(TimeOfDay.fromDateTime(value).format(context)),
          ),
        ),
      ],
    );
  }
}

class _EmptyProfessionalsView extends StatelessWidget {
  const _EmptyProfessionalsView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_add_outlined, size: 52),
            SizedBox(height: 12),
            Text(
              'Cadastre um profissional antes de configurar a agenda.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 52),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
