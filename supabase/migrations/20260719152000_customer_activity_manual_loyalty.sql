-- Makes customer loyalty operational inside the owner app: owners/managers can
-- review real booking history and manually fix a customer's loyalty tier.

create or replace function public.list_customer_activity(
  target_business_id uuid,
  raw_query text default ''
)
returns table (
  id uuid,
  business_id uuid,
  name text,
  normalized_name text,
  email text,
  normalized_email text,
  phone text,
  normalized_phone text,
  loyalty_tier public.customer_loyalty_tier,
  manual_tier_override public.customer_loyalty_tier,
  manual_tier_reason text,
  relationship_started_at timestamptz,
  last_completed_at timestamptz,
  completed_visits_count integer,
  scheduled_appointments_count integer,
  next_scheduled_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz,
  deleted_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  clean_query text := lower(trim(coalesce(raw_query, '')));
  phone_query text := regexp_replace(lower(trim(coalesce(raw_query, ''))), '[^0-9]', '', 'g');
begin
  if not public.has_business_role(
    target_business_id,
    array['owner', 'manager']::public.membership_role[]
  ) then
    raise exception 'Not allowed';
  end if;

  return query
  select
    c.id,
    c.business_id,
    c.name,
    c.normalized_name,
    c.email,
    c.normalized_email,
    c.phone,
    c.normalized_phone,
    public.calculate_customer_loyalty_tier(c.business_id, c.id, now())
      as loyalty_tier,
    c.manual_tier_override,
    c.manual_tier_reason,
    c.relationship_started_at,
    case
      when c.last_completed_at is null
        and max(a.starts_at) filter (where a.status = 'completed') is null
      then null
      else greatest(
        coalesce(c.last_completed_at, '-infinity'::timestamptz),
        coalesce(
          max(a.starts_at) filter (where a.status = 'completed'),
          '-infinity'::timestamptz
        )
      )
    end as last_completed_at,
    greatest(
      c.completed_visits_count,
      count(a.id) filter (where a.status = 'completed')::integer
    ) as completed_visits_count,
    count(a.id) filter (
      where a.status in ('scheduled', 'confirmed')
        and a.starts_at >= now()
    )::integer as scheduled_appointments_count,
    min(a.starts_at) filter (
      where a.status in ('scheduled', 'confirmed')
        and a.starts_at >= now()
    ) as next_scheduled_at,
    c.created_at,
    c.updated_at,
    c.deleted_at
  from public.customers c
  left join public.appointments a
    on a.customer_id = c.id
   and a.business_id = c.business_id
  where c.business_id = target_business_id
    and c.deleted_at is null
    and (
      clean_query = ''
      or c.normalized_name like '%' || clean_query || '%'
      or c.normalized_email like '%' || clean_query || '%'
      or (
        phone_query <> ''
        and c.normalized_phone like '%' || phone_query || '%'
      )
    )
  group by c.id
  order by
    max(a.starts_at) filter (where a.status = 'completed') desc nulls last,
    min(a.starts_at) filter (
      where a.status in ('scheduled', 'confirmed')
        and a.starts_at >= now()
    ) asc nulls last,
    c.name asc;
end;
$$;

create or replace function public.update_customer_loyalty_override(
  target_customer_id uuid,
  target_tier public.customer_loyalty_tier default null,
  target_reason text default ''
)
returns public.customers
language plpgsql
security definer
set search_path = ''
as $$
declare
  customer_record public.customers;
  updated_customer public.customers;
begin
  select * into customer_record
  from public.customers
  where id = target_customer_id
    and deleted_at is null
  for update;

  if customer_record.id is null then
    raise exception 'Customer not found';
  end if;

  if not public.has_business_role(
    customer_record.business_id,
    array['owner', 'manager']::public.membership_role[]
  ) then
    raise exception 'Not allowed';
  end if;

  update public.customers
  set
    manual_tier_override = target_tier,
    manual_tier_reason = case
      when target_tier is null then ''
      else left(trim(coalesce(target_reason, '')), 240)
    end,
    loyalty_tier = case
      when target_tier is null then public.calculate_customer_loyalty_tier(
        business_id,
        id,
        now()
      )
      else target_tier
    end,
    updated_at = now()
  where id = target_customer_id
  returning * into updated_customer;

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
    updated_customer.business_id,
    (select auth.uid()),
    'customer.loyalty_override.updated',
    'customer',
    updated_customer.id,
    to_jsonb(customer_record),
    to_jsonb(updated_customer)
  );

  return updated_customer;
end;
$$;

grant execute on function public.list_customer_activity(uuid, text)
  to authenticated;

grant execute on function public.update_customer_loyalty_override(
  uuid,
  public.customer_loyalty_tier,
  text
) to authenticated;
