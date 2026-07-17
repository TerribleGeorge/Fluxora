import 'package:flutter/material.dart';

class PatchNotesPage extends StatelessWidget {
  const PatchNotesPage({super.key});

  static const version = '1.0.0';
  static const buildNumber = '16';

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
            icon: Icons.calendar_month_outlined,
            title: 'Novo agendamento online',
            items: [
              'O estabelecimento agora pode criar um link público para o cliente agendar sem instalar aplicativo.',
              'Cada profissional recebe seus próprios serviços, expediente, intervalos, folgas e bloqueios.',
              'O cliente escolhe serviço, profissional e somente horários realmente disponíveis.',
              'O painel explica o que é regra geral do portal e o que serve apenas como padrão para novos profissionais.',
            ],
          ),
          _ReleaseSection(
            icon: Icons.lock_outline,
            title: 'Reservas protegidas no servidor',
            items: [
              'O Supabase confere novamente o horário no instante da confirmação.',
              'Bloqueios de concorrência impedem duas reservas simultâneas para o mesmo profissional.',
              'Uma chave de idempotência evita agendamentos duplicados após toque repetido ou falha de rede.',
              'Somente as funções públicas indispensáveis ficam acessíveis sem login.',
            ],
          ),
          _ReleaseSection(
            icon: Icons.workspace_premium_outlined,
            title: 'Fidelidade com identidade protegida',
            items: [
              'Agendamentos públicos usam preço cheio enquanto a identidade do cliente não estiver confirmada.',
              'Dono, gerente ou profissional responsável pode usar “Associar a Cliente Fiel” antes do checkout.',
              'A associação recalcula o desconto e registra a correção para auditoria.',
              'Funcionários pesquisam somente no atendimento permitido e recebem e-mail e telefone mascarados.',
            ],
          ),
          _ReleaseSection(
            icon: Icons.manage_history_outlined,
            title: 'Agenda administrável',
            items: [
              'O dono pode vincular serviços específicos a cada integrante da equipe.',
              'É possível dividir o dia em dois ou mais períodos, incluindo intervalo de almoço.',
              'Folgas podem bloquear somente um profissional ou todo o estabelecimento.',
              'O servidor impede que o último horário elegível seja removido enquanto o portal estiver ativo.',
            ],
          ),
          _ReleaseSection(
            icon: Icons.verified_outlined,
            title: 'Qualidade e continuidade',
            items: [
              'A análise estática foi concluída sem problemas.',
              'A suíte automatizada passou por 84 testes de domínio, segurança, interface e integração.',
              'O build web de produção foi validado com a configuração real do Supabase.',
              'Vendas, produtos, checkout, comissões, caixa e lucro real continuam preservados.',
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
              'caixa e lucro real, agora com um portal seguro de agendamento '
              'online por profissional.',
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
