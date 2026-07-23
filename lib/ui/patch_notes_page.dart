import 'package:flutter/material.dart';

class PatchNotesPage extends StatelessWidget {
  const PatchNotesPage({super.key});

  static const version = '1.0.0';
  static const buildNumber = '20';

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
            icon: Icons.verified_user_outlined,
            title: 'Cadastro de estabelecimento com CNPJ validado',
            items: [
              'O cadastro do estabelecimento agora solicita CNPJ para liberar o teste gratuito com mais segurança.',
              'O Fluxora valida o documento antes de criar o negócio e aceita o novo padrão alfanumérico de CNPJ.',
              'A base do Supabase bloqueia o mesmo CNPJ em mais de uma conta, mesmo usando e-mails diferentes.',
              'Essa proteção reduz abuso do período grátis e fortalece a identidade real de cada estabelecimento.',
            ],
          ),
          _ReleaseSection(
            icon: Icons.security_outlined,
            title: 'Blindagem antifraude no backend',
            items: [
              'As regras de criação de estabelecimento foram reforçadas diretamente no banco de dados.',
              'O CNPJ é normalizado e comparado no Supabase para evitar duplicidade por formatação diferente.',
              'O app mostra mensagens claras quando o documento é inválido ou já pertence a outro cadastro.',
              'A regra fica protegida fora do cliente, reduzindo risco de manipulação pelo aplicativo.',
            ],
          ),
          _ReleaseSection(
            icon: Icons.badge_outlined,
            title: 'Login do funcionário preservado',
            items: [
              'A separação entre Proprietário e Funcionário continua disponível na tela de entrada.',
              'O dono entra com e-mail e senha da conta principal.',
              'O funcionário entra com e-mail do estabelecimento, nome cadastrado e senha definida pelo dono.',
              'Esse fluxo segue ajudando a impedir acesso indevido aos relatórios financeiros do proprietário.',
            ],
          ),
          _ReleaseSection(
            icon: Icons.loyalty_outlined,
            title: 'Clientes recorrentes e fidelidade',
            items: [
              'A base de clientes continua preparada para considerar histórico de agendamentos e atendimentos.',
              'O dono pode classificar clientes fiéis de forma mais direta quando fizer sentido para o negócio.',
              'O Fluxora fica preparado para reconhecer clientes assíduos quando retornarem ao estabelecimento.',
              'O objetivo é aplicar preços e descontos corretos no fechamento sem depender de importação de planilhas.',
            ],
          ),
          _ReleaseSection(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Financeiro mais acessível no celular',
            items: [
              'A navegação mobile foi ajustada para dar mais destaque às áreas financeiras importantes.',
              'Lançamentos, despesas, retiradas e impostos ficaram menos escondidos na experiência do dono.',
              'A mudança deixa o fluxo mais próximo do uso real de quem controla o caixa pelo celular.',
              'O foco continua sendo mostrar lucro real depois de comissões, custos e despesas.',
            ],
          ),
          _ReleaseSection(
            icon: Icons.school_outlined,
            title: 'Manual inicial atualizado',
            items: [
              'O guia rápido da tela inicial foi atualizado com o fluxo real de login do funcionário.',
              'O dono recebe instruções para cadastrar equipe, criar acesso e liberar o estabelecimento no site do cliente.',
              'O funcionário vê como entrar pelo modo correto sem usar a conta do proprietário.',
              'O texto deixa mais claro que o cliente agenda pelo site público sem precisar instalar aplicativo.',
            ],
          ),
          _ReleaseSection(
            icon: Icons.verified_outlined,
            title: 'Qualidade e continuidade',
            items: [
              'As regras de permissão continuam separando dono, gerente e funcionário.',
              'Os testes automatizados cobrem autenticação, CNPJ, agenda, financeiro, fidelidade, checkout e agendamento público.',
              'A arquitetura com BLoC, Provider, repositórios e Supabase foi preservada.',
              'Vendas, produtos, caixa, comissões, fidelidade e lucro real continuam como núcleo do Fluxora.',
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
              'de beleza acompanharem vendas, equipe, fidelidade, produtos, '
              'caixa e lucro real, agora com CNPJ validado no cadastro, '
              'proteção contra duplicidade de teste grátis e login de funcionário claro.',
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
