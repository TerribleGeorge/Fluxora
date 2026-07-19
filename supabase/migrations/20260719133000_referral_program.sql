create or replace function public.generate_referral_code()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  candidate text;
begin
  loop
    candidate := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
    exit when not exists (
      select 1
      from public.businesses
      where referral_code = candidate
    );
  end loop;
  return candidate;
end;
$$;

alter table public.businesses
  add column if not exists referral_code text;

update public.businesses
set referral_code = public.generate_referral_code()
where referral_code is null or trim(referral_code) = '';

alter table public.businesses
  alter column referral_code set not null,
  alter column referral_code set default public.generate_referral_code(),
  add constraint businesses_referral_code_format
    check (referral_code ~ '^[A-Z0-9]{6}$');

create unique index if not exists businesses_referral_code_key
  on public.businesses(referral_code);

create table if not exists public.business_referral_redemptions (
  id uuid primary key default gen_random_uuid(),
  referrer_business_id uuid not null references public.businesses(id) on delete cascade,
  referred_business_id uuid not null references public.businesses(id) on delete cascade,
  code text not null,
  bonus_days integer not null default 30 check (bonus_days > 0),
  created_at timestamptz not null default now(),
  unique (referred_business_id),
  check (referrer_business_id <> referred_business_id)
);

alter table public.business_referral_redemptions enable row level security;

create policy "referral_redemptions_select_members"
on public.business_referral_redemptions for select to authenticated
using (
  public.is_business_member(referrer_business_id)
  or public.is_business_member(referred_business_id)
);

create or replace function public.redeem_referral(
  code text,
  target_business_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_code text := upper(trim(coalesce(code, '')));
  referred_id uuid;
  referrer_id uuid;
  bonus_days integer := 30;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required';
  end if;

  if normalized_code = '' then
    return jsonb_build_object('redeemed', false, 'reason', 'empty_code');
  end if;

  if target_business_id is null then
    select b.id
      into referred_id
    from public.businesses b
    join public.memberships m on m.business_id = b.id
    where m.user_id = (select auth.uid())
      and m.active
      and m.role = 'owner'
    order by b.created_at desc
    limit 1;
  else
    referred_id := target_business_id;
  end if;

  if referred_id is null then
    raise exception 'No business available for referral redemption';
  end if;

  if not public.has_business_role(
    referred_id,
    array['owner']::public.membership_role[]
  ) then
    raise exception 'Only business owners can redeem referrals';
  end if;

  select id
    into referrer_id
  from public.businesses
  where referral_code = normalized_code;

  if referrer_id is null then
    raise exception 'Invalid referral code';
  end if;

  if referrer_id = referred_id then
    raise exception 'A business cannot redeem its own referral code';
  end if;

  insert into public.business_referral_redemptions (
    referrer_business_id,
    referred_business_id,
    code,
    bonus_days
  )
  values (referrer_id, referred_id, normalized_code, bonus_days);

  update public.business_subscriptions
  set trial_ends_at = greatest(trial_ends_at, now()) + make_interval(days => bonus_days)
  where business_id in (referrer_id, referred_id);

  return jsonb_build_object(
    'redeemed',
    true,
    'bonusDays',
    bonus_days,
    'referrerBusinessId',
    referrer_id,
    'referredBusinessId',
    referred_id
  );
exception
  when unique_violation then
    return jsonb_build_object('redeemed', false, 'reason', 'already_redeemed');
end;
$$;

create or replace function public.create_business(
  business_name text,
  business_kind public.business_type,
  business_document text default '',
  business_phone text default '',
  referral_code text default ''
)
returns public.businesses
language plpgsql
security definer
set search_path = ''
as $$
declare
  created_business public.businesses;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required';
  end if;
  if char_length(trim(business_name)) < 2 then
    raise exception 'Invalid business name';
  end if;

  insert into public.businesses (name, type, document, phone, created_by)
  values (
    trim(business_name),
    business_kind,
    coalesce(trim(business_document), ''),
    coalesce(trim(business_phone), ''),
    (select auth.uid())
  )
  returning * into created_business;

  insert into public.memberships (business_id, user_id, role)
  values (created_business.id, (select auth.uid()), 'owner');

  if trim(coalesce(referral_code, '')) <> '' then
    perform public.redeem_referral(referral_code, created_business.id);
  end if;

  return created_business;
end;
$$;
