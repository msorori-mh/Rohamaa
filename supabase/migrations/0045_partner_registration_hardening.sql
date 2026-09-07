-- Harden partner registration and remove the mutable search_path warning.

create or replace function public.canonical_item_category(p_category text)
returns text
language sql
immutable
parallel safe
set search_path = public
as $$
  select case lower(trim(coalesce(p_category,'')))
    when 'books' then 'education'
    when 'education' then 'education'
    when 'furniture' then 'home_furniture'
    when 'home' then 'home_furniture'
    when 'home_furniture' then 'home_furniture'
    when 'clothes' then 'clothes'
    when 'children' then 'children'
    when 'electronics' then 'electronics'
    when 'tools_trades' then 'tools_trades'
    when 'events' then 'events'
    else 'other'
  end;
$$;

create or replace function public.user_register_service_partner(
  p_display_name text,
  p_partner_kind text,
  p_description text,
  p_contact_phone text,
  p_monthly_case_capacity integer,
  p_service_area_id uuid,
  p_terms_version text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_id uuid;
  v_code text;
begin
  if v_user is null then raise exception 'authentication required'; end if;
  if not public.is_active_user() then raise exception 'active user required'; end if;
  if length(trim(coalesce(p_display_name,''))) < 3 then raise exception 'display name is required'; end if;
  if p_partner_kind not in ('salon','clothing_shop','event_setup','repair_shop','printing_shop','workshop','other') then
    raise exception 'invalid partner kind';
  end if;
  if p_monthly_case_capacity is null or p_monthly_case_capacity < 1 or p_monthly_case_capacity > 100 then
    raise exception 'invalid monthly capacity';
  end if;
  if p_terms_version <> 'v1' then raise exception 'current partner safety terms must be accepted'; end if;
  if p_service_area_id is null then raise exception 'service area is required'; end if;
  if not exists (
    select 1 from public.addresses a
    where a.user_id=v_user and a.service_area_id=p_service_area_id
  ) then
    raise exception 'service area must belong to an operational address for this account';
  end if;

  v_code := 'RHM-MRB-PRT-' || upper(substr(encode(gen_random_bytes(6),'hex'),1,10));

  insert into public.service_partners(
    public_code,owner_user_id,service_area_id,display_name,partner_kind,
    description,contact_phone,monthly_case_capacity,verification_status,
    terms_version,terms_accepted_at
  ) values (
    v_code,v_user,p_service_area_id,trim(p_display_name),p_partner_kind,
    nullif(trim(coalesce(p_description,'')),''),
    nullif(trim(coalesce(p_contact_phone,'')),''),
    p_monthly_case_capacity,'pending','v1',now()
  ) returning id into v_id;

  insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values(v_user,'register_service_partner','service_partner',v_id,jsonb_build_object('terms_version','v1'));

  return v_id;
end;
$$;

revoke all on function public.user_register_service_partner(text,text,text,text,integer,uuid,text) from public, anon;
grant execute on function public.user_register_service_partner(text,text,text,text,integer,uuid,text) to authenticated;

-- Partner creation/status changes are now RPC-driven. Owners can read their rows;
-- staff changes verification through admin_set_service_partner_status().
revoke insert, update on public.service_partners from authenticated;
grant select on public.service_partners to authenticated;

create or replace function public.admin_set_service_partner_status(
  p_partner_id uuid,
  p_status text,
  p_note text default null
)
returns void
language plpgsql
set search_path = public
as $$
declare
  v_terms_at timestamptz;
  v_terms_version text;
begin
  if not public.is_admin() then raise exception 'admin access required'; end if;
  if p_status not in ('verified','rejected','suspended') then raise exception 'invalid partner status'; end if;

  select terms_accepted_at,terms_version into v_terms_at,v_terms_version
  from public.service_partners
  where id=p_partner_id;
  if not found then raise exception 'partner not found'; end if;
  if p_status='verified' and (v_terms_at is null or v_terms_version<>'v1') then
    raise exception 'current partner safety terms must be accepted before verification';
  end if;

  update public.service_partners
  set verification_status=p_status,
      verified_by=case when p_status='verified' then auth.uid() else verified_by end,
      verified_at=case when p_status='verified' then now() else verified_at end,
      admin_note=nullif(trim(coalesce(p_note,'')),''),
      updated_at=now()
  where id=p_partner_id;

  if p_status in ('rejected','suspended') then
    update public.service_offers
    set status='paused',updated_at=now()
    where partner_id=p_partner_id and status in ('submitted','approved');
  end if;

  insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values(auth.uid(),'set_service_partner_status','service_partner',p_partner_id,jsonb_build_object('status',p_status));
end;
$$;
