# Agendamento público do Fluxora

## Objetivo

O cliente agenda pelo navegador, sem instalar aplicativo e sem escolher nível
de fidelidade. O preço, a identidade do cliente, a disponibilidade e a criação
do agendamento são calculados no Supabase. O aplicativo do estabelecimento
configura quais serviços cada profissional atende, seus expedientes e seus
bloqueios.

## Fluxo entregue

1. O cliente abre `/#/agendar/<slug>`.
2. O portal carrega somente serviços e profissionais habilitados para o link.
3. Depois de escolher o serviço, aparecem apenas profissionais vinculados a ele.
4. Os horários respeitam expediente individual, duração do serviço, almoço,
   folgas, bloqueios gerais e agendamentos existentes.
5. Nome, e-mail e telefone são enviados ao servidor, mas o portal mantém o
   preço cheio enquanto não existe prova de posse da identidade.
6. A confirmação reutiliza uma chave idempotente: repetir a mesma tentativa não
   cria dois agendamentos.

## Configuração pelo proprietário

1. Abra **Configurações > Agendamento online > Agenda por profissional**.
2. Escolha um profissional e marque os serviços que ele realmente executa.
3. Cadastre um ou mais períodos por dia. Dois períodos, por exemplo, permitem
   representar manhã e tarde com intervalo de almoço.
4. Salve a agenda e, quando necessário, crie bloqueios gerais ou individuais.
5. Volte, defina o endereço do estabelecimento e ative o link público.

O servidor impede a ativação quando não existe pelo menos um profissional
ativo com serviço ativo e expediente configurado. Um profissional sem serviços
marcados fica intencionalmente oculto do portal.

## Banco e segurança

As migrações são aplicadas nesta ordem:

- `supabase/migrations/20260716190000_public_booking_portal_security.sql`
- `supabase/migrations/20260716210000_professional_booking_availability.sql`

Controles implementados:

- o cliente anônimo não acessa tabelas internas diretamente;
- RLS separa os estabelecimentos e limita a configuração a proprietário/gestor;
- serviços e profissionais precisam pertencer ao mesmo estabelecimento;
- horários são recalculados e bloqueados novamente no momento da confirmação;
- locks no banco protegem contra duas reservas simultâneas do mesmo horário;
- a chave pública de idempotência impede duplicação por retry ou toque repetido;
- a RPC antiga de criação foi revogada e somente a versão atual fica pública;
- o nível de fidelidade não é enviado nem selecionado pelo cliente;
- uma identidade pública não verificada nunca recebe desconto nem altera as
  identidades confiáveis de um cliente fiel;
- o funcionário responsável pode buscar candidatos por uma RPC limitada, com
  e-mail e telefone mascarados, sem acesso direto à tabela de clientes;
- a associação manual, antes do checkout, recalcula o desconto e registra
  auditoria.

O funil público usa correspondência estrita de identidade apenas para evitar
duplicações, sem conceder benefício. Até existir OTP por e-mail/telefone, todo
agendamento público nasce com preço cheio e nível `new`. O dono, o gerente ou o
profissional responsável pode usar **Associar a Cliente Fiel** antes do checkout;
nesse momento o Supabase confirma a permissão, vincula o cadastro correto e
recalcula o preço. Um desafio anti-bot continua recomendado antes de tráfego
público amplo.

## Build web

Exemplo de build para produção:

```powershell
flutter build web --release `
  --base-href /fluxora-agendamento/ `
  --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=SUA_CHAVE_PUBLICAVEL `
  --dart-define=PUBLIC_BOOKING_BASE_URL=https://terriblegeorge.github.io/fluxora-agendamento
```

A chave usada no navegador deve ser a chave publicável/anon. Nunca inclua a
`service_role` no app ou na hospedagem web. Como a rota compartilhada usa `#`,
ela funciona em hospedagem estática sem regra especial de reescrita.

## Critérios de validação

- `flutter analyze --no-pub`
- `flutter test --no-pub`
- `flutter build web --release` com as duas definições do Supabase
- abrir o link em janela anônima;
- confirmar que um serviço mostra somente os profissionais vinculados;
- confirmar almoço, bloqueio e horário já ocupado;
- reenviar uma confirmação após falha de rede e verificar apenas um registro;
- verificar no Supabase que a RPC antiga não pode ser executada por `anon`.

## Pendências externas para publicação

- executar as duas migrações no projeto Supabase de produção;
- escolher domínio/hospedagem e definir `PUBLIC_BOOKING_BASE_URL`;
- configurar OTP ou proteção anti-bot antes de tráfego público amplo;
- realizar um agendamento ponta a ponta com um estabelecimento real.
