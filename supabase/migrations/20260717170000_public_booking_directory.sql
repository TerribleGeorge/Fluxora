-- Public discovery for customer booking.
-- Customers do not need an account; only opted-in businesses appear here.

alter table public.public_booking_settings
  add column if not exists listed_in_directory boolean not null default false,
  add column if not exists postal_code text not null default '',
  add column if not exists address_line text not null default '',
  add column if not exists address_district text not null default '',
  add column if not exists address_city text not null default '',
  add column if not exists address_state text not null default '';

create index if not exists public_booking_settings_directory_idx
  on public.public_booking_settings(address_state, address_city, listed_in_directory)
  where listed_in_directory;

create or replace function public.save_public_booking_settings(
  target_business_id uuid,
  target_enabled boolean,
  target_listed_in_directory boolean,
  target_public_slug text,
  target_postal_code text,
  target_address_line text,
  target_address_district text,
  target_address_city text,
  target_address_state text,
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
  normalized_postal_code text := regexp_replace(coalesce(target_postal_code, ''), '\D', '', 'g');
  normalized_state text := upper(trim(coalesce(target_address_state, '')));
begin
  if not public.has_business_role(
    target_business_id,
    array['owner', 'manager']::public.membership_role[]
  ) then
    raise exception 'Owner or manager access required';
  end if;

  if target_listed_in_directory then
    if not target_enabled then
      raise exception 'Enable public booking before listing this business';
    end if;
    if char_length(normalized_postal_code) < 8 then
      raise exception 'Postal code is required for public listing';
    end if;
    if char_length(trim(coalesce(target_address_city, ''))) < 2
      or char_length(normalized_state) <> 2 then
      raise exception 'City and state are required for public listing';
    end if;
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
    listed_in_directory,
    postal_code,
    address_line,
    address_district,
    address_city,
    address_state,
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
    target_listed_in_directory,
    normalized_postal_code,
    trim(coalesce(target_address_line, '')),
    trim(coalesce(target_address_district, '')),
    trim(coalesce(target_address_city, '')),
    normalized_state,
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
    listed_in_directory = excluded.listed_in_directory,
    postal_code = excluded.postal_code,
    address_line = excluded.address_line,
    address_district = excluded.address_district,
    address_city = excluded.address_city,
    address_state = excluded.address_state,
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
    'listed_in_directory', saved_settings.listed_in_directory,
    'postal_code', saved_settings.postal_code,
    'address_line', saved_settings.address_line,
    'address_district', saved_settings.address_district,
    'address_city', saved_settings.address_city,
    'address_state', saved_settings.address_state,
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

create or replace function public.search_public_booking_businesses(
  raw_query text default '',
  raw_city text default '',
  raw_state text default '',
  raw_postal_code text default ''
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  clean_query text := public.slugify_public_booking(raw_query);
  clean_city text := public.slugify_public_booking(raw_city);
  clean_state text := upper(trim(coalesce(raw_state, '')));
  clean_postal_code text := regexp_replace(coalesce(raw_postal_code, ''), '\D', '', 'g');
  result jsonb;
begin
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'business_name', candidate.name,
        'business_type', candidate.type,
        'slug', candidate.public_slug,
        'postal_code', candidate.postal_code,
        'address_line', candidate.address_line,
        'district', candidate.address_district,
        'city', candidate.address_city,
        'state', candidate.address_state,
        'service_count', candidate.service_count,
        'professional_count', candidate.professional_count
      )
      order by candidate.address_state, candidate.address_city, candidate.name
    ),
    '[]'::jsonb
  ) into result
  from (
    select
      business.name,
      business.type,
      business.public_slug,
      settings.postal_code,
      settings.address_line,
      settings.address_district,
      settings.address_city,
      settings.address_state,
      (
        select count(distinct service.id)
        from public.beauty_services service
        where service.business_id = business.id
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
          )
      ) as service_count,
      (
        select count(distinct professional.id)
        from public.professionals professional
        where professional.business_id = business.id
          and professional.active
          and exists (
            select 1
            from public.professional_services mapping
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
          )
      ) as professional_count
    from public.businesses business
    join public.public_booking_settings settings
      on settings.business_id = business.id
    where settings.enabled
      and settings.listed_in_directory
      and business.public_slug is not null
      and (clean_state = '' or settings.address_state = clean_state)
      and (
        clean_city = ''
        or public.slugify_public_booking(settings.address_city) = clean_city
      )
      and (
        clean_postal_code = ''
        or settings.postal_code like clean_postal_code || '%'
      )
      and (
        clean_query = ''
        or public.slugify_public_booking(business.name) like '%' || clean_query || '%'
        or public.slugify_public_booking(settings.address_district) like '%' || clean_query || '%'
        or public.slugify_public_booking(settings.address_city) like '%' || clean_query || '%'
        or exists (
          select 1
          from public.beauty_services service
          where service.business_id = business.id
            and service.active
            and public.slugify_public_booking(service.name) like '%' || clean_query || '%'
        )
      )
    order by settings.address_state, settings.address_city, business.name
    limit 50
  ) candidate
  where candidate.service_count > 0
    and candidate.professional_count > 0;

  return result;
end;
$$;

revoke execute on function public.save_public_booking_settings(
  uuid, boolean, boolean, text, text, text, text, text, text, text,
  smallint[], time, time, integer, integer, integer
) from public, anon, authenticated;
grant execute on function public.save_public_booking_settings(
  uuid, boolean, boolean, text, text, text, text, text, text, text,
  smallint[], time, time, integer, integer, integer
) to authenticated;

revoke execute on function public.search_public_booking_businesses(
  text, text, text, text
) from public, anon, authenticated;
grant execute on function public.search_public_booking_businesses(
  text, text, text, text
) to anon, authenticated;
