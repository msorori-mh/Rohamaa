-- Ruhamaa Courier Dispatch V2: explicit courier response, guarded handoff
-- progression, private courier notifications, and admin reassignment.

alter table public.deliveries
  add column if not exists courier_responded_at timestamptz,
  add column if not exists offer_expires_at timestamptz,
  add column if not exists rejection_reason text,
  add column if not exists dispatch_attempt integer not null default 1;

alter table public.deliveries
  drop constraint if exists deliveries_rejection_reason_check,
  add constraint deliveries_rejection_reason_check
    check (rejection_reason is null or rejection_reason in (
      'unavailable','too_far','vehicle_issue','schedule_conflict','other'
    )),
  drop constraint if exists deliveries_dispatch_attempt_check,
  add constraint deliveries_dispatch_attempt_check check (dispatch_attempt > 0);

update public.deliveries
set offer_expires_at = coalesce(assigned_at, created_at) + interval '30 minutes'
where status = 'assigned' and offer_expires_at is null;

create index if not exists deliveries_dispatch_queue_idx
  on public.deliveries(status, offer_expires_at, assigned_at desc);

do $$
begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime')
     and not exists(
       select 1 from pg_publication_tables
       where pubname='supabase_realtime' and schemaname='public' and tablename='deliveries'
     ) then
    alter publication supabase_realtime add table public.deliveries;
  end if;
end $$;

alter table public.user_notifications
  drop constraint if exists user_notifications_action_route_check;
alter table public.user_notifications
  add constraint user_notifications_action_route_check
  check (action_route in ('/offers','/handoffs','/my-services','/partners','/courier'));

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
  if not exists(select 1 from public.matches where id=p_match_id and status='accepted') then raise exception 'match must be accepted first'; end if;
  if exists(select 1 from public.deliveries where match_id=p_match_id) then raise exception 'delivery already exists'; end if;
  if not exists(select 1 from public.couriers where user_id=p_courier_id and active) then raise exception 'courier inactive'; end if;

  v_code := 'RHM-MRB-DEL-' || to_char(now(),'YYMMDD') || '-' || upper(substr(encode(gen_random_bytes(5),'hex'),1,8));
  insert into public.deliveries(
    public_code,match_id,courier_id,vehicle_id,status,pickup_pin_hash,
    delivery_pin_hash,assigned_at,offer_expires_at,dispatch_attempt
  ) values (
    v_code,p_match_id,p_courier_id,p_vehicle_id,'assigned',null,
    null,now(),now()+interval '30 minutes',1
  ) returning id into v_id;

  update public.donations set status='pickup_scheduled',updated_at=now()
   where id=(select donation_id from public.matches where id=p_match_id);
  update public.needs set status='delivery_scheduled',updated_at=now()
   where id=(select need_id from public.matches where id=p_match_id);

  insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values(auth.uid(),'create_delivery','delivery',v_id,jsonb_build_object(
    'courier_id',p_courier_id,'vehicle_id',p_vehicle_id,'dispatch_attempt',1
  ));
  insert into public.delivery_events(delivery_id,actor_id,event_type,metadata)
  values(v_id,auth.uid(),'courier_assigned',jsonb_build_object(
    'courier_id',p_courier_id,'vehicle_id',p_vehicle_id,'dispatch_attempt',1
  ));

  return query select v_id,v_code,null::text,null::text;
end;
$$;

create or replace function public.courier_respond_delivery(
  p_delivery_id uuid,
  p_accept boolean,
  p_reason text default null
)
returns public.delivery_status
language plpgsql
security definer
set search_path = public
as $$
declare
  v_delivery public.deliveries;
  v_next public.delivery_status;
begin
  if not public.is_courier() or not public.is_active_user() then raise exception 'active courier required'; end if;
  select * into v_delivery from public.deliveries
  where id=p_delivery_id and courier_id=auth.uid() for update;
  if not found then raise exception 'delivery not assigned to courier'; end if;
  if v_delivery.status <> 'assigned' then raise exception 'assignment is no longer awaiting response'; end if;

  if p_accept then
    if v_delivery.offer_expires_at is not null and v_delivery.offer_expires_at < now() then
      raise exception 'assignment offer expired';
    end if;
    update public.deliveries
    set status='heading_to_pickup',courier_responded_at=now(),rejection_reason=null
    where id=p_delivery_id;
    v_next := 'heading_to_pickup';
    insert into public.delivery_events(delivery_id,actor_id,event_type,metadata)
    values(p_delivery_id,auth.uid(),'courier_accepted',jsonb_build_object('dispatch_attempt',v_delivery.dispatch_attempt));
  else
    if p_reason is null or p_reason not in ('unavailable','too_far','vehicle_issue','schedule_conflict','other') then
      raise exception 'valid rejection reason required';
    end if;
    update public.deliveries
    set status='rescheduled',courier_responded_at=now(),rejection_reason=p_reason,
        courier_id=null,vehicle_id=null
    where id=p_delivery_id;
    v_next := 'rescheduled';
    insert into public.delivery_events(delivery_id,actor_id,event_type,metadata)
    values(p_delivery_id,auth.uid(),'courier_rejected',jsonb_build_object(
      'reason',p_reason,'dispatch_attempt',v_delivery.dispatch_attempt
    ));
  end if;

  insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values(auth.uid(),case when p_accept then 'courier_accept_delivery' else 'courier_reject_delivery' end,
    'delivery',p_delivery_id,jsonb_build_object('reason',p_reason,'dispatch_attempt',v_delivery.dispatch_attempt));
  return v_next;
end;
$$;

create or replace function public.courier_start_dropoff(p_delivery_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_courier() or not public.is_active_user() then raise exception 'active courier required'; end if;
  update public.deliveries set status='heading_to_recipient'
  where id=p_delivery_id and courier_id=auth.uid() and status='picked_up';
  if not found then raise exception 'delivery is not ready for dropoff'; end if;
  insert into public.delivery_events(delivery_id,actor_id,event_type)
  values(p_delivery_id,auth.uid(),'heading_to_recipient');
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values(auth.uid(),'start_delivery_dropoff','delivery',p_delivery_id,'{}'::jsonb);
end;
$$;

create or replace function public.user_issue_handoff_pin(p_delivery_id uuid,p_kind text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_bytes bytea;
  v_pin text;
  v_donor uuid;
  v_recipient uuid;
  v_status public.delivery_status;
begin
  if not public.is_active_user() then raise exception 'account suspended'; end if;
  select d.user_id,n.user_id,del.status into v_donor,v_recipient,v_status
  from public.deliveries del
  join public.matches m on m.id=del.match_id
  join public.donations d on d.id=m.donation_id
  join public.needs n on n.id=m.need_id
  where del.id=p_delivery_id for update of del;
  if not found then raise exception 'delivery not found'; end if;

  if p_kind='pickup' then
    if v_donor<>auth.uid() then raise exception 'not pickup owner'; end if;
    if v_status<>'heading_to_pickup' then raise exception 'pickup PIN unavailable in this state'; end if;
  elsif p_kind='delivery' then
    if v_recipient<>auth.uid() then raise exception 'not delivery owner'; end if;
    if v_status<>'heading_to_recipient' then raise exception 'delivery PIN unavailable in this state'; end if;
  else
    raise exception 'invalid handoff kind';
  end if;

  v_bytes:=gen_random_bytes(2);
  v_pin:=lpad((((get_byte(v_bytes,0)*256)+get_byte(v_bytes,1))%10000)::text,4,'0');
  if p_kind='pickup' then
    update public.deliveries set pickup_pin_hash=public.hash_pin(v_pin) where id=p_delivery_id;
  else
    update public.deliveries set delivery_pin_hash=public.hash_pin(v_pin) where id=p_delivery_id;
  end if;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values(auth.uid(),'issue_handoff_pin','delivery',p_delivery_id,jsonb_build_object('kind',p_kind));
  return v_pin;
end;
$$;

create or replace function public.verify_delivery_pin(
  p_delivery_id uuid,
  p_pin text,
  p_kind text,
  p_latitude double precision default null,
  p_longitude double precision default null
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_delivery public.deliveries;
  v_expected_hash text;
begin
  if not public.is_courier() or not public.is_active_user() then raise exception 'active courier required'; end if;
  select * into v_delivery from public.deliveries where id=p_delivery_id for update;
  if not found then return false; end if;
  if v_delivery.courier_id<>auth.uid() then raise exception 'not assigned courier'; end if;

  if p_kind='pickup' then
    if v_delivery.status<>'heading_to_pickup' then raise exception 'pickup is not ready for verification'; end if;
    v_expected_hash:=v_delivery.pickup_pin_hash;
  elsif p_kind='delivery' then
    if v_delivery.status<>'heading_to_recipient' then raise exception 'dropoff is not ready for verification'; end if;
    v_expected_hash:=v_delivery.delivery_pin_hash;
  else
    raise exception 'invalid pin kind';
  end if;

  if v_expected_hash is null or public.hash_pin(p_pin)<>v_expected_hash then
    insert into public.risk_flags(user_id,delivery_id,rule_code,severity,details)
    values(auth.uid(),p_delivery_id,'INVALID_DELIVERY_PIN','medium',jsonb_build_object('kind',p_kind));
    return false;
  end if;

  if p_kind='pickup' then
    update public.deliveries set status='picked_up',picked_up_at=now(),pickup_pin_hash=null where id=p_delivery_id;
    update public.donations set status='picked_up',updated_at=now()
    where id=(select m.donation_id from public.matches m where m.id=v_delivery.match_id);
  else
    update public.deliveries set status='delivered',delivered_at=now(),delivery_pin_hash=null where id=p_delivery_id;
    update public.donations set status='delivered',updated_at=now()
    where id=(select m.donation_id from public.matches m where m.id=v_delivery.match_id);
    update public.needs set status='fulfilled',updated_at=now()
    where id=(select m.need_id from public.matches m where m.id=v_delivery.match_id);
  end if;

  insert into public.delivery_events(delivery_id,actor_id,event_type,latitude,longitude)
  values(p_delivery_id,auth.uid(),case when p_kind='pickup' then 'pickup_pin_verified' else 'delivery_pin_verified' end,p_latitude,p_longitude);
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values(auth.uid(),case when p_kind='pickup' then 'confirm_delivery_pickup' else 'confirm_delivery_dropoff' end,'delivery',p_delivery_id,'{}'::jsonb);
  return true;
end;
$$;

create or replace function public.admin_reassign_delivery(
  p_delivery_id uuid,
  p_courier_id uuid,
  p_vehicle_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_delivery public.deliveries;
begin
  if not public.is_admin() then raise exception 'admin required'; end if;
  select * into v_delivery from public.deliveries where id=p_delivery_id for update;
  if not found then raise exception 'delivery not found'; end if;
  if v_delivery.status not in ('assigned','failed','rescheduled') then raise exception 'delivery cannot be reassigned in its current state'; end if;
  if not exists(select 1 from public.couriers where user_id=p_courier_id and active) then raise exception 'courier inactive'; end if;

  update public.deliveries
  set courier_id=p_courier_id,vehicle_id=p_vehicle_id,status='assigned',assigned_at=now(),
      courier_responded_at=null,offer_expires_at=now()+interval '30 minutes',
      rejection_reason=null,dispatch_attempt=dispatch_attempt+1
  where id=p_delivery_id;

  insert into public.delivery_events(delivery_id,actor_id,event_type,metadata)
  values(p_delivery_id,auth.uid(),'courier_reassigned',jsonb_build_object(
    'previous_courier_id',v_delivery.courier_id,'courier_id',p_courier_id,
    'vehicle_id',p_vehicle_id,'dispatch_attempt',v_delivery.dispatch_attempt+1
  ));
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values(auth.uid(),'reassign_delivery','delivery',p_delivery_id,jsonb_build_object(
    'previous_courier_id',v_delivery.courier_id,'courier_id',p_courier_id,
    'vehicle_id',p_vehicle_id,'dispatch_attempt',v_delivery.dispatch_attempt+1
  ));
end;
$$;

create or replace function public.admin_delivery_dispatch_queue()
returns table(
  delivery_id uuid, public_code text, status public.delivery_status,
  assigned_at timestamptz, offer_expires_at timestamptz, dispatch_attempt integer,
  courier_id uuid, courier_name text, vehicle_id uuid, vehicle_code text,
  rejection_reason text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'admin required'; end if;
  return query
  select d.id,d.public_code,d.status,d.assigned_at,d.offer_expires_at,d.dispatch_attempt,
         d.courier_id,p.full_name,d.vehicle_id,v.code,d.rejection_reason
  from public.deliveries d
  left join public.profiles p on p.id=d.courier_id
  left join public.vehicles v on v.id=d.vehicle_id
  where d.status <> 'delivered'
  order by case d.status when 'failed' then 0 when 'rescheduled' then 1 when 'assigned' then 2 else 3 end,
           d.assigned_at nulls first;
end;
$$;

create or replace function public.courier_task_details(p_delivery_id uuid)
returns table(
  delivery_id uuid, public_code text, status public.delivery_status,
  pickup_area text, pickup_description text, pickup_latitude double precision,
  pickup_longitude double precision, pickup_phone text,
  dropoff_area text, dropoff_description text, dropoff_latitude double precision,
  dropoff_longitude double precision, dropoff_phone text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_courier() or not public.is_active_user() then raise exception 'active courier required'; end if;
  return query
  select del.id,del.public_code,del.status,
    case when del.status in ('assigned','heading_to_pickup') then da.area end,
    case when del.status='heading_to_pickup' then da.description end,
    case when del.status='heading_to_pickup' then da.latitude end,
    case when del.status='heading_to_pickup' then da.longitude end,
    case when del.status='heading_to_pickup' then dp.phone end,
    case when del.status in ('picked_up','heading_to_recipient') then na.area end,
    case when del.status in ('picked_up','heading_to_recipient') then na.description end,
    case when del.status in ('picked_up','heading_to_recipient') then na.latitude end,
    case when del.status in ('picked_up','heading_to_recipient') then na.longitude end,
    case when del.status in ('picked_up','heading_to_recipient') then np.phone end
  from public.deliveries del
  join public.matches m on m.id=del.match_id
  join public.donations d on d.id=m.donation_id
  join public.needs n on n.id=m.need_id
  join public.profiles dp on dp.id=d.user_id
  join public.profiles np on np.id=n.user_id
  left join public.addresses da on da.id=d.address_id
  left join public.addresses na on na.id=n.address_id
  where del.id=p_delivery_id and del.courier_id=auth.uid();
end;
$$;

create or replace function public.notify_delivery_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_donor uuid;
  v_recipient uuid;
begin
  if tg_op='UPDATE'
     and new.status::text is not distinct from old.status::text
     and new.courier_id is not distinct from old.courier_id then return new; end if;

  select d.user_id,n.user_id into v_donor,v_recipient
  from public.matches m
  join public.donations d on d.id=m.donation_id
  join public.needs n on n.id=m.need_id
  where m.id=new.match_id;

  if new.status='assigned' and new.courier_id is not null then
    perform public.insert_user_notification(
      new.courier_id,'courier_assignment','مهمة توصيل جديدة',
      'أُسندت إليك المهمة '||new.public_code||'. افتحها واقبلها أو اعتذر عنها.',
      'deliveries',new.id,'/courier',
      'deliveries:courier:'||new.id||':attempt:'||new.dispatch_attempt
    );
  end if;

  perform public.insert_user_notification(
    v_donor,'delivery_status','تحديث استلام التبرع',
    'تم تحديث رحلة '||new.public_code||'. افتح المتابعة لمعرفة الخطوة الحالية.',
    'deliveries',new.id,'/handoffs','deliveries:donor:'||new.id||':'||new.status::text||':'||new.dispatch_attempt
  );
  perform public.insert_user_notification(
    v_recipient,'delivery_status','تحديث تسليم التبرع',
    'تم تحديث رحلة '||new.public_code||'. افتح المتابعة لمعرفة الخطوة الحالية.',
    'deliveries',new.id,'/handoffs','deliveries:recipient:'||new.id||':'||new.status::text||':'||new.dispatch_attempt
  );
  return new;
end;
$$;

revoke all on function public.courier_respond_delivery(uuid,boolean,text) from public, anon;
revoke all on function public.courier_start_dropoff(uuid) from public, anon;
revoke all on function public.admin_reassign_delivery(uuid,uuid,uuid) from public, anon;
revoke all on function public.admin_delivery_dispatch_queue() from public, anon;
revoke all on function public.courier_task_details(uuid) from public, anon;
revoke all on function public.user_issue_handoff_pin(uuid,text) from public, anon;
revoke all on function public.verify_delivery_pin(uuid,text,text,double precision,double precision) from public, anon;
grant execute on function public.courier_respond_delivery(uuid,boolean,text) to authenticated;
grant execute on function public.courier_start_dropoff(uuid) to authenticated;
grant execute on function public.admin_reassign_delivery(uuid,uuid,uuid) to authenticated;
grant execute on function public.admin_delivery_dispatch_queue() to authenticated;
grant execute on function public.courier_task_details(uuid) to authenticated;
grant execute on function public.user_issue_handoff_pin(uuid,text) to authenticated;
grant execute on function public.verify_delivery_pin(uuid,text,text,double precision,double precision) to authenticated;

comment on function public.courier_respond_delivery(uuid,boolean,text) is
  'Assigned active courier accepts or rejects one pending dispatch; every transition is audited.';
comment on function public.admin_reassign_delivery(uuid,uuid,uuid) is
  'Admin-only reassignment for an uncompleted delivery, preserving attempt history in events and audit logs.';
