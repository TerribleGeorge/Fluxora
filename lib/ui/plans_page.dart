import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/billing_repository.dart';
import '../domain/business_repository.dart';

class PlansPage extends StatefulWidget {
  const PlansPage({super.key, this.expired = false});
  final bool expired;

  @override
  State<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends State<PlansPage> {
  late final Future<List<BillingProduct>> _productsFuture;
  bool _buying = false;

  @override
  void initState() {
    super.initState();
    _productsFuture = context.read<BillingRepository>().loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    final plans = FluxoraBillingCatalog.founderPlans;
    return Scaffold(
      appBar: widget.expired ? null : AppBar(title: const Text('Fluxora Pro')),
      body: FutureBuilder<List<BillingProduct>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          final storeProduct = snapshot.data
              ?.where(
                (product) =>
                    product.productId == FluxoraBillingCatalog.founderProductId,
              )
              .firstOrNull;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (widget.expired) ...[
                const SizedBox(height: 32),
                Text(
                  'Seu período gratuito terminou',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Seus dados continuam protegidos. Assine o Fluxora Pro para continuar usando a gestão do seu negócio.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
              ] else ...[
                Text(
                  'Plano fundador',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Entre cedo, pague justo e ajude a construir o melhor app de gestão para beleza.',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'O preço fundador existe porque o Fluxora ainda está evoluindo com os primeiros negócios reais. Conforme entregarmos agenda, automações, relatórios avançados e integrações, novos clientes poderão entrar em preços maiores.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
              ],
              if (snapshot.connectionState == ConnectionState.waiting)
                const LinearProgressIndicator(),
              if (snapshot.hasError)
                _BillingNotice(
                  text:
                      'A Google Play ainda não retornou os planos. Você pode continuar usando o app durante o período gratuito.',
                  isError: true,
                ),
              for (final plan in plans)
                _PlanCard(
                  plan: plan,
                  storeProduct: storeProduct,
                  buying: _buying,
                  onBuy:
                      plan.id == FluxoraBillingCatalog.founderMonthlyBasePlanId
                      ? () => _buy(context)
                      : null,
                ),
              const SizedBox(height: 12),
              _BillingNotice(
                text: storeProduct == null
                    ? 'A contratação aparecerá aqui assim que a assinatura for criada e aprovada na Google Play.'
                    : 'A cobrança é processada pela Google Play. Você pode cancelar pela sua conta Google.',
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _buy(BuildContext context) async {
    setState(() => _buying = true);
    try {
      await context.read<BillingRepository>().buy(
        FluxoraBillingCatalog.founderProductId,
        businessId: context.read<BusinessAccess>().business.id,
      );
    } on Exception catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.storeProduct,
    required this.buying,
    required this.onBuy,
  });

  final BillingPlan plan;
  final BillingProduct? storeProduct;
  final bool buying;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final active = storeProduct != null && onBuy != null;
    return Card(
      color: plan.highlight ? colorScheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (plan.highlight)
                  Chip(
                    label: const Text('Fundador'),
                    backgroundColor: colorScheme.primary,
                    labelStyle: TextStyle(color: colorScheme.onPrimary),
                  ),
              ],
            ),
            Text(
              plan.priceLabel,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (plan.id == FluxoraBillingCatalog.founderMonthlyBasePlanId) ...[
              const SizedBox(height: 4),
              Text(
                '14 dias grátis. Depois, ${plan.priceLabel} pela Google Play.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
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
            FilledButton(
              onPressed: active && !buying ? onBuy : null,
              child: Text(
                active
                    ? buying
                          ? 'Abrindo Google Play...'
                          : 'Começar 14 dias grátis'
                    : 'Em breve na Google Play',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillingNotice extends StatelessWidget {
  const _BillingNotice({required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: isError
          ? colorScheme.errorContainer
          : colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isError
                ? colorScheme.onErrorContainer
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
