import 'package:flutter/material.dart';

class PatchNotesPage extends StatelessWidget {
  const PatchNotesPage({super.key});

  static const version = '1.0.0';
  static const buildNumber = '5';

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
            icon: Icons.insights_outlined,
            title: 'Entenda o que realmente sobra',
            items: [
              'Acompanhe faturamento, lucro real, margem e ticket médio.',
              'Separe despesas operacionais, impostos e retiradas do proprietário.',
              'Consulte resultados por período, profissional e serviço.',
            ],
          ),
          _ReleaseSection(
            icon: Icons.point_of_sale_outlined,
            title: 'Vendas e recebimentos',
            items: [
              'Registre serviços e produtos em um único atendimento.',
              'Informe dinheiro, Pix, cartão, parcelas e taxas de pagamento.',
              'Cancele vendas preservando o histórico do negócio.',
            ],
          ),
          _ReleaseSection(
            icon: Icons.groups_outlined,
            title: 'Equipe, serviços e comissões',
            items: [
              'Cadastre profissionais, serviços e regras de comissão.',
              'Calcule automaticamente o valor devido a cada profissional.',
              'Registre repasses e acompanhe os saldos pendentes.',
            ],
          ),
          _ReleaseSection(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Caixa organizado',
            items: [
              'Abra, confira e feche o caixa com segurança.',
              'Compare o dinheiro esperado com o valor contado.',
              'Mantenha as movimentações financeiras organizadas.',
            ],
          ),
          _ReleaseSection(
            icon: Icons.workspace_premium_outlined,
            title: 'Plano fundador preparado',
            items: [
              'A tela de planos agora apresenta o Fluxora Pro Fundador.',
              'O app foi preparado para assinaturas pela Google Play.',
              'A condição fundadora comunica preço justo para os primeiros usuários.',
            ],
          ),
          _ReleaseSection(
            icon: Icons.cloud_sync_outlined,
            title: 'Continuidade e segurança',
            items: [
              'Continue trabalhando quando a conexão estiver instável.',
              'Exporte seus dados e solicite a exclusão da conta pelo app.',
              'Controle o acesso de proprietário, gestor e profissional.',
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
              'de beleza acompanharem vendas, equipe, caixa e lucro real.',
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
