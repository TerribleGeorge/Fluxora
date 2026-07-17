import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/public_booking.dart';
import 'professional_booking_configuration_page.dart';

class PublicBookingSettingsPage extends StatefulWidget {
  const PublicBookingSettingsPage({
    super.key,
    required this.businessId,
    required this.repository,
  });

  final String businessId;
  final PublicBookingRepository repository;

  @override
  State<PublicBookingSettingsPage> createState() =>
      _PublicBookingSettingsPageState();
}

class _PublicBookingSettingsPageState extends State<PublicBookingSettingsPage> {
  final _slugController = TextEditingController();
  final _noticeController = TextEditingController();
  final _advanceController = TextEditingController();
  PublicBookingSettings? _settings;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _slugController.dispose();
    _noticeController.dispose();
    _advanceController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final settings = await widget.repository.getSettings(widget.businessId);
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _slugController.text = settings.slug;
        _noticeController.text = settings.minimumNoticeMinutes.toString();
        _advanceController.text = settings.maximumAdvanceDays.toString();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Agendamento online')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _settings == null
          ? _ErrorState(message: _error, onRetry: _load)
          : LayoutBuilder(
              builder: (context, constraints) => Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: constraints.maxWidth > 760 ? 720 : null,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _introCard(context),
                      const SizedBox(height: 16),
                      _newProfessionalDefaultsCard(context),
                      const SizedBox(height: 16),
                      _portalRulesCard(context),
                      const SizedBox(height: 16),
                      _professionalAgendaCard(context),
                      const SizedBox(height: 16),
                      FilledButton.icon(
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
                          _saving ? 'Salvando...' : 'Salvar configurações',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _professionalAgendaCard(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        leading: const CircleAvatar(child: Icon(Icons.calendar_month_outlined)),
        title: const Text('Agenda por profissional'),
        subtitle: const Text(
          'Defina serviços, expediente, almoço, folgas e bloqueios.',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ProfessionalBookingConfigurationPage(
              businessId: widget.businessId,
              repository: widget.repository,
            ),
          ),
        ),
      ),
    );
  }

  Widget _introCard(BuildContext context) {
    final settings = _settings!;
    final link = _publicLink(settings.slug);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Aceitar agendamentos pelo link'),
              subtitle: const Text(
                'Quando desligado, ninguém consegue abrir sua agenda pública.',
              ),
              value: settings.enabled,
              onChanged: (value) =>
                  setState(() => _settings = settings.copyWith(enabled: value)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _slugController,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Endereço personalizado',
                prefixText: '/agendar/',
                helperText: 'Use letras minúsculas, números e hífen.',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Text('Seu link', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            SelectableText(
              link.isEmpty
                  ? 'O endereço definitivo aparecerá após a publicação do portal web.'
                  : link,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _slugController.text.trim().isEmpty || link.isEmpty
                  ? null
                  : () => _copyLink(link),
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copiar link'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _newProfessionalDefaultsCard(BuildContext context) {
    final settings = _settings!;
    const dayLabels = {
      1: 'Seg',
      2: 'Ter',
      3: 'Qua',
      4: 'Qui',
      5: 'Sex',
      6: 'Sáb',
      7: 'Dom',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Padrão para novos profissionais',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            const Text(
              'Estes dias e horários preenchem somente a agenda de profissionais '
              'criados depois. Para alterar a equipe atual, use “Agenda por '
              'profissional” abaixo.',
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: dayLabels.entries
                  .map((entry) {
                    final selected = settings.workingDays.contains(entry.key);
                    return FilterChip(
                      label: Text(entry.value),
                      selected: selected,
                      onSelected: (value) {
                        final days = {...settings.workingDays};
                        value ? days.add(entry.key) : days.remove(entry.key);
                        setState(
                          () =>
                              _settings = settings.copyWith(workingDays: days),
                        );
                      },
                    );
                  })
                  .toList(growable: false),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _TimeButton(
                    label: 'Abre',
                    value: settings.openingLabel,
                    onTap: () => _pickTime(opening: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeButton(
                    label: 'Fecha',
                    value: settings.closingLabel,
                    onTap: () => _pickTime(opening: false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _portalRulesCard(BuildContext context) {
    final settings = _settings!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Regras gerais do portal',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            const Text(
              'Estas regras valem para todos os profissionais e horários '
              'oferecidos no link público.',
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<int>(
              initialValue: settings.slotIntervalMinutes,
              decoration: const InputDecoration(
                labelText: 'Intervalo entre opções de horário',
                helperText:
                    'Define de quanto em quanto tempo o portal sugere horários.',
              ),
              items: const [10, 15, 20, 30, 60]
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text('$value minutos'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(
                () => _settings = settings.copyWith(
                  slotIntervalMinutes: value ?? settings.slotIntervalMinutes,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _noticeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Antecedência mínima',
                      suffixText: 'min',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _advanceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Agenda aberta por',
                      suffixText: 'dias',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: settings.timeZone,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Fuso horário',
                helperText: 'Usado para impedir horários incorretos no site.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime({required bool opening}) async {
    final settings = _settings!;
    final source = opening ? settings.openingMinutes : settings.closingMinutes;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: source ~/ 60, minute: source % 60),
    );
    if (selected == null || !mounted) return;
    final minutes = selected.hour * 60 + selected.minute;
    setState(() {
      _settings = opening
          ? settings.copyWith(openingMinutes: minutes)
          : settings.copyWith(closingMinutes: minutes);
    });
  }

  Future<void> _save() async {
    final current = _settings!;
    final slug = _slugController.text.trim().toLowerCase();
    final notice = int.tryParse(_noticeController.text.trim());
    final advance = int.tryParse(_advanceController.text.trim());
    final message = _validate(
      current,
      slug: slug,
      notice: notice,
      advance: advance,
    );
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    final updated = current.copyWith(
      slug: slug,
      minimumNoticeMinutes: notice,
      maximumAdvanceDays: advance,
    );
    setState(() => _saving = true);
    try {
      await widget.repository.saveSettings(updated);
      if (!mounted) return;
      setState(() {
        _settings = updated;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agendamento online atualizado.')),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  String? _validate(
    PublicBookingSettings settings, {
    required String slug,
    required int? notice,
    required int? advance,
  }) {
    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(slug)) {
      return 'Escolha um endereço com letras minúsculas, números e hífen.';
    }
    if (settings.workingDays.isEmpty) {
      return 'Selecione pelo menos um dia de atendimento.';
    }
    if (settings.closingMinutes <= settings.openingMinutes) {
      return 'O horário de fechamento precisa ser posterior à abertura.';
    }
    if (notice == null || notice < 0 || notice > 10080) {
      return 'Informe uma antecedência mínima válida.';
    }
    if (advance == null || advance < 1 || advance > 365) {
      return 'A agenda pode ficar aberta entre 1 e 365 dias.';
    }
    return null;
  }

  Future<void> _copyLink(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Link copiado.')));
    }
  }

  String _publicLink(String fallbackSlug) {
    final slug = _slugController.text.trim().isEmpty
        ? fallbackSlug
        : _slugController.text.trim().toLowerCase();
    const configuredBase = String.fromEnvironment(
      'PUBLIC_BOOKING_BASE_URL',
      defaultValue: '',
    );
    final uri = Uri.base;
    final runtimeBase =
        kIsWeb && (uri.scheme == 'http' || uri.scheme == 'https')
        ? uri.resolve('.').toString().replaceFirst(RegExp(r'/$'), '')
        : '';
    final base = configuredBase.trim().isNotEmpty
        ? configuredBase.trim().replaceFirst(RegExp(r'/$'), '')
        : runtimeBase;
    if (base.isEmpty) return '';
    return '$base/#/agendar/${Uri.encodeComponent(slug)}';
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Text(label),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              message ?? 'Não foi possível carregar as configurações.',
              textAlign: TextAlign.center,
            ),
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
