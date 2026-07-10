import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/account.dart';
import '../domain/appointment.dart';
import '../domain/appointment_availability.dart';
import '../domain/business_repository.dart';
import '../domain/checkout_repository.dart';
import '../domain/product.dart';
import '../domain/sale.dart';
import '../state/auth_bloc.dart';
import '../state/appointment_bloc.dart';
import '../state/appointment_event.dart';
import '../state/appointment_state.dart';
import '../state/catalog_bloc.dart';
import '../state/operations_bloc.dart';
import '../state/operations_event.dart';
import '../state/product_bloc.dart';
import '../state/product_event.dart';
import '../state/sales_bloc.dart';
import '../state/sales_event.dart';
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
                            canCheckout:
                                !cancelledOrCompleted(item) &&
                                (!professionalMode ||
                                    item.professionalId ==
                                        linkedProfessionalId),
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

bool cancelledOrCompleted(Appointment item) =>
    item.status == AppointmentStatus.cancelled ||
    item.status == AppointmentStatus.completed ||
    item.status == AppointmentStatus.noShow;

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
    required this.canCheckout,
    this.servicePrice,
  });

  final Appointment appointment;
  final String professionalName;
  final String serviceName;
  final double? servicePrice;
  final bool canManage;
  final bool canCheckout;

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
        trailing: _trailing(context, cancelled),
      ),
    );
  }

  Widget _trailing(BuildContext context, bool cancelled) {
    if (cancelled || (!canManage && !canCheckout)) return Text(_statusLabel);
    return PopupMenuButton<String>(
      onSelected: (action) {
        if (action == 'checkout') {
          _showCheckoutSheet(context, appointment);
          return;
        }
        final status = switch (action) {
          'confirm' => AppointmentStatus.confirmed,
          'cancel' => AppointmentStatus.cancelled,
          _ => null,
        };
        if (status != null) {
          context.read<AppointmentBloc>().add(
            AppointmentStatusChanged(appointment.id, status),
          );
        }
      },
      itemBuilder: (_) => [
        if (canManage)
          const PopupMenuItem(value: 'confirm', child: Text('Confirmar')),
        if (canCheckout)
          const PopupMenuItem(value: 'checkout', child: Text('Concluir')),
        if (canManage)
          const PopupMenuItem(value: 'cancel', child: Text('Cancelar')),
      ],
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

Future<void> _showCheckoutSheet(
  BuildContext context,
  Appointment appointment,
) async {
  final checkoutRepository = context.read<CheckoutRepository>();
  final catalog = context.read<CatalogBloc>().state;
  final productBloc = context.read<ProductBloc>();
  final messenger = ScaffoldMessenger.of(context);
  final service = catalog.services
      .where((item) => item.id == appointment.serviceId)
      .firstOrNull;
  final serviceBase = appointment.serviceBasePrice > 0
      ? appointment.serviceBasePrice
      : service?.price ?? 0;
  final serviceFinal = appointment.serviceFinalPrice > 0
      ? appointment.serviceFinalPrice
      : serviceBase - appointment.discountAmount;
  final feePercent = TextEditingController(text: '0');
  final notes = TextEditingController();
  var method = PaymentMethod.pix;
  var selectedProducts = <String, int>{};
  var saving = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setModalState) {
        final products = productBloc.state.products
            .where((item) => item.active && item.stockQuantity > 0)
            .toList();
        final productTotal = selectedProducts.entries.fold<double>(0, (
          sum,
          entry,
        ) {
          final product = products
              .where((item) => item.id == entry.key)
              .firstOrNull;
          return sum + (product == null ? 0 : product.salePrice * entry.value);
        });
        final total = serviceFinal + productTotal;
        final fee = total * _number(feePercent.text) / 100;
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
                    'Fechar atendimento',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${appointment.customerName} • ${service?.name ?? 'Serviço'}',
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _CheckoutLine('Preço do serviço', serviceBase),
                          if (appointment.discountAmount > 0)
                            _CheckoutLine(
                              'Desconto de fidelidade',
                              -appointment.discountAmount,
                            ),
                          _CheckoutLine(
                            'Serviço a receber',
                            serviceFinal,
                            bold: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Produtos vendidos',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (products.isEmpty)
                    const Text('Nenhum produto ativo com estoque disponível.')
                  else
                    for (final product in products)
                      Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.inventory_2_outlined),
                          ),
                          title: Text(product.name),
                          subtitle: Text(
                            '${money(product.salePrice)} • estoque ${product.stockQuantity}',
                          ),
                          trailing: _QuantityStepper(
                            value: selectedProducts[product.id] ?? 0,
                            max: product.stockQuantity,
                            onChanged: (value) => setModalState(() {
                              selectedProducts = Map.of(selectedProducts);
                              if (value <= 0) {
                                selectedProducts.remove(product.id);
                              } else {
                                selectedProducts[product.id] = value;
                              }
                            }),
                          ),
                        ),
                      ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<PaymentMethod>(
                    initialValue: method,
                    decoration: const InputDecoration(
                      labelText: 'Forma de pagamento',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: PaymentMethod.cash,
                        child: Text('Dinheiro'),
                      ),
                      DropdownMenuItem(
                        value: PaymentMethod.pix,
                        child: Text('Pix'),
                      ),
                      DropdownMenuItem(
                        value: PaymentMethod.debitCard,
                        child: Text('Cartão de débito'),
                      ),
                      DropdownMenuItem(
                        value: PaymentMethod.creditCard,
                        child: Text('Cartão de crédito'),
                      ),
                    ],
                    onChanged: (value) =>
                        setModalState(() => method = value ?? method),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: feePercent,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Taxa do pagamento (%)',
                      helperText: 'Use 0 para dinheiro ou Pix sem taxa.',
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notes,
                    decoration: const InputDecoration(
                      labelText: 'Observações do fechamento',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _CheckoutLine('Serviço', serviceFinal),
                          _CheckoutLine('Produtos', productTotal),
                          if (fee > 0) _CheckoutLine('Taxa estimada', -fee),
                          const Divider(),
                          _CheckoutLine('Total recebido', total, bold: true),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: saving
                        ? null
                        : () async {
                            setModalState(() => saving = true);
                            try {
                              await checkoutRepository
                                  .completeAppointmentCheckout(
                                    appointmentId: appointment.id,
                                    paymentMethod: method,
                                    paymentFeePercent: _number(
                                      feePercent.text,
                                    ),
                                    products: [
                                      for (final entry
                                          in selectedProducts.entries)
                                        CheckoutProductLine(
                                          productId: entry.key,
                                          quantity: entry.value,
                                        ),
                                    ],
                                    notes: notes.text,
                                  );
                              if (!context.mounted) return;
                              context.read<AppointmentBloc>().add(
                                const AppointmentsStarted(),
                              );
                              context.read<SalesBloc>().add(
                                const SalesStarted(),
                              );
                              context.read<ProductBloc>().add(
                                const ProductStarted(),
                              );
                              context.read<OperationsBloc>().add(
                                const OperationsStarted(),
                              );
                              Navigator.pop(sheetContext);
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Atendimento fechado e caixa atualizado.',
                                  ),
                                ),
                              );
                            } on Exception catch (error) {
                              setModalState(() => saving = false);
                              messenger.showSnackBar(
                                SnackBar(content: Text(error.toString())),
                              );
                            }
                          },
                    icon: saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: const Text('Confirmar fechamento'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  feePercent.dispose();
  notes.dispose();
}

class _CheckoutLine extends StatelessWidget {
  const _CheckoutLine(this.label, this.value, {this.bold = false});

  final String label;
  final double value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(money(value), style: style),
        ],
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Remover',
          onPressed: value <= 0 ? null : () => onChanged(value - 1),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text('$value'),
        IconButton(
          tooltip: 'Adicionar',
          onPressed: value >= max ? null : () => onChanged(value + 1),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
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

double _number(String value) {
  return double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
}
