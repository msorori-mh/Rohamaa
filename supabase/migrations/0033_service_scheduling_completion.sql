create or replace function public.admin_schedule_service_match(
  p_match_id uuid,
  p_scheduled_at timestamptz,
  p_note text default null
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_match public.service_matches%rowtype;
begin
  if not public.is_admin() then raise exception 'admin access required'; end if;
  if p_scheduled_at is null then raise exception 'scheduled time is required'; end if;

  select * into v_match
  from public.service_matches
  where id = p_match_id
  for update;

  if v_match.id is null then raise exception 'service match not found'; end if;
  if v_match.provider_response <> 'accepted' or v_match.requester_response <> 'accepted' then
    raise exception 'both participants must accept before scheduling';
  end if;
  if v_match.status not in ('accepted','scheduled') then
    raise exception 'service match is not ready for scheduling';
  end if;

  update public.service_matches
  set status = 'scheduled',
      scheduled_at = p_scheduled_at,
      operational_note = coalesce(nullif(trim(coalesce(p_note, '')), ''), operational_note),
      updated_at = now()
  where id = p_match_id;

  update public.service_requests
  set status = 'scheduled', updated_at = now()
  where id = v_match.service_request_id;
end;
$$;

create or replace function public.admin_complete_service_match(p_match_id uuid)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_match public.service_matches%rowtype;
begin
  if not public.is_admin() then raise exception 'admin access required'; end if;

  select * into v_match
  from public.service_matches
  where id = p_match_id
  for update;

  if v_match.id is null then raise exception 'service match not found'; end if;
  if v_match.status not in ('accepted','scheduled') then
    raise exception 'service match is not active';
  end if;

  update public.service_matches
  set status = 'completed', updated_at = now()
  where id = p_match_id;

  update public.service_offers
  set status = 'completed', updated_at = now()
  where id = v_match.service_offer_id;

  update public.service_requests
  set status = 'completed', updated_at = now()
  where id = v_match.service_request_id;
end;
$$;

revoke all on function public.admin_schedule_service_match(uuid, timestamptz, text) from public, anon;
grant execute on function public.admin_schedule_service_match(uuid, timestamptz, text) to authenticated;
revoke all on function public.admin_complete_service_match(uuid) from public, anon;
grant execute on function public.admin_complete_service_match(uuid) to authenticated;

comment on function public.admin_schedule_service_match(uuid, timestamptz, text) is
  'Schedules a service only after both provider and requester have accepted.';
comment on function public.admin_complete_service_match(uuid) is
  'Marks an accepted/scheduled donated-time service as completed.';
