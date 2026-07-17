create type public.cash_session_status as enum ('open', 'closed');

create table public.commission_payouts (
  id uuid primary key,
  business_id uuid not null references public.businesses(id) on delete cascade,
  professional_id uuid not null references public.professionals(id),
  amount numeric(14, 2) not null check (amount > 0),
  period_start timestamptz not null,
  period_end timestamptz not null check (period_end >= period_start),
  paid_at timestamptz not null,
  method text not null,
  notes text not null default '',
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

create table public.cash_sessions (
  id uuid primary key,
  business_id uuid not null references public.businesses(id) on delete cascade,
  opening_balance numeric(14, 2) not null check (opening_balance >= 0),
  opened_at timestamptz not null,
  opened_by uuid not null references public.profiles(id),
  status public.cash_session_status not null default 'open',
  closed_at timestamptz,
  closed_by uuid references public.profiles(id),
  expected_closing numeric(14, 2),
  counted_closing numeric(14, 2),
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (status = 'open' and closed_at is null)
    or
    (status = 'closed' and closed_at is not null and closed_by is not null
      and expected_closing is not null and counted_closing is not null)
  )
);

create unique index cash_sessions_one_open_idx
on public.cash_sessions(business_id) where status = 'open';
create index commission_payouts_professional_idx
on public.commission_payouts(professional_id, paid_at desc);

create trigger cash_sessions_set_updated_at before update on public.cash_sessions
for each row execute function public.set_updated_at();

alter table public.commission_payouts enable row level security;
alter table public.cash_sessions enable row level security;

create policy "payouts_select_members" on public.commission_payouts
for select to authenticated using (public.is_business_member(business_id));
create policy "payouts_manage_operators" on public.commission_payouts
for all to authenticated
using (public.has_business_role(
  business_id, array['owner', 'manager']::public.membership_role[]
))
with check (created_by = (select auth.uid()) and public.has_business_role(
  business_id, array['owner', 'manager']::public.membership_role[]
));

create policy "cash_select_members" on public.cash_sessions
for select to authenticated using (public.is_business_member(business_id));
create policy "cash_manage_operators" on public.cash_sessions
for all to authenticated
using (public.has_business_role(
  business_id, array['owner', 'manager']::public.membership_role[]
))
with check (public.has_business_role(
  business_id, array['owner', 'manager']::public.membership_role[]
));
