create type public.service_commission_type as enum (
  'businessDefault',
  'percentage',
  'fixedAmount'
);

create table public.professionals (
  id uuid primary key,
  business_id uuid not null references public.businesses(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete set null,
  name text not null check (char_length(trim(name)) >= 2),
  phone text not null default '',
  email text not null default '',
  default_commission_percent numeric(5, 2) not null default 0
    check (default_commission_percent between 0 and 100),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, user_id)
);

create table public.beauty_services (
  id uuid primary key,
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null check (char_length(trim(name)) >= 2),
  category text not null default 'Serviços',
  price numeric(14, 2) not null check (price > 0),
  duration_minutes integer not null check (duration_minutes between 5 and 1440),
  commission_type public.service_commission_type not null default 'businessDefault',
  commission_value numeric(14, 2) not null default 0 check (commission_value >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index professionals_business_idx on public.professionals(business_id);
create index beauty_services_business_idx on public.beauty_services(business_id);

create trigger professionals_set_updated_at before update on public.professionals
for each row execute function public.set_updated_at();

create trigger beauty_services_set_updated_at before update on public.beauty_services
for each row execute function public.set_updated_at();

alter table public.professionals enable row level security;
alter table public.beauty_services enable row level security;

create policy "professionals_select_members" on public.professionals
for select to authenticated using (public.is_business_member(business_id));

create policy "professionals_manage_operators" on public.professionals
for all to authenticated
using (public.has_business_role(
  business_id, array['owner', 'manager']::public.membership_role[]
))
with check (public.has_business_role(
  business_id, array['owner', 'manager']::public.membership_role[]
));

create policy "services_select_members" on public.beauty_services
for select to authenticated using (public.is_business_member(business_id));

create policy "services_manage_operators" on public.beauty_services
for all to authenticated
using (public.has_business_role(
  business_id, array['owner', 'manager']::public.membership_role[]
))
with check (public.has_business_role(
  business_id, array['owner', 'manager']::public.membership_role[]
));
