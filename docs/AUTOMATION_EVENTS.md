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

## Supabase como motor gratuito

Para reduzir custo e evitar dependência de plataformas externas, o primeiro
motor de automação do Fluxora será o próprio Supabase.

Componentes:

- tabela `automation_events`;
- triggers no banco para criar eventos;
- Edge Function `process-automation-events`;
- integração com WhatsApp Cloud API e e-mail dentro da função, quando as
  credenciais externas estiverem configuradas.

O app não precisa conhecer o provedor final de mensagem. Ele registra o dado
operacional e o banco cria o evento correspondente.

## Implementação atual

Quando um agendamento é criado ou alterado, o Supabase cria eventos na tabela
`automation_events`:

| Evento | Quando fica disponível | Objetivo |
| --- | --- | --- |
| `appointment.created` | imediatamente | Avisar o profissional sobre novo agendamento. |
| `appointment.updated` | imediatamente | Registrar mudança de horário, profissional, serviço ou status. |
| `appointment.cancelled` | imediatamente | Registrar cancelamento. |
| `appointment.reminder` | 30 minutos antes do atendimento | Lembrar o cliente por WhatsApp e/ou e-mail. |

Se o horário do agendamento mudar, o lembrete pendente é recalculado. Se o
agendamento for cancelado, o lembrete pendente é removido.

## Canais de envio

### WhatsApp

A Edge Function `process-automation-events` está preparada para a WhatsApp
Cloud API oficial da Meta. Para produção, configure os secrets abaixo no
Supabase:

```powershell
npx supabase secrets set WHATSAPP_ACCESS_TOKEN="TOKEN_DA_META" --project-ref nqcoxxbzwzcuwprbzpdb
npx supabase secrets set WHATSAPP_PHONE_NUMBER_ID="PHONE_NUMBER_ID" --project-ref nqcoxxbzwzcuwprbzpdb
npx supabase secrets set WHATSAPP_TEMPLATE_LANGUAGE="pt_BR" --project-ref nqcoxxbzwzcuwprbzpdb
npx supabase secrets set WHATSAPP_TEMPLATE_APPOINTMENT_CREATED="fluxora_novo_agendamento" --project-ref nqcoxxbzwzcuwprbzpdb
npx supabase secrets set WHATSAPP_TEMPLATE_APPOINTMENT_REMINDER="fluxora_lembrete_agendamento" --project-ref nqcoxxbzwzcuwprbzpdb
```

Para mensagens automáticas iniciadas pelo estabelecimento, use templates
aprovados na Meta. O modo de texto livre só deve ser usado em testes ou em
janelas permitidas pela plataforma:

```powershell
npx supabase secrets set WHATSAPP_ALLOW_FREEFORM_TEXT="true" --project-ref nqcoxxbzwzcuwprbzpdb
```

### E-mail

O envio de e-mail está preparado para Resend:

```powershell
npx supabase secrets set RESEND_API_KEY="SUA_CHAVE_RESEND" --project-ref nqcoxxbzwzcuwprbzpdb
npx supabase secrets set EMAIL_FROM="Fluxora <agenda@seudominio.com>" --project-ref nqcoxxbzwzcuwprbzpdb
```

## Processamento automático

Os eventos só viram mensagens quando a Edge Function é chamada. Para produção,
configure um agendamento recorrente no Supabase para chamar:

```text
process-automation-events
```

Recomendação inicial:

- frequência: a cada 1 minuto;
- método: `POST`;
- objetivo: processar eventos `pending` cujo `available_at` já chegou.

Também é possível acionar manualmente durante testes:

```powershell
npx supabase functions invoke process-automation-events --project-ref nqcoxxbzwzcuwprbzpdb
```

Sem credenciais de WhatsApp/e-mail, a função processa o evento e registra o
canal como `skipped`, sem quebrar o app.

## n8n ou alternativas futuras

O n8n, Make, Pipedream ou Activepieces podem ser conectados depois consultando
a tabela `automation_events` ou recebendo webhooks disparados pela Edge
Function. A decisão final depende do provedor de WhatsApp escolhido e dos
custos reais.

Para produção, o envio precisa respeitar:

- consentimento do cliente para mensagens;
- identificação clara do estabelecimento;
- opção de parar lembretes promocionais;
- separação entre mensagem transacional e marketing.
