create type public.subscription_plan as enum ('trial', 'essential', 'management', 'pro');
create type public.subscription_status as enum ('trialing', 'active', 'pastDue', 'cancelled');

create table public.business_subscriptions (
  business_id uuid primary key references public.businesses(id) on delete cascade,
  plan public.subscription_plan not null default 'trial',
  status public.subscription_status not null default 'trialing',
  trial_ends_at timestamptz not null default (now() + interval '14 days'),
  current_period_ends_at timestamptz,
  provider text,
  provider_customer_id text,
  provider_subscription_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger subscriptions_set_updated_at
before update on public.business_subscriptions
for each row execute function public.set_updated_at();

create or replace function public.create_business_trial()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.business_subscriptions (business_id) values (new.id);
  return new;
end;
$$;

create trigger on_business_created_trial
after insert on public.businesses
for each row execute function public.create_business_trial();

insert into public.business_subscriptions (business_id)
select id from public.businesses
on conflict (business_id) do nothing;

alter table public.business_subscriptions enable row level security;

create policy "subscriptions_select_members" on public.business_subscriptions
for select to authenticated using (public.is_business_member(business_id));

-- Updates are intentionally not granted to application users. A verified
-- payment webhook or service-role backend will own plan/status transitions.
