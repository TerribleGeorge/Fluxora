# Fluxora

Gestão e inteligência financeira para negócios do ramo de beleza.

## Fundação atual

- Aplicativo Flutter para Android, iOS, web e Windows
- Interface responsiva para celular e desktop
- BLoC para eventos, regras e estados de cada domínio
- Provider dedicado exclusivamente à injeção de dependências
- Dashboard de saldo, entradas e saídas
- Cadastro e exclusão de lançamentos
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
A próxima etapa de infraestrutura conecta autenticação, PostgreSQL,
estabelecimentos, membros e sincronização segura por usuário.

O escopo comercial da primeira versão está registrado em
[`docs/PRODUCT_SCOPE_V1.md`](docs/PRODUCT_SCOPE_V1.md).

## Validação

```powershell
flutter analyze --no-pub
flutter test --no-pub
flutter run
```
