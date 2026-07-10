import 'package:flutter/material.dart';

class PatchNotesPage extends StatelessWidget {
  const PatchNotesPage({super.key});

  static const version = '1.0.0';
  static const buildNumber = '14';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novidades da versão')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _ReleaseHeader(),
          SizedBox(height: 16),
          _ReleaseSection(
            icon: Icons.workspace_premium_outlined,
            title: 'Fidelidade configurável por estabelecimento',
            items: [
              'O dono agora pode ativar ou desativar o módulo de fidelidade no próprio app.',
              'Cada estabelecimento define seus descontos para Standard, Gold e Premium.',
              'A regra não fica engessada: cada negócio decide a própria estratégia de fidelização.',
              'O prazo de inatividade também pode ser ajustado para proteger a margem do negócio.',
            ],
          ),
          _ReleaseSection(
            icon: Icons.verified_user_outlined,
            title: 'Base antifraude para agendamento público',
            items: [
              'O Supabase foi preparado para identificar clientes por e-mail ou por telefone + nome.',
              'O cliente não escolhe nível de fidelidade no site, reduzindo tentativa de fraude.',
              'O preço aplicado fica travado no agendamento para preservar o histórico financeiro.',
              'A base de correção “Associar a Cliente Fiel” foi preparada no banco.',
            ],
          ),
          _ReleaseSection(
            icon: Icons.inventory_2_outlined,
            title: 'Produtos, estoque e custo de venda',
            items: [
              'A aba Cadastros agora tem área de Produtos.',
              'O dono pode registrar preço de venda, custo unitário, estoque e estoque mínimo.',
              'As sugestões de produtos respeitam o nicho do estabelecimento.',
              'O relatório mensal passa a descontar custo dos produtos vendidos no lucro real.',
            ],
          ),
          _ReleaseSection(
            icon: Icons.add_business_outlined,
            title: 'Serviços personalizados sem prender o dono',
            items: [
              'A lista de serviços por nicho continua disponível como sugestão rápida.',
              'O dono também pode criar serviços ou experiências fora da lista.',
              'Exemplos como experiência de realidade virtual, pacotes VIP ou combos próprios podem ser cadastrados manualmente.',
              'Nome, categoria, preço, duração e comissão continuam totalmente ajustáveis.',
            ],
          ),
          _ReleaseSection(
            icon: Icons.point_of_sale_outlined,
            title: 'Checkout financeiro preparado',
            items: [
              'O banco foi preparado para fechar atendimento com serviço, produtos e forma de pagamento.',
              'O checkout já considera desconto de fidelidade, taxa de pagamento, comissão e custo de produto.',
              'A baixa automática de estoque foi preparada no Supabase.',
              'Funcionários só poderão atuar nos próprios atendimentos.',
            ],
          ),
          _ReleaseSection(
            icon: Icons.security_outlined,
            title: 'Permissões mais seguras',
            items: [
              'As políticas do Supabase foram reforçadas para separar dono, gestor e funcionário.',
              'Funcionários não acessam relatórios financeiros completos.',
              'Vendas e dados sensíveis foram preparados para visualização restrita.',
              'Produtos vendáveis podem ser exibidos sem expor custo interno ao funcionário.',
            ],
          ),
          _ReleaseSection(
            icon: Icons.description_outlined,
            title: 'Documentação de regra de negócio',
            items: [
              'A arquitetura foi atualizada para refletir o foco exclusivo em beleza e bem-estar.',
              'As regras de fidelidade, antifraude, produto, checkout e permissões foram documentadas.',
              'A base técnica ficou mais fácil de explicar, revisar e evoluir.',
            ],
          ),
          _ReleaseSection(
            icon: Icons.cloud_sync_outlined,
            title: 'Continuidade da versão anterior',
            items: [
              'Agenda, vendas, caixa, serviços, profissionais, assinatura e sincronização continuam disponíveis.',
              'O Fluxora segue preparado para teste grátis de 14 dias e assinatura pela Google Play.',
              'Exportação de dados, exclusão de conta e recuperação de senha seguem preservadas.',
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Fluxora é um produto DevVoid.dev.',
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ReleaseHeader extends StatelessWidget {
  const _ReleaseHeader();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bem-vindo ao Fluxora',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Versão ${PatchNotesPage.version} (${PatchNotesPage.buildNumber})',
            ),
            const SizedBox(height: 12),
            const Text(
              'A primeira versão reúne as ferramentas essenciais para negócios '
              'de beleza acompanharem fidelidade, produtos, vendas, equipe, '
              'caixa e lucro real.',
            ),
          ],
        ),
      ),
    );
  }
}

class _ReleaseSection extends StatelessWidget {
  const _ReleaseSection({
    required this.icon,
    required this.title,
    required this.items,
  });

  final IconData icon;
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
