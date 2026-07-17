import 'package:flutter/material.dart';

import '../domain/business_metrics.dart';
import 'money.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key, required this.metrics});
  final BusinessMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relatório mensal')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ResultTable(metrics: metrics),
          const SizedBox(height: 24),
          _BreakdownSection(
            title: 'Faturamento por profissional',
            items: metrics.byProfessional,
          ),
          const SizedBox(height: 24),
          _BreakdownSection(
            title: 'Faturamento por serviço',
            items: metrics.byService,
          ),
        ],
      ),
    );
  }
}

class _ResultTable extends StatelessWidget {
  const _ResultTable({required this.metrics});
  final BusinessMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Faturamento bruto', metrics.grossRevenue),
      ('(-) Taxas de pagamento', -metrics.cardFees),
      ('(+) Outras receitas', metrics.otherIncome),
      ('(-) Comissões', -metrics.commissions),
      ('(-) Custo dos produtos vendidos', -metrics.productCosts),
      ('(-) Despesas operacionais', -metrics.operatingExpenses),
      ('(-) Impostos', -metrics.taxes),
      ('Lucro antes das retiradas', metrics.profitBeforeWithdrawal),
      ('(-) Retiradas do proprietário', -metrics.ownerWithdrawals),
      ('Disponível após retiradas', metrics.availableAfterWithdrawals),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            for (var index = 0; index < rows.length; index++) ...[
              Row(
                children: [
                  Expanded(child: Text(rows[index].$1)),
                  Text(
                    money(rows[index].$2),
                    style: TextStyle(
                      fontWeight: index >= rows.length - 3
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              if (index < rows.length - 1) const Divider(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}

class _BreakdownSection extends StatelessWidget {
  const _BreakdownSection({required this.title, required this.items});
  final String title;
  final List<MetricBreakdown> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Text('Sem dados no período.')
        else
          for (var index = 0; index < items.length; index++)
            Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(items[index].label),
                subtitle: Text('${items[index].count} ocorrência(s)'),
                trailing: Text(money(items[index].amount)),
              ),
            ),
      ],
    );
  }
}
