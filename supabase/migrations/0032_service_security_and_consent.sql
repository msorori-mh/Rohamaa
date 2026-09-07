drop policy if exists "users_insert_own_service_offers" on public.service_offers;
create policy "users_insert_own_service_offers"
on public.service_offers for insert to authenticated
with check (
  user_id = (select auth.uid())
  and public.is_active_user()
  and status = 'submitted'
  and verification_status = 'pending'
  and pricing_mode in ('free','materials_only')
);

drop policy if exists "users_insert_own_service_requests" on public.service_requests;
create policy "users_insert_own_service_requests"
on public.service_requests for insert to authenticated
with check (
  user_id = (select auth.uid())
  and public.is_active_user()
  and status = 'submitted'
);

alter function public.admin_service_match_candidates(uuid) security invoker;
alter function public.admin_create_service_match(uuid, uuid, timestamptz, text) security invoker;

alter table public.service_matches
  add column if not exists provider_response text not null default 'pending'
    check (provider_response in ('pending','accepted','declined')),
  add column if not exists requester_response text not null default 'pending'
    check (requester_response in ('pending','accepted','declined')),
  add column if not exists provider_responded_at timestamptz,
  add column if not exists requester_responded_at timestamptz;

create or replace function public.user_pending_service_matches()
returns table (
  match_id uuid,
  my_side text,
  service_title text,
  service_type text,
  category text,
  status text,
  my_response text,
  other_response text,
  scheduled_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    m.id as match_id,
    case when o.user_id = auth.uid() then 'provider' else 'requester' end as my_side,
    case when o.user_id = auth.uid() then r.title else o.title end as service_title,
    r.service_type,
    r.category,
    m.status,
    case when o.user_id = auth.uid() then m.provider_response else m.requester_response end as my_response,
    case when o.user_id = auth.uid() then m.requester_response else m.provider_response end as other_response,
    m.scheduled_at
  from public.service_matches m
  join public.service_offers o on o.id = m.service_offer_id
  join public.service_requests r on r.id = m.service_request_id
  where (o.user_id = auth.uid() or r.user_id = auth.uid())
    and m.status in ('proposed','accepted','scheduled')
  order by m.created_at desc;
$$;

create or replace function public.user_respond_service_match(
  p_match_id uuid,
  p_accept boolean
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_match public.service_matches%rowtype;
  v_offer_user uuid;
  v_request_user uuid;
  v_new_status text;
begin
  if v_user is null then raise exception 'authentication required'; end if;
  if not public.is_active_user() then raise exception 'account is not active'; end if;

  select m.* into v_match
  from public.service_matches m
  where m.id = p_match_id
  for update;

  if v_match.id is null then raise exception 'service match not found'; end if;
  if v_match.status not in ('proposed','accepted') then raise exception 'service match is not awaiting response'; end if;

  select user_id into v_offer_user from public.service_offers where id = v_match.service_offer_id;
  select user_id into v_request_user from public.service_requests where id = v_match.service_request_id;

  if v_user = v_offer_user then
    update public.service_matches
    set provider_response = case when p_accept then 'accepted' else 'declined' end,
        provider_responded_at = now(),
        updated_at = now()
    where id = p_match_id;
  elsif v_user = v_request_user then
    update public.service_matches
    set requester_response = case when p_accept then 'accepted' else 'declined' end,
        requester_responded_at = now(),
        updated_at = now()
    where id = p_match_id;
  else
    raise exception 'not a participant in this service match';
  end if;

  select * into v_match from public.service_matches where id = p_match_id;

  if v_match.provider_response = 'declined' or v_match.requester_response = 'declined' then
    v_new_status := 'declined';
    update public.service_matches set status = 'declined', updated_at = now() where id = p_match_id;
    update public.service_offers set status = 'approved', updated_at = now() where id = v_match.service_offer_id;
    update public.service_requests set status = 'reviewing', updated_at = now() where id = v_match.service_request_id;
  elsif v_match.provider_response = 'accepted' and v_match.requester_response = 'accepted' then
    v_new_status := 'accepted';
    update public.service_matches set status = 'accepted', updated_at = now() where id = p_match_id;
  else
    v_new_status := 'proposed';
  end if;

  return v_new_status;
end;
$$;

revoke all on function public.user_pending_service_matches() from public, anon;
grant execute on function public.user_pending_service_matches() to authenticated;
revoke all on function public.user_respond_service_match(uuid, boolean) from public, anon;
grant execute on function public.user_respond_service_match(uuid, boolean) to authenticated;

comment on function public.user_respond_service_match(uuid, boolean) is
  'Records provider/requester consent. A service match is accepted only when both sides accept; no reciprocal-help credits are used.';
