import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/catalog.dart';
import '../domain/sale.dart';
import '../state/catalog_bloc.dart';
import '../state/operations_bloc.dart';
import '../state/operations_event.dart';
import '../state/operations_state.dart';
import 'money.dart';

class OperationsPage extends StatelessWidget {
  const OperationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Caixa e comissões')),
      body: BlocConsumer<OperationsBloc, OperationsState>(
        listenWhen: (before, after) =>
            after.message != null && before.message != after.message,
        listener: (context, state) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.message!))),
        builder: (context, state) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final professionals = context
              .watch<CatalogBloc>()
              .state
              .professionals;
          return RefreshIndicator(
            onRefresh: () async =>
                context.read<OperationsBloc>().add(const OperationsStarted()),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _CashCard(state: state),
                const SizedBox(height: 24),
                Text(
                  'Comissões a repassar',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (professionals.isEmpty)
                  const Card(
                    child: ListTile(
                      title: Text('Nenhum profissional cadastrado'),
                    ),
                  )
                else
                  for (final professional in professionals)
                    _CommissionCard(
                      professional: professional,
                      amount: state.commissionBalances[professional.id] ?? 0,
                    ),
                const SizedBox(height: 24),
                Text(
                  'Últimos repasses',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (state.payouts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Nenhum repasse registrado.'),
                  )
                else
                  for (final payout in state.payouts.take(10))
                    ListTile(
                      leading: const Icon(Icons.payments_outlined),
                      title: Text(
                        professionals
                                .where(
                                  (item) => item.id == payout.professionalId,
                                )
                                .firstOrNull
                                ?.name ??
                            'Profissional',
                      ),
                      subtitle: Text(_methodLabel(payout.method)),
                      trailing: Text(money(payout.amount)),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CashCard extends StatelessWidget {
  const _CashCard({required this.state});
  final OperationsState state;

  @override
  Widget build(BuildContext context) {
    final open = state.openCash;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  open == null ? Icons.lock_outline : Icons.lock_open_outlined,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    open == null ? 'Caixa fechado' : 'Caixa aberto',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            if (open != null) ...[
              const SizedBox(height: 16),
              Text(
                'Saldo esperado',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Text(
                money(state.expectedCash),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () => _showCloseCash(context, state.expectedCash),
                child: const Text('Fechar caixa'),
              ),
            ] else ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _showOpenCash(context),
                child: const Text('Abrir caixa'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CommissionCard extends StatelessWidget {
  const _CommissionCard({required this.professional, required this.amount});
  final Professional professional;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
        title: Text(professional.name),
        subtitle: const Text('Saldo de comissão disponível'),
        trailing: Text(
          money(amount < 0 ? 0 : amount),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        onTap: amount > 0
            ? () => _showPayout(context, professional, amount)
            : null,
      ),
    );
  }
}

Future<void> _showOpenCash(BuildContext context) async {
  final controller = TextEditingController(text: '0');
  try {
    await _valueDialog(
      context,
      title: 'Abrir caixa',
      label: 'Saldo inicial',
      controller: controller,
      action: 'Abrir',
      onConfirm: () => context.read<OperationsBloc>().add(
        CashOpened(_number(controller.text)),
      ),
    );
  } finally {
    controller.dispose();
  }
}

Future<void> _showCloseCash(BuildContext context, double expected) async {
  final controller = TextEditingController(text: expected.toStringAsFixed(2));
  try {
    await _valueDialog(
      context,
      title: 'Fechar caixa',
      label: 'Valor contado',
      controller: controller,
      action: 'Confirmar fechamento',
      onConfirm: () => context.read<OperationsBloc>().add(
        CashClosed(countedBalance: _number(controller.text)),
      ),
    );
  } finally {
    controller.dispose();
  }
}

Future<void> _showPayout(
  BuildContext context,
  Professional professional,
  double available,
) async {
  final controller = TextEditingController(text: available.toStringAsFixed(2));
  var method = PaymentMethod.pix;
  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Repasse para ${professional.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Valor (máximo ${money(available)})',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PaymentMethod>(
                initialValue: method,
                decoration: const InputDecoration(
                  labelText: 'Forma de repasse',
                ),
                items: PaymentMethod.values
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(_methodLabel(item)),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => method = value ?? method),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                context.read<OperationsBloc>().add(
                  CommissionPaid(
                    professionalId: professional.id,
                    amount: _number(controller.text),
                    method: method,
                  ),
                );
                Navigator.pop(dialogContext);
              },
              child: const Text('Registrar repasse'),
            ),
          ],
        ),
      ),
    );
  } finally {
    controller.dispose();
  }
}

Future<void> _valueDialog(
  BuildContext context, {
  required String title,
  required String label,
  required TextEditingController controller,
  required String action,
  required VoidCallback onConfirm,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, prefixText: 'R\$ '),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            onConfirm();
            Navigator.pop(dialogContext);
          },
          child: Text(action),
        ),
      ],
    ),
  );
}

String _methodLabel(PaymentMethod method) => switch (method) {
  PaymentMethod.cash => 'Dinheiro',
  PaymentMethod.pix => 'Pix',
  PaymentMethod.debitCard => 'Cartão de débito',
  PaymentMethod.creditCard => 'Cartão de crédito',
  PaymentMethod.other => 'Outro',
};

double _number(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
