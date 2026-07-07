create extension if not exists pgcrypto;

create type public.business_type as enum (
  'barbershop',
  'beautySalon',
  'nailStudio',
  'browAndLashStudio',
  'makeupStudio',
  'spa',
  'aestheticClinic',
  'otherBeauty'
);

create type public.membership_role as enum ('owner', 'manager', 'professional');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null check (char_length(trim(name)) >= 2),
  email text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.businesses (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) >= 2),
  type public.business_type not null,
  document text not null default '',
  phone text not null default '',
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.memberships (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.membership_role not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, user_id)
);

create type public.transaction_type as enum ('income', 'expense');

create table public.finance_transactions (
  id uuid primary key,
  business_id uuid not null references public.businesses(id) on delete cascade,
  description text not null check (char_length(trim(description)) >= 2),
  amount numeric(14, 2) not null check (amount > 0),
  category text not null default 'Outros',
  occurred_at timestamptz not null,
  type public.transaction_type not null,
  notes text not null default '',
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index memberships_user_id_idx on public.memberships(user_id);
create index memberships_business_id_idx on public.memberships(business_id);
create index finance_transactions_business_date_idx
  on public.finance_transactions(business_id, occurred_at desc);
create index finance_transactions_updated_idx
  on public.finance_transactions(business_id, updated_at);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger businesses_set_updated_at
before update on public.businesses
for each row execute function public.set_updated_at();

create trigger memberships_set_updated_at
before update on public.memberships
for each row execute function public.set_updated_at();

create trigger finance_transactions_set_updated_at
before update on public.finance_transactions
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, name, email)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'name'), ''), 'Novo usuário'),
    coalesce(new.email, '')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.is_business_member(target_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.memberships
    where business_id = target_business_id
      and user_id = (select auth.uid())
      and active
  );
$$;

create or replace function public.has_business_role(
  target_business_id uuid,
  allowed_roles public.membership_role[]
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.memberships
    where business_id = target_business_id
      and user_id = (select auth.uid())
      and active
      and role = any(allowed_roles)
  );
$$;

create or replace function public.shares_business_with(target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.memberships mine
    join public.memberships theirs
      on theirs.business_id = mine.business_id
    where mine.user_id = (select auth.uid())
      and mine.active
      and theirs.active
      and theirs.user_id = target_user_id
  );
$$;

create or replace function public.prevent_last_owner_removal()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.role = 'owner'
    and old.active
    and (new.role <> 'owner' or not new.active)
    and not exists (
      select 1 from public.memberships
      where business_id = old.business_id
        and id <> old.id
        and role = 'owner'
        and active
    )
  then
    raise exception 'A business must retain an active owner';
  end if;
  return new;
end;
$$;

create trigger memberships_keep_owner
before update on public.memberships
for each row execute function public.prevent_last_owner_removal();

create or replace function public.create_business(
  business_name text,
  business_kind public.business_type,
  business_document text default '',
  business_phone text default ''
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

  return created_business;
end;
$$;

alter table public.profiles enable row level security;
alter table public.businesses enable row level security;
alter table public.memberships enable row level security;
alter table public.finance_transactions enable row level security;

create policy "profiles_select_self_or_shared_business"
on public.profiles for select to authenticated
using (
  id = (select auth.uid())
  or public.shares_business_with(id)
);

create policy "profiles_update_self"
on public.profiles for update to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

create policy "businesses_select_members"
on public.businesses for select to authenticated
using (public.is_business_member(id));

create policy "businesses_update_owners"
on public.businesses for update to authenticated
using (public.has_business_role(id, array['owner']::public.membership_role[]))
with check (public.has_business_role(id, array['owner']::public.membership_role[]));

create policy "memberships_select_same_business"
on public.memberships for select to authenticated
using (public.is_business_member(business_id));

create policy "memberships_insert_owners"
on public.memberships for insert to authenticated
with check (
  public.has_business_role(
    business_id,
    array['owner']::public.membership_role[]
  )
);

create policy "memberships_update_owners"
on public.memberships for update to authenticated
using (
  public.has_business_role(
    business_id,
    array['owner']::public.membership_role[]
  )
)
with check (
  public.has_business_role(
    business_id,
    array['owner']::public.membership_role[]
  )
);

create policy "transactions_select_members"
on public.finance_transactions for select to authenticated
using (public.is_business_member(business_id));

create policy "transactions_insert_operators"
on public.finance_transactions for insert to authenticated
with check (
  created_by = (select auth.uid())
  and public.has_business_role(
    business_id,
    array['owner', 'manager']::public.membership_role[]
  )
);

create policy "transactions_update_operators"
on public.finance_transactions for update to authenticated
using (
  public.has_business_role(
    business_id,
    array['owner', 'manager']::public.membership_role[]
  )
)
with check (
  public.has_business_role(
    business_id,
    array['owner', 'manager']::public.membership_role[]
  )
);

revoke all on function public.create_business(text, public.business_type, text, text)
from public;
grant execute on function public.create_business(text, public.business_type, text, text)
to authenticated;

revoke all on function public.is_business_member(uuid) from public;
revoke all on function public.has_business_role(uuid, public.membership_role[]) from public;
revoke all on function public.shares_business_with(uuid) from public;
grant execute on function public.is_business_member(uuid) to authenticated;
grant execute on function public.has_business_role(uuid, public.membership_role[]) to authenticated;
grant execute on function public.shares_business_with(uuid) to authenticated;
