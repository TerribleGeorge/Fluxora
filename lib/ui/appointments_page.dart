import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/account.dart';
import '../domain/appointment.dart';
import '../domain/appointment_availability.dart';
import '../domain/business_repository.dart';
import '../state/auth_bloc.dart';
import '../state/appointment_bloc.dart';
import '../state/appointment_event.dart';
import '../state/appointment_state.dart';
import '../state/catalog_bloc.dart';
import 'money.dart';

class AppointmentsPage extends StatelessWidget {
  const AppointmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final access = context.watch<BusinessAccess>();
    final professionalMode =
        access.membership.role == MembershipRole.professional;
    return Scaffold(
      appBar: AppBar(
        title: Text(professionalMode ? 'Minha agenda' : 'Agenda'),
        actions: [
          IconButton(
            onPressed: () => _pickDay(context),
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
      ),
      body: BlocConsumer<AppointmentBloc, AppointmentState>(
        listenWhen: (before, after) =>
            after.message != null && before.message != after.message,
        listener: (context, state) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.message!))),
        builder: (context, state) {
          final catalog = context.watch<CatalogBloc>().state;
          final userId = context.watch<AuthBloc>().state.identity?.id;
          final linkedProfessionalId = professionalMode
              ? catalog.professionals
                    .where((item) => item.userId == userId)
                    .firstOrNull
                    ?.id
              : null;
          final visibleAppointments =
              professionalMode && linkedProfessionalId != null
              ? state.appointments
                    .where(
                      (item) => item.professionalId == linkedProfessionalId,
                    )
                    .toList()
              : state.appointments;
          if (state.loading && state.appointments.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              _DayHeader(day: state.selectedDay),
              if (professionalMode)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Text(
                    'Você visualiza somente seus próprios atendimentos.',
                    textAlign: TextAlign.center,
                  ),
                ),
              Expanded(
                child: professionalMode && linkedProfessionalId == null
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'Seu usuário ainda não foi vinculado a um cadastro de profissional.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : visibleAppointments.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'Nenhum atendimento agendado para este dia.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: visibleAppointments.length,
                        itemBuilder: (context, index) {
                          final item = visibleAppointments[index];
                          final professional = catalog.professionals
                              .where(
                                (candidate) =>
                                    candidate.id == item.professionalId,
                              )
                              .firstOrNull;
                          final service = catalog.services
                              .where(
                                (candidate) => candidate.id == item.serviceId,
                              )
                              .firstOrNull;
                          return _AppointmentCard(
                            appointment: item,
                            professionalName:
                                professional?.name ?? 'Profissional',
                            serviceName: service?.name ?? 'Serviço',
                            servicePrice: service?.price,
                            canManage: !professionalMode,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: professionalMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAppointmentForm(context),
              icon: const Icon(Icons.event_available_outlined),
              label: const Text('Agendar'),
            ),
    );
  }

  Future<void> _pickDay(BuildContext context) async {
    final bloc = context.read<AppointmentBloc>();
    final picked = await showDatePicker(
      context: context,
      initialDate: bloc.state.selectedDay,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && context.mounted) {
      bloc.add(AppointmentDayChanged(picked));
    }
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isToday =
        day.year == today.year &&
        day.month == today.month &&
        day.day == today.day;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.today_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isToday
                    ? 'Hoje'
                    : '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}/${day.year}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(_weekday(day)),
          ],
        ),
      ),
    );
  }

  String _weekday(DateTime value) {
    const labels = [
      'segunda',
      'terça',
      'quarta',
      'quinta',
      'sexta',
      'sábado',
      'domingo',
    ];
    return labels[value.weekday - 1];
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.professionalName,
    required this.serviceName,
    required this.canManage,
    this.servicePrice,
  });

  final Appointment appointment;
  final String professionalName;
  final String serviceName;
  final double? servicePrice;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final cancelled = appointment.status == AppointmentStatus.cancelled;
    return Card(
      child: ListTile(
        enabled: !cancelled,
        leading: CircleAvatar(child: Icon(_icon)),
        title: Text('$serviceName • ${appointment.customerName}'),
        subtitle: Text(
          '${_time(appointment.startsAt)} - ${_time(appointment.endsAt)}'
          ' • $professionalName'
          '${servicePrice == null ? '' : ' • ${money(servicePrice!)}'}'
          '${appointment.customerPhone.isEmpty ? '' : '\n${appointment.customerPhone}'}',
        ),
        isThreeLine: appointment.customerPhone.isNotEmpty,
        trailing: canManage && !cancelled
            ? PopupMenuButton<AppointmentStatus>(
                onSelected: (status) => context.read<AppointmentBloc>().add(
                  AppointmentStatusChanged(appointment.id, status),
                ),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: AppointmentStatus.confirmed,
                    child: Text('Confirmar'),
                  ),
                  PopupMenuItem(
                    value: AppointmentStatus.completed,
                    child: Text('Concluir'),
                  ),
                  PopupMenuItem(
                    value: AppointmentStatus.cancelled,
                    child: Text('Cancelar'),
                  ),
                ],
              )
            : Text(_statusLabel),
      ),
    );
  }

  IconData get _icon => switch (appointment.status) {
    AppointmentStatus.confirmed => Icons.verified_outlined,
    AppointmentStatus.completed => Icons.check_circle_outline,
    AppointmentStatus.cancelled => Icons.block,
    AppointmentStatus.noShow => Icons.person_off_outlined,
    AppointmentStatus.scheduled => Icons.schedule,
  };

  String get _statusLabel => switch (appointment.status) {
    AppointmentStatus.scheduled => 'Agendado',
    AppointmentStatus.confirmed => 'Confirmado',
    AppointmentStatus.completed => 'Concluído',
    AppointmentStatus.cancelled => 'Cancelado',
    AppointmentStatus.noShow => 'Não veio',
  };

  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

Future<void> _showAppointmentForm(BuildContext context) async {
  final catalog = context.read<CatalogBloc>().state;
  final professionals = catalog.professionals
      .where((item) => item.active)
      .toList();
  final services = catalog.services.where((item) => item.active).toList();
  if (professionals.isEmpty || services.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cadastre profissionais e serviços antes de agendar.'),
      ),
    );
    return;
  }

  final bloc = context.read<AppointmentBloc>();
  final customer = TextEditingController();
  final phone = TextEditingController();
  final notes = TextEditingController();
  var professionalId = professionals.first.id;
  var serviceId = services.first.id;
  var day = bloc.state.selectedDay;
  var time = TimeOfDay.now();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setModalState) {
        final service = services.firstWhere((item) => item.id == serviceId);
        final slots = AppointmentAvailability.availableStarts(
          day: day,
          durationMinutes: service.durationMinutes,
          appointments: bloc.state.appointments,
          professionalId: professionalId,
        ).take(16).toList(growable: false);
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Novo agendamento',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: customer,
                    decoration: const InputDecoration(
                      labelText: 'Nome do cliente',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'WhatsApp do cliente',
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: professionalId,
                    decoration: const InputDecoration(
                      labelText: 'Profissional',
                    ),
                    items: professionals
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setModalState(
                      () => professionalId = value ?? professionalId,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: serviceId,
                    decoration: const InputDecoration(labelText: 'Serviço'),
                    items: services
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(
                              '${item.name} • ${item.durationMinutes} min',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setModalState(() => serviceId = value ?? serviceId),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: day,
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 30),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (picked != null) {
                              bloc.add(AppointmentDayChanged(picked));
                              setModalState(() => day = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text(
                            '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: time,
                            );
                            if (picked != null) {
                              setModalState(() => time = picked);
                            }
                          },
                          icon: const Icon(Icons.schedule),
                          label: Text(
                            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (slots.isNotEmpty) ...[
                    Text(
                      'Horários disponíveis',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final slot in slots)
                          ChoiceChip(
                            label: Text(_timeLabel(slot)),
                            selected:
                                time.hour == slot.hour &&
                                time.minute == slot.minute,
                            onSelected: (_) => setModalState(
                              () => time = TimeOfDay.fromDateTime(slot),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ] else ...[
                    const Text(
                      'Nenhum horário livre encontrado para este profissional neste dia. Você ainda pode escolher outro dia, serviço ou profissional.',
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextField(
                    controller: notes,
                    decoration: const InputDecoration(labelText: 'Observações'),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () {
                      bloc.add(
                        AppointmentCreated(
                          professionalId: professionalId,
                          serviceId: serviceId,
                          customerName: customer.text,
                          customerPhone: phone.text,
                          startsAt: DateTime(
                            day.year,
                            day.month,
                            day.day,
                            time.hour,
                            time.minute,
                          ),
                          durationMinutes: service.durationMinutes,
                          notes: notes.text,
                        ),
                      );
                      Navigator.pop(sheetContext);
                    },
                    child: const Text('Salvar agendamento'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  customer.dispose();
  phone.dispose();
  notes.dispose();
}

String _timeLabel(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
