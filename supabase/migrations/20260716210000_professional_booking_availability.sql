-- Professional-specific services, working hours and public booking idempotency.
-- Public clients receive only narrow DTOs through explicitly granted RPCs.

alter table public.appointments
  add column if not exists public_idempotency_key uuid;

create unique index if not exists appointments_public_idempotency_key_unique_idx
  on public.appointments(public_idempotency_key)
  where public_idempotency_key is not null;

create table if not exists public.professional_services (
  business_id uuid not null references public.businesses(id) on delete cascade,
  professional_id uuid not null references public.professionals(id) on delete cascade,
  service_id uuid not null references public.beauty_services(id) on delete cascade,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (professional_id, service_id)
);

create index if not exists professional_services_business_idx
  on public.professional_services(business_id, active);
create index if not exists professional_services_service_idx
  on public.professional_services(service_id, active);

create table if not exists public.professional_working_hours (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  professional_id uuid not null references public.professionals(id) on delete cascade,
  iso_weekday smallint not null check (iso_weekday between 1 and 7),
  start_time time not null,
  end_time time not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (start_time < end_time),
  unique (professional_id, iso_weekday, start_time, end_time)
);

create index if not exists professional_working_hours_business_idx
  on public.professional_working_hours(business_id, professional_id, iso_weekday)
  where active;

create table if not exists public.availability_blocks (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  professional_id uuid references public.professionals(id) on delete cascade,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  reason text not null default '' check (char_length(reason) <= 250),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

create index if not exists availability_blocks_business_range_idx
  on public.availability_blocks(business_id, starts_at, ends_at);
create index if not exists availability_blocks_professional_range_idx
  on public.availability_blocks(professional_id, starts_at, ends_at)
  where professional_id is not null;

create or replace function public.validate_professional_service_business()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.professionals professional
    where professional.id = new.professional_id
      and professional.business_id = new.business_id
  ) then
    raise exception 'Professional does not belong to this business';
  end if;
  if not exists (
    select 1
    from public.beauty_services service
    where service.id = new.service_id
      and service.business_id = new.business_id
  ) then
    raise exception 'Service does not belong to this business';
  end if;
  return new;
end;
$$;

drop trigger if exists professional_services_validate_business
  on public.professional_services;
create trigger professional_services_validate_business
before insert or update of business_id, professional_id, service_id
on public.professional_services
for each row execute function public.validate_professional_service_business();

create or replace function public.validate_professional_working_hour()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    perform public.lock_professional_booking_agenda(old.professional_id);
    return old;
  end if;

  if not exists (
    select 1
    from public.professionals professional
    where professional.id = new.professional_id
      and professional.business_id = new.business_id
  ) then
    raise exception 'Professional does not belong to this business';
  end if;

  perform public.lock_professional_booking_agenda(new.professional_id);

  if new.active and exists (
    select 1
    from public.professional_working_hours existing_hour
    where existing_hour.professional_id = new.professional_id
      and existing_hour.business_id = new.business_id
      and existing_hour.iso_weekday = new.iso_weekday
      and existing_hour.active
      and existing_hour.id <> new.id
      and existing_hour.start_time < new.end_time
      and existing_hour.end_time > new.start_time
  ) then
    raise exception 'Professional working-hour intervals cannot overlap';
  end if;
  return new;
end;
$$;

drop trigger if exists professional_working_hours_validate
  on public.professional_working_hours;
create trigger professional_working_hours_validate
before insert or update or delete
on public.professional_working_hours
for each row execute function public.validate_professional_working_hour();

create or replace function public.validate_availability_block_business()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  agenda_professional_id uuid;
begin
  if tg_op = 'DELETE' then
    if old.professional_id is not null then
      perform public.lock_professional_booking_agenda(old.professional_id);
    else
      for agenda_professional_id in
        select professional.id
        from public.professionals professional
        where professional.business_id = old.business_id
        order by professional.id
      loop
        perform public.lock_professional_booking_agenda(
          agenda_professional_id
        );
      end loop;
    end if;
    return old;
  end if;

  if new.professional_id is not null and not exists (
    select 1
    from public.professionals professional
    where professional.id = new.professional_id
      and professional.business_id = new.business_id
  ) then
    raise exception 'Professional does not belong to this business';
  end if;

  if tg_op = 'UPDATE' then
    if old.professional_id is null
      or new.professional_id is null
      or old.business_id <> new.business_id
    then
      for agenda_professional_id in
        select professional.id
        from public.professionals professional
        where professional.business_id in (old.business_id, new.business_id)
        order by professional.business_id, professional.id
      loop
        perform public.lock_professional_booking_agenda(
          agenda_professional_id
        );
      end loop;
    else
      for agenda_professional_id in
        select distinct candidate.id
        from unnest(array[old.professional_id, new.professional_id])
          candidate(id)
        order by candidate.id
      loop
        perform public.lock_professional_booking_agenda(
          agenda_professional_id
        );
      end loop;
    end if;
  elsif new.professional_id is not null then
    perform public.lock_professional_booking_agenda(new.professional_id);
  else
    for agenda_professional_id in
      select professional.id
      from public.professionals professional
      where professional.business_id = new.business_id
      order by professional.id
    loop
      perform public.lock_professional_booking_agenda(
        agenda_professional_id
      );
    end loop;
  end if;
  return new;
end;
$$;

drop trigger if exists availability_blocks_validate_business
  on public.availability_blocks;
create trigger availability_blocks_validate_business
before insert or update or delete
on public.availability_blocks
for each row execute function public.validate_availability_block_business();

drop trigger if exists professional_services_set_updated_at
  on public.professional_services;
create trigger professional_services_set_updated_at
before update on public.professional_services
for each row execute function public.set_updated_at();

drop trigger if exists professional_working_hours_set_updated_at
  on public.professional_working_hours;
create trigger professional_working_hours_set_updated_at
before update on public.professional_working_hours
for each row execute function public.set_updated_at();

drop trigger if exists availability_blocks_set_updated_at
  on public.availability_blocks;
create trigger availability_blocks_set_updated_at
before update on public.availability_blocks
for each row execute function public.set_updated_at();

-- Existing professionals inherit only the legacy weekly schedule. Service
-- mappings intentionally remain empty until an owner explicitly assigns them;
-- guessing that every professional performs every service is unsafe.
insert into public.professional_working_hours (
  business_id, professional_id, iso_weekday, start_time, end_time, active
)
select
  professional.business_id,
  professional.id,
  selected_day,
  settings.opening_time,
  settings.closing_time,
  true
from public.professionals professional
join public.public_booking_settings settings
  on settings.business_id = professional.business_id
cross join lateral unnest(settings.working_days) selected_day
where professional.active
  and not exists (
    select 1
    from public.professional_working_hours existing_hour
    where existing_hour.professional_id = professional.id
  )
on conflict (professional_id, iso_weekday, start_time, end_time) do nothing;

create or replace function public.create_default_professional_booking_configuration()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.professional_working_hours (
    business_id, professional_id, iso_weekday, start_time, end_time, active
  )
  select
    new.business_id,
    new.id,
    selected_day,
    settings.opening_time,
    settings.closing_time,
    true
  from public.public_booking_settings settings
  cross join lateral unnest(settings.working_days) selected_day
  where settings.business_id = new.business_id
  on conflict (professional_id, iso_weekday, start_time, end_time) do nothing;

  return new;
end;
$$;

drop trigger if exists professionals_create_booking_configuration
  on public.professionals;
create trigger professionals_create_booking_configuration
after insert on public.professionals
for each row execute function public.create_default_professional_booking_configuration();

alter table public.professional_services enable row level security;
alter table public.professional_working_hours enable row level security;
alter table public.availability_blocks enable row level security;

drop policy if exists "professional_services_owner_manager_only"
  on public.professional_services;
create policy "professional_services_owner_manager_only"
on public.professional_services for all to authenticated
using (public.has_business_role(
  business_id, array['owner', 'manager']::public.membership_role[]
))
with check (public.has_business_role(
  business_id, array['owner', 'manager']::public.membership_role[]
));

drop policy if exists "professional_working_hours_owner_manager_only"
  on public.professional_working_hours;
create policy "professional_working_hours_owner_manager_only"
on public.professional_working_hours for all to authenticated
using (public.has_business_role(
  business_id, array['owner', 'manager']::public.membership_role[]
))
with check (public.has_business_role(
  business_id, array['owner', 'manager']::public.membership_role[]
));

drop policy if exists "availability_blocks_owner_manager_only"
  on public.availability_blocks;
create policy "availability_blocks_owner_manager_only"
on public.availability_blocks for all to authenticated
using (public.has_business_role(
  business_id, array['owner', 'manager']::public.membership_role[]
))
with check (public.has_business_role(
  business_id, array['owner', 'manager']::public.membership_role[]
));

create or replace function public.get_professional_booking_configuration(
  target_professional_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  target_business_id uuid;
  services_json jsonb;
  working_hours_json jsonb;
begin
  select professional.business_id into target_business_id
  from public.professionals professional
  where professional.id = target_professional_id;

  if target_business_id is null then
    raise exception 'Professional not found';
  end if;
  if not public.has_business_role(
    target_business_id,
    array['owner', 'manager']::public.membership_role[]
  ) then
    raise exception 'Owner or manager access required';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', service.id,
        'name', service.name,
        'category', service.category,
        'active', service.active,
        'assigned', coalesce(mapping.active, false)
      ) order by service.name
    ),
    '[]'::jsonb
  ) into services_json
  from public.beauty_services service
  left join public.professional_services mapping
    on mapping.professional_id = target_professional_id
   and mapping.service_id = service.id
   and mapping.business_id = target_business_id
  where service.business_id = target_business_id;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', working_hour.id,
        'iso_weekday', working_hour.iso_weekday,
        'start_time', to_char(working_hour.start_time, 'HH24:MI'),
        'end_time', to_char(working_hour.end_time, 'HH24:MI'),
        'active', working_hour.active
      ) order by
        working_hour.iso_weekday,
        working_hour.start_time,
        working_hour.end_time
    ),
    '[]'::jsonb
  ) into working_hours_json
  from public.professional_working_hours working_hour
  where working_hour.business_id = target_business_id
    and working_hour.professional_id = target_professional_id;

  return jsonb_build_object(
    'professional_id', target_professional_id,
    'business_id', target_business_id,
    'services', services_json,
    'working_hours', working_hours_json
  );
end;
$$;

create or replace function public.save_professional_booking_configuration(
  target_professional_id uuid,
  target_service_ids uuid[],
  target_working_hours jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_business_id uuid;
  selected_service_ids uuid[] := coalesce(
    target_service_ids, array[]::uuid[]
  );
begin
  select professional.business_id into target_business_id
  from public.professionals professional
  where professional.id = target_professional_id
  for update;

  if target_business_id is null then
    raise exception 'Professional not found';
  end if;
  if not public.has_business_role(
    target_business_id,
    array['owner', 'manager']::public.membership_role[]
  ) then
    raise exception 'Owner or manager access required';
  end if;
  perform public.lock_professional_booking_agenda(target_professional_id);
  if target_working_hours is null
    or jsonb_typeof(target_working_hours) <> 'array'
  then
    raise exception 'Working hours must be a JSON array';
  end if;
  if exists (
    select 1 from unnest(selected_service_ids) selected_id
    where selected_id is null
  ) then
    raise exception 'Service identifiers cannot be null';
  end if;
  if (
    select count(distinct selected_id)
    from unnest(selected_service_ids) selected_id
  ) <> (
    select count(*)
    from public.beauty_services service
    where service.business_id = target_business_id
      and service.active
      and service.id = any(selected_service_ids)
  ) then
    raise exception 'Every selected service must be active in this business';
  end if;

  update public.professional_services
  set active = false
  where business_id = target_business_id
    and professional_id = target_professional_id
    and active;

  insert into public.professional_services (
    business_id, professional_id, service_id, active
  )
  select
    target_business_id,
    target_professional_id,
    selected_id,
    true
  from (
    select distinct unnest(selected_service_ids) as selected_id
  ) selected_services
  on conflict (professional_id, service_id) do update
    set business_id = excluded.business_id,
        active = true,
        updated_at = now();

  delete from public.professional_working_hours
  where business_id = target_business_id
    and professional_id = target_professional_id;

  insert into public.professional_working_hours (
    business_id,
    professional_id,
    iso_weekday,
    start_time,
    end_time,
    active
  )
  select distinct
    target_business_id,
    target_professional_id,
    item.iso_weekday,
    item.start_time,
    item.end_time,
    coalesce(item.active, true)
  from jsonb_to_recordset(target_working_hours) as item(
    iso_weekday smallint,
    start_time time,
    end_time time,
    active boolean
  );

  -- Never let an edit silently leave an enabled public portal with no valid
  -- professional + service + working-hour combination. Raising here rolls the
  -- entire configuration change back atomically.
  if exists (
    select 1
    from public.public_booking_settings settings
    where settings.business_id = target_business_id
      and settings.enabled
  ) and not exists (
    select 1
    from public.professionals professional
    join public.professional_services mapping
      on mapping.business_id = professional.business_id
     and mapping.professional_id = professional.id
     and mapping.active
    join public.beauty_services service
      on service.id = mapping.service_id
     and service.business_id = mapping.business_id
     and service.active
    where professional.business_id = target_business_id
      and professional.active
      and exists (
        select 1
        from public.professional_working_hours working_hour
        where working_hour.business_id = professional.business_id
          and working_hour.professional_id = professional.id
          and working_hour.active
      )
  ) then
    raise exception 'An enabled public portal must retain at least one active professional with a service and working hours';
  end if;

  return public.get_professional_booking_configuration(
    target_professional_id
  );
end;
$$;

create or replace function public.save_public_booking_settings(
  target_business_id uuid,
  target_enabled boolean,
  target_public_slug text,
  target_time_zone text,
  target_working_days smallint[],
  target_opening_time time,
  target_closing_time time,
  target_slot_interval_minutes integer,
  target_minimum_notice_minutes integer,
  target_maximum_advance_days integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  saved_slug text;
  saved_settings public.public_booking_settings;
begin
  if not public.has_business_role(
    target_business_id,
    array['owner', 'manager']::public.membership_role[]
  ) then
    raise exception 'Owner or manager access required';
  end if;
  if target_enabled and not exists (
    select 1
    from public.professionals professional
    join public.professional_services mapping
      on mapping.business_id = professional.business_id
     and mapping.professional_id = professional.id
     and mapping.active
    join public.beauty_services service
      on service.id = mapping.service_id
     and service.business_id = mapping.business_id
     and service.active
    where professional.business_id = target_business_id
      and professional.active
      and exists (
        select 1
        from public.professional_working_hours working_hour
        where working_hour.business_id = professional.business_id
          and working_hour.professional_id = professional.id
          and working_hour.active
      )
  ) then
    raise exception 'Configure at least one active professional with a service and working hours before enabling public booking';
  end if;

  update public.businesses
  set public_slug = target_public_slug
  where id = target_business_id
  returning public_slug into saved_slug;
  if saved_slug is null then
    raise exception 'Business not found';
  end if;

  insert into public.public_booking_settings (
    business_id,
    enabled,
    time_zone,
    working_days,
    opening_time,
    closing_time,
    slot_interval_minutes,
    minimum_notice_minutes,
    maximum_advance_days
  ) values (
    target_business_id,
    target_enabled,
    target_time_zone,
    target_working_days,
    target_opening_time,
    target_closing_time,
    target_slot_interval_minutes,
    target_minimum_notice_minutes,
    target_maximum_advance_days
  )
  on conflict (business_id) do update set
    enabled = excluded.enabled,
    time_zone = excluded.time_zone,
    working_days = excluded.working_days,
    opening_time = excluded.opening_time,
    closing_time = excluded.closing_time,
    slot_interval_minutes = excluded.slot_interval_minutes,
    minimum_notice_minutes = excluded.minimum_notice_minutes,
    maximum_advance_days = excluded.maximum_advance_days
  returning * into saved_settings;

  return jsonb_build_object(
    'business_id', saved_settings.business_id,
    'public_slug', saved_slug,
    'enabled', saved_settings.enabled,
    'time_zone', saved_settings.time_zone,
    'working_days', to_jsonb(saved_settings.working_days),
    'opening_time', to_char(saved_settings.opening_time, 'HH24:MI'),
    'closing_time', to_char(saved_settings.closing_time, 'HH24:MI'),
    'slot_interval_minutes', saved_settings.slot_interval_minutes,
    'minimum_notice_minutes', saved_settings.minimum_notice_minutes,
    'maximum_advance_days', saved_settings.maximum_advance_days
  );
end;
$$;

create or replace function public.list_availability_blocks(
  target_business_id uuid,
  target_professional_id uuid default null,
  target_range_start timestamptz default now(),
  target_range_end timestamptz default now() + interval '180 days'
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  blocks_json jsonb;
begin
  if not public.has_business_role(
    target_business_id,
    array['owner', 'manager']::public.membership_role[]
  ) then
    raise exception 'Owner or manager access required';
  end if;
  if target_range_end <= target_range_start then
    raise exception 'Invalid availability-block range';
  end if;
  if target_professional_id is not null and not exists (
    select 1 from public.professionals professional
    where professional.id = target_professional_id
      and professional.business_id = target_business_id
  ) then
    raise exception 'Professional not found';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', block.id,
        'business_id', block.business_id,
        'professional_id', block.professional_id,
        'starts_at', block.starts_at,
        'ends_at', block.ends_at,
        'reason', block.reason
      ) order by block.starts_at, block.ends_at
    ),
    '[]'::jsonb
  ) into blocks_json
  from public.availability_blocks block
  where block.business_id = target_business_id
    and block.starts_at < target_range_end
    and block.ends_at > target_range_start
    and (
      target_professional_id is null
      or block.professional_id is null
      or block.professional_id = target_professional_id
    );

  return blocks_json;
end;
$$;

create or replace function public.create_availability_block(
  target_business_id uuid,
  target_professional_id uuid,
  target_starts_at timestamptz,
  target_ends_at timestamptz,
  target_reason text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  created_block public.availability_blocks;
  agenda_professional_id uuid;
begin
  if not public.has_business_role(
    target_business_id,
    array['owner', 'manager']::public.membership_role[]
  ) then
    raise exception 'Owner or manager access required';
  end if;
  if target_professional_id is not null and not exists (
    select 1
    from public.professionals professional
    where professional.id = target_professional_id
      and professional.business_id = target_business_id
  ) then
    raise exception 'Professional not found';
  end if;

  if target_professional_id is not null then
    perform public.lock_professional_booking_agenda(
      target_professional_id
    );
  else
    -- A business-wide block affects every agenda. Lock them in a stable order
    -- before inserting so a concurrent booking cannot pass slot validation.
    for agenda_professional_id in
      select professional.id
      from public.professionals professional
      where professional.business_id = target_business_id
      order by professional.id
    loop
      perform public.lock_professional_booking_agenda(
        agenda_professional_id
      );
    end loop;
  end if;

  insert into public.availability_blocks (
    business_id,
    professional_id,
    starts_at,
    ends_at,
    reason,
    created_by
  ) values (
    target_business_id,
    target_professional_id,
    target_starts_at,
    target_ends_at,
    trim(coalesce(target_reason, '')),
    (select auth.uid())
  )
  returning * into created_block;

  return jsonb_build_object(
    'id', created_block.id,
    'business_id', created_block.business_id,
    'professional_id', created_block.professional_id,
    'starts_at', created_block.starts_at,
    'ends_at', created_block.ends_at,
    'reason', created_block.reason
  );
end;
$$;

create or replace function public.delete_availability_block(
  target_block_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_business_id uuid;
  target_professional_id uuid;
  agenda_professional_id uuid;
begin
  select block.business_id, block.professional_id
    into target_business_id, target_professional_id
  from public.availability_blocks block
  where block.id = target_block_id;

  if target_business_id is null then
    raise exception 'Availability block not found';
  end if;
  if not public.has_business_role(
    target_business_id,
    array['owner', 'manager']::public.membership_role[]
  ) then
    raise exception 'Owner or manager access required';
  end if;

  if target_professional_id is not null then
    perform public.lock_professional_booking_agenda(
      target_professional_id
    );
  else
    for agenda_professional_id in
      select professional.id
      from public.professionals professional
      where professional.business_id = target_business_id
      order by professional.id
    loop
      perform public.lock_professional_booking_agenda(
        agenda_professional_id
      );
    end loop;
  end if;

  delete from public.availability_blocks
  where id = target_block_id;
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
  catalog_working_days smallint[];
begin
  select business.* into business_record
  from public.businesses business
  join public.public_booking_settings settings
    on settings.business_id = business.id
  where business.public_slug = public.slugify_public_booking(target_slug)
    and settings.enabled;

  if business_record.id is null then
    raise exception 'Public booking disabled or not found';
  end if;

  select * into settings_record
  from public.public_booking_settings
  where business_id = business_record.id;

  select coalesce(
    array_agg(
      distinct working_hour.iso_weekday
      order by working_hour.iso_weekday
    ),
    array[]::smallint[]
  ) into catalog_working_days
  from public.professional_working_hours working_hour
  join public.professionals professional
    on professional.id = working_hour.professional_id
   and professional.business_id = working_hour.business_id
   and professional.active
  where working_hour.business_id = business_record.id
    and working_hour.active
    and exists (
      select 1
      from public.professional_services mapping
      join public.beauty_services service
        on service.id = mapping.service_id
       and service.business_id = mapping.business_id
       and service.active
      where mapping.business_id = working_hour.business_id
        and mapping.professional_id = working_hour.professional_id
        and mapping.active
    );

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
    and service.active
    and exists (
      select 1
      from public.professional_services mapping
      join public.professionals professional
        on professional.id = mapping.professional_id
       and professional.business_id = mapping.business_id
       and professional.active
      where mapping.business_id = service.business_id
        and mapping.service_id = service.id
        and mapping.active
        and exists (
          select 1
          from public.professional_working_hours working_hour
          where working_hour.business_id = mapping.business_id
            and working_hour.professional_id = mapping.professional_id
            and working_hour.active
        )
    );

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', professional.id,
        'name', professional.name,
        'service_ids', (
          select coalesce(
            jsonb_agg(mapping.service_id order by mapping.service_id),
            '[]'::jsonb
          )
          from public.professional_services mapping
          join public.beauty_services service
            on service.id = mapping.service_id
           and service.business_id = mapping.business_id
           and service.active
          where mapping.business_id = professional.business_id
            and mapping.professional_id = professional.id
            and mapping.active
        )
      ) order by professional.name
    ),
    '[]'::jsonb
  ) into professionals_json
  from public.professionals professional
  where professional.business_id = business_record.id
    and professional.active
    and exists (
      select 1
      from public.professional_services mapping
      join public.beauty_services service
        on service.id = mapping.service_id
       and service.business_id = mapping.business_id
       and service.active
      where mapping.business_id = professional.business_id
        and mapping.professional_id = professional.id
        and mapping.active
    )
    and exists (
      select 1
      from public.professional_working_hours working_hour
      where working_hour.business_id = professional.business_id
        and working_hour.professional_id = professional.id
        and working_hour.active
    );

  return jsonb_build_object(
    'business_name', business_record.name,
    'business_type', business_record.type,
    'slug', business_record.public_slug,
    'time_zone', settings_record.time_zone,
    'local_today', to_char(
      now() at time zone settings_record.time_zone,
      'YYYY-MM-DD'
    ),
    'working_days', to_jsonb(catalog_working_days),
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
begin
  select business.id into target_business_id
  from public.businesses business
  join public.public_booking_settings settings
    on settings.business_id = business.id
  where business.public_slug = public.slugify_public_booking(target_slug)
    and settings.enabled;

  if target_business_id is null then
    raise exception 'Public booking disabled or not found';
  end if;

  select * into settings_record
  from public.public_booking_settings
  where business_id = target_business_id;

  select service.duration_minutes into service_duration
  from public.beauty_services service
  join public.professional_services mapping
    on mapping.business_id = service.business_id
   and mapping.service_id = service.id
   and mapping.professional_id = target_professional_id
   and mapping.active
  join public.professionals professional
    on professional.id = mapping.professional_id
   and professional.business_id = mapping.business_id
   and professional.active
  where service.id = target_service_id
    and service.business_id = target_business_id
    and service.active;

  if service_duration is null then
    raise exception 'Professional does not offer this service';
  end if;

  local_today := (now() at time zone settings_record.time_zone)::date;
  if target_day < local_today
    or target_day > local_today + settings_record.maximum_advance_days
  then
    return;
  end if;

  return query
  select
    available.candidate as starts_at,
    available.candidate + make_interval(mins => service_duration) as ends_at,
    to_char(
      available.candidate at time zone settings_record.time_zone,
      'HH24:MI'
    ) as local_time_label
  from (
    select distinct generated.candidate
    from public.professional_working_hours working_hour
    cross join lateral generate_series(
      (target_day + working_hour.start_time)
        at time zone settings_record.time_zone,
      ((target_day + working_hour.end_time)
        at time zone settings_record.time_zone)
        - make_interval(mins => service_duration),
      make_interval(mins => settings_record.slot_interval_minutes)
    ) generated(candidate)
    where working_hour.business_id = target_business_id
      and working_hour.professional_id = target_professional_id
      and working_hour.iso_weekday = extract(isodow from target_day)::smallint
      and working_hour.active
  ) available
  where available.candidate >= now()
    + make_interval(mins => settings_record.minimum_notice_minutes)
    and not exists (
      select 1
      from public.appointments appointment
      where appointment.business_id = target_business_id
        and appointment.professional_id = target_professional_id
        and appointment.status in ('scheduled', 'confirmed')
        and appointment.starts_at
          < available.candidate + make_interval(mins => service_duration)
        and appointment.ends_at > available.candidate
    )
    and not exists (
      select 1
      from public.availability_blocks block
      where block.business_id = target_business_id
        and (
          block.professional_id is null
          or block.professional_id = target_professional_id
        )
        and block.starts_at
          < available.candidate + make_interval(mins => service_duration)
        and block.ends_at > available.candidate
    )
  order by available.candidate;
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

  select business.id into target_business_id
  from public.businesses business
  join public.public_booking_settings settings
    on settings.business_id = business.id
  where business.public_slug = public.slugify_public_booking(target_slug)
    and settings.enabled;
  if target_business_id is null then
    raise exception 'Public booking disabled or not found';
  end if;

  select service.price into service_price
  from public.beauty_services service
  where service.id = target_service_id
    and service.business_id = target_business_id
    and service.active
    and exists (
      select 1
      from public.professional_services mapping
      join public.professionals professional
        on professional.id = mapping.professional_id
       and professional.business_id = mapping.business_id
       and professional.active
      where mapping.business_id = service.business_id
        and mapping.service_id = service.id
        and mapping.active
        and exists (
          select 1
          from public.professional_working_hours working_hour
          where working_hour.business_id = mapping.business_id
            and working_hour.professional_id = mapping.professional_id
            and working_hour.active
        )
    );
  if service_price is null then
    raise exception 'Service not found';
  end if;

  -- Fail closed until an OTP flow proves possession of a trusted identity.
  -- Names, phones and emails submitted on a public form never unlock loyalty.
  return jsonb_build_object(
    'base_price', service_price,
    'final_price', service_price
  );
end;
$$;

create or replace function public.create_public_booking_v3(
  target_slug text,
  target_professional_id uuid,
  target_service_id uuid,
  raw_name text,
  raw_email text,
  raw_phone text,
  target_starts_at timestamptz,
  target_idempotency_key uuid,
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
  existing_appointment public.appointments;
  customer_id uuid;
  tier public.customer_loyalty_tier := 'new';
  discount_percent numeric := 0;
  discount_amount numeric := 0;
  final_price numeric;
  target_ends_at timestamptz;
  appointment_id uuid := gen_random_uuid();
  booking_reference text;
  local_day date;
  clean_name text := public.normalize_name(raw_name);
  clean_email text := public.normalize_email(raw_email);
  clean_phone text := public.normalize_phone(raw_phone);
begin
  if target_idempotency_key is null then
    raise exception 'Idempotency key is required';
  end if;
  if char_length(clean_name) < 2 then
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

  select business.id into target_business_id
  from public.businesses business
  join public.public_booking_settings settings
    on settings.business_id = business.id
  where business.public_slug = public.slugify_public_booking(target_slug)
    and settings.enabled;
  if target_business_id is null then
    raise exception 'Public booking disabled or not found';
  end if;

  select * into settings_record
  from public.public_booking_settings
  where business_id = target_business_id;

  -- Serialize every attempt sharing this key before reading or inserting.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(target_idempotency_key::text, 0)
  );

  select * into existing_appointment
  from public.appointments appointment
  where appointment.public_idempotency_key = target_idempotency_key;

  if existing_appointment.id is not null then
    if existing_appointment.business_id <> target_business_id
      or existing_appointment.professional_id <> target_professional_id
      or existing_appointment.service_id <> target_service_id
      or existing_appointment.starts_at <> target_starts_at
      or public.normalize_name(existing_appointment.customer_name) <> clean_name
      or public.normalize_email(existing_appointment.customer_email) <> clean_email
      or public.normalize_phone(existing_appointment.customer_phone) <> clean_phone
    then
      raise exception 'Idempotency key was already used for another booking';
    end if;

    return jsonb_build_object(
      'reference', existing_appointment.public_reference,
      'starts_at', existing_appointment.starts_at,
      'ends_at', existing_appointment.ends_at,
      'final_price', existing_appointment.service_final_price,
      'local_date_time_label',
        to_char(
          existing_appointment.starts_at
            at time zone settings_record.time_zone,
          'DD/MM/YYYY, HH24:MI'
        )
        || '–'
        || to_char(
          existing_appointment.ends_at at time zone settings_record.time_zone,
          'HH24:MI'
        )
    );
  end if;

  select service.* into service_record
  from public.beauty_services service
  join public.professional_services mapping
    on mapping.business_id = service.business_id
   and mapping.service_id = service.id
   and mapping.professional_id = target_professional_id
   and mapping.active
  join public.professionals professional
    on professional.id = mapping.professional_id
   and professional.business_id = mapping.business_id
   and professional.active
  where service.id = target_service_id
    and service.business_id = target_business_id
    and service.active;
  if service_record.id is null then
    raise exception 'Professional does not offer this service';
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

  -- Serialize the final slot validation and appointment insert per professional.
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
  -- The public portal always charges full price until a future OTP proves
  -- ownership. An owner can still associate/reprice safely before checkout.
  tier := 'new';
  discount_percent := 0;
  discount_amount := 0;
  final_price := service_record.price;
  target_ends_at := target_starts_at
    + make_interval(mins => service_record.duration_minutes);
  booking_reference := 'FX-' || upper(
    substring(replace(appointment_id::text, '-', '') from 1 for 10)
  );

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
    public_reference,
    public_idempotency_key
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
    'confirmed',
    'publicBooking',
    trim(coalesce(target_notes, '')),
    tier,
    service_record.price,
    discount_percent,
    discount_amount,
    final_price,
    now(),
    booking_reference,
    target_idempotency_key
  );

  return jsonb_build_object(
    'reference', booking_reference,
    'starts_at', target_starts_at,
    'ends_at', target_ends_at,
    'final_price', final_price,
    'local_date_time_label',
      to_char(
        target_starts_at at time zone settings_record.time_zone,
        'DD/MM/YYYY, HH24:MI'
      )
      || '–'
      || to_char(
        target_ends_at at time zone settings_record.time_zone,
        'HH24:MI'
      )
  );
end;
$$;

-- New scheduling tables are never exposed to anonymous users. Authenticated
-- direct access is still constrained to owners/managers by RLS.
revoke all on table public.professional_services
  from public, anon, authenticated;
revoke all on table public.professional_working_hours
  from public, anon, authenticated;
revoke all on table public.availability_blocks
  from public, anon, authenticated;

-- Authenticated clients may inspect these rows under RLS, but every mutation
-- must pass through the locking SECURITY DEFINER RPCs below.
grant select on public.professional_services to authenticated;
grant select on public.professional_working_hours to authenticated;
grant select on public.availability_blocks to authenticated;
grant all on public.professional_services to service_role;
grant all on public.professional_working_hours to service_role;
grant all on public.availability_blocks to service_role;

revoke execute on function public.validate_professional_service_business()
  from public, anon, authenticated;
revoke execute on function public.validate_professional_working_hour()
  from public, anon, authenticated;
revoke execute on function public.validate_availability_block_business()
  from public, anon, authenticated;
revoke execute on function public.create_default_professional_booking_configuration()
  from public, anon, authenticated;
revoke execute on function public.lock_professional_booking_agenda(uuid)
  from public, anon, authenticated;
revoke execute on function public.lock_booking_customer_identity(
  uuid, text, text, text
) from public, anon, authenticated;

revoke execute on function public.get_professional_booking_configuration(uuid)
  from public, anon, authenticated;
revoke execute on function public.save_professional_booking_configuration(
  uuid, uuid[], jsonb
) from public, anon, authenticated;
revoke execute on function public.save_public_booking_settings(
  uuid, boolean, text, text, smallint[], time, time,
  integer, integer, integer
) from public, anon, authenticated;
revoke execute on function public.list_availability_blocks(
  uuid, uuid, timestamptz, timestamptz
) from public, anon, authenticated;
revoke execute on function public.create_availability_block(
  uuid, uuid, timestamptz, timestamptz, text
) from public, anon, authenticated;
revoke execute on function public.delete_availability_block(uuid)
  from public, anon, authenticated;

grant execute on function public.get_professional_booking_configuration(uuid)
  to authenticated;
grant execute on function public.save_professional_booking_configuration(
  uuid, uuid[], jsonb
) to authenticated;
grant execute on function public.save_public_booking_settings(
  uuid, boolean, text, text, smallint[], time, time,
  integer, integer, integer
) to authenticated;
grant execute on function public.list_availability_blocks(
  uuid, uuid, timestamptz, timestamptz
) to authenticated;
grant execute on function public.create_availability_block(
  uuid, uuid, timestamptz, timestamptz, text
) to authenticated;
grant execute on function public.delete_availability_block(uuid)
  to authenticated;

-- V2 has no idempotency key and must no longer be reachable from clients.
revoke execute on function public.create_public_booking_v2(
  text, uuid, uuid, text, text, text, timestamptz, text
) from public, anon, authenticated;

revoke execute on function public.get_public_booking_page(text)
  from public, anon, authenticated;
revoke execute on function public.get_public_available_slots(
  text, uuid, uuid, date
) from public, anon, authenticated;
revoke execute on function public.quote_public_booking(
  text, uuid, text, text, text
) from public, anon, authenticated;
revoke execute on function public.create_public_booking_v3(
  text, uuid, uuid, text, text, text, timestamptz, uuid, text
) from public, anon, authenticated;

grant execute on function public.get_public_booking_page(text)
  to anon, authenticated;
grant execute on function public.get_public_available_slots(
  text, uuid, uuid, date
) to anon, authenticated;
grant execute on function public.quote_public_booking(
  text, uuid, text, text, text
) to anon, authenticated;
grant execute on function public.create_public_booking_v3(
  text, uuid, uuid, text, text, text, timestamptz, uuid, text
) to anon, authenticated;
