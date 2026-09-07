-- Safety and capacity controls for Ruhamaa Verified Partner Services V1.

alter table public.service_partners
  add column if not exists terms_version text,
  add column if not exists terms_accepted_at timestamptz;

create table if not exists public.service_incidents (
  id uuid primary key default gen_random_uuid(),
  service_match_id uuid not null references public.service_matches(id) on delete cascade,
  reporter_user_id uuid not null references public.profiles(id) on delete cascade,
  incident_type text not null check (incident_type in (
    'unexpected_charge','privacy','photo_marketing','no_show','conduct','quality','other'
  )),
  description text not null,
  status text not null default 'open' check (status in ('open','reviewing','resolved','dismissed')),
  resolved_by uuid references public.profiles(id) on delete set null,
  resolution text,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

alter table public.service_incidents enable row level security;

create policy "service_incidents_reporter_select"
on public.service_incidents for select to authenticated
using (reporter_user_id = (select auth.uid()) or public.is_admin());

create policy "service_incidents_participant_insert"
on public.service_incidents for insert to authenticated
with check (
  reporter_user_id = (select auth.uid())
  and public.is_active_user()
  and exists (
    select 1
    from public.service_matches sm
    join public.service_offers so on so.id = sm.service_offer_id
    join public.service_requests sr on sr.id = sm.service_request_id
    where sm.id = service_match_id
      and (so.user_id = (select auth.uid()) or sr.user_id = (select auth.uid()))
  )
);

create policy "service_incidents_admin_all"
on public.service_incidents for all to authenticated
using (public.is_admin()) with check (public.is_admin());

grant select, insert, update on public.service_incidents to authenticated;

create index if not exists service_incidents_status_created_idx
  on public.service_incidents(status, created_at);
create index if not exists service_incidents_match_idx
  on public.service_incidents(service_match_id, created_at);

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
begin
  if not public.is_admin() then raise exception 'admin access required'; end if;
  if p_status not in ('verified','rejected','suspended') then raise exception 'invalid partner status'; end if;

  select terms_accepted_at into v_terms_at
  from public.service_partners
  where id = p_partner_id;
  if not found then raise exception 'partner not found'; end if;
  if p_status='verified' and v_terms_at is null then
    raise exception 'partner safety terms must be accepted before verification';
  end if;

  update public.service_partners
  set verification_status = p_status,
      verified_by = case when p_status='verified' then auth.uid() else verified_by end,
      verified_at = case when p_status='verified' then now() else verified_at end,
      admin_note = nullif(trim(coalesce(p_note,'')),''),
      updated_at = now()
  where id = p_partner_id;

  if p_status in ('rejected','suspended') then
    update public.service_offers
    set status='paused', updated_at=now()
    where partner_id=p_partner_id and status in ('submitted','approved');
  end if;

  insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values(auth.uid(),'set_service_partner_status','service_partner',p_partner_id,jsonb_build_object('status',p_status));
end;
$$;

create or replace function public.admin_service_match_candidates(p_request_id uuid)
returns table (
  offer_id uuid,
  offer_code text,
  provider_kind text,
  category text,
  service_type text,
  title text,
  available_hours numeric,
  service_area_id uuid,
  score integer
)
language plpgsql
set search_path = public
as $$
declare
  v_request public.service_requests%rowtype;
begin
  if not public.is_admin() then raise exception 'admin access required'; end if;

  select * into v_request from public.service_requests where id = p_request_id;
  if v_request.id is null then raise exception 'service request not found'; end if;

  return query
  select
    o.id,
    o.public_code,
    o.provider_kind,
    o.category,
    o.service_type,
    o.title,
    o.available_hours,
    o.service_area_id,
    (
      case when o.service_type = v_request.service_type then 50 else 20 end
      + case when o.service_area_id is not distinct from v_request.service_area_id then 25 else 0 end
      + case when v_request.estimated_hours is null or o.available_hours >= v_request.estimated_hours then 15 else 0 end
      + least(10, greatest(0, floor(extract(epoch from (now() - o.created_at)) / 86400)::int))
    )::integer as score
  from public.service_offers o
  where o.status = 'approved'
    and o.verification_status = 'verified'
    and o.category = v_request.category
    and o.user_id <> v_request.user_id
    and (
      o.provider_kind = 'person'
      or exists (
        select 1
        from public.service_partners p
        where p.id = o.partner_id
          and p.verification_status = 'verified'
          and p.terms_accepted_at is not null
          and (
            select count(*)
            from public.service_matches sm
            join public.service_offers po on po.id = sm.service_offer_id
            where po.partner_id = p.id
              and sm.status in ('proposed','accepted','scheduled','completed')
              and sm.created_at >= date_trunc('month', now())
              and sm.created_at < date_trunc('month', now()) + interval '1 month'
          ) < p.monthly_case_capacity
      )
    )
  order by score desc, o.created_at asc;
end;
$$;

revoke all on function public.admin_service_match_candidates(uuid) from public, anon;
grant execute on function public.admin_service_match_candidates(uuid) to authenticated;

create or replace function public.admin_resolve_service_incident(
  p_incident_id uuid,
  p_status text,
  p_resolution text
)
returns void
language plpgsql
set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'admin access required'; end if;
  if p_status not in ('resolved','dismissed') then raise exception 'invalid incident resolution status'; end if;
  if length(trim(coalesce(p_resolution,''))) < 3 then raise exception 'resolution is required'; end if;

  update public.service_incidents
  set status=p_status,
      resolution=trim(p_resolution),
      resolved_by=auth.uid(),
      resolved_at=now()
  where id=p_incident_id;
  if not found then raise exception 'incident not found'; end if;

  insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values(auth.uid(),'resolve_service_incident','service_incident',p_incident_id,jsonb_build_object('status',p_status));
end;
$$;

revoke all on function public.admin_resolve_service_incident(uuid,text,text) from public, anon;
grant execute on function public.admin_resolve_service_incident(uuid,text,text) to authenticated;

comment on table public.service_incidents is
  'Private safety/quality incident reports for matched services. No public reviews, ratings, or marketing feed.';
