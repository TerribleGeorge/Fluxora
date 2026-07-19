import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/customer.dart';
import '../state/customer_bloc.dart';
import '../state/customer_event.dart';
import '../state/customer_state.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      body: BlocConsumer<CustomerBloc, CustomerState>(
        listenWhen: (before, after) =>
            after.message != null && before.message != after.message,
        listener: (context, state) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.message!))),
        builder: (context, state) {
          final customers = state.customers.where(_matchesQuery).toList();
          return RefreshIndicator(
            onRefresh: () async =>
                context.read<CustomerBloc>().add(const CustomerStarted()),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Clientes agendados e atendidos',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'O Fluxora usa esta lista para reconhecer recorrência, guardar histórico e aplicar a fidelidade certa no checkout.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Buscar por nome, e-mail ou telefone',
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: 16),
                if (state.loading && state.customers.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (customers.isEmpty)
                  const _EmptyCustomersCard()
                else
                  ...customers.map(
                    (customer) => _CustomerCard(
                      customer: customer,
                      settings: state.loyaltySettings,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _matchesQuery(Customer customer) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return customer.name.toLowerCase().contains(query) ||
        customer.email.toLowerCase().contains(query) ||
        customer.phone.toLowerCase().contains(query);
  }
}

class _EmptyCustomersCard extends StatelessWidget {
  const _EmptyCustomersCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.people_alt_outlined, size: 48),
            const SizedBox(height: 16),
            Text(
              'Nenhum cliente registrado ainda',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Quando alguém agendar pelo site ou for associado a um atendimento, o histórico aparecerá aqui.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer, required this.settings});

  final Customer customer;
  final LoyaltySettings? settings;

  @override
  Widget build(BuildContext context) {
    final effectiveTier = settings == null
        ? customer.loyaltyTier
        : customer.effectiveTier(settings: settings!, now: DateTime.now());
    final discount = settings?.discountFor(effectiveTier) ?? 0;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            customer.hasManualLoyalty
                ? Icons.workspace_premium
                : Icons.person_outline,
          ),
        ),
        title: Text(customer.name),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (customer.email.isNotEmpty) Text(customer.email),
              if (customer.phone.isNotEmpty) Text(customer.phone),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.calendar_month_outlined),
                    label: Text(
                      '${customer.scheduledAppointmentsCount} agendado(s)',
                    ),
                  ),
                  Chip(
                    avatar: const Icon(Icons.check_circle_outline),
                    label: Text('${customer.completedVisitsCount} atendido(s)'),
                  ),
                  Chip(
                    avatar: Icon(
                      customer.hasManualLoyalty
                          ? Icons.edit_outlined
                          : Icons.auto_awesome_outlined,
                    ),
                    label: Text(
                      '${customer.hasManualLoyalty ? 'Manual' : 'Automático'}: ${effectiveTier.label}'
                      '${discount > 0 ? ' • ${discount.toStringAsFixed(1)}%' : ''}',
                    ),
                  ),
                ],
              ),
              if (customer.nextScheduledAt != null) ...[
                const SizedBox(height: 4),
                Text('Próximo: ${_formatDate(customer.nextScheduledAt!)}'),
              ],
              if (customer.lastCompletedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Último atendimento: ${_formatDate(customer.lastCompletedAt!)}',
                ),
              ],
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showLoyaltySheet(context, customer),
      ),
    );
  }

  Future<void> _showLoyaltySheet(
    BuildContext context,
    Customer customer,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _CustomerLoyaltySheet(customer: customer),
    );
  }
}

class _CustomerLoyaltySheet extends StatefulWidget {
  const _CustomerLoyaltySheet({required this.customer});

  final Customer customer;

  @override
  State<_CustomerLoyaltySheet> createState() => _CustomerLoyaltySheetState();
}

class _CustomerLoyaltySheetState extends State<_CustomerLoyaltySheet> {
  CustomerLoyaltyTier? _tier;
  late final TextEditingController _reason;

  @override
  void initState() {
    super.initState();
    _tier = widget.customer.manualTierOverride;
    _reason = TextEditingController(text: widget.customer.manualTierReason);
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.customer.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Escolha “Automático” para o Fluxora calcular pelo histórico, ou fixe um nível quando você já sabe que esse cliente merece desconto.',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<CustomerLoyaltyTier?>(
              initialValue: _tier,
              decoration: const InputDecoration(labelText: 'Categoria'),
              items: [
                const DropdownMenuItem<CustomerLoyaltyTier?>(
                  value: null,
                  child: Text('Automático pelo histórico'),
                ),
                ...CustomerLoyaltyTier.values.map(
                  (tier) => DropdownMenuItem<CustomerLoyaltyTier?>(
                    value: tier,
                    child: Text(tier.label),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _tier = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Observação interna',
                hintText: 'Ex.: cliente antigo da casa, desconto combinado...',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                context.read<CustomerBloc>().add(
                  CustomerLoyaltyOverrideSaved(
                    customerId: widget.customer.id,
                    tier: _tier,
                    reason: _reason.text,
                  ),
                );
                Navigator.pop(context);
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Salvar categoria do cliente'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month/${date.year} às $hour:$minute';
}
