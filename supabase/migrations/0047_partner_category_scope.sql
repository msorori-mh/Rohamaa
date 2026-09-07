-- Limit verified partner offers to service categories consistent with the verified activity.

create or replace function public.validate_business_service_offer()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_owner uuid;
  v_status text;
  v_kind text;
begin
  if new.provider_kind = 'person' then
    new.partner_id := null;
    return new;
  end if;

  if new.partner_id is null then
    raise exception 'business service offers require a verified Ruhamaa partner';
  end if;

  select owner_user_id, verification_status, partner_kind
    into v_owner, v_status, v_kind
  from public.service_partners
  where id = new.partner_id;

  if v_owner is null then raise exception 'partner not found'; end if;
  if v_owner <> new.user_id then raise exception 'partner must belong to offer owner'; end if;
  if v_status <> 'verified' then raise exception 'partner must be verified before creating a business offer'; end if;

  if v_kind = 'salon' and new.category <> 'beauty_wedding' then
    raise exception 'salon partners may offer wedding/beauty services only';
  elsif v_kind = 'clothing_shop' and new.category <> 'beauty_wedding' then
    raise exception 'clothing shop partners may offer occasion clothing services only';
  elsif v_kind = 'event_setup' and new.category <> 'event_setup' then
    raise exception 'event setup partners may offer event setup services only';
  elsif v_kind = 'repair_shop' and new.category not in ('appliance_repair','device_repair') then
    raise exception 'repair partners may offer appliance/device repair only';
  elsif v_kind = 'printing_shop' and new.category <> 'printing_stationery' then
    raise exception 'printing partners may offer printing/stationery services only';
  elsif v_kind = 'workshop' and new.category not in ('carpentry','tailoring','painting','moving_assembly','appliance_repair','device_repair') then
    raise exception 'workshop service is outside the verified V1 scope';
  end if;

  return new;
end;
$$;

comment on function public.validate_business_service_offer() is
  'Ensures a verified business partner can only submit service offers consistent with its reviewed activity type.';
