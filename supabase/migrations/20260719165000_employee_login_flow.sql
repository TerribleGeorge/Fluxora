-- Employee login is explicit in the UI, but still backed by normal Supabase
-- Auth users. The owner configures a professional login; employees enter with
-- the business owner e-mail, their registered login name and their password.

alter table public.professionals
  add column if not exists login_enabled boolean not null default false,
  add column if not exists login_name text not null default '',
  add column if not exists login_email text not null default '';

create unique index if not exists professionals_login_email_unique_idx
  on public.professionals(login_email)
  where login_email <> '';

create index if not exists professionals_employee_login_lookup_idx
  on public.professionals(business_id, lower(trim(login_name)))
  where login_enabled and active;

create or replace function public.resolve_employee_login_email(
  business_owner_email text,
  professional_login_name text
)
returns table (login_email text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  clean_owner_email text := public.normalize_email(business_owner_email);
  clean_login_name text := public.normalize_name(professional_login_name);
begin
  if char_length(clean_owner_email) < 5 or char_length(clean_login_name) < 2 then
    return;
  end if;

  return query
  select p.login_email
  from public.professionals p
  join public.businesses b
    on b.id = p.business_id
  join public.profiles owner_profile
    on owner_profile.id = b.created_by
  where public.normalize_email(owner_profile.email) = clean_owner_email
    and p.login_enabled
    and p.active
    and p.login_email <> ''
    and public.normalize_name(p.login_name) = clean_login_name
  limit 1;
end;
$$;

grant execute on function public.resolve_employee_login_email(text, text)
  to anon, authenticated;
