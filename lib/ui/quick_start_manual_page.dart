import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/account.dart';
import '../domain/business_repository.dart';

class QuickStartManualCard extends StatelessWidget {
  const QuickStartManualCard({super.key});

  @override
  Widget build(BuildContext context) {
    final access = context.watch<BusinessAccess>();
    final isProfessional =
        access.membership.role == MembershipRole.professional;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isProfessional
                      ? Icons.badge_outlined
                      : Icons.menu_book_outlined,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isProfessional
                        ? 'Guia rápido do funcionário'
                        : 'Guia rápido do dono',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              isProfessional
                  ? 'Entenda como acessar sua agenda, concluir atendimentos e usar o Fluxora sem ver os dados financeiros do dono.'
                  : 'Aprenda a cadastrar equipe, criar login de funcionário e deixar seu estabelecimento visível para clientes.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: isProfessional
                  ? const [
                      _GuideChip(label: 'Minha agenda'),
                      _GuideChip(label: 'Atendimento'),
                      _GuideChip(label: 'Comissões'),
                    ]
                  : const [
                      _GuideChip(label: 'Equipe'),
                      _GuideChip(label: 'Permissões'),
                      _GuideChip(label: 'Site do cliente'),
                    ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const QuickStartManualPage(),
                  ),
                ),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Abrir manual'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuickStartManualPage extends StatelessWidget {
  const QuickStartManualPage({super.key});

  @override
  Widget build(BuildContext context) {
    final access = context.watch<BusinessAccess>();
    final isProfessional =
        access.membership.role == MembershipRole.professional;
    return DefaultTabController(
      length: 2,
      initialIndex: isProfessional ? 1 : 0,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manual rápido do Fluxora'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.storefront_outlined), text: 'Dono'),
              Tab(icon: Icon(Icons.badge_outlined), text: 'Funcionário'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_OwnerManual(), _ProfessionalManual()],
        ),
      ),
    );
  }
}

class _OwnerManual extends StatelessWidget {
  const _OwnerManual();

  @override
  Widget build(BuildContext context) {
    return const _ManualList(
      introduction:
          'O Fluxora tem dois lados: o painel do dono, onde você gerencia o negócio, e o site do cliente, onde a pessoa encontra seu estabelecimento e agenda sem instalar aplicativo.',
      sections: [
        _ManualSectionData(
          icon: Icons.login_outlined,
          title: '1. Acesso do dono',
          body:
              'Use o app Android ou o painel web administrativo. Entre com seu e-mail e senha para acessar faturamento, caixa, comissões, serviços, equipe, produtos, relatórios e configurações.',
          bullets: [
            'Painel do dono: https://terriblegeorge.github.io/fluxora-admin/',
            'Site do cliente: https://terriblegeorge.github.io/fluxora-agendamento/',
            'O cliente não usa o painel do dono.',
          ],
        ),
        _ManualSectionData(
          icon: Icons.groups_outlined,
          title: '2. Como preparar sua equipe',
          body:
              'Cadastre primeiro os profissionais que atendem no estabelecimento. Depois libere o acesso de funcionário, cadastre os serviços e vincule cada serviço ao profissional certo.',
          bullets: [
            'Abra Mais > Equipe e serviços e crie o profissional.',
            'Ative Criar acesso de funcionário, defina o nome de login e uma senha inicial.',
            'Cadastre os serviços oferecidos, incluindo serviços personalizados do seu estabelecimento.',
            'No profissional, marque quais serviços ele atende.',
            'Configure os dias, horários e bloqueios de agenda do profissional.',
          ],
        ),
        _ManualSectionData(
          icon: Icons.admin_panel_settings_outlined,
          title: '3. Como funciona o login do funcionário',
          body:
              'A tela de entrada tem dois modos: Proprietário e Funcionário. O dono entra com e-mail e senha. O funcionário entra com o e-mail do estabelecimento, o nome cadastrado no profissional e a senha definida pelo dono.',
          bullets: [
            'Proprietário: usa o e-mail e a senha da conta do dono.',
            'Funcionário: usa o e-mail do estabelecimento, o nome cadastrado e a senha inicial criada pelo dono.',
            'Dono ou gerente: vê financeiro, lucro líquido, caixa, despesas, produtos, equipe e relatórios.',
            'Funcionário: vê apenas a própria agenda, próprios atendimentos e ações operacionais liberadas.',
            'Nunca compartilhe a senha do dono com funcionário.',
            'Se o funcionário esquecer a senha, redefina o acesso no cadastro do profissional.',
          ],
        ),
        _ManualSectionData(
          icon: Icons.public_outlined,
          title: '4. Como aparecer no site do cliente',
          body:
              'O estabelecimento só aparece na busca pública quando está completo o suficiente para receber agendamentos reais. Isso evita que o cliente encontre uma página vazia ou sem horários.',
          bullets: [
            'Abra Mais > Agendamento online nas configurações.',
            'Ative Agendamento público.',
            'Ative Aparecer na busca pública.',
            'Preencha CEP, cidade e UF.',
            'Tenha pelo menos 1 serviço ativo.',
            'Tenha pelo menos 1 profissional ativo.',
            'Vincule o serviço ao profissional.',
            'Configure os horários de atendimento do profissional.',
          ],
        ),
        _ManualSectionData(
          icon: Icons.event_available_outlined,
          title: '5. Como o cliente agenda',
          body:
              'O cliente entra no site público, procura por estabelecimento, serviço, cidade ou CEP, escolhe o serviço, escolhe o profissional, seleciona um horário disponível e confirma com nome, e-mail e telefone.',
          bullets: [
            'O cliente não precisa criar conta.',
            'O cliente não escolhe nível de fidelidade ou desconto.',
            'O sistema usa os dados informados para reconhecer recorrência em segundo plano.',
            'O agendamento aparece no Fluxora para o dono e para o profissional responsável.',
          ],
        ),
      ],
    );
  }
}

class _ProfessionalManual extends StatelessWidget {
  const _ProfessionalManual();

  @override
  Widget build(BuildContext context) {
    return const _ManualList(
      introduction:
          'O acesso do funcionário foi pensado para o trabalho do dia a dia: entrar com credenciais próprias, ver agenda, atender cliente e concluir atendimento sem expor informações estratégicas do dono.',
      sections: [
        _ManualSectionData(
          icon: Icons.link_outlined,
          title: '1. Onde o funcionário entra',
          body:
              'O funcionário usa o mesmo painel web administrativo ou o app, mas deve escolher o modo Funcionário na tela de login. Esse modo separa a operação do colaborador da conta do dono.',
          bullets: [
            'Acesso web: https://terriblegeorge.github.io/fluxora-admin/',
            'Na tela de entrada, toque em Funcionário.',
            'Informe o e-mail do estabelecimento passado pelo dono.',
            'Digite o nome cadastrado exatamente como foi liberado no seu acesso.',
            'Digite a senha definida pelo dono.',
            'Nunca entre pelo modo Proprietário usando a conta do dono.',
            'Se estiver no iPhone, entre pelo navegador.',
            'Se estiver no Android, pode usar o app quando disponível.',
          ],
        ),
        _ManualSectionData(
          icon: Icons.calendar_month_outlined,
          title: '2. O que o funcionário deve ver',
          body:
              'O funcionário deve focar nos próprios atendimentos. A agenda mostra os horários ligados a ele para que consiga se organizar e concluir serviços sem depender do dono.',
          bullets: [
            'Agenda própria.',
            'Cliente e serviço do atendimento.',
            'Horário marcado.',
            'Botão para concluir atendimento.',
            'Produtos vendidos naquele atendimento, quando liberado.',
            'Suas próprias comissões ou pagamentos, quando liberado pelo dono.',
          ],
        ),
        _ManualSectionData(
          icon: Icons.visibility_off_outlined,
          title: '3. O que o funcionário não deve ver',
          body:
              'As informações estratégicas do estabelecimento pertencem ao dono. O Fluxora deve bloquear dados que não fazem parte da rotina individual do funcionário.',
          bullets: [
            'Faturamento total da empresa.',
            'Lucro líquido real do dono.',
            'Despesas, retiradas e impostos.',
            'Comissões de outros profissionais.',
            'Relatórios financeiros gerais.',
            'Configurações do estabelecimento e assinatura.',
          ],
        ),
        _ManualSectionData(
          icon: Icons.point_of_sale_outlined,
          title: '4. Como concluir um atendimento',
          body:
              'Ao finalizar o serviço, o funcionário marca o atendimento como concluído. Se houver venda de produto no checkout, ele adiciona os itens vendidos e informa a forma de pagamento.',
          bullets: [
            'Confira se o cliente e o serviço estão corretos.',
            'Inclua produtos vendidos, se existirem.',
            'Confirme a forma de pagamento.',
            'Finalize o atendimento para alimentar o caixa do estabelecimento.',
          ],
        ),
      ],
    );
  }
}

class _ManualList extends StatelessWidget {
  const _ManualList({required this.introduction, required this.sections});

  final String introduction;
  final List<_ManualSectionData> sections;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              introduction,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final section in sections) ...[
          _ManualSection(section),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ManualSection extends StatelessWidget {
  const _ManualSection(this.section);

  final _ManualSectionData section;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(section.icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    section.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(section.body),
            const SizedBox(height: 10),
            for (final bullet in section.bullets)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(bullet)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ManualSectionData {
  const _ManualSectionData({
    required this.icon,
    required this.title,
    required this.body,
    required this.bullets,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<String> bullets;
}

class _GuideChip extends StatelessWidget {
  const _GuideChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: const Icon(Icons.check_circle_outline, size: 18),
      label: Text(label),
    );
  }
}
