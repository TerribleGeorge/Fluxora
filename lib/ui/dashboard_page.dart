import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../domain/business_metrics.dart';
import '../domain/business_repository.dart';
import '../state/appointment_bloc.dart';
import '../state/catalog_bloc.dart';
import '../state/catalog_event.dart';
import '../state/finance_bloc.dart';
import '../state/finance_event.dart';
import '../state/sales_bloc.dart';
import '../state/sales_event.dart';
import 'money.dart';
import 'quick_start_manual_page.dart';
import 'reports_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    this.onOpenCatalog,
    this.onOpenSales,
    this.onOpenAppointments,
    this.onOpenPlans,
  });

  final VoidCallback? onOpenCatalog;
  final VoidCallback? onOpenSales;
  final VoidCallback? onOpenAppointments;
  final VoidCallback? onOpenPlans;

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
            tooltip: 'Manual rápido',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const QuickStartManualPage(),
              ),
            ),
            icon: const Icon(Icons.help_outline),
          ),
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
            const QuickStartManualCard(),
            const SizedBox(height: 12),
            _SetupProgressCard(
              onOpenCatalog: onOpenCatalog,
              onOpenSales: onOpenSales,
              onOpenAppointments: onOpenAppointments,
              onOpenPlans: onOpenPlans,
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

class _SetupProgressCard extends StatelessWidget {
  const _SetupProgressCard({
    this.onOpenCatalog,
    this.onOpenSales,
    this.onOpenAppointments,
    this.onOpenPlans,
  });

  final VoidCallback? onOpenCatalog;
  final VoidCallback? onOpenSales;
  final VoidCallback? onOpenAppointments;
  final VoidCallback? onOpenPlans;

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogBloc>().state;
    final sales = context.watch<SalesBloc>().state.sales;
    final appointments = context.watch<AppointmentBloc>().state.appointments;
    final steps = [
      _SetupStep(
        title: 'Cadastrar profissional',
        done: catalog.professionals.isNotEmpty,
        actionLabel: 'Equipe',
        onPressed: onOpenCatalog,
      ),
      _SetupStep(
        title: 'Cadastrar serviço',
        done: catalog.services.isNotEmpty,
        actionLabel: 'Serviços',
        onPressed: onOpenCatalog,
      ),
      _SetupStep(
        title: 'Criar primeiro agendamento',
        done: appointments.isNotEmpty,
        actionLabel: 'Agenda',
        onPressed: onOpenAppointments,
      ),
      _SetupStep(
        title: 'Registrar primeira venda',
        done: sales.isNotEmpty,
        actionLabel: 'Vendas',
        onPressed: onOpenSales,
      ),
      _SetupStep(
        title: 'Conferir plano fundador',
        done: false,
        actionLabel: 'Planos',
        onPressed: onOpenPlans,
        optional: true,
      ),
    ];
    final requiredSteps = steps.where((item) => !item.optional).toList();
    final completed = requiredSteps.where((item) => item.done).length;
    if (completed == requiredSteps.length) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.rocket_launch_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Deixe seu negócio pronto',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text('$completed/${requiredSteps.length}'),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: completed / requiredSteps.length,
              minHeight: 6,
              borderRadius: BorderRadius.circular(999),
            ),
            const SizedBox(height: 12),
            for (final step in steps)
              if (!step.done)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    step.optional
                        ? Icons.lightbulb_outline
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(step.title),
                  trailing: TextButton(
                    onPressed: step.onPressed,
                    child: Text(step.actionLabel),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _SetupStep {
  const _SetupStep({
    required this.title,
    required this.done,
    required this.actionLabel,
    required this.onPressed,
    this.optional = false,
  });

  final String title;
  final bool done;
  final String actionLabel;
  final VoidCallback? onPressed;
  final bool optional;
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
