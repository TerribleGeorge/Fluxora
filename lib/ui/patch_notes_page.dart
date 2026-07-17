import 'package:flutter/material.dart';

class PatchNotesPage extends StatelessWidget {
  const PatchNotesPage({super.key});

  static const version = '1.0.0';
  static const buildNumber = '18';

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
            icon: Icons.email_outlined,
            title: 'Notificações por e-mail preparadas',
            items: [
              'O Fluxora agora processa eventos de agendamento para avisar profissional, cliente e dono por e-mail.',
              'Novo agendamento pode gerar aviso para o profissional e resumo para o dono ou gerente.',
              'Lembretes de atendimento continuam agendados para trinta minutos antes do horário marcado.',
              'A integração fica pronta para Resend sem exigir WhatsApp em produção neste momento.',
            ],
          ),
          _ReleaseSection(
            icon: Icons.event_available_outlined,
            title: 'Convite de calendário no agendamento',
            items: [
              'E-mails de agendamento podem incluir um arquivo .ics compatível com Google Agenda, Apple Calendar e Outlook.',
              'O convite leva nome do serviço, profissional, cliente, estabelecimento e referência do agendamento.',
              'O calendário recebe alarme de trinta minutos antes sem depender de API externa paga.',
              'A solução funciona como uma alternativa gratuita e estável enquanto o WhatsApp oficial não entra em produção.',
            ],
          ),
          _ReleaseSection(
            icon: Icons.inventory_2_outlined,
            title: 'Relatórios e alertas operacionais',
            items: [
              'Movimentos de estoque agora podem gerar eventos de automação para acompanhamento do dono.',
              'Produtos abaixo do mínimo criam alertas com proteção contra repetição excessiva.',
              'O resumo de estoque inclui quantidade de produtos ativos, baixo estoque, valor em custo, valor potencial de venda e resultado mensal de produtos.',
              'O cadastro de produtos registra movimentações quando há alteração de estoque.',
            ],
          ),
          _ReleaseSection(
            icon: Icons.notifications_active_outlined,
            title: 'WhatsApp preparado, mas seguro',
            items: [
              'A integração oficial com WhatsApp Cloud API foi isolada atrás de uma chave de ativação.',
              'Enquanto o WhatsApp estiver desligado, falhas da Meta não impedem o envio por e-mail.',
              'O webhook de status já está preparado para registrar enviado, entregue, lido ou falha quando a integração for ativada.',
              'A função guarda o identificador retornado pelo provedor para facilitar auditoria e suporte.',
            ],
          ),
          _ReleaseSection(
            icon: Icons.school_outlined,
            title: 'Manual para dono e funcionário',
            items: [
              'A tela inicial ganhou um guia rápido explicando o papel do site do dono, site do cliente e acesso do funcionário.',
              'O manual orienta como cadastrar equipe, serviços e deixar o estabelecimento visível para agendamento.',
              'Funcionários entendem que usam login próprio e visualização restrita à rotina de atendimento.',
              'O guia reduz dúvidas operacionais antes do primeiro uso real do Fluxora.',
            ],
          ),
          _ReleaseSection(
            icon: Icons.public_outlined,
            title: 'Portal público mais consistente',
            items: [
              'Serviços cadastrados passam a ser vinculados automaticamente quando o estabelecimento possui apenas um profissional ativo.',
              'Isso evita que o cliente veja uma lista vazia no site de agendamento após o dono criar novos serviços.',
              'Quando houver vários profissionais, o dono mantém controle manual de quais serviços pertencem a cada pessoa.',
              'O portal público preserva a regra de mostrar apenas serviços com profissional e disponibilidade reais.',
            ],
          ),
          _ReleaseSection(
            icon: Icons.verified_outlined,
            title: 'Qualidade e continuidade',
            items: [
              'As funções do Supabase foram publicadas com sucesso após as mudanças de automação.',
              'O processamento de eventos foi testado com WhatsApp desligado para garantir que o e-mail continue seguro.',
              'A documentação de automações foi atualizada com comandos, webhook, e-mail e calendário.',
              'Vendas, produtos, checkout, comissões, caixa, fidelidade e lucro real continuam preservados.',
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
              'caixa e lucro real, agora com automações de e-mail, convite de '
              'calendário e base técnica preparada para notificações futuras.',
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
