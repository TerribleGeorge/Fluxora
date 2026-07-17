# Notas da versão 1.0.0 (build 18)

## Texto para o Google Play Console

```text
<pt-BR>
Preparamos notificações por e-mail para agendamentos, lembretes e avisos ao dono do estabelecimento. Os e-mails de agenda podem incluir convite de calendário compatível com Google Agenda, Apple Calendar e Outlook, com lembrete de 30 minutos antes. Também melhoramos automações de estoque, documentação operacional e deixamos a base de WhatsApp oficial preparada, mas desligada por segurança até a ativação em produção.
</pt-BR>
```

## Detalhes internos

- `appointment.created` envia aviso por e-mail para profissional e dono/gerente
  quando houver endereço configurado.
- `appointment.reminder` mantém lembrete ao cliente e pode anexar `.ics`.
- Convites `.ics` usam horário real do atendimento, descrição, local e alarme de
  30 minutos.
- WhatsApp Cloud API passa a depender de `WHATSAPP_NOTIFICATIONS_ENABLED=true`,
  evitando que falhas da Meta bloqueiem e-mails.
- Webhook `whatsapp-webhook` preparado para registrar status de mensagem quando
  a integração oficial for ativada.
- Relatórios de produto e estoque incluem resumo financeiro e alerta de baixo
  estoque.
- Serviços de estabelecimento com apenas um profissional são vinculados
  automaticamente para aparecerem no portal público.
- Manual rápido para dono e funcionário incluído na tela inicial.
