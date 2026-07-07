import 'package:flutter/material.dart';

class PlansPage extends StatelessWidget {
  const PlansPage({super.key, this.expired = false});
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final plans = const [
      _Plan(
        name: 'Essencial',
        price: 'R\$ 69,90/mês',
        description: 'Para pequenos espaços com até 3 profissionais.',
        features: ['Vendas e serviços', 'Caixa', 'Comissões', 'Dashboard'],
      ),
      _Plan(
        name: 'Gestão',
        price: 'R\$ 119,90/mês',
        description: 'Para equipes que precisam enxergar o lucro real.',
        features: [
          'Profissionais ilimitados',
          'Relatórios completos',
          'Repasses e taxas',
          'Sincronização segura',
        ],
        highlighted: true,
      ),
      _Plan(
        name: 'Pro',
        price: 'R\$ 179,90/mês',
        description: 'Preparado para operações em crescimento.',
        features: [
          'Tudo do Gestão',
          'Recursos avançados futuros',
          'Suporte prioritário',
          'Exportações avançadas',
        ],
      ),
    ];
    return Scaffold(
      appBar: expired ? null : AppBar(title: const Text('Planos Fluxora')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (expired) ...[
            const SizedBox(height: 32),
            Text(
              'Seu período gratuito terminou',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Seus dados continuam protegidos. Escolha um plano para continuar.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
          ],
          for (final plan in plans) _PlanCard(plan: plan),
          const SizedBox(height: 16),
          const Text(
            'A contratação será habilitada após a configuração do faturamento na Google Play. Nenhuma cobrança é feita nesta versão.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});
  final _Plan plan;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: plan.highlighted
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(plan.name, style: Theme.of(context).textTheme.titleLarge),
            Text(plan.price, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(plan.description),
            const SizedBox(height: 12),
            for (final feature in plan.features)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(feature)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(onPressed: null, child: const Text('Em breve')),
          ],
        ),
      ),
    );
  }
}

class _Plan {
  const _Plan({
    required this.name,
    required this.price,
    required this.description,
    required this.features,
    this.highlighted = false,
  });
  final String name;
  final String price;
  final String description;
  final List<String> features;
  final bool highlighted;
}
