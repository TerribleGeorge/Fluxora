# Visão de plataforma — Fluxora

## Decisão de produto

O Fluxora deve evoluir de um app financeiro para uma plataforma operacional
para negócios de beleza. A base continuará sendo a gestão financeira do
estabelecimento, mas a experiência completa passa a ter três públicos:

1. Dono ou gestor do estabelecimento.
2. Profissional ou funcionário.
3. Cliente final que agenda serviços.

## Dono e gestor

O dono será o comprador principal. Ele deve conseguir administrar o negócio no
app mobile e, futuramente, também em um painel web para PC.

### App mobile

Uso diário e operação rápida:

- dashboard financeiro;
- vendas e atendimentos;
- caixa;
- serviços;
- profissionais;
- comissões;
- despesas;
- retiradas;
- planos e assinatura.

### Painel web

Uso administrativo mais confortável:

- relatórios maiores;
- fechamento mensal;
- configuração do negócio;
- conferência de equipe;
- exportação de dados;
- automações;
- agenda em visão semanal ou mensal.

## Profissional

O profissional precisa de acesso próprio, limitado ao que diz respeito a ele.

Ele pode visualizar:

- agenda própria;
- serviços direcionados a ele;
- dados básicos do cliente do atendimento;
- comissões geradas;
- repasses recebidos;
- saldo pendente de comissão;
- avisos do estabelecimento.

Ele não pode visualizar:

- lucro total do negócio;
- despesas;
- retirada do dono;
- faturamento geral, salvo permissão futura;
- dados financeiros de outros profissionais;
- assinatura do estabelecimento.

## Cliente final

O cliente final não deve ser obrigado a instalar app no início. O primeiro
caminho deve ser uma página pública de agendamento acessível por link,
Instagram, QR Code ou WhatsApp.

Fluxo desejado:

1. Cliente acessa o link público do estabelecimento.
2. Escolhe serviço.
3. Escolhe profissional ou primeira disponibilidade.
4. Escolhe dia e horário.
5. Informa nome e WhatsApp.
6. Confirma o agendamento.
7. Recebe confirmação e lembretes.

Um app dedicado ao cliente só será considerado se a página pública e o WhatsApp
validarem demanda real.

## Automações com n8n e WhatsApp

O n8n será usado como motor de automação externo, recebendo eventos do Fluxora
e enviando mensagens por WhatsApp por meio de um provedor aprovado.

Eventos prioritários:

- novo agendamento;
- agendamento remarcado;
- agendamento cancelado;
- lembrete antes do atendimento;
- venda registrada;
- caixa fechado;
- comissão disponível;
- repasse realizado;
- teste gratuito perto do fim;
- assinatura com problema;
- cliente ausente há muito tempo.

Destinatários:

- dono ou gestor;
- profissional responsável;
- cliente final.

## Arquitetura de evolução

```text
Fluxora Mobile
  ├── Dono/Gestor
  └── Profissional

Fluxora Web
  ├── Painel administrativo
  └── Agenda pública do cliente

Supabase
  ├── autenticação
  ├── banco operacional
  ├── regras de acesso
  └── eventos/webhooks

n8n
  ├── WhatsApp do dono
  ├── WhatsApp do profissional
  └── WhatsApp do cliente
```

## Ordem de construção

1. Estabilizar o app do dono.
2. Criar agenda interna.
3. Criar visão do profissional.
4. Criar página pública de agendamento.
5. Criar eventos de automação.
6. Integrar n8n e WhatsApp.
7. Criar painel web administrativo.
8. Refinar permissões e relatórios por perfil.
