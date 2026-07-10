import 'package:flutter/material.dart';

class PatchNotesPage extends StatelessWidget {
  const PatchNotesPage({super.key});

  static const version = '1.0.0';
  static const buildNumber = '15';

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
            icon: Icons.language_outlined,
            title: 'Preparação para usuários de outros países',
            items: [
              'O Fluxora agora tem a base técnica de internacionalização configurada.',
              'O app foi preparado para reconhecer idiomas e regiões de vários mercados.',
              'Componentes do sistema, como calendários, seletores e direção de texto, passam a respeitar melhor o idioma do aparelho.',
              'Português do Brasil segue como idioma principal enquanto os textos próprios do app são traduzidos por etapas.',
            ],
          ),
          _ReleaseSection(
            icon: Icons.public_outlined,
            title: 'Expansão internacional com segurança',
            items: [
              'Foram adicionados idiomas e variações regionais usados em mercados prioritários.',
              'A estrutura evita espalhar configurações de idioma pelo código, facilitando futuras traduções.',
              'A base já considera idiomas com leitura da direita para a esquerda, como árabe e hebraico.',
              'Textos ligados a dinheiro, assinatura, privacidade e exclusão de dados terão revisão mais cuidadosa antes de tradução pública.',
            ],
          ),
          _ReleaseSection(
            icon: Icons.description_outlined,
            title: 'Documentação de internacionalização',
            items: [
              'Foi criada uma documentação própria explicando como o Fluxora será traduzido.',
              'A estratégia recomenda começar por inglês, espanhol e português de Portugal.',
              'A documentação separa localização do sistema de tradução dos textos próprios do produto.',
              'Isso ajuda a evoluir o app sem publicar traduções automáticas ruins em telas sensíveis.',
            ],
          ),
          _ReleaseSection(
            icon: Icons.verified_outlined,
            title: 'Qualidade validada por testes',
            items: [
              'Foi adicionado teste automático para garantir mercados prioritários na lista de idiomas.',
              'O teste também impede idiomas duplicados na configuração central.',
              'A análise do Flutter permanece sem erros.',
              'A suíte de testes confirma que as regras financeiras, assinatura, fidelidade, catálogo, checkout e agenda continuam preservadas.',
            ],
          ),
          _ReleaseSection(
            icon: Icons.workspace_premium_outlined,
            title: 'Continuidade da gestão de beleza',
            items: [
              'Agenda, vendas, caixa, serviços, profissionais, produtos e assinatura continuam disponíveis.',
              'Fidelidade configurável, permissões por perfil e checkout financeiro seguem preservados.',
              'O Fluxora continua focado em beleza e bem-estar, com cálculo de lucro real para o dono.',
              'A base internacional foi adicionada sem alterar o fluxo principal já validado.',
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
              'caixa e lucro real, agora com base preparada para expansão '
              'internacional.',
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
