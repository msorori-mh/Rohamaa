-- service_partners direct UPDATE is intentionally revoked from authenticated.
-- Make the admin-only status RPC the sole privileged mutation path.

create or replace function public.admin_set_service_partner_status(
  p_partner_id uuid,
  p_status text,
  p_note text default null
)
returns void
language plpgsql
security definer
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

revoke all on function public.admin_set_service_partner_status(uuid,text,text) from public, anon;
grant execute on function public.admin_set_service_partner_status(uuid,text,text) to authenticated;
