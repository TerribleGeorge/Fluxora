-- Public booking portal and security hardening.
-- This migration intentionally exposes only narrow DTO RPCs to anon users.

alter table public.businesses
  add column if not exists public_slug text;

alter table public.appointments
  add column if not exists public_reference text;

create unique index if not exists businesses_public_slug_unique_idx
  on public.businesses(public_slug)
  where public_slug is not null;

create unique index if not exists appointments_public_reference_unique_idx
  on public.appointments(public_reference)
  where public_reference is not null;

create or replace function public.slugify_public_booking(value text)
returns text
language sql
immutable
security invoker
set search_path = ''
as $$
  select trim(both '-' from regexp_replace(
    translate(
      lower(trim(coalesce(value, ''))),
      'áàâãäåéèêëíìîïóòôõöúùûüçñýÿ',
      'aaaaaaeeeeiiiiooooouuuucnyy'
    ),
    '[^a-z0-9]+',
    '-',
    'g'
  ));
$$;

create or replace function public.set_business_public_slug()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_slug text;
begin
  normalized_slug := public.slugify_public_booking(new.public_slug);
  if normalized_slug = '' then
    normalized_slug := public.slugify_public_booking(new.name);
    if normalized_slug = '' then
      normalized_slug := 'estabelecimento';
    end if;
    normalized_slug := normalized_slug || '-' || substring(new.id::text from 1 for 8);
  end if;

  if char_length(normalized_slug) < 3 or char_length(normalized_slug) > 80 then
    raise exception 'Public booking slug must contain between 3 and 80 characters';
  end if;
  new.public_slug := normalized_slug;
  return new;
end;
$$;

drop trigger if exists businesses_set_public_slug on public.businesses;
create trigger businesses_set_public_slug
before insert or update of name, public_slug on public.businesses
for each row execute function public.set_business_public_slug();

update public.businesses
set public_slug = null
where public_slug is null or trim(public_slug) = '';

create table if not exists public.public_booking_settings (
  business_id uuid primary key references public.businesses(id) on delete cascade,
  enabled boolean not null default false,
  time_zone text not null default 'America/Sao_Paulo',
  working_days smallint[] not null default array[1, 2, 3, 4, 5, 6]::smallint[],
  opening_time time not null default '08:00',
  closing_time time not null default '19:00',
  slot_interval_minutes integer not null default 15
    check (slot_interval_minutes between 5 and 120),
  minimum_notice_minutes integer not null default 60
    check (minimum_notice_minutes between 0 and 10080),
  maximum_advance_days integer not null default 60
    check (maximum_advance_days between 1 and 365),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (opening_time < closing_time),
  check (cardinality(working_days) between 1 and 7)
);

create or replace function public.validate_public_booking_settings()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1
    from unnest(new.working_days) as selected_day
    where selected_day < 1 or selected_day > 7
  ) then
    raise exception 'Working days must use ISO values from 1 to 7';
  end if;
  if not exists (
    select 1 from pg_catalog.pg_timezone_names where name = new.time_zone
  ) then
    raise exception 'Invalid IANA time zone';
  end if;
  return new;
end;
$$;

drop trigger if exists public_booking_settings_validate on public.public_booking_settings;
create trigger public_booking_settings_validate
before insert or update on public.public_booking_settings
for each row execute function public.validate_public_booking_settings();

drop trigger if exists public_booking_settings_set_updated_at on public.public_booking_settings;
create trigger public_booking_settings_set_updated_at
before update on public.public_booking_settings
for each row execute function public.set_updated_at();

insert into public.public_booking_settings (business_id)
select id from public.businesses
on conflict (business_id) do nothing;

create or replace function public.create_default_public_booking_settings()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.public_booking_settings (business_id)
  values (new.id)
  on conflict (business_id) do nothing;
  return new;
end;
$$;

drop trigger if exists businesses_create_public_booking_settings on public.businesses;
create trigger businesses_create_public_booking_settings
after insert on public.businesses
for each row execute function public.create_default_public_booking_settings();

alter table public.public_booking_settings enable row level security;

drop policy if exists "public_booking_settings_select_owners_managers"
  on public.public_booking_settings;
create policy "public_booking_settings_select_owners_managers"
on public.public_booking_settings for select to authenticated
using (public.has_business_role(
  business_id,
  array['owner', 'manager']::public.membership_role[]
));

drop policy if exists "public_booking_settings_manage_owners_managers"
  on public.public_booking_settings;
create policy "public_booking_settings_manage_owners_managers"
on public.public_booking_settings for all to authenticated
using (public.has_business_role(
  business_id,
  array['owner', 'manager']::public.membership_role[]
))
with check (public.has_business_role(
  business_id,
  array['owner', 'manager']::public.membership_role[]
));

-- Policies are additive. Remove the broad member policy so a professional
-- cannot read appointments belonging to another professional.
drop policy if exists "appointments_select_members" on public.appointments;
drop policy if exists "appointments_professionals_read_own" on public.appointments;
drop policy if exists "appointments_select_owners_managers" on public.appointments;
create policy "appointments_select_owners_managers"
on public.appointments for select to authenticated
using (public.has_business_role(
  business_id,
  array['owner', 'manager']::public.membership_role[]
));

drop policy if exists "appointments_professional_read_own" on public.appointments;
create policy "appointments_professional_read_own"
on public.appointments for select to authenticated
using (
  exists (
    select 1
    from public.professionals p
    where p.id = appointments.professional_id
      and p.business_id = appointments.business_id
      and p.user_id = (select auth.uid())
      and p.active
  )
);

-- Every operation that can change a professional's visible agenda uses this
-- exact lock. The text namespace prevents collisions with unrelated locks.
create or replace function public.lock_professional_booking_agenda(
  target_professional_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if target_professional_id is null then
    raise exception 'Professional is required for an agenda lock';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'fluxora:professional-agenda:' || target_professional_id::text,
      0
    )
  );
end;
$$;

-- A check-before-insert alone races. This trigger serializes writes for each
-- professional with the shared agenda lock and rejects overlapping active
-- appointments.
create or replace function public.prevent_appointment_overlap()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status not in ('scheduled', 'confirmed') then
    return new;
  end if;

  perform public.lock_professional_booking_agenda(new.professional_id);

  if exists (
    select 1
    from public.appointments a
    where a.professional_id = new.professional_id
      and a.business_id = new.business_id
      and a.id <> new.id
      and a.status in ('scheduled', 'confirmed')
      and a.starts_at < new.ends_at
      and a.ends_at > new.starts_at
  ) then
    raise exception using
      errcode = '23P01',
      message = 'Time slot unavailable';
  end if;
  return new;
end;
$$;

drop trigger if exists appointments_prevent_overlap on public.appointments;
create trigger appointments_prevent_overlap
before insert or update of professional_id, business_id, starts_at, ends_at, status
on public.appointments
for each row execute function public.prevent_appointment_overlap();

-- Public identity lookup is deliberately fail-closed. An email alone never
-- identifies a customer. All three submitted fields must match, while the
-- name+phone fallback is restricted to a legacy customer that truly has no
-- email. Booking-created aliases are untrusted until an owner/import or a
-- future OTP flow proves possession.
create or replace function public.find_booking_customer(
  target_business_id uuid,
  raw_name text,
  raw_email text,
  raw_phone text
)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  clean_name text := public.normalize_name(raw_name);
  clean_email text := public.normalize_email(raw_email);
  clean_phone text := public.normalize_phone(raw_phone);
  found_customer_id uuid;
  name_phone_identity text;
begin
  name_phone_identity := clean_name || '|' || clean_phone;

  if clean_name = '' or clean_phone = '' or clean_email = '' then
    return null;
  end if;

  -- Strict composite match. Aliases participate only when they are verified
  -- or were asserted by an owner/manual import.
  select customer.id into found_customer_id
  from public.customers customer
  where customer.business_id = target_business_id
    and customer.deleted_at is null
    and (
      (
        customer.normalized_name = clean_name
        and (
          customer.normalized_phone = clean_phone
          or exists (
            select 1
            from public.customer_identities phone_identity
            where phone_identity.business_id = target_business_id
              and phone_identity.customer_id = customer.id
              and phone_identity.identity_type = 'phone'
              and phone_identity.identity_value = clean_phone
              and (
                phone_identity.verified
                or phone_identity.source in ('manual', 'import')
              )
          )
        )
      )
      or exists (
        select 1
        from public.customer_identities name_phone_alias
        where name_phone_alias.business_id = target_business_id
          and name_phone_alias.customer_id = customer.id
          and name_phone_alias.identity_type = 'namePhone'
          and name_phone_alias.identity_value = name_phone_identity
          and (
            name_phone_alias.verified
            or name_phone_alias.source in ('manual', 'import')
          )
      )
    )
    and (
      customer.normalized_email = clean_email
      or exists (
        select 1
        from public.customer_identities email_alias
        where email_alias.business_id = target_business_id
          and email_alias.customer_id = customer.id
          and email_alias.identity_type = 'email'
          and email_alias.identity_value = clean_email
          and (
            email_alias.verified
            or email_alias.source in ('manual', 'import')
          )
      )
    )
  order by case
    when customer.normalized_name = clean_name
      and customer.normalized_phone = clean_phone
      and customer.normalized_email = clean_email then 0
    else 1
  end, customer.id
  limit 1;

  if found_customer_id is not null then
    return found_customer_id;
  end if;

  -- Legacy fallback: name+phone may identify only a customer with no email at
  -- all. It is refused when the submitted email already belongs to any other
  -- active customer, preventing cross-customer contamination.
  select customer.id into found_customer_id
  from public.customers customer
  where customer.business_id = target_business_id
    and customer.deleted_at is null
    and customer.normalized_email = ''
    and not exists (
      select 1
      from public.customer_identities existing_email
      where existing_email.business_id = target_business_id
        and existing_email.customer_id = customer.id
        and existing_email.identity_type = 'email'
        and (
          existing_email.verified
          or existing_email.source in ('manual', 'import')
        )
    )
    and (
      (
        customer.normalized_name = clean_name
        and (
          customer.normalized_phone = clean_phone
          or exists (
            select 1
            from public.customer_identities phone_identity
            where phone_identity.business_id = target_business_id
              and phone_identity.customer_id = customer.id
              and phone_identity.identity_type = 'phone'
              and phone_identity.identity_value = clean_phone
              and (
                phone_identity.verified
                or phone_identity.source in ('manual', 'import')
              )
          )
        )
      )
      or exists (
        select 1
        from public.customer_identities name_phone_alias
        where name_phone_alias.business_id = target_business_id
          and name_phone_alias.customer_id = customer.id
          and name_phone_alias.identity_type = 'namePhone'
          and name_phone_alias.identity_value = name_phone_identity
          and (
            name_phone_alias.verified
            or name_phone_alias.source in ('manual', 'import')
          )
      )
    )
    and not exists (
      select 1
      from public.customers other_customer
      where other_customer.business_id = target_business_id
        and other_customer.id <> customer.id
        and other_customer.deleted_at is null
        and other_customer.normalized_email = clean_email
    )
    and not exists (
      select 1
      from public.customer_identities other_email
      join public.customers other_customer
        on other_customer.id = other_email.customer_id
       and other_customer.deleted_at is null
      where other_email.business_id = target_business_id
        and other_email.customer_id <> customer.id
        and other_email.identity_type = 'email'
        and other_email.identity_value = clean_email
        and (
          other_email.verified
          or other_email.source in ('manual', 'import')
        )
    )
  order by customer.id
  limit 1;

  return found_customer_id;
end;
$$;

-- Serialize customer resolution across professionals. Every caller locks the
-- same deterministic email/name-phone/composite keys in lexical order, so two
-- simultaneous bookings cannot create duplicate customers for one identity.
create or replace function public.lock_booking_customer_identity(
  target_business_id uuid,
  raw_name text,
  raw_email text,
  raw_phone text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  clean_name text := public.normalize_name(raw_name);
  clean_email text := public.normalize_email(raw_email);
  clean_phone text := public.normalize_phone(raw_phone);
  lock_key text;
begin
  for lock_key in
    select distinct candidate.key
    from unnest(array[
      target_business_id::text || ':email:' || clean_email,
      target_business_id::text || ':name-phone:' || clean_name || '|' || clean_phone,
      target_business_id::text || ':composite:' || clean_name || '|' || clean_phone || '|' || clean_email
    ]) as candidate(key)
    order by candidate.key
  loop
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(
        'fluxora:booking-customer:' || lock_key,
        0
      )
    );
  end loop;
end;
$$;

-- Booking identities are unverified until a later OTP/owner confirmation.
-- A conflicting identity is never transferred to another customer.
create or replace function public.record_booking_identity(
  target_business_id uuid,
  target_customer_id uuid,
  target_type public.customer_identity_type,
  normalized_value text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if normalized_value is null or char_length(trim(normalized_value)) < 2 then
    return;
  end if;

  insert into public.customer_identities (
    business_id,
    customer_id,
    identity_type,
    identity_value,
    source,
    verified
  )
  values (
    target_business_id,
    target_customer_id,
    target_type,
    normalized_value,
    'booking',
    false
  )
  on conflict (business_id, identity_type, identity_value) do nothing;
end;
$$;

create or replace function public.upsert_customer_identity(
  target_business_id uuid,
  target_customer_id uuid,
  target_type public.customer_identity_type,
  raw_value text,
  target_source public.customer_identity_source default 'booking',
  target_verified boolean default false
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized text;
  existing_customer_id uuid;
begin
  if raw_value is null or trim(raw_value) = '' then
    return;
  end if;
  normalized := case
    when target_type = 'email' then public.normalize_email(raw_value)
    when target_type = 'phone' then public.normalize_phone(raw_value)
    else public.normalize_name(raw_value)
  end;
  if char_length(normalized) < 2 then
    return;
  end if;

  select customer_id into existing_customer_id
  from public.customer_identities
  where business_id = target_business_id
    and identity_type = target_type
    and identity_value = normalized;

  if existing_customer_id is not null and existing_customer_id <> target_customer_id then
    raise exception 'Identity already belongs to another customer';
  end if;

  insert into public.customer_identities (
    business_id, customer_id, identity_type, identity_value, source, verified
  ) values (
    target_business_id,
    target_customer_id,
    target_type,
    normalized,
    target_source,
    target_verified
  )
  on conflict (business_id, identity_type, identity_value)
  do update set
    source = excluded.source,
    verified = public.customer_identities.verified or excluded.verified;
end;
$$;

create or replace function public.find_or_create_booking_customer(
  target_business_id uuid,
  raw_name text,
  raw_email text,
  raw_phone text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  clean_name text := public.normalize_name(raw_name);
  clean_email text := public.normalize_email(raw_email);
  clean_phone text := public.normalize_phone(raw_phone);
  found_customer_id uuid;
  created_customer boolean := false;
  filled_legacy_email boolean := false;
  existing_email text;
begin
  if char_length(clean_name) < 2 then
    raise exception 'Customer name is required';
  end if;
  if char_length(clean_email) < 5 then
    raise exception 'Customer email is required';
  end if;
  if char_length(clean_phone) < 8 then
    raise exception 'Customer phone is required';
  end if;

  perform public.lock_booking_customer_identity(
    target_business_id, raw_name, raw_email, raw_phone
  );

  found_customer_id := public.find_booking_customer(
    target_business_id, raw_name, raw_email, raw_phone
  );

  if found_customer_id is null then
    insert into public.customers (
      business_id,
      name,
      normalized_name,
      email,
      normalized_email,
      phone,
      normalized_phone,
      relationship_started_at
    ) values (
      target_business_id,
      trim(raw_name),
      clean_name,
      trim(raw_email),
      clean_email,
      trim(raw_phone),
      clean_phone,
      now()
    )
    returning id into found_customer_id;
    created_customer := true;
  else
    select customer.normalized_email into existing_email
    from public.customers customer
    where customer.id = found_customer_id
      and customer.business_id = target_business_id
    for update;

    -- The only public mutation allowed on an existing customer is safely
    -- filling an empty legacy email after the strict name+phone match above.
    if existing_email = '' then
      update public.customers
      set email = trim(raw_email),
          normalized_email = clean_email
      where id = found_customer_id
        and business_id = target_business_id
        and normalized_email = '';
      filled_legacy_email := found;
    end if;
  end if;

  if created_customer then
    -- New public identities remain unverified until OTP/owner confirmation.
    perform public.record_booking_identity(
      target_business_id, found_customer_id, 'email', clean_email
    );
    perform public.record_booking_identity(
      target_business_id, found_customer_id, 'phone', clean_phone
    );
    perform public.record_booking_identity(
      target_business_id,
      found_customer_id,
      'namePhone',
      clean_name || '|' || clean_phone
    );
  elsif filled_legacy_email then
    perform public.record_booking_identity(
      target_business_id, found_customer_id, 'email', clean_email
    );
  end if;
  return found_customer_id;
end;
$$;

create or replace function public.get_public_booking_page(target_slug text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  business_record public.businesses;
  settings_record public.public_booking_settings;
  services_json jsonb;
  professionals_json jsonb;
begin
  select b.* into business_record
  from public.businesses b
  join public.public_booking_settings s on s.business_id = b.id
  where b.public_slug = public.slugify_public_booking(target_slug)
    and s.enabled;

  if business_record.id is null then
    raise exception 'Public booking disabled or not found';
  end if;

  select * into settings_record
  from public.public_booking_settings
  where business_id = business_record.id;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', service.id,
        'name', service.name,
        'category', service.category,
        'price', service.price,
        'duration_minutes', service.duration_minutes
      ) order by service.name
    ),
    '[]'::jsonb
  ) into services_json
  from public.beauty_services service
  where service.business_id = business_record.id
    and service.active;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', professional.id,
        'name', professional.name
      ) order by professional.name
    ),
    '[]'::jsonb
  ) into professionals_json
  from public.professionals professional
  where professional.business_id = business_record.id
    and professional.active;

  return jsonb_build_object(
    'business_name', business_record.name,
    'business_type', business_record.type,
    'slug', business_record.public_slug,
    'time_zone', settings_record.time_zone,
    'local_today', to_char(now() at time zone settings_record.time_zone, 'YYYY-MM-DD'),
    'working_days', to_jsonb(settings_record.working_days),
    'maximum_advance_days', settings_record.maximum_advance_days,
    'services', services_json,
    'professionals', professionals_json
  );
end;
$$;

create or replace function public.get_public_available_slots(
  target_slug text,
  target_professional_id uuid,
  target_service_id uuid,
  target_day date
)
returns table (
  starts_at timestamptz,
  ends_at timestamptz,
  local_time_label text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  target_business_id uuid;
  settings_record public.public_booking_settings;
  service_duration integer;
  local_today date;
  opening_at timestamptz;
  closing_at timestamptz;
begin
  select b.id into target_business_id
  from public.businesses b
  join public.public_booking_settings settings on settings.business_id = b.id
  where b.public_slug = public.slugify_public_booking(target_slug)
    and settings.enabled;

  if target_business_id is null then
    raise exception 'Public booking disabled or not found';
  end if;

  select * into settings_record
  from public.public_booking_settings
  where business_id = target_business_id;

  select duration_minutes into service_duration
  from public.beauty_services
  where id = target_service_id
    and business_id = target_business_id
    and active;
  if service_duration is null then
    raise exception 'Service not found';
  end if;

  if not exists (
    select 1 from public.professionals
    where id = target_professional_id
      and business_id = target_business_id
      and active
  ) then
    raise exception 'Professional not found';
  end if;

  local_today := (now() at time zone settings_record.time_zone)::date;
  if target_day < local_today
    or target_day > local_today + settings_record.maximum_advance_days
  then
    return;
  end if;
  if not (
    extract(isodow from target_day)::smallint = any(settings_record.working_days)
  ) then
    return;
  end if;

  opening_at := (target_day + settings_record.opening_time)
    at time zone settings_record.time_zone;
  closing_at := (target_day + settings_record.closing_time)
    at time zone settings_record.time_zone;

  return query
  select
    candidate as starts_at,
    candidate + make_interval(mins => service_duration) as ends_at,
    to_char(candidate at time zone settings_record.time_zone, 'HH24:MI') as local_time_label
  from generate_series(
    opening_at,
    closing_at - make_interval(mins => service_duration),
    make_interval(mins => settings_record.slot_interval_minutes)
  ) as slots(candidate)
  where candidate >= now() + make_interval(mins => settings_record.minimum_notice_minutes)
    and not exists (
      select 1
      from public.appointments appointment
      where appointment.business_id = target_business_id
        and appointment.professional_id = target_professional_id
        and appointment.status in ('scheduled', 'confirmed')
        and appointment.starts_at < candidate + make_interval(mins => service_duration)
        and appointment.ends_at > candidate
    )
  order by candidate;
end;
$$;

create or replace function public.quote_public_booking(
  target_slug text,
  target_service_id uuid,
  raw_name text,
  raw_email text,
  raw_phone text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  target_business_id uuid;
  service_price numeric;
  clean_name text := public.normalize_name(raw_name);
  clean_email text := public.normalize_email(raw_email);
  clean_phone text := public.normalize_phone(raw_phone);
begin
  if char_length(clean_name) < 2 then
    raise exception 'Customer name is required';
  end if;
  if char_length(clean_email) < 5 then
    raise exception 'Customer email is required';
  end if;
  if char_length(clean_phone) < 8 then
    raise exception 'Customer phone is required';
  end if;

  select b.id into target_business_id
  from public.businesses b
  join public.public_booking_settings settings on settings.business_id = b.id
  where b.public_slug = public.slugify_public_booking(target_slug)
    and settings.enabled;
  if target_business_id is null then
    raise exception 'Public booking disabled or not found';
  end if;

  select price into service_price
  from public.beauty_services
  where id = target_service_id
    and business_id = target_business_id
    and active;
  if service_price is null then
    raise exception 'Service not found';
  end if;

  -- Fail closed until the public portal implements OTP possession proof.
  -- Submitted personal data must never unlock an automatic loyalty discount.
  return jsonb_build_object(
    'base_price', service_price,
    'final_price', service_price
  );
end;
$$;

create or replace function public.create_public_booking_v2(
  target_slug text,
  target_professional_id uuid,
  target_service_id uuid,
  raw_name text,
  raw_email text,
  raw_phone text,
  target_starts_at timestamptz,
  target_notes text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_business_id uuid;
  settings_record public.public_booking_settings;
  service_record public.beauty_services;
  customer_id uuid;
  tier public.customer_loyalty_tier := 'new';
  discount_percent numeric := 0;
  discount_amount numeric := 0;
  final_price numeric;
  target_ends_at timestamptz;
  appointment_id uuid := gen_random_uuid();
  booking_reference text;
  local_day date;
  clean_email text := public.normalize_email(raw_email);
  clean_phone text := public.normalize_phone(raw_phone);
begin
  if char_length(public.normalize_name(raw_name)) < 2 then
    raise exception 'Customer name is required';
  end if;
  if char_length(clean_email) < 5 then
    raise exception 'Customer email is required';
  end if;
  if char_length(clean_phone) < 8 then
    raise exception 'Customer phone is required';
  end if;
  if char_length(coalesce(target_notes, '')) > 1000 then
    raise exception 'Booking notes are too long';
  end if;

  select b.id into target_business_id
  from public.businesses b
  join public.public_booking_settings settings on settings.business_id = b.id
  where b.public_slug = public.slugify_public_booking(target_slug)
    and settings.enabled;
  if target_business_id is null then
    raise exception 'Public booking disabled or not found';
  end if;

  select * into settings_record
  from public.public_booking_settings
  where business_id = target_business_id;

  select * into service_record
  from public.beauty_services
  where id = target_service_id
    and business_id = target_business_id
    and active;
  if service_record.id is null then
    raise exception 'Service not found';
  end if;
  if not exists (
    select 1 from public.professionals
    where id = target_professional_id
      and business_id = target_business_id
      and active
  ) then
    raise exception 'Professional not found';
  end if;

  -- Limit repeated submissions from the same identity without storing IP data.
  if (
    select count(*)
    from public.appointments appointment
    where appointment.business_id = target_business_id
      and appointment.created_at >= now() - interval '1 hour'
      and (
        public.normalize_email(appointment.customer_email) = clean_email
        or public.normalize_phone(appointment.customer_phone) = clean_phone
      )
  ) >= 5 then
    raise exception 'Too many booking attempts. Try again later';
  end if;

  perform public.lock_professional_booking_agenda(target_professional_id);
  local_day := (target_starts_at at time zone settings_record.time_zone)::date;
  if not exists (
    select 1
    from public.get_public_available_slots(
      target_slug,
      target_professional_id,
      target_service_id,
      local_day
    ) available
    where available.starts_at = target_starts_at
  ) then
    raise exception using
      errcode = '23P01',
      message = 'Time slot unavailable';
  end if;

  customer_id := public.find_or_create_booking_customer(
    target_business_id, raw_name, raw_email, raw_phone
  );
  -- Public loyalty remains fail-closed until a future OTP proves that the
  -- visitor owns a trusted customer identity.
  tier := 'new';
  discount_percent := 0;
  discount_amount := 0;
  final_price := service_record.price;
  target_ends_at := target_starts_at
    + make_interval(mins => service_record.duration_minutes);
  booking_reference := 'FX-' || upper(substring(replace(appointment_id::text, '-', '') from 1 for 10));

  insert into public.appointments (
    id,
    business_id,
    professional_id,
    service_id,
    customer_id,
    customer_name,
    customer_email,
    customer_phone,
    starts_at,
    ends_at,
    status,
    source,
    notes,
    loyalty_tier_applied,
    service_base_price,
    discount_percent_applied,
    discount_amount,
    service_final_price,
    pricing_locked_at,
    public_reference
  ) values (
    appointment_id,
    target_business_id,
    target_professional_id,
    target_service_id,
    customer_id,
    trim(raw_name),
    trim(raw_email),
    trim(raw_phone),
    target_starts_at,
    target_ends_at,
    'scheduled',
    'publicBooking',
    trim(coalesce(target_notes, '')),
    tier,
    service_record.price,
    discount_percent,
    discount_amount,
    final_price,
    now(),
    booking_reference
  );

  return jsonb_build_object(
    'reference', booking_reference,
    'starts_at', target_starts_at,
    'ends_at', target_ends_at,
    'final_price', final_price,
    'local_date_time_label',
      to_char(target_starts_at at time zone settings_record.time_zone, 'DD/MM/YYYY, HH24:MI')
      || '–'
      || to_char(target_ends_at at time zone settings_record.time_zone, 'HH24:MI')
  );
end;
$$;

-- Manual identity correction is allowed only before checkout. Repricing an
-- already paid sale without redoing payment fee, commission and items would
-- corrupt the financial ledger, so that unsafe legacy behavior is blocked.
create or replace function public.link_appointment_to_customer(
  target_appointment_id uuid,
  target_customer_id uuid
)
returns public.appointments
language plpgsql
security definer
set search_path = ''
as $$
declare
  appointment_record public.appointments;
  service_record public.beauty_services;
  tier public.customer_loyalty_tier;
  applied_discount_percent numeric;
  applied_discount_amount numeric;
  old_data jsonb;
begin
  select * into appointment_record
  from public.appointments
  where id = target_appointment_id
  for update;

  if appointment_record.id is null then
    raise exception 'Appointment not found';
  end if;
  if appointment_record.status not in ('scheduled', 'confirmed')
    or exists (
      select 1 from public.sales
      where appointment_id = target_appointment_id
        and business_id = appointment_record.business_id
    )
  then
    raise exception 'Customer association must happen before checkout';
  end if;
  if not (
    public.has_business_role(
      appointment_record.business_id,
      array['owner', 'manager']::public.membership_role[]
    )
    or exists (
      select 1 from public.professionals professional
      where professional.id = appointment_record.professional_id
        and professional.user_id = (select auth.uid())
        and professional.active
    )
  ) then
    raise exception 'Not allowed';
  end if;
  if not exists (
    select 1 from public.customers
    where id = target_customer_id
      and business_id = appointment_record.business_id
      and deleted_at is null
  ) then
    raise exception 'Customer not found';
  end if;

  select * into service_record
  from public.beauty_services
  where id = appointment_record.service_id
    and business_id = appointment_record.business_id
    and active;
  if service_record.id is null then
    raise exception 'Service not found';
  end if;

  old_data := to_jsonb(appointment_record);
  tier := public.calculate_customer_loyalty_tier(
    appointment_record.business_id,
    target_customer_id,
    now()
  );
  applied_discount_percent := coalesce(
    public.discount_percent_for_tier(appointment_record.business_id, tier),
    0
  );
  applied_discount_amount := round(
    service_record.price * applied_discount_percent / 100,
    2
  );

  update public.appointments
  set
    customer_id = target_customer_id,
    loyalty_tier_applied = tier,
    service_base_price = service_record.price,
    discount_percent_applied = applied_discount_percent,
    discount_amount = applied_discount_amount,
    service_final_price = service_record.price - applied_discount_amount,
    pricing_locked_at = now()
  where id = target_appointment_id
  returning * into appointment_record;

  perform public.upsert_customer_identity(
    appointment_record.business_id,
    target_customer_id,
    'email',
    appointment_record.customer_email,
    'manual',
    true
  );
  perform public.upsert_customer_identity(
    appointment_record.business_id,
    target_customer_id,
    'phone',
    appointment_record.customer_phone,
    'manual',
    true
  );
  perform public.upsert_customer_identity(
    appointment_record.business_id,
    target_customer_id,
    'namePhone',
    public.normalize_name(appointment_record.customer_name)
      || '|'
      || public.normalize_phone(appointment_record.customer_phone),
    'manual',
    true
  );

  insert into public.audit_logs (
    business_id,
    actor_id,
    action,
    aggregate_type,
    aggregate_id,
    before_data,
    after_data
  ) values (
    appointment_record.business_id,
    (select auth.uid()),
    'appointment.customer_linked',
    'appointment',
    target_appointment_id,
    old_data,
    to_jsonb(appointment_record)
  );

  return appointment_record;
end;
$$;

-- The employee association flow must not require SELECT access to the full
-- customer table. This RPC is scoped to one pending appointment, verifies that
-- the caller may operate that appointment and returns only masked identity
-- hints plus the loyalty tier needed to choose the correct record.
create or replace function public.search_linkable_customers(
  target_appointment_id uuid,
  raw_query text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  appointment_record public.appointments;
  search_text text := lower(trim(coalesce(raw_query, '')));
  search_name text;
  search_phone text;
  result jsonb;
begin
  if length(search_text) < 2 then
    return '[]'::jsonb;
  end if;
  if length(search_text) > 80 then
    raise exception 'Search is too long';
  end if;

  select * into appointment_record
  from public.appointments
  where id = target_appointment_id;

  if appointment_record.id is null then
    raise exception 'Appointment not found';
  end if;
  if appointment_record.status not in ('scheduled', 'confirmed')
    or exists (
      select 1 from public.sales
      where appointment_id = target_appointment_id
        and business_id = appointment_record.business_id
    )
  then
    raise exception 'Customer association must happen before checkout';
  end if;
  if not (
    public.has_business_role(
      appointment_record.business_id,
      array['owner', 'manager']::public.membership_role[]
    )
    or exists (
      select 1
      from public.professionals professional
      where professional.id = appointment_record.professional_id
        and professional.business_id = appointment_record.business_id
        and professional.user_id = (select auth.uid())
        and professional.active
    )
  ) then
    raise exception 'Not allowed';
  end if;

  search_name := public.normalize_name(search_text);
  search_phone := public.normalize_phone(search_text);

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', candidate.id,
        'business_id', candidate.business_id,
        'name', candidate.name,
        'email', case
          when coalesce(candidate.email, '') = '' then ''
          else left(split_part(candidate.email, '@', 1), 2)
            || '***@'
            || split_part(candidate.email, '@', 2)
        end,
        'phone', case
          when coalesce(candidate.normalized_phone, '') = '' then ''
          else '******' || right(candidate.normalized_phone, 4)
        end,
        'loyalty_tier', candidate.loyalty_tier,
        'manual_tier_override', candidate.manual_tier_override,
        'created_at', candidate.created_at,
        'updated_at', candidate.updated_at
      )
      order by candidate.name, candidate.id
    ),
    '[]'::jsonb
  ) into result
  from (
    select customer.*
    from public.customers customer
    where customer.business_id = appointment_record.business_id
      and customer.deleted_at is null
      and (
        position(search_name in public.normalize_name(customer.name)) > 0
        or position(search_text in lower(coalesce(customer.email, ''))) > 0
        or (
          length(search_phone) >= 2
          and position(search_phone in coalesce(customer.normalized_phone, '')) > 0
        )
      )
    order by customer.name, customer.id
    limit 20
  ) candidate;

  return result;
end;
$$;

-- Remove default PUBLIC execution from every privileged helper. Only the four
-- intentionally limited portal RPCs are exposed to anonymous clients.
revoke execute on function public.slugify_public_booking(text)
  from public, anon, authenticated;
revoke execute on function public.set_business_public_slug()
  from public, anon, authenticated;
revoke execute on function public.validate_public_booking_settings()
  from public, anon, authenticated;
revoke execute on function public.create_default_public_booking_settings()
  from public, anon, authenticated;
revoke execute on function public.lock_professional_booking_agenda(uuid)
  from public, anon, authenticated;
revoke execute on function public.prevent_appointment_overlap()
  from public, anon, authenticated;
revoke execute on function public.find_booking_customer(uuid, text, text, text)
  from public, anon, authenticated;
revoke execute on function public.lock_booking_customer_identity(
  uuid, text, text, text
) from public, anon, authenticated;
revoke execute on function public.record_booking_identity(
  uuid, uuid, public.customer_identity_type, text
) from public, anon, authenticated;
revoke execute on function public.upsert_customer_identity(
  uuid,
  uuid,
  public.customer_identity_type,
  text,
  public.customer_identity_source,
  boolean
) from public, anon, authenticated;
revoke execute on function public.find_or_create_booking_customer(
  uuid, text, text, text
) from public, anon, authenticated;
revoke execute on function public.calculate_customer_loyalty_tier(
  uuid, uuid, timestamptz
) from public, anon, authenticated;
revoke execute on function public.discount_percent_for_tier(
  uuid, public.customer_loyalty_tier
) from public, anon, authenticated;
revoke execute on function public.resolve_booking_price(
  uuid, uuid, text, text, text
) from public, anon, authenticated;
revoke execute on function public.create_public_booking(
  uuid, uuid, uuid, text, text, text, timestamptz, text
) from public, anon, authenticated;
revoke execute on function public.create_business_trial()
  from public, anon, authenticated;
revoke execute on function public.enqueue_appointment_automation_event()
  from public, anon, authenticated;
revoke execute on function public.handle_new_user()
  from public, anon, authenticated;
revoke execute on function public.prevent_last_owner_removal()
  from public, anon, authenticated;
revoke execute on function public.products_match_business_type()
  from public, anon, authenticated;
revoke execute on function public.set_updated_at()
  from public, anon, authenticated;
revoke execute on function public.normalize_email(text)
  from public, anon, authenticated;
revoke execute on function public.normalize_name(text)
  from public, anon, authenticated;
revoke execute on function public.normalize_phone(text)
  from public, anon, authenticated;
revoke execute on function public.link_appointment_to_customer(uuid, uuid)
  from public, anon, authenticated;
revoke execute on function public.complete_appointment_checkout(
  uuid, text, numeric, jsonb, text
) from public, anon, authenticated;
revoke execute on function public.search_linkable_customers(uuid, text)
  from public, anon, authenticated;

revoke execute on function public.get_public_booking_page(text) from public;
revoke execute on function public.get_public_available_slots(
  text, uuid, uuid, date
) from public;
revoke execute on function public.quote_public_booking(
  text, uuid, text, text, text
) from public;
revoke execute on function public.create_public_booking_v2(
  text, uuid, uuid, text, text, text, timestamptz, text
) from public;

grant execute on function public.get_public_booking_page(text)
  to anon, authenticated;
grant execute on function public.get_public_available_slots(
  text, uuid, uuid, date
) to anon, authenticated;
grant execute on function public.quote_public_booking(
  text, uuid, text, text, text
) to anon, authenticated;
grant execute on function public.create_public_booking_v2(
  text, uuid, uuid, text, text, text, timestamptz, text
) to anon, authenticated;
grant execute on function public.link_appointment_to_customer(uuid, uuid)
  to authenticated;
grant execute on function public.search_linkable_customers(uuid, text)
  to authenticated;
grant execute on function public.complete_appointment_checkout(
  uuid, text, numeric, jsonb, text
) to authenticated;

grant select, insert, update on public.public_booking_settings
  to authenticated;
