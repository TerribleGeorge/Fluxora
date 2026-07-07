import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../domain/business_metrics.dart';
import '../domain/business_repository.dart';
import '../state/catalog_bloc.dart';
import '../state/catalog_event.dart';
import '../state/finance_bloc.dart';
import '../state/finance_event.dart';
import '../state/sales_bloc.dart';
import '../state/sales_event.dart';
import 'money.dart';
import 'reports_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final access = context.watch<BusinessAccess>();
    final metrics = currentMonthMetrics(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Visão geral'),
            Text(
              access.business.name,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Relatórios',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ReportsPage(metrics: metrics),
              ),
            ),
            icon: const Icon(Icons.assessment_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<SalesBloc>().add(const SalesStarted());
          context.read<FinanceBloc>().add(const FinanceStarted());
          context.read<CatalogBloc>().add(const CatalogStarted());
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Resultado deste mês',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _ProfitCard(metrics: metrics),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth >= 720
                    ? (constraints.maxWidth - 24) / 3
                    : (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MetricCard(
                      width: width,
                      label: 'Faturamento',
                      value: money(metrics.grossRevenue),
                      icon: Icons.trending_up,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'Comissões',
                      value: money(metrics.commissions),
                      icon: Icons.groups_outlined,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'Despesas',
                      value: money(metrics.operatingExpenses),
                      icon: Icons.receipt_long_outlined,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'Taxas de cartão',
                      value: money(metrics.cardFees),
                      icon: Icons.credit_card,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'Impostos',
                      value: money(metrics.taxes),
                      icon: Icons.account_balance_outlined,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'Ticket médio',
                      value: money(metrics.averageTicket),
                      icon: Icons.sell_outlined,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Quem mais faturou',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ReportsPage(metrics: metrics),
                    ),
                  ),
                  child: const Text('Ver relatório'),
                ),
              ],
            ),
            if (metrics.byProfessional.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Registre vendas para visualizar o desempenho.'),
                ),
              )
            else
              for (final item in metrics.byProfessional.take(3))
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline),
                  ),
                  title: Text(item.label),
                  subtitle: Text('${item.count} venda(s)'),
                  trailing: Text(money(item.amount)),
                ),
          ],
        ),
      ),
    );
  }
}

BusinessMetrics currentMonthMetrics(BuildContext context) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month);
  final end = DateTime(now.year, now.month + 1);
  return BusinessMetrics.calculate(
    start: start,
    end: end,
    sales: context.watch<SalesBloc>().state.sales,
    transactions: context.watch<FinanceBloc>().state.transactions,
    professionals: context.watch<CatalogBloc>().state.professionals,
    services: context.watch<CatalogBloc>().state.services,
  );
}

class _ProfitCard extends StatelessWidget {
  const _ProfitCard({required this.metrics});
  final BusinessMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final positive = metrics.availableAfterWithdrawals >= 0;
    return Card(
      color: positive
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quanto realmente sobrou'),
            const SizedBox(height: 8),
            Text(
              money(metrics.availableAfterWithdrawals),
              style: Theme.of(
                context,
              ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Lucro ${money(metrics.profitBeforeWithdrawal)} • retiradas ${money(metrics.ownerWithdrawals)} • margem ${metrics.marginPercent.toStringAsFixed(1)}%',
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
  });
  final double width;
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: 16),
              Text(label),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
