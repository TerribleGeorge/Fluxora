# Eventos de automação — Fluxora

## Objetivo

O app não deve chamar WhatsApp diretamente. O Fluxora deve registrar eventos
de negócio e um orquestrador externo, inicialmente n8n, transforma esses
eventos em mensagens, lembretes e integrações.

## Princípio

```text
Ação no Fluxora
  -> registro no Supabase
  -> evento de automação
  -> n8n
  -> WhatsApp / e-mail / outro canal
```

## Eventos iniciais

### appointment.created

Disparado quando um agendamento é criado.

Destinatários:

- dono ou gestor;
- profissional responsável;
- cliente.

Dados mínimos:

- estabelecimento;
- serviço;
- profissional;
- cliente;
- telefone do cliente;
- início;
- fim;
- origem do agendamento.

### appointment.updated

Disparado quando horário, profissional ou serviço muda.

Destinatários:

- profissional anterior, se mudou;
- profissional novo;
- cliente;
- dono ou gestor.

### appointment.cancelled

Disparado quando um agendamento é cancelado.

Destinatários:

- cliente;
- profissional;
- dono ou gestor.

### appointment.reminder

Disparado antes do atendimento.

Destinatários:

- cliente;
- profissional.

### commission.available

Disparado quando uma venda gera comissão para um profissional.

Destinatários:

- profissional;
- dono ou gestor, opcional.

### payout.created

Disparado quando o dono registra um repasse.

Destinatários:

- profissional.

### cash.closed

Disparado quando o caixa é fechado.

Destinatários:

- dono ou gestor.

## n8n

O n8n deve receber os eventos por webhook ou consultar uma tabela de fila de
eventos no Supabase. A decisão final depende do provedor de WhatsApp escolhido.

Para produção, o envio precisa respeitar:

- consentimento do cliente para mensagens;
- identificação clara do estabelecimento;
- opção de parar lembretes promocionais;
- separação entre mensagem transacional e marketing.
