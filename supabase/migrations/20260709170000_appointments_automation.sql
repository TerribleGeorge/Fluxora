create type public.appointment_status as enum (
  'scheduled',
  'confirmed',
  'completed',
  'cancelled',
  'noShow'
);

create type public.appointment_source as enum (
  'internal',
  'publicBooking',
  'whatsapp',
  'imported'
);

create type public.automation_event_status as enum (
  'pending',
  'processing',
  'processed',
  'failed'
);

create table public.appointments (
  id uuid primary key,
  business_id uuid not null references public.businesses(id) on delete cascade,
  professional_id uuid not null references public.professionals(id),
  service_id uuid not null references public.beauty_services(id),
  customer_name text not null check (char_length(trim(customer_name)) >= 2),
  customer_phone text not null default '',
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status public.appointment_status not null default 'scheduled',
  source public.appointment_source not null default 'internal',
  notes text not null default '',
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  cancelled_at timestamptz,
  check (ends_at > starts_at),
  check (ends_at >= starts_at + interval '5 minutes')
);

create table public.automation_events (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  event_type text not null check (char_length(trim(event_type)) >= 3),
  aggregate_type text not null check (char_length(trim(aggregate_type)) >= 2),
  aggregate_id uuid not null,
  payload jsonb not null default '{}'::jsonb,
  status public.automation_event_status not null default 'pending',
  attempts integer not null default 0 check (attempts >= 0),
  last_error text,
  available_at timestamptz not null default now(),
  processed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index appointments_business_starts_idx
  on public.appointments(business_id, starts_at desc);

create index appointments_professional_starts_idx
  on public.appointments(professional_id, starts_at);

create index automation_events_status_available_idx
  on public.automation_events(status, available_at, created_at);

create index automation_events_business_created_idx
  on public.automation_events(business_id, created_at desc);

create trigger appointments_set_updated_at
before update on public.appointments
for each row execute function public.set_updated_at();

create trigger automation_events_set_updated_at
before update on public.automation_events
for each row execute function public.set_updated_at();

create or replace function public.enqueue_appointment_automation_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  event_name text;
begin
  if tg_op = 'INSERT' then
    event_name := 'appointment.created';
  elsif tg_op = 'UPDATE' and new.status = 'cancelled' and old.status <> 'cancelled' then
    event_name := 'appointment.cancelled';
  elsif tg_op = 'UPDATE' and (
    new.starts_at <> old.starts_at
    or new.ends_at <> old.ends_at
    or new.professional_id <> old.professional_id
    or new.service_id <> old.service_id
    or new.status <> old.status
  ) then
    event_name := 'appointment.updated';
  else
    return new;
  end if;

  insert into public.automation_events (
    business_id,
    event_type,
    aggregate_type,
    aggregate_id,
    payload
  )
  values (
    new.business_id,
    event_name,
    'appointment',
    new.id,
    jsonb_build_object(
      'appointmentId', new.id,
      'businessId', new.business_id,
      'professionalId', new.professional_id,
      'serviceId', new.service_id,
      'customerName', new.customer_name,
      'customerPhone', new.customer_phone,
      'startsAt', new.starts_at,
      'endsAt', new.ends_at,
      'status', new.status,
      'source', new.source
    )
  );

  return new;
end;
$$;

create trigger appointments_enqueue_automation_event
after insert or update on public.appointments
for each row execute function public.enqueue_appointment_automation_event();

alter table public.appointments enable row level security;
alter table public.automation_events enable row level security;

create policy "appointments_select_members" on public.appointments
for select to authenticated using (public.is_business_member(business_id));

create policy "appointments_manage_operators" on public.appointments
for all to authenticated
using (public.has_business_role(
  business_id, array['owner', 'manager']::public.membership_role[]
))
with check (public.has_business_role(
  business_id, array['owner', 'manager']::public.membership_role[]
));

create policy "appointments_professionals_read_own" on public.appointments
for select to authenticated using (
  exists (
    select 1
    from public.professionals p
    join public.memberships m
      on m.business_id = p.business_id
     and m.user_id = (select auth.uid())
     and m.role = 'professional'
     and m.active
    where p.id = appointments.professional_id
      and p.user_id = (select auth.uid())
  )
);

create policy "automation_events_select_owners_managers" on public.automation_events
for select to authenticated using (public.has_business_role(
  business_id, array['owner', 'manager']::public.membership_role[]
));

-- Events are created by database triggers and processed by service-role
-- functions. Regular app users should not insert or update automation events.
