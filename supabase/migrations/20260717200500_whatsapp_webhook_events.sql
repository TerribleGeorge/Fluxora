create table if not exists public.whatsapp_webhook_events (
  id bigint generated always as identity primary key,
  provider text not null default 'meta_whatsapp',
  event_kind text not null,
  message_id text,
  phone_number_id text,
  wa_id text,
  status text,
  payload jsonb not null,
  received_at timestamptz not null default now()
);

create index if not exists whatsapp_webhook_events_message_id_idx
  on public.whatsapp_webhook_events (message_id);

create index if not exists whatsapp_webhook_events_received_at_idx
  on public.whatsapp_webhook_events (received_at desc);

alter table public.whatsapp_webhook_events enable row level security;
