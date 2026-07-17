# Fluxora

Gestão e inteligência financeira para negócios do ramo de beleza.

## Fundação atual

- Aplicativo Flutter para Android, iOS, web e Windows
- Interface responsiva para celular e desktop
- BLoC para eventos, regras e estados de cada domínio
- Provider dedicado exclusivamente à injeção de dependências
- Dashboard de saldo, entradas e saídas
- Profissionais, serviços e regras de comissão
- Atendimentos, produtos e formas de pagamento
- Taxas, repasses, despesas, impostos e retiradas
- Abertura, conferência e fechamento de caixa
- Dashboard de lucro real e relatórios de desempenho
- Período de teste e preparação para planos comerciais
- Exportação e exclusão de conta
- Portal web público para o cliente agendar sem instalar aplicativo
- Agenda individual por profissional, serviços vinculados, almoço e bloqueios
- Reserva idempotente para impedir agendamentos duplicados em reenvios
- Núcleo financeiro independente da interface
- Persistência local real em Android, iOS, web e Windows
- Repositório substituível, preparado para PostgreSQL/Supabase
- Tema Material 3 e identidade visual própria
- Testes automatizados das regras financeiras

## Arquitetura

```text
lib/
  app/       tema e inicialização
  data/      implementação dos repositórios
  domain/    entidades e contratos do negócio
  state/     BLoCs, eventos, estados e regras financeiras
  ui/        páginas e componentes visuais
```

Os lançamentos são armazenados localmente e permanecem após fechar o aplicativo.
A infraestrutura já está preparada para autenticação, PostgreSQL,
estabelecimentos, membros e sincronização segura por usuário. A ativação do
ambiente remoto depende da criação e configuração do projeto Supabase.

O escopo comercial da primeira versão está registrado em
[`docs/PRODUCT_SCOPE_V1.md`](docs/PRODUCT_SCOPE_V1.md).

As ações externas necessárias para publicação estão em
[`docs/RELEASE_CHECKLIST.md`](docs/RELEASE_CHECKLIST.md).

A arquitetura, implantação e validação do portal do cliente estão em
[`docs/PUBLIC_BOOKING.md`](docs/PUBLIC_BOOKING.md).

## Validação

```powershell
flutter analyze --no-pub
flutter test --no-pub
flutter run
```
