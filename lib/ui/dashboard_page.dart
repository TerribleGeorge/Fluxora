import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/transaction.dart';
import '../state/finance_bloc.dart';
import '../state/finance_event.dart';
import '../state/finance_state.dart';
import 'money.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FinanceBloc, FinanceState>(
      builder: (context, state) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'FLUXORA',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                letterSpacing: 4,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Seu dinheiro, com direção.',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 28),
            if (state.loading)
              const LinearProgressIndicator()
            else if (state.errorMessage case final message?)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: Text(message),
                  trailing: TextButton(
                    onPressed: () =>
                        context.read<FinanceBloc>().add(const FinanceStarted()),
                    child: const Text('Tentar novamente'),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _MetricCard(
                  label: 'Saldo disponível',
                  value: money(state.balance),
                  icon: Icons.account_balance_wallet_rounded,
                ),
                _MetricCard(
                  label: 'Entradas',
                  value: money(state.income),
                  icon: Icons.south_west_rounded,
                  positive: true,
                ),
                _MetricCard(
                  label: 'Saídas',
                  value: money(state.expenses),
                  icon: Icons.north_east_rounded,
                  positive: false,
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Atividade recente',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text('${state.transactions.length} lançamentos'),
              ],
            ),
            const SizedBox(height: 12),
            if (!state.loading && state.transactions.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.insights_rounded,
                        size: 44,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Seu painel começa com o primeiro lançamento.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Use a aba Lançamentos para registrar uma entrada ou saída.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ...state.transactions
                .take(5)
                .map(
                  (item) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          item.type == TransactionType.income
                              ? Icons.add
                              : Icons.remove,
                        ),
                      ),
                      title: Text(item.description),
                      subtitle: Text(item.category),
                      trailing: Text(
                        '${item.type == TransactionType.income ? '+' : '-'} ${money(item.amount)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: item.type == TransactionType.income
                              ? Colors.greenAccent
                              : Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.positive,
  });
  final String label;
  final String value;
  final IconData icon;
  final bool? positive;

  @override
  Widget build(BuildContext context) {
    final color = positive == null
        ? Theme.of(context).colorScheme.primary
        : positive!
        ? Colors.greenAccent
        : Theme.of(context).colorScheme.error;
    return SizedBox(
      width: 280,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 24),
              Text(label),
              const SizedBox(height: 5),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
