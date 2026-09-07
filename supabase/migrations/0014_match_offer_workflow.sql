-- Sanad V1: private match offer -> beneficiary accepts/declines -> delivery assignment.

alter table public.matches
  add column if not exists status text not null default 'offered'
    check (status in ('offered','accepted','declined','cancelled')),
  add column if not exists responded_at timestamptz;

create index if not exists matches_status_created_idx on public.matches(status,created_at);

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

  if exists (
    select 1 from matches
    where donation_id=p_donation_id and status in ('offered','accepted')
  ) then
    raise exception 'donation already has an active offer/match';
  end if;

  if not exists (
    select 1 from donations
    where id=p_donation_id and status in ('submitted','under_review','available')
  ) then
    raise exception 'donation unavailable';
  end if;

  if not exists (
    select 1 from needs
    where id=p_need_id and status in ('submitted','waiting','candidate_found')
  ) then
    raise exception 'need unavailable';
  end if;

  insert into matches(donation_id,need_id,score,score_details,approved_by,status)
  values(p_donation_id,p_need_id,0,jsonb_build_object('approved_manually',true),auth.uid(),'offered')
  returning id into v_match;

  update donations set status='under_review', updated_at=now() where id=p_donation_id;
  update needs set status='candidate_found', updated_at=now() where id=p_need_id;

  insert into audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values(auth.uid(),'offer_match','match',v_match,jsonb_build_object('donation_id',p_donation_id,'need_id',p_need_id));

  return v_match;
end;
$$;

create or replace function public.user_pending_match_offers()
returns table(
  match_id uuid,
  need_id uuid,
  need_code text,
  donation_code text,
  item_type text,
  category text,
  item_condition text,
  offered_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select m.id,n.id,n.public_code,d.public_code,d.item_type,d.category,d.condition,m.created_at
  from matches m
  join needs n on n.id=m.need_id
  join donations d on d.id=m.donation_id
  where n.user_id=auth.uid() and m.status='offered'
  order by m.created_at desc;
$$;

create or replace function public.user_respond_match_offer(
  p_match_id uuid,
  p_accept boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_donation uuid;
  v_need uuid;
  v_need_owner uuid;
begin
  select m.donation_id,m.need_id,n.user_id
    into v_donation,v_need,v_need_owner
  from matches m
  join needs n on n.id=m.need_id
  where m.id=p_match_id and m.status='offered'
  for update of m;

  if not found then raise exception 'offer unavailable'; end if;
  if v_need_owner<>auth.uid() then raise exception 'not offer owner'; end if;

  if p_accept then
    update matches set status='accepted', responded_at=now() where id=p_match_id;
    update donations set status='matched',updated_at=now() where id=v_donation;
    update needs set status='matched',updated_at=now() where id=v_need;
  else
    update matches set status='declined', responded_at=now() where id=p_match_id;
    update donations set status='available',updated_at=now() where id=v_donation;
    update needs set status='waiting',updated_at=now() where id=v_need;
  end if;

  insert into audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values(auth.uid(),case when p_accept then 'accept_match_offer' else 'decline_match_offer' end,'match',p_match_id,'{}'::jsonb);
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
  v_id uuid;
  v_code text;
begin
  if not public.is_admin() then raise exception 'admin required'; end if;
  if p_pickup_pin is not null or p_delivery_pin is not null then raise exception 'admin PIN issuance is disabled'; end if;
  if not exists(select 1 from matches where id=p_match_id and status='accepted') then raise exception 'match must be accepted first'; end if;
  if exists(select 1 from deliveries where match_id=p_match_id) then raise exception 'delivery already exists'; end if;
  if not exists(select 1 from couriers where user_id=p_courier_id and active) then raise exception 'courier inactive'; end if;

  v_code := 'SND-MRB-DEL-' || to_char(now(),'YYMMDD') || '-' || upper(substr(encode(gen_random_bytes(5),'hex'),1,8));
  insert into deliveries(public_code,match_id,courier_id,vehicle_id,status,pickup_pin_hash,delivery_pin_hash,assigned_at)
  values(v_code,p_match_id,p_courier_id,p_vehicle_id,'assigned',null,null,now())
  returning id into v_id;

  update donations d set status='pickup_scheduled',updated_at=now()
   where d.id=(select donation_id from matches where id=p_match_id);
  update needs n set status='delivery_scheduled',updated_at=now()
   where n.id=(select need_id from matches where id=p_match_id);

  insert into audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values(auth.uid(),'create_delivery','delivery',v_id,jsonb_build_object('courier_id',p_courier_id,'vehicle_id',p_vehicle_id));

  return query select v_id,v_code,null::text,null::text;
end;
$$;

revoke all on function public.user_pending_match_offers() from public, anon;
revoke all on function public.user_respond_match_offer(uuid,boolean) from public, anon;
grant execute on function public.user_pending_match_offers() to authenticated;
grant execute on function public.user_respond_match_offer(uuid,boolean) to authenticated;
