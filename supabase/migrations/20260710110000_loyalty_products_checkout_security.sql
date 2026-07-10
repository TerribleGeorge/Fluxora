-- Fluxora beauty/wellness business rules:
-- loyalty tiers, anti-fraud customer matching, niche-aware products,
-- appointment checkout, stock movement, and staff-safe RLS.

do $$
begin
  create type public.customer_loyalty_tier as enum (
    'new',
    'standard',
    'gold',
    'premium'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.customer_identity_type as enum (
    'email',
    'phone',
    'namePhone'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.customer_identity_source as enum (
    'booking',
    'manual',
    'import'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.customer_import_status as enum (
    'draft',
    'reviewing',
    'imported',
    'failed'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.product_stock_movement_type as enum (
    'purchase',
    'sale',
    'adjustment',
    'loss'
  );
exception
  when duplicate_object then null;
end $$;

create table if not exists public.business_loyalty_settings (
  business_id uuid primary key references public.businesses(id) on delete cascade,
  enabled boolean not null default false,
  standard_discount_percent numeric(5, 2) not null default 0
    check (standard_discount_percent between 0 and 100),
  gold_discount_percent numeric(5, 2) not null default 0
    check (gold_discount_percent between 0 and 100),
  premium_discount_percent numeric(5, 2) not null default 0
    check (premium_discount_percent between 0 and 100),
  inactive_after_days integer not null default 90
    check (inactive_after_days between 1 and 1095),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null check (char_length(trim(name)) >= 2),
  normalized_name text not null,
  email text not null default '',
  normalized_email text not null default '',
  phone text not null default '',
  normalized_phone text not null default '',
  loyalty_tier public.customer_loyalty_tier not null default 'new',
  manual_tier_override public.customer_loyalty_tier,
  manual_tier_reason text not null default '',
  relationship_started_at timestamptz,
  last_completed_at timestamptz,
  completed_visits_count integer not null default 0 check (completed_visits_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.customer_identities (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  customer_id uuid not null references public.customers(id) on delete cascade,
  identity_type public.customer_identity_type not null,
  identity_value text not null check (char_length(trim(identity_value)) >= 2),
  verified boolean not null default false,
  source public.customer_identity_source not null default 'booking',
  created_at timestamptz not null default now(),
  unique (business_id, identity_type, identity_value)
);

create table if not exists public.customer_import_batches (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  file_name text not null,
  file_type text not null check (file_type in ('csv', 'xlsx', 'txt')),
  status public.customer_import_status not null default 'draft',
  default_tier public.customer_loyalty_tier not null default 'new',
  total_rows integer not null default 0 check (total_rows >= 0),
  processed_rows integer not null default 0 check (processed_rows >= 0),
  failed_rows integer not null default 0 check (failed_rows >= 0),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.customer_import_rows (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.customer_import_batches(id) on delete cascade,
  raw_data jsonb not null default '{}'::jsonb,
  parsed_name text not null default '',
  parsed_email text not null default '',
  parsed_phone text not null default '',
  selected_initial_tier public.customer_loyalty_tier not null default 'new',
  status public.customer_import_status not null default 'draft',
  error_message text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.product_templates (
  id uuid primary key default gen_random_uuid(),
  business_type public.business_type not null,
  name text not null check (char_length(trim(name)) >= 2),
  category text not null default 'Produtos',
  suggested_sale_price numeric(14, 2) not null default 0 check (suggested_sale_price >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (business_type, name)
);

create table if not exists public.products (
  id uuid primary key,
  business_id uuid not null references public.businesses(id) on delete cascade,
  business_type public.business_type not null,
  name text not null check (char_length(trim(name)) >= 2),
  category text not null default 'Produtos',
  sale_price numeric(14, 2) not null check (sale_price >= 0),
  unit_cost numeric(14, 2) not null default 0 check (unit_cost >= 0),
  stock_quantity integer not null default 0 check (stock_quantity >= 0),
  min_stock_quantity integer not null default 0 check (min_stock_quantity >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.product_stock_movements (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  movement_type public.product_stock_movement_type not null,
  quantity integer not null check (quantity <> 0),
  unit_cost numeric(14, 2) not null default 0 check (unit_cost >= 0),
  sale_id uuid references public.sales(id) on delete set null,
  notes text not null default '',
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  actor_id uuid references public.profiles(id),
  action text not null check (char_length(trim(action)) >= 3),
  aggregate_type text not null check (char_length(trim(aggregate_type)) >= 2),
  aggregate_id uuid,
  before_data jsonb not null default '{}'::jsonb,
  after_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.appointments
  add column if not exists customer_id uuid references public.customers(id) on delete set null,
  add column if not exists customer_email text not null default '',
  add column if not exists loyalty_tier_applied public.customer_loyalty_tier not null default 'new',
  add column if not exists service_base_price numeric(14, 2) not null default 0 check (service_base_price >= 0),
  add column if not exists discount_percent_applied numeric(5, 2) not null default 0 check (discount_percent_applied between 0 and 100),
  add column if not exists discount_amount numeric(14, 2) not null default 0 check (discount_amount >= 0),
  add column if not exists service_final_price numeric(14, 2) not null default 0 check (service_final_price >= 0),
  add column if not exists pricing_locked_at timestamptz;

alter table public.sales
  add column if not exists appointment_id uuid references public.appointments(id) on delete set null,
  add column if not exists customer_id uuid references public.customers(id) on delete set null,
  add column if not exists loyalty_tier_applied public.customer_loyalty_tier not null default 'new',
  add column if not exists service_gross_total numeric(14, 2) not null default 0 check (service_gross_total >= 0),
  add column if not exists service_discount_total numeric(14, 2) not null default 0 check (service_discount_total >= 0),
  add column if not exists product_gross_total numeric(14, 2) not null default 0 check (product_gross_total >= 0),
  add column if not exists product_cost_total numeric(14, 2) not null default 0 check (product_cost_total >= 0),
  add column if not exists estimated_profit numeric(14, 2) not null default 0;

create index if not exists customers_business_email_idx
  on public.customers(business_id, normalized_email)
  where deleted_at is null and normalized_email <> '';

create index if not exists customers_business_phone_name_idx
  on public.customers(business_id, normalized_phone, normalized_name)
  where deleted_at is null and normalized_phone <> '';

create index if not exists customer_identities_lookup_idx
  on public.customer_identities(business_id, identity_type, identity_value);

create index if not exists products_business_active_idx
  on public.products(business_id, active, name);

create index if not exists product_stock_movements_product_idx
  on public.product_stock_movements(product_id, created_at desc);

create index if not exists appointments_customer_idx
  on public.appointments(customer_id, starts_at desc);

create trigger business_loyalty_settings_set_updated_at
before update on public.business_loyalty_settings
for each row execute function public.set_updated_at();

create trigger customers_set_updated_at
before update on public.customers
for each row execute function public.set_updated_at();

create trigger customer_import_batches_set_updated_at
before update on public.customer_import_batches
for each row execute function public.set_updated_at();

create trigger products_set_updated_at
before update on public.products
for each row execute function public.set_updated_at();

create or replace function public.normalize_email(value text)
returns text
language sql
immutable
security invoker
set search_path = ''
as $$
  select lower(trim(coalesce(value, '')));
$$;

create or replace function public.normalize_phone(value text)
returns text
language sql
immutable
security invoker
set search_path = ''
as $$
  select regexp_replace(coalesce(value, ''), '[^0-9]+', '', 'g');
$$;

create or replace function public.normalize_name(value text)
returns text
language sql
immutable
security invoker
set search_path = ''
as $$
  select lower(regexp_replace(trim(coalesce(value, '')), '\s+', ' ', 'g'));
$$;

create or replace function public.products_match_business_type()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_type public.business_type;
begin
  select type into current_type
  from public.businesses
  where id = new.business_id;

  if current_type is null then
    raise exception 'Business not found';
  end if;

  if new.business_type <> current_type then
    raise exception 'Product niche does not match business type';
  end if;

  return new;
end;
$$;

drop trigger if exists products_match_business_type_trigger on public.products;
create trigger products_match_business_type_trigger
before insert or update on public.products
for each row execute function public.products_match_business_type();

create or replace function public.calculate_customer_loyalty_tier(
  target_business_id uuid,
  target_customer_id uuid,
  reference_time timestamptz default now()
)
returns public.customer_loyalty_tier
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  settings public.business_loyalty_settings;
  customer public.customers;
  active_since timestamptz;
  active_months numeric;
begin
  select * into customer
  from public.customers
  where id = target_customer_id
    and business_id = target_business_id
    and deleted_at is null;

  if customer.id is null then
    return 'new';
  end if;

  select * into settings
  from public.business_loyalty_settings
  where business_id = target_business_id;

  if settings.business_id is null or not settings.enabled then
    return 'new';
  end if;

  if customer.manual_tier_override is not null then
    return customer.manual_tier_override;
  end if;

  if customer.last_completed_at is null
    or customer.last_completed_at < reference_time - make_interval(days => settings.inactive_after_days)
  then
    return 'new';
  end if;

  active_since := coalesce(customer.relationship_started_at, customer.created_at);
  active_months := extract(epoch from (reference_time - active_since)) / 2592000.0;

  if active_months >= 12 then
    return 'premium';
  elsif active_months >= 6 then
    return 'gold';
  elsif active_months >= 3 then
    return 'standard';
  end if;

  return 'new';
end;
$$;

create or replace function public.discount_percent_for_tier(
  target_business_id uuid,
  target_tier public.customer_loyalty_tier
)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when coalesce(enabled, false) = false then 0
    when target_tier = 'standard' then standard_discount_percent
    when target_tier = 'gold' then gold_discount_percent
    when target_tier = 'premium' then premium_discount_percent
    else 0
  end
  from public.business_loyalty_settings
  where business_id = target_business_id;
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
    normalized,
    target_source,
    target_verified
  )
  on conflict (business_id, identity_type, identity_value)
  do update set
    customer_id = excluded.customer_id,
    source = excluded.source,
    verified = customer_identities.verified or excluded.verified;
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

  select c.id into found_customer_id
  from public.customers c
  where c.business_id = target_business_id
    and c.deleted_at is null
    and c.normalized_email = clean_email
  limit 1;

  if found_customer_id is null then
    select c.id into found_customer_id
    from public.customers c
    where c.business_id = target_business_id
      and c.deleted_at is null
      and c.normalized_phone = clean_phone
      and c.normalized_name = clean_name
    limit 1;
  end if;

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
    )
    values (
      target_business_id,
      trim(raw_name),
      clean_name,
      trim(coalesce(raw_email, '')),
      clean_email,
      trim(coalesce(raw_phone, '')),
      clean_phone,
      now()
    )
    returning id into found_customer_id;
  else
    update public.customers
    set
      name = case when char_length(trim(name)) < 2 then trim(raw_name) else name end,
      email = case when normalized_email = '' then trim(coalesce(raw_email, '')) else email end,
      normalized_email = case when normalized_email = '' then clean_email else normalized_email end,
      phone = case when normalized_phone = '' then trim(coalesce(raw_phone, '')) else phone end,
      normalized_phone = case when normalized_phone = '' then clean_phone else normalized_phone end
    where id = found_customer_id;
  end if;

  perform public.upsert_customer_identity(target_business_id, found_customer_id, 'email', clean_email, 'booking', true);
  perform public.upsert_customer_identity(target_business_id, found_customer_id, 'phone', clean_phone, 'booking', true);
  perform public.upsert_customer_identity(
    target_business_id,
    found_customer_id,
    'namePhone',
    clean_name || '|' || clean_phone,
    'booking',
    true
  );

  return found_customer_id;
end;
$$;

create or replace function public.resolve_booking_price(
  target_business_id uuid,
  target_service_id uuid,
  raw_name text,
  raw_email text,
  raw_phone text
)
returns table (
  customer_id uuid,
  loyalty_tier public.customer_loyalty_tier,
  base_price numeric,
  discount_percent numeric,
  discount_amount numeric,
  final_price numeric
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  resolved_customer_id uuid;
  service_price numeric;
  tier public.customer_loyalty_tier;
  percent numeric;
begin
  select price into service_price
  from public.beauty_services
  where id = target_service_id
    and business_id = target_business_id
    and active;

  if service_price is null then
    raise exception 'Service not found';
  end if;

  resolved_customer_id := public.find_or_create_booking_customer(
    target_business_id,
    raw_name,
    raw_email,
    raw_phone
  );
  tier := public.calculate_customer_loyalty_tier(target_business_id, resolved_customer_id, now());
  percent := coalesce(public.discount_percent_for_tier(target_business_id, tier), 0);

  return query select
    resolved_customer_id,
    tier,
    service_price,
    percent,
    round(service_price * percent / 100, 2),
    service_price - round(service_price * percent / 100, 2);
end;
$$;

create or replace function public.create_public_booking(
  target_business_id uuid,
  target_professional_id uuid,
  target_service_id uuid,
  raw_name text,
  raw_email text,
  raw_phone text,
  target_starts_at timestamptz,
  target_notes text default ''
)
returns public.appointments
language plpgsql
security definer
set search_path = ''
as $$
declare
  service_record public.beauty_services;
  pricing record;
  created_appointment public.appointments;
  target_ends_at timestamptz;
begin
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

  target_ends_at := target_starts_at + make_interval(mins => service_record.duration_minutes);

  if exists (
    select 1 from public.appointments a
    where a.business_id = target_business_id
      and a.professional_id = target_professional_id
      and a.status not in ('cancelled', 'noShow')
      and a.starts_at < target_ends_at
      and a.ends_at > target_starts_at
  ) then
    raise exception 'Time slot unavailable';
  end if;

  select * into pricing
  from public.resolve_booking_price(
    target_business_id,
    target_service_id,
    raw_name,
    raw_email,
    raw_phone
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
    pricing_locked_at
  )
  values (
    gen_random_uuid(),
    target_business_id,
    target_professional_id,
    target_service_id,
    pricing.customer_id,
    trim(raw_name),
    trim(raw_email),
    trim(raw_phone),
    target_starts_at,
    target_ends_at,
    'scheduled',
    'publicBooking',
    coalesce(target_notes, ''),
    pricing.loyalty_tier,
    pricing.base_price,
    pricing.discount_percent,
    pricing.discount_amount,
    pricing.final_price,
    now()
  )
  returning * into created_appointment;

  return created_appointment;
end;
$$;

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
  percent numeric;
  discount numeric;
  final_amount numeric;
  old_data jsonb;
begin
  select * into appointment_record
  from public.appointments
  where id = target_appointment_id;

  if appointment_record.id is null then
    raise exception 'Appointment not found';
  end if;

  if not (
    public.has_business_role(appointment_record.business_id, array['owner', 'manager']::public.membership_role[])
    or exists (
      select 1 from public.professionals p
      where p.id = appointment_record.professional_id
        and p.user_id = (select auth.uid())
        and p.active
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
  where id = appointment_record.service_id;

  old_data := to_jsonb(appointment_record);
  tier := public.calculate_customer_loyalty_tier(appointment_record.business_id, target_customer_id, now());
  percent := coalesce(public.discount_percent_for_tier(appointment_record.business_id, tier), 0);
  discount := round(service_record.price * percent / 100, 2);
  final_amount := service_record.price - discount;

  update public.appointments
  set
    customer_id = target_customer_id,
    loyalty_tier_applied = tier,
    service_base_price = service_record.price,
    discount_percent_applied = percent,
    discount_amount = discount,
    service_final_price = final_amount,
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
    public.normalize_name(appointment_record.customer_name) || '|' || public.normalize_phone(appointment_record.customer_phone),
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
  )
  values (
    appointment_record.business_id,
    (select auth.uid()),
    'appointment.customer_linked',
    'appointment',
    target_appointment_id,
    old_data,
    to_jsonb(appointment_record)
  );

  update public.sales
  set
    customer_id = target_customer_id,
    loyalty_tier_applied = tier,
    service_gross_total = service_record.price,
    service_discount_total = discount,
    gross_total = greatest(gross_total - coalesce(service_discount_total, 0) + discount, 0),
    estimated_profit = greatest(gross_total - fee_amount - service_discount_total - product_cost_total, 0)
  where appointment_id = target_appointment_id
    and business_id = appointment_record.business_id;

  return appointment_record;
end;
$$;

create or replace function public.complete_appointment_checkout(
  target_appointment_id uuid,
  payment_method text,
  payment_fee_percent numeric default 0,
  product_lines jsonb default '[]'::jsonb,
  checkout_notes text default ''
)
returns public.sales
language plpgsql
security definer
set search_path = ''
as $$
declare
  appointment_record public.appointments;
  service_record public.beauty_services;
  professional_record public.professionals;
  product_line jsonb;
  product_record public.products;
  product_quantity integer;
  product_total numeric := 0;
  product_cost numeric := 0;
  service_final numeric;
  service_base numeric;
  service_discount numeric;
  gross_total numeric;
  fee_amount numeric;
  commission_amount numeric := 0;
  sale_items jsonb := '[]'::jsonb;
  created_sale public.sales;
  sale_id uuid := gen_random_uuid();
  tier public.customer_loyalty_tier;
begin
  if payment_method not in ('cash', 'pix', 'debitCard', 'creditCard', 'other') then
    raise exception 'Invalid payment method';
  end if;

  select * into appointment_record
  from public.appointments
  where id = target_appointment_id
    and status in ('scheduled', 'confirmed');

  if appointment_record.id is null then
    raise exception 'Appointment not found or already closed';
  end if;

  select * into professional_record
  from public.professionals
  where id = appointment_record.professional_id;

  if not (
    public.has_business_role(appointment_record.business_id, array['owner', 'manager']::public.membership_role[])
    or professional_record.user_id = (select auth.uid())
  ) then
    raise exception 'Not allowed';
  end if;

  select * into service_record
  from public.beauty_services
  where id = appointment_record.service_id;

  service_base := case
    when appointment_record.service_base_price > 0 then appointment_record.service_base_price
    else service_record.price
  end;
  service_discount := appointment_record.discount_amount;
  service_final := case
    when appointment_record.service_final_price > 0 then appointment_record.service_final_price
    else service_base - service_discount
  end;
  tier := appointment_record.loyalty_tier_applied;

  commission_amount := case service_record.commission_type
    when 'percentage' then service_final * service_record.commission_value / 100
    when 'fixedAmount' then service_record.commission_value
    else service_final * professional_record.default_commission_percent / 100
  end;

  sale_items := sale_items || jsonb_build_array(jsonb_build_object(
    'id', gen_random_uuid(),
    'type', 'service',
    'description', service_record.name,
    'quantity', 1,
    'unitPrice', service_final,
    'serviceId', service_record.id,
    'commissionAmount', round(commission_amount, 2),
    'basePrice', service_base,
    'discountAmount', service_discount,
    'loyaltyTier', tier
  ));

  for product_line in select * from jsonb_array_elements(product_lines)
  loop
    product_quantity := greatest(coalesce((product_line ->> 'quantity')::integer, 0), 0);
    if product_quantity <= 0 then
      continue;
    end if;

    select * into product_record
    from public.products
    where id = (product_line ->> 'productId')::uuid
      and business_id = appointment_record.business_id
      and active
    for update;

    if product_record.id is null then
      raise exception 'Product not found';
    end if;

    if product_record.stock_quantity < product_quantity then
      raise exception 'Insufficient product stock';
    end if;

    update public.products
    set stock_quantity = stock_quantity - product_quantity
    where id = product_record.id;

    product_total := product_total + product_record.sale_price * product_quantity;
    product_cost := product_cost + product_record.unit_cost * product_quantity;

    sale_items := sale_items || jsonb_build_array(jsonb_build_object(
      'id', gen_random_uuid(),
      'type', 'product',
      'description', product_record.name,
      'quantity', product_quantity,
      'unitPrice', product_record.sale_price,
      'productId', product_record.id,
      'commissionAmount', 0,
      'unitCost', product_record.unit_cost
    ));

    insert into public.product_stock_movements (
      business_id,
      product_id,
      movement_type,
      quantity,
      unit_cost,
      sale_id,
      notes,
      created_by
    )
    values (
      appointment_record.business_id,
      product_record.id,
      'sale',
      -product_quantity,
      product_record.unit_cost,
      sale_id,
      'Baixa automática no fechamento do atendimento',
      (select auth.uid())
    );
  end loop;

  gross_total := service_final + product_total;
  fee_amount := round(gross_total * greatest(payment_fee_percent, 0) / 100, 2);

  insert into public.sales (
    id,
    business_id,
    professional_id,
    appointment_id,
    customer_id,
    items,
    payment,
    gross_total,
    fee_amount,
    occurred_at,
    customer_name,
    notes,
    status,
    created_by,
    loyalty_tier_applied,
    service_gross_total,
    service_discount_total,
    product_gross_total,
    product_cost_total,
    estimated_profit
  )
  values (
    sale_id,
    appointment_record.business_id,
    appointment_record.professional_id,
    appointment_record.id,
    appointment_record.customer_id,
    sale_items,
    jsonb_build_object(
      'method', payment_method,
      'amount', gross_total,
      'feePercent', greatest(payment_fee_percent, 0),
      'installments', 1
    ),
    gross_total,
    fee_amount,
    now(),
    appointment_record.customer_name,
    coalesce(checkout_notes, ''),
    'completed',
    (select auth.uid()),
    tier,
    service_base,
    service_discount,
    product_total,
    product_cost,
    gross_total - fee_amount - round(commission_amount, 2) - product_cost
  )
  returning * into created_sale;

  update public.appointments
  set status = 'completed', updated_at = now()
  where id = appointment_record.id;

  if appointment_record.customer_id is not null then
    update public.customers
    set
      last_completed_at = now(),
      relationship_started_at = coalesce(relationship_started_at, now()),
      completed_visits_count = completed_visits_count + 1,
      loyalty_tier = public.calculate_customer_loyalty_tier(
        appointment_record.business_id,
        appointment_record.customer_id,
        now()
      )
    where id = appointment_record.customer_id;
  end if;

  return created_sale;
end;
$$;

create or replace view public.sellable_products
as
select
  p.id,
  p.business_id,
  p.business_type,
  p.name,
  p.category,
  p.sale_price,
  p.stock_quantity,
  p.min_stock_quantity,
  p.active,
  p.updated_at
from public.products p
where p.active
  and public.is_business_member(p.business_id);

alter table public.business_loyalty_settings enable row level security;
alter table public.customers enable row level security;
alter table public.customer_identities enable row level security;
alter table public.customer_import_batches enable row level security;
alter table public.customer_import_rows enable row level security;
alter table public.product_templates enable row level security;
alter table public.products enable row level security;
alter table public.product_stock_movements enable row level security;
alter table public.audit_logs enable row level security;

drop policy if exists "business_loyalty_settings_select_owners_managers" on public.business_loyalty_settings;
create policy "business_loyalty_settings_select_owners_managers"
on public.business_loyalty_settings for select to authenticated
using (public.has_business_role(business_id, array['owner', 'manager']::public.membership_role[]));

drop policy if exists "business_loyalty_settings_manage_owners_managers" on public.business_loyalty_settings;
create policy "business_loyalty_settings_manage_owners_managers"
on public.business_loyalty_settings for all to authenticated
using (public.has_business_role(business_id, array['owner', 'manager']::public.membership_role[]))
with check (public.has_business_role(business_id, array['owner', 'manager']::public.membership_role[]));

drop policy if exists "customers_select_owners_managers" on public.customers;
create policy "customers_select_owners_managers"
on public.customers for select to authenticated
using (public.has_business_role(business_id, array['owner', 'manager']::public.membership_role[]));

drop policy if exists "customers_manage_owners_managers" on public.customers;
create policy "customers_manage_owners_managers"
on public.customers for all to authenticated
using (public.has_business_role(business_id, array['owner', 'manager']::public.membership_role[]))
with check (public.has_business_role(business_id, array['owner', 'manager']::public.membership_role[]));

drop policy if exists "customer_identities_select_owners_managers" on public.customer_identities;
create policy "customer_identities_select_owners_managers"
on public.customer_identities for select to authenticated
using (public.has_business_role(business_id, array['owner', 'manager']::public.membership_role[]));

drop policy if exists "customer_identities_manage_owners_managers" on public.customer_identities;
create policy "customer_identities_manage_owners_managers"
on public.customer_identities for all to authenticated
using (public.has_business_role(business_id, array['owner', 'manager']::public.membership_role[]))
with check (public.has_business_role(business_id, array['owner', 'manager']::public.membership_role[]));

drop policy if exists "customer_import_batches_manage_owners_managers" on public.customer_import_batches;
create policy "customer_import_batches_manage_owners_managers"
on public.customer_import_batches for all to authenticated
using (public.has_business_role(business_id, array['owner', 'manager']::public.membership_role[]))
with check (
  created_by = (select auth.uid())
  and public.has_business_role(business_id, array['owner', 'manager']::public.membership_role[])
);

drop policy if exists "customer_import_rows_manage_owners_managers" on public.customer_import_rows;
create policy "customer_import_rows_manage_owners_managers"
on public.customer_import_rows for all to authenticated
using (
  exists (
    select 1 from public.customer_import_batches b
    where b.id = customer_import_rows.batch_id
      and public.has_business_role(b.business_id, array['owner', 'manager']::public.membership_role[])
  )
)
with check (
  exists (
    select 1 from public.customer_import_batches b
    where b.id = customer_import_rows.batch_id
      and public.has_business_role(b.business_id, array['owner', 'manager']::public.membership_role[])
  )
);

drop policy if exists "product_templates_select_members" on public.product_templates;
create policy "product_templates_select_members"
on public.product_templates for select to authenticated
using (true);

drop policy if exists "products_select_owners_managers" on public.products;
create policy "products_select_owners_managers"
on public.products for select to authenticated
using (public.has_business_role(business_id, array['owner', 'manager']::public.membership_role[]));

drop policy if exists "products_manage_owners_managers" on public.products;
create policy "products_manage_owners_managers"
on public.products for all to authenticated
using (public.has_business_role(business_id, array['owner', 'manager']::public.membership_role[]))
with check (public.has_business_role(business_id, array['owner', 'manager']::public.membership_role[]));

drop policy if exists "product_stock_movements_select_owners_managers" on public.product_stock_movements;
create policy "product_stock_movements_select_owners_managers"
on public.product_stock_movements for select to authenticated
using (public.has_business_role(business_id, array['owner', 'manager']::public.membership_role[]));

drop policy if exists "audit_logs_select_owners" on public.audit_logs;
create policy "audit_logs_select_owners"
on public.audit_logs for select to authenticated
using (public.has_business_role(business_id, array['owner']::public.membership_role[]));

drop policy if exists "transactions_select_members" on public.finance_transactions;
create policy "transactions_select_owners_managers"
on public.finance_transactions for select to authenticated
using (public.has_business_role(business_id, array['owner', 'manager']::public.membership_role[]));

drop policy if exists "sales_select_members" on public.sales;
create policy "sales_select_owners_managers"
on public.sales for select to authenticated
using (public.has_business_role(business_id, array['owner', 'manager']::public.membership_role[]));

drop policy if exists "sales_select_professional_own" on public.sales;
create policy "sales_select_professional_own"
on public.sales for select to authenticated
using (
  exists (
    select 1 from public.professionals p
    where p.id = sales.professional_id
      and p.business_id = sales.business_id
      and p.user_id = (select auth.uid())
      and p.active
  )
);

drop policy if exists "sales_insert_operators" on public.sales;
create policy "sales_insert_owners_managers_or_assigned_professional"
on public.sales for insert to authenticated
with check (
  created_by = (select auth.uid())
  and (
    public.has_business_role(business_id, array['owner', 'manager']::public.membership_role[])
    or exists (
      select 1 from public.professionals p
      where p.id = professional_id
        and p.business_id = business_id
        and p.user_id = (select auth.uid())
        and p.active
    )
  )
);

drop policy if exists "sales_update_operators" on public.sales;
create policy "sales_update_owners_managers_or_assigned_professional"
on public.sales for update to authenticated
using (
  public.has_business_role(business_id, array['owner', 'manager']::public.membership_role[])
  or exists (
    select 1 from public.professionals p
    where p.id = sales.professional_id
      and p.business_id = sales.business_id
      and p.user_id = (select auth.uid())
      and p.active
  )
)
with check (
  public.has_business_role(business_id, array['owner', 'manager']::public.membership_role[])
  or exists (
    select 1 from public.professionals p
    where p.id = sales.professional_id
      and p.business_id = sales.business_id
      and p.user_id = (select auth.uid())
      and p.active
  )
);

insert into public.product_templates (business_type, name, category, suggested_sale_price)
values
  ('barbershop', 'Pomada modeladora', 'Finalizadores', 39.90),
  ('barbershop', 'Óleo para barba', 'Barba', 44.90),
  ('barbershop', 'Balm pós-barba', 'Barba', 34.90),
  ('barbershop', 'Shampoo masculino', 'Cabelo', 29.90),
  ('barbershop', 'Gel fixador', 'Finalizadores', 24.90),
  ('beautySalon', 'Shampoo profissional', 'Cabelo', 49.90),
  ('beautySalon', 'Máscara capilar', 'Tratamento capilar', 59.90),
  ('beautySalon', 'Leave-in', 'Finalizadores', 39.90),
  ('beautySalon', 'Óleo reparador', 'Finalizadores', 44.90),
  ('nailStudio', 'Esmalte', 'Unhas', 12.90),
  ('nailStudio', 'Base fortalecedora', 'Unhas', 18.90),
  ('nailStudio', 'Lixa de unha', 'Acessórios', 4.90),
  ('nailStudio', 'Óleo secante', 'Unhas', 14.90),
  ('nailStudio', 'Creme para mãos', 'Hidratação', 24.90),
  ('browAndLashStudio', 'Sérum para cílios', 'Cílios', 59.90),
  ('browAndLashStudio', 'Escovinha descartável', 'Acessórios', 3.90),
  ('browAndLashStudio', 'Henna para sobrancelhas', 'Sobrancelhas', 34.90),
  ('makeupStudio', 'Batom', 'Maquiagem', 29.90),
  ('makeupStudio', 'Base facial', 'Maquiagem', 69.90),
  ('makeupStudio', 'Fixador de maquiagem', 'Maquiagem', 49.90),
  ('spa', 'Óleo corporal', 'Relaxamento', 49.90),
  ('spa', 'Sais de banho', 'Relaxamento', 34.90),
  ('spa', 'Creme hidratante corporal', 'Hidratação', 39.90),
  ('aestheticClinic', 'Protetor solar cosmético', 'Cuidados faciais', 69.90),
  ('aestheticClinic', 'Sérum cosmético', 'Cuidados faciais', 89.90),
  ('aestheticClinic', 'Máscara facial cosmética', 'Cuidados faciais', 39.90),
  ('otherBeauty', 'Produto de revenda', 'Produtos', 29.90)
on conflict (business_type, name) do update set
  category = excluded.category,
  suggested_sale_price = excluded.suggested_sale_price,
  active = true;

grant select on public.sellable_products to authenticated;
grant execute on function public.normalize_email(text) to anon, authenticated;
grant execute on function public.normalize_phone(text) to anon, authenticated;
grant execute on function public.normalize_name(text) to anon, authenticated;
grant execute on function public.resolve_booking_price(uuid, uuid, text, text, text) to anon, authenticated;
grant execute on function public.create_public_booking(uuid, uuid, uuid, text, text, text, timestamptz, text) to anon, authenticated;
grant execute on function public.link_appointment_to_customer(uuid, uuid) to authenticated;
grant execute on function public.complete_appointment_checkout(uuid, text, numeric, jsonb, text) to authenticated;
