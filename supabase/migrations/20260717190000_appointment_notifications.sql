-- Appointment notifications and reminders.
-- Creates immediate events for new/changed appointments and a reminder event
-- scheduled 30 minutes before the appointment starts.

create index if not exists automation_events_appointment_reminder_pending_idx
  on public.automation_events(aggregate_id, event_type, status)
  where event_type = 'appointment.reminder'
    and status in ('pending', 'processing');

create or replace function public.appointment_automation_payload(
  appointment_record public.appointments
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  business_record public.businesses;
  professional_record public.professionals;
  service_record public.beauty_services;
  settings_record public.public_booking_settings;
  owner_contacts jsonb;
  local_starts_at text;
  local_ends_at text;
  local_date text;
  local_start_time text;
  local_end_time text;
  timezone_name text := 'America/Sao_Paulo';
begin
  select * into business_record
  from public.businesses
  where id = appointment_record.business_id;

  select * into professional_record
  from public.professionals
  where id = appointment_record.professional_id;

  select * into service_record
  from public.beauty_services
  where id = appointment_record.service_id;

  select * into settings_record
  from public.public_booking_settings
  where business_id = appointment_record.business_id;

  timezone_name := coalesce(nullif(settings_record.time_zone, ''), timezone_name);

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'name', profile.name,
        'email', profile.email
      )
      order by profile.name, profile.email
    ),
    '[]'::jsonb
  )
  into owner_contacts
  from public.memberships membership
  join public.profiles profile on profile.id = membership.user_id
  where membership.business_id = appointment_record.business_id
    and membership.active
    and membership.role in ('owner', 'manager');

  local_starts_at := to_char(
    appointment_record.starts_at at time zone timezone_name,
    'YYYY-MM-DD"T"HH24:MI:SS'
  );
  local_ends_at := to_char(
    appointment_record.ends_at at time zone timezone_name,
    'YYYY-MM-DD"T"HH24:MI:SS'
  );
  local_date := to_char(
    appointment_record.starts_at at time zone timezone_name,
    'DD/MM/YYYY'
  );
  local_start_time := to_char(
    appointment_record.starts_at at time zone timezone_name,
    'HH24:MI'
  );
  local_end_time := to_char(
    appointment_record.ends_at at time zone timezone_name,
    'HH24:MI'
  );

  return jsonb_build_object(
    'appointmentId', appointment_record.id,
    'businessId', appointment_record.business_id,
    'businessName', coalesce(business_record.name, ''),
    'businessPhone', coalesce(business_record.phone, ''),
    'professionalId', appointment_record.professional_id,
    'professionalName', coalesce(professional_record.name, ''),
    'professionalPhone', coalesce(professional_record.phone, ''),
    'professionalEmail', coalesce(professional_record.email, ''),
    'serviceId', appointment_record.service_id,
    'serviceName', coalesce(service_record.name, ''),
    'servicePrice', coalesce(appointment_record.service_final_price, service_record.price, 0),
    'customerName', appointment_record.customer_name,
    'customerPhone', appointment_record.customer_phone,
    'customerEmail', coalesce(appointment_record.customer_email, ''),
    'startsAt', appointment_record.starts_at,
    'endsAt', appointment_record.ends_at,
    'localStartsAt', local_starts_at,
    'localEndsAt', local_ends_at,
    'localDate', local_date,
    'localStartTime', local_start_time,
    'localEndTime', local_end_time,
    'timeZone', timezone_name,
    'status', appointment_record.status,
    'source', appointment_record.source,
    'publicReference', coalesce(appointment_record.public_reference, ''),
    'ownerContacts', owner_contacts,
    'recipients', jsonb_build_object(
      'professional', jsonb_build_object(
        'name', coalesce(professional_record.name, ''),
        'phone', coalesce(professional_record.phone, ''),
        'email', coalesce(professional_record.email, '')
      ),
      'customer', jsonb_build_object(
        'name', appointment_record.customer_name,
        'phone', appointment_record.customer_phone,
        'email', coalesce(appointment_record.customer_email, '')
      ),
      'owners', owner_contacts
    )
  );
end;
$$;

create or replace function public.enqueue_appointment_automation_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  event_name text;
  payload_data jsonb;
  reminder_at timestamptz;
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

  payload_data := public.appointment_automation_payload(new);

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
    payload_data
  );

  delete from public.automation_events event
  where event.aggregate_type = 'appointment'
    and event.aggregate_id = new.id
    and event.event_type = 'appointment.reminder'
    and event.status = 'pending';

  if new.status in ('scheduled', 'confirmed') then
    reminder_at := new.starts_at - interval '30 minutes';
    if reminder_at < now() then
      reminder_at := now();
    end if;

    insert into public.automation_events (
      business_id,
      event_type,
      aggregate_type,
      aggregate_id,
      payload,
      available_at
    )
    values (
      new.business_id,
      'appointment.reminder',
      'appointment',
      new.id,
      payload_data || jsonb_build_object('reminderMinutesBefore', 30),
      reminder_at
    );
  end if;

  return new;
end;
$$;

revoke execute on function public.appointment_automation_payload(public.appointments)
  from public, anon, authenticated;
revoke execute on function public.enqueue_appointment_automation_event()
  from public, anon, authenticated;
