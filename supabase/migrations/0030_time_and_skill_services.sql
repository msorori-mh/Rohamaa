create table if not exists public.service_offers (
  id uuid primary key default gen_random_uuid(),
  public_code text not null unique,
  user_id uuid not null references public.profiles(id) on delete cascade,
  service_area_id uuid references public.service_areas(id) on delete set null,
  provider_kind text not null default 'person' check (provider_kind in ('person','business')),
  category text not null check (category in (
    'plumbing','electrical','carpentry','tailoring','appliance_repair',
    'device_repair','painting','moving_assembly','beauty_wedding',
    'event_setup','printing_stationery','other'
  )),
  service_type text not null,
  title text not null,
  description text,
  availability_mode text not null check (availability_mode in ('hours','half_day','day','custom')),
  available_hours numeric(5,2) not null check (available_hours > 0 and available_hours <= 24),
  availability_note text,
  materials_mode text not null default 'case_by_case' check (materials_mode in ('none','provider','recipient','case_by_case')),
  pricing_mode text not null default 'free' check (pricing_mode in ('free','materials_only')),
  verification_status text not null default 'pending' check (verification_status in ('pending','verified','rejected')),
  status text not null default 'submitted' check (status in ('submitted','approved','paused','matched','completed','rejected','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.service_requests (
  id uuid primary key default gen_random_uuid(),
  public_code text not null unique,
  user_id uuid not null references public.profiles(id) on delete cascade,
  service_area_id uuid references public.service_areas(id) on delete set null,
  category text not null check (category in (
    'plumbing','electrical','carpentry','tailoring','appliance_repair',
    'device_repair','painting','moving_assembly','beauty_wedding',
    'event_setup','printing_stationery','other'
  )),
  service_type text not null,
  title text not null,
  details text not null,
  estimated_hours numeric(5,2) check (estimated_hours is null or (estimated_hours > 0 and estimated_hours <= 24)),
  preferred_time_note text,
  materials_available boolean not null default false,
  status text not null default 'submitted' check (status in ('submitted','reviewing','matched','scheduled','completed','rejected','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.service_matches (
  id uuid primary key default gen_random_uuid(),
  service_offer_id uuid not null references public.service_offers(id) on delete restrict,
  service_request_id uuid not null references public.service_requests(id) on delete restrict,
  status text not null default 'proposed' check (status in ('proposed','accepted','declined','scheduled','completed','cancelled')),
  scheduled_at timestamptz,
  approved_by uuid references public.profiles(id) on delete set null,
  operational_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(service_offer_id, service_request_id)
);

create index if not exists service_offers_match_idx
  on public.service_offers(category, service_type, service_area_id, status, verification_status);
create index if not exists service_requests_match_idx
  on public.service_requests(category, service_type, service_area_id, status);

alter table public.service_offers enable row level security;
alter table public.service_requests enable row level security;
alter table public.service_matches enable row level security;

create policy "users_read_own_service_offers"
on public.service_offers for select to authenticated
using (user_id = (select auth.uid()) or public.is_admin());

create policy "users_insert_own_service_offers"
on public.service_offers for insert to authenticated
with check (
  user_id = (select auth.uid())
  and status = 'submitted'
  and verification_status = 'pending'
  and pricing_mode in ('free','materials_only')
);

create policy "admins_update_service_offers"
on public.service_offers for update to authenticated
using (public.is_admin()) with check (public.is_admin());

create policy "users_read_own_service_requests"
on public.service_requests for select to authenticated
using (user_id = (select auth.uid()) or public.is_admin());

create policy "users_insert_own_service_requests"
on public.service_requests for insert to authenticated
with check (user_id = (select auth.uid()) and status = 'submitted');

create policy "admins_update_service_requests"
on public.service_requests for update to authenticated
using (public.is_admin()) with check (public.is_admin());

create policy "users_read_own_service_matches"
on public.service_matches for select to authenticated
using (
  public.is_admin()
  or exists (
    select 1 from public.service_offers o
    where o.id = service_offer_id and o.user_id = (select auth.uid())
  )
  or exists (
    select 1 from public.service_requests r
    where r.id = service_request_id and r.user_id = (select auth.uid())
  )
);

create policy "admins_manage_service_matches"
on public.service_matches for all to authenticated
using (public.is_admin()) with check (public.is_admin());

create or replace function public.prevent_self_service_match()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_offer_user uuid;
  v_request_user uuid;
begin
  select user_id into v_offer_user from public.service_offers where id = new.service_offer_id;
  select user_id into v_request_user from public.service_requests where id = new.service_request_id;
  if v_offer_user is null or v_request_user is null then
    raise exception 'service offer or request not found';
  end if;
  if v_offer_user = v_request_user then
    raise exception 'self service matching is not allowed';
  end if;
  return new;
end;
$$;

drop trigger if exists service_matches_no_self_match on public.service_matches;
create trigger service_matches_no_self_match
before insert or update of service_offer_id, service_request_id
on public.service_matches
for each row execute function public.prevent_self_service_match();

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
security definer
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
  order by score desc, o.created_at asc;
end;
$$;

revoke all on function public.admin_service_match_candidates(uuid) from public, anon;
grant execute on function public.admin_service_match_candidates(uuid) to authenticated;

grant select, insert on public.service_offers to authenticated;
grant update on public.service_offers to authenticated;
grant select, insert on public.service_requests to authenticated;
grant update on public.service_requests to authenticated;
grant select, insert, update, delete on public.service_matches to authenticated;

comment on table public.service_offers is 'Donated time and professional/community skill offers. Offering help never increases eligibility priority for the provider.';
comment on table public.service_requests is 'Private requests for donated time or skills. Users do not browse providers; Ruhamaa reviews and matches.';
comment on table public.service_matches is 'Admin-reviewed matches between donated skills/time and service requests.';
