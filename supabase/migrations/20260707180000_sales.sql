create type public.sale_status as enum ('completed', 'cancelled');

create table public.sales (
  id uuid primary key,
  business_id uuid not null references public.businesses(id) on delete cascade,
  professional_id uuid not null references public.professionals(id),
  items jsonb not null check (jsonb_array_length(items) > 0),
  payment jsonb not null,
  gross_total numeric(14, 2) not null check (gross_total > 0),
  fee_amount numeric(14, 2) not null default 0 check (fee_amount >= 0),
  occurred_at timestamptz not null,
  customer_name text not null default '',
  notes text not null default '',
  status public.sale_status not null default 'completed',
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index sales_business_date_idx on public.sales(business_id, occurred_at desc);
create index sales_professional_idx on public.sales(professional_id, occurred_at desc);

create trigger sales_set_updated_at before update on public.sales
for each row execute function public.set_updated_at();

alter table public.sales enable row level security;

create policy "sales_select_members" on public.sales
for select to authenticated using (public.is_business_member(business_id));

create policy "sales_insert_operators" on public.sales
for insert to authenticated with check (
  created_by = (select auth.uid())
  and public.has_business_role(
    business_id, array['owner', 'manager']::public.membership_role[]
  )
);

create policy "sales_update_operators" on public.sales
for update to authenticated
using (public.has_business_role(
  business_id, array['owner', 'manager']::public.membership_role[]
))
with check (public.has_business_role(
  business_id, array['owner', 'manager']::public.membership_role[]
));
