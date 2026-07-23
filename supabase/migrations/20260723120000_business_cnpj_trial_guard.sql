create or replace function public.normalize_business_document(raw_document text)
returns text
language sql
immutable
set search_path = ''
as $$
  select upper(regexp_replace(coalesce(raw_document, ''), '[^[:alnum:]]', '', 'g'));
$$;

create or replace function public.cnpj_character_value(value text)
returns integer
language plpgsql
immutable
set search_path = ''
as $$
declare
  code integer;
begin
  code := ascii(value);
  if code between 48 and 57 then
    return code - 48;
  end if;
  if code between 65 and 90 then
    return code - 48;
  end if;
  raise exception 'Invalid CNPJ character';
end;
$$;

create or replace function public.calculate_cnpj_digit(
  base text,
  weights integer[]
)
returns integer
language plpgsql
immutable
set search_path = ''
as $$
declare
  index integer;
  total integer := 0;
  remainder integer;
  digit integer;
begin
  for index in 1..array_length(weights, 1) loop
    total := total + public.cnpj_character_value(substr(base, index, 1)) * weights[index];
  end loop;

  remainder := total % 11;
  digit := 11 - remainder;
  if digit >= 10 then
    return 0;
  end if;
  return digit;
end;
$$;

create or replace function public.is_valid_business_document(raw_document text)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  document text;
  first_digit integer;
  second_digit integer;
begin
  document := public.normalize_business_document(raw_document);

  if document !~ '^[A-Z0-9]{12}[0-9]{2}$' then
    return false;
  end if;

  if document ~ '^([0-9])\1{13}$' then
    return false;
  end if;

  first_digit := public.calculate_cnpj_digit(
    substr(document, 1, 12),
    array[5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
  );
  second_digit := public.calculate_cnpj_digit(
    substr(document, 1, 12) || first_digit::text,
    array[6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
  );

  return right(document, 2) = first_digit::text || second_digit::text;
end;
$$;

alter table public.businesses
  add column if not exists document_normalized text not null default '';

update public.businesses
set
  document = public.normalize_business_document(document),
  document_normalized = public.normalize_business_document(document)
where document <> public.normalize_business_document(document)
   or document_normalized <> public.normalize_business_document(document);

alter table public.businesses
  drop constraint if exists businesses_document_normalized_valid;

alter table public.businesses
  add constraint businesses_document_normalized_valid
  check (
    document_normalized = ''
    or public.is_valid_business_document(document_normalized)
  );

create unique index if not exists businesses_document_normalized_unique_idx
  on public.businesses(document_normalized)
  where document_normalized <> '';

create or replace function public.sync_business_document_normalized()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.document := public.normalize_business_document(new.document);
  new.document_normalized := public.normalize_business_document(new.document);
  return new;
end;
$$;

drop trigger if exists businesses_sync_document_normalized on public.businesses;
create trigger businesses_sync_document_normalized
before insert or update of document on public.businesses
for each row execute function public.sync_business_document_normalized();

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
  normalized_document text;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required';
  end if;
  if char_length(trim(business_name)) < 2 then
    raise exception 'Invalid business name';
  end if;

  normalized_document := public.normalize_business_document(business_document);

  if not public.is_valid_business_document(normalized_document) then
    raise exception 'Invalid CNPJ';
  end if;

  if exists (
    select 1
    from public.businesses
    where document_normalized = normalized_document
  ) then
    raise exception 'CNPJ already registered';
  end if;

  insert into public.businesses (
    name,
    type,
    document,
    document_normalized,
    phone,
    created_by
  )
  values (
    trim(business_name),
    business_kind,
    normalized_document,
    normalized_document,
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

revoke all on function public.normalize_business_document(text) from public;
revoke all on function public.cnpj_character_value(text) from public;
revoke all on function public.calculate_cnpj_digit(text, integer[]) from public;
revoke all on function public.is_valid_business_document(text) from public;
revoke all on function public.create_business(
  text,
  public.business_type,
  text,
  text,
  text
) from public;

grant execute on function public.normalize_business_document(text) to authenticated;
grant execute on function public.is_valid_business_document(text) to authenticated;
grant execute on function public.create_business(
  text,
  public.business_type,
  text,
  text,
  text
) to authenticated;
