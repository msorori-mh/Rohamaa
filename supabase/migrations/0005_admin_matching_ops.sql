-- Sanad V1: admin authorization, matching queue, payment verification,
-- courier minimum-information operations, and server-side delivery creation.

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'admin' and not p.is_suspended
  );
$$;

create or replace function public.is_courier()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    join public.couriers c on c.user_id = p.id
    where p.id = auth.uid()
      and p.role = 'courier'
      and not p.is_suspended
      and c.active
  );
$$;

create or replace function public.distance_km(lat1 double precision, lon1 double precision, lat2 double precision, lon2 double precision)
returns double precision
language sql
immutable
as $$
  select case
    when lat1 is null or lon1 is null or lat2 is null or lon2 is null then null
    else 6371 * 2 * asin(sqrt(
      power(sin(radians(lat2-lat1)/2),2) +
      cos(radians(lat1))*cos(radians(lat2))*power(sin(radians(lon2-lon1)/2),2)
    ))
  end;
$$;

create or replace function public.admin_match_candidates(p_donation_id uuid, p_limit integer default 20)
returns table (
  need_id uuid,
  need_code text,
  item_type text,
  category text,
  age_hours numeric,
  distance_km numeric,
  prior_same_category integer,
  trust_score integer,
  score numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'admin required'; end if;

  return query
  with d as (
    select don.*, a.latitude dlat, a.longitude dlon
    from donations don left join addresses a on a.id = don.address_id
    where don.id = p_donation_id and don.status in ('submitted','under_review','available')
  ), candidates as (
    select n,
           p.trust_score,
           a.latitude nlat,
           a.longitude nlon,
           public.distance_km(d.dlat,d.dlon,a.latitude,a.longitude) dist,
           (select count(*)::int
              from needs oldn
             where oldn.user_id=n.user_id
               and oldn.category=n.category
               and oldn.status='fulfilled'
               and oldn.updated_at > now()-interval '120 days') prior_count,
           extract(epoch from (now()-n.created_at))/3600 ageh,
           d.category dcategory,
           d.item_type ditem
    from d
    join needs n on n.status in ('submitted','waiting','candidate_found')
    join profiles p on p.id=n.user_id and not p.is_suspended
    left join addresses a on a.id=n.address_id
    where lower(n.category)=lower(d.category)
      and (lower(n.item_type)=lower(d.item_type)
           or lower(n.item_type) like '%'||lower(d.item_type)||'%'
           or lower(d.item_type) like '%'||lower(n.item_type)||'%')
  )
  select c.n.id,
         c.n.public_code,
         c.n.item_type,
         c.n.category,
         round(c.ageh::numeric,1),
         case when c.dist is null then null else round(c.dist::numeric,1) end,
         c.prior_count,
         c.trust_score,
         round((
           40
           + least(c.ageh/24, 15)
           + case when c.dist is null then 0 when c.dist<=3 then 20 when c.dist<=7 then 12 when c.dist<=15 then 5 else 0 end
           + least(greatest(c.trust_score,0),10)
           - least(c.prior_count*8,24)
         )::numeric,2)
  from candidates c
  order by 9 desc, c.n.created_at asc
  limit greatest(1,least(p_limit,100));
end;
$$;

create or replace function public.admin_approve_match(p_donation_id uuid, p_need_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match uuid;
begin
  if not public.is_admin() then raise exception 'admin required'; end if;

  if exists (select 1 from matches where donation_id=p_donation_id) then
    raise exception 'donation already matched';
  end if;

  insert into matches(donation_id,need_id,score,score_details,approved_by)
  values(p_donation_id,p_need_id,0,jsonb_build_object('approved_manually',true),auth.uid())
  returning id into v_match;

  update donations set status='matched', updated_at=now() where id=p_donation_id;
  update needs set status='matched', updated_at=now() where id=p_need_id;

  insert into audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values(auth.uid(),'approve_match','match',v_match,jsonb_build_object('donation_id',p_donation_id,'need_id',p_need_id));

  return v_match;
end;
$$;

create or replace function public.admin_create_delivery(
  p_match_id uuid,
  p_courier_id uuid,
  p_vehicle_id uuid default null,
  p_pickup_pin text default null,
  p_delivery_pin text default null
)
returns table(delivery_id uuid, public_code text, pickup_pin text, delivery_pin text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pick text := coalesce(p_pickup_pin,lpad((floor(random()*10000))::int::text,4,'0'));
  v_drop text := coalesce(p_delivery_pin,lpad((floor(random()*10000))::int::text,4,'0'));
  v_id uuid;
  v_code text;
begin
  if not public.is_admin() then raise exception 'admin required'; end if;
  if v_pick !~ '^\d{4}$' or v_drop !~ '^\d{4}$' then raise exception 'PIN must be 4 digits'; end if;
  if not exists(select 1 from couriers where user_id=p_courier_id and active) then raise exception 'courier inactive'; end if;

  v_code := public.generate_public_code('SND-MRB-DEL');
  insert into deliveries(public_code,match_id,courier_id,vehicle_id,status,pickup_pin_hash,delivery_pin_hash,assigned_at)
  values(v_code,p_match_id,p_courier_id,p_vehicle_id,'assigned',public.hash_pin(v_pick),public.hash_pin(v_drop),now())
  returning id into v_id;

  update donations d set status='pickup_scheduled',updated_at=now()
   where d.id=(select donation_id from matches where id=p_match_id);
  update needs n set status='delivery_scheduled',updated_at=now()
   where n.id=(select need_id from matches where id=p_match_id);

  insert into audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values(auth.uid(),'create_delivery','delivery',v_id,jsonb_build_object('courier_id',p_courier_id,'vehicle_id',p_vehicle_id));

  return query select v_id,v_code,v_pick,v_drop;
end;
$$;

create or replace function public.admin_verify_contribution(p_contribution_id uuid, p_verified boolean, p_note text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'admin required'; end if;
  update contributions
     set status=case when p_verified then 'verified'::contribution_status else 'rejected'::contribution_status end,
         verified_by=auth.uid(), verified_at=now()
   where id=p_contribution_id and status='pending';
  insert into audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values(auth.uid(),case when p_verified then 'verify_contribution' else 'reject_contribution' end,'contribution',p_contribution_id,jsonb_build_object('note',p_note));
end;
$$;

create or replace function public.courier_task_details(p_delivery_id uuid)
returns table(
  delivery_id uuid,
  public_code text,
  status delivery_status,
  pickup_area text,
  pickup_description text,
  pickup_latitude double precision,
  pickup_longitude double precision,
  pickup_phone text,
  dropoff_area text,
  dropoff_description text,
  dropoff_latitude double precision,
  dropoff_longitude double precision,
  dropoff_phone text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_courier() then raise exception 'courier required'; end if;
  return query
  select del.id,del.public_code,del.status,
         da.area,da.description,da.latitude,da.longitude,dp.phone,
         na.area,na.description,na.latitude,na.longitude,np.phone
  from deliveries del
  join matches m on m.id=del.match_id
  join donations d on d.id=m.donation_id
  join needs n on n.id=m.need_id
  join profiles dp on dp.id=d.user_id
  join profiles np on np.id=n.user_id
  left join addresses da on da.id=d.address_id
  left join addresses na on na.id=n.address_id
  where del.id=p_delivery_id and del.courier_id=auth.uid();
end;
$$;

-- Admin read policies for operational screens. Privileged mutation remains RPC-based.
create policy "admin_profiles_select" on profiles for select using (public.is_admin());
create policy "admin_addresses_select" on addresses for select using (public.is_admin());
create policy "admin_needs_select" on needs for select using (public.is_admin());
create policy "admin_donations_select" on donations for select using (public.is_admin());
create policy "admin_matches_select" on matches for select using (public.is_admin());
create policy "admin_deliveries_select" on deliveries for select using (public.is_admin());
create policy "admin_contributions_select" on contributions for select using (public.is_admin());
create policy "admin_risk_flags_select" on risk_flags for select using (public.is_admin());
create policy "admin_audit_logs_select" on audit_logs for select using (public.is_admin());

create index if not exists needs_matching_idx on needs(status,category,item_type,created_at);
create index if not exists donations_matching_idx on donations(status,category,item_type,created_at);
create index if not exists risk_flags_open_idx on risk_flags(resolved,severity,created_at desc);
