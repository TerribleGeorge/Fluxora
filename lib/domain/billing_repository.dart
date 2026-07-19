class BillingPlan {
  const BillingPlan({
    required this.id,
    required this.name,
    required this.priceLabel,
    required this.description,
    required this.features,
    required this.highlight,
  });

  final String id;
  final String name;
  final String priceLabel;
  final String description;
  final List<String> features;
  final bool highlight;
}

class BillingProduct {
  const BillingProduct({
    required this.productId,
    required this.title,
    required this.description,
    required this.price,
  });

  final String productId;
  final String title;
  final String description;
  final String price;
}

abstract class BillingRepository {
  Future<bool> isAvailable();

  Future<List<BillingProduct>> loadProducts();

  Future<void> buy(String productId, {required String businessId});
}

class BillingUnavailableException implements Exception {
  const BillingUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FluxoraBillingCatalog {
  static const founderProductId = 'fluxora_pro';
  static const founderMonthlyBasePlanId = 'mensal';
  static const founderAnnualBasePlanId = 'pro-fundador-anual';
  static const founderTrialOfferId = 'teste-14-dias';

  static const founderPlans = [
    BillingPlan(
      id: founderMonthlyBasePlanId,
      name: 'Fluxora Pro Fundador',
      priceLabel: 'R\$ 39,99/mês',
      description:
          'Condição especial para os primeiros negócios que ajudarem a construir o Fluxora.',
      highlight: true,
      features: [
        '14 dias grátis para testar sem risco',
        'Vendas, serviços, despesas e retiradas',
        'Comissões, repasses e fechamento de caixa',
        'Dashboard de lucro real e margem',
        'Sincronização segura entre dispositivos',
        'Preço fundador para a fase inicial',
      ],
    ),
    BillingPlan(
      id: founderAnnualBasePlanId,
      name: 'Fluxora Pro Anual',
      priceLabel: 'R\$ 399,90/ano',
      description:
          'Economia para quem quer consolidar a gestão por um ano inteiro.',
      highlight: false,
      features: [
        'Todos os recursos do Fluxora Pro',
        'Preço anual com desconto',
        'Menos preocupação com renovação mensal',
        'Acesso às melhorias da fase fundadora',
      ],
    ),
  ];
}
