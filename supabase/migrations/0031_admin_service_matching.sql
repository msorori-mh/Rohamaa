create or replace function public.admin_create_service_match(
  p_request_id uuid,
  p_offer_id uuid,
  p_scheduled_at timestamptz default null,
  p_note text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request public.service_requests%rowtype;
  v_offer public.service_offers%rowtype;
  v_match_id uuid;
begin
  if not public.is_admin() then raise exception 'admin access required'; end if;

  select * into v_request from public.service_requests where id = p_request_id for update;
  select * into v_offer from public.service_offers where id = p_offer_id for update;

  if v_request.id is null then raise exception 'service request not found'; end if;
  if v_offer.id is null then raise exception 'service offer not found'; end if;
  if v_request.user_id = v_offer.user_id then raise exception 'self service matching is not allowed'; end if;
  if v_offer.status <> 'approved' or v_offer.verification_status <> 'verified' then
    raise exception 'service offer is not approved';
  end if;
  if v_request.status not in ('submitted','reviewing') then
    raise exception 'service request is not open';
  end if;
  if v_offer.category <> v_request.category then
    raise exception 'service category mismatch';
  end if;

  insert into public.service_matches(
    service_offer_id,
    service_request_id,
    status,
    scheduled_at,
    approved_by,
    operational_note
  ) values (
    p_offer_id,
    p_request_id,
    case when p_scheduled_at is null then 'proposed' else 'scheduled' end,
    p_scheduled_at,
    auth.uid(),
    nullif(trim(coalesce(p_note, '')), '')
  )
  returning id into v_match_id;

  update public.service_offers
  set status = 'matched', updated_at = now()
  where id = p_offer_id;

  update public.service_requests
  set status = case when p_scheduled_at is null then 'matched' else 'scheduled' end,
      updated_at = now()
  where id = p_request_id;

  return v_match_id;
end;
$$;

revoke all on function public.admin_create_service_match(uuid, uuid, timestamptz, text) from public, anon;
grant execute on function public.admin_create_service_match(uuid, uuid, timestamptz, text) to authenticated;

comment on function public.admin_create_service_match(uuid, uuid, timestamptz, text) is
  'Creates an admin-reviewed service match. It never uses contribution/payment history or reciprocal-help credits.';
