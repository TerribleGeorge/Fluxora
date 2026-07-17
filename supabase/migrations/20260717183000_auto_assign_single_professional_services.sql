-- Keep the public booking catalog immediately useful for simple businesses.
-- When a business has only one active professional, new active services are
-- automatically assigned to that professional. Existing inactive manual
-- mappings are respected and are not reactivated silently.

create or replace function public.assign_service_to_sole_active_professional()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_professional_id uuid;
begin
  if not new.active then
    return new;
  end if;

  select professional.id
  into target_professional_id
  from public.professionals professional
  where professional.business_id = new.business_id
    and professional.active
  order by professional.created_at, professional.id
  limit 1;

  if target_professional_id is null then
    return new;
  end if;

  if (
    select count(*)
    from public.professionals professional
    where professional.business_id = new.business_id
      and professional.active
  ) <> 1 then
    return new;
  end if;

  insert into public.professional_services (
    business_id,
    professional_id,
    service_id,
    active
  ) values (
    new.business_id,
    target_professional_id,
    new.id,
    true
  )
  on conflict (professional_id, service_id) do nothing;

  return new;
end;
$$;

drop trigger if exists beauty_services_assign_to_sole_professional
  on public.beauty_services;
create trigger beauty_services_assign_to_sole_professional
after insert or update of active
on public.beauty_services
for each row execute function public.assign_service_to_sole_active_professional();

create or replace function public.assign_active_services_to_sole_professional()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not new.active then
    return new;
  end if;

  if (
    select count(*)
    from public.professionals professional
    where professional.business_id = new.business_id
      and professional.active
  ) <> 1 then
    return new;
  end if;

  insert into public.professional_services (
    business_id,
    professional_id,
    service_id,
    active
  )
  select
    new.business_id,
    new.id,
    service.id,
    true
  from public.beauty_services service
  where service.business_id = new.business_id
    and service.active
  on conflict (professional_id, service_id) do nothing;

  return new;
end;
$$;

drop trigger if exists professionals_assign_services_when_sole
  on public.professionals;
create trigger professionals_assign_services_when_sole
after insert or update of active
on public.professionals
for each row execute function public.assign_active_services_to_sole_professional();

insert into public.professional_services (
  business_id,
  professional_id,
  service_id,
  active
)
select
  service.business_id,
  professional.id,
  service.id,
  true
from public.beauty_services service
join public.professionals professional
  on professional.business_id = service.business_id
 and professional.active
where service.active
  and (
    select count(*)
    from public.professionals active_professional
    where active_professional.business_id = service.business_id
      and active_professional.active
  ) = 1
on conflict (professional_id, service_id) do nothing;

revoke execute on function public.assign_service_to_sole_active_professional()
  from public, anon, authenticated;
revoke execute on function public.assign_active_services_to_sole_professional()
  from public, anon, authenticated;
