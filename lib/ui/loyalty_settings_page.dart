import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/customer.dart';
import '../state/customer_bloc.dart';
import '../state/customer_event.dart';
import '../state/customer_state.dart';

class LoyaltySettingsPage extends StatelessWidget {
  const LoyaltySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fidelidade de clientes')),
      body: BlocConsumer<CustomerBloc, CustomerState>(
        listenWhen: (before, after) =>
            after.message != null && before.message != after.message,
        listener: (context, state) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.message!))),
        builder: (context, state) {
          final settings = state.loyaltySettings;
          if (state.loading && settings == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _LoyaltySettingsForm(
            settings: settings ?? const LoyaltySettings(businessId: ''),
            customersCount: state.customers.length,
          );
        },
      ),
    );
  }
}

class _LoyaltySettingsForm extends StatefulWidget {
  const _LoyaltySettingsForm({
    required this.settings,
    required this.customersCount,
  });

  final LoyaltySettings settings;
  final int customersCount;

  @override
  State<_LoyaltySettingsForm> createState() => _LoyaltySettingsFormState();
}

class _LoyaltySettingsFormState extends State<_LoyaltySettingsForm> {
  late bool enabled;
  late final TextEditingController standard;
  late final TextEditingController gold;
  late final TextEditingController premium;
  late final TextEditingController inactiveDays;

  @override
  void initState() {
    super.initState();
    enabled = widget.settings.enabled;
    standard = TextEditingController(
      text: widget.settings.standardDiscountPercent.toStringAsFixed(1),
    );
    gold = TextEditingController(
      text: widget.settings.goldDiscountPercent.toStringAsFixed(1),
    );
    premium = TextEditingController(
      text: widget.settings.premiumDiscountPercent.toStringAsFixed(1),
    );
    inactiveDays = TextEditingController(
      text: widget.settings.inactiveAfterDays.toString(),
    );
  }

  @override
  void didUpdateWidget(covariant _LoyaltySettingsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      enabled = widget.settings.enabled;
      standard.text = widget.settings.standardDiscountPercent.toStringAsFixed(1);
      gold.text = widget.settings.goldDiscountPercent.toStringAsFixed(1);
      premium.text = widget.settings.premiumDiscountPercent.toStringAsFixed(1);
      inactiveDays.text = widget.settings.inactiveAfterDays.toString();
    }
  }

  @override
  void dispose() {
    standard.dispose();
    gold.dispose();
    premium.dispose();
    inactiveDays.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: SwitchListTile(
            value: enabled,
            title: const Text('Ativar módulo de fidelidade'),
            subtitle: Text(
              enabled
                  ? 'O Fluxora reconhece clientes fiéis e aplica descontos automaticamente no agendamento.'
                  : 'Todos os clientes pagam o preço padrão dos serviços.',
            ),
            onChanged: (value) => setState(() => enabled = value),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Descontos por nível',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'O cliente nunca escolhe o nível. O Supabase identifica por e-mail ou telefone + nome.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _PercentField(
                  controller: standard,
                  label: 'Standard — 3 meses ativos (%)',
                ),
                const SizedBox(height: 12),
                _PercentField(
                  controller: gold,
                  label: 'Gold — 6 meses ativos (%)',
                ),
                const SizedBox(height: 12),
                _PercentField(
                  controller: premium,
                  label: 'Premium — 12+ meses ativos (%)',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: inactiveDays,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Dias para considerar cliente inativo',
                    helperText:
                        'Padrão recomendado: 90 dias sem atendimento concluído.',
                  ),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.people_alt_outlined)),
            title: Text('${widget.customersCount} cliente(s) registrados'),
            subtitle: const Text(
              'A importação em lote entra na próxima etapa do produto.',
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Salvar fidelidade'),
        ),
      ],
    );
  }

  void _save() {
    context.read<CustomerBloc>().add(
      LoyaltySettingsSaved(
        LoyaltySettings(
          businessId: widget.settings.businessId,
          enabled: enabled,
          standardDiscountPercent: _number(standard.text),
          goldDiscountPercent: _number(gold.text),
          premiumDiscountPercent: _number(premium.text),
          inactiveAfterDays: int.tryParse(inactiveDays.text.trim()) ?? 90,
        ),
      ),
    );
  }
}

class _PercentField extends StatelessWidget {
  const _PercentField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
    );
  }
}

double _number(String value) {
  return double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
}
