-- Staged SQL: CI generates its migration filename with Supabase CLI.
-- Forward-only repair; no operational rows are deleted or modified.
alter policy contributions_owner_insert on public.contributions
  with check (user_id=(select auth.uid()) and public.is_active_user()
    and status='pending' and verified_by is null and verified_at is null);
alter policy donations_owner_insert on public.donations
  with check (user_id=(select auth.uid()) and public.is_active_user() and status='submitted');
alter policy needs_owner_insert on public.needs
  with check (user_id=(select auth.uid()) and public.is_active_user() and status='submitted');

create or replace function public.is_active_user() returns boolean
language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.profiles where id=(select auth.uid())
    and not is_suspended and not force_password_change);
$$;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.profiles where id=(select auth.uid())
    and role::text='admin' and not is_suspended and not force_password_change);
$$;
revoke all on function public.is_admin() from public,anon;
grant execute on function public.is_admin() to authenticated;

create or replace function public.is_courier() returns boolean
language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.profiles where id=(select auth.uid())
    and role::text='courier' and not is_suspended and not force_password_change
    and exists(select 1 from public.couriers c where c.user_id=(select auth.uid()) and c.active));
$$;
revoke all on function public.is_courier() from public,anon;
grant execute on function public.is_courier() to authenticated;

create or replace function public.is_supervisor() returns boolean
language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.profiles where id=(select auth.uid())
    and role::text='supervisor' and not is_suspended and not force_password_change);
$$;
revoke all on function public.is_supervisor() from public,anon;
grant execute on function public.is_supervisor() to authenticated;

-- pgcrypto is installed in extensions on both hosted and local Supabase.
alter function public.generate_public_code(text) set search_path=public,extensions;
alter function public.hash_pin(text) set search_path=public,extensions;
alter function public.admin_create_delivery(uuid,uuid,uuid,text,text) set search_path=public,extensions;
alter function public.user_register_service_partner(text,text,text,text,integer,uuid,text) set search_path=public,extensions;

alter table public.deliveries
  add column pickup_pin_expires_at timestamptz,
  add column delivery_pin_expires_at timestamptz,
  add column pickup_pin_attempts integer not null default 0 check(pickup_pin_attempts between 0 and 5),
  add column delivery_pin_attempts integer not null default 0 check(delivery_pin_attempts between 0 and 5);

-- RLS still scopes rows; deny all PIN material, including wildcard reads.
revoke select on public.deliveries from authenticated,anon,public;
do $$ declare cols text; begin
  select string_agg(quote_ident(attname),', ' order by attnum) into cols
  from pg_attribute where attrelid='public.deliveries'::regclass and attnum>0 and not attisdropped
    and attname not in ('pickup_pin_hash','delivery_pin_hash','pickup_pin_expires_at','delivery_pin_expires_at','pickup_pin_attempts','delivery_pin_attempts');
  execute format('grant select (%s) on public.deliveries to authenticated',cols);
end $$;

-- Preserve INVOKER recovery RPCs: give admins the row update policy they need.
-- The column privilege is shared by JWT roles, so a trigger protects owners.
grant update(status,updated_at) on public.donations to authenticated;
create policy admin_donations_recovery_update on public.donations for update to authenticated
  using(public.is_admin()) with check(public.is_admin());
create or replace function public.guard_donation_workflow_update() returns trigger
language plpgsql security invoker set search_path=public as $$
begin
  if current_user='authenticated' and new.status is distinct from old.status then
    if not public.is_admin() then raise exception 'workflow state is server controlled'; end if;
    if not exists(select 1 from public.inventory_items i where i.donation_id=old.id and
      ((new.status='under_review' and i.status='inspection_pending') or
       (new.status='available' and i.status='ready_for_distribution') or
       (new.status='rejected' and i.status='recycled'))) then
      raise exception 'inventory transition required';
    end if;
  end if;
  return new;
end $$;
revoke all on function public.guard_donation_workflow_update() from public,anon,authenticated;
create trigger guard_donation_workflow_update before update on public.donations
  for each row execute function public.guard_donation_workflow_update();

update storage.buckets set file_size_limit=5242880,
  allowed_mime_types=array['image/jpeg','image/png','image/webp']
where id='donation-images';

create or replace function public.user_issue_handoff_pin(p_delivery_id uuid,p_kind text)
returns text
language plpgsql
security definer
set search_path = public,extensions
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
    update public.deliveries set pickup_pin_hash=public.hash_pin(v_pin),pickup_pin_expires_at=now()+interval '10 minutes',pickup_pin_attempts=0 where id=p_delivery_id;
  else
    update public.deliveries set delivery_pin_hash=public.hash_pin(v_pin),delivery_pin_expires_at=now()+interval '10 minutes',delivery_pin_attempts=0 where id=p_delivery_id;
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
set search_path = public,extensions
as $$
declare
  v_delivery public.deliveries;
  v_expected_hash text;
  v_expires_at timestamptz;
  v_attempts integer;
begin
  if not public.is_courier() or not public.is_active_user() then raise exception 'active courier required'; end if;
  select * into v_delivery from public.deliveries where id=p_delivery_id for update;
  if not found then return false; end if;
  if v_delivery.courier_id<>auth.uid() then raise exception 'not assigned courier'; end if;

  if p_kind='pickup' then
    if v_delivery.status<>'heading_to_pickup' then raise exception 'pickup is not ready for verification'; end if;
    v_expected_hash:=v_delivery.pickup_pin_hash;
    v_expires_at:=v_delivery.pickup_pin_expires_at; v_attempts:=v_delivery.pickup_pin_attempts;
  elsif p_kind='delivery' then
    if v_delivery.status<>'heading_to_recipient' then raise exception 'dropoff is not ready for verification'; end if;
    v_expected_hash:=v_delivery.delivery_pin_hash;
    v_expires_at:=v_delivery.delivery_pin_expires_at; v_attempts:=v_delivery.delivery_pin_attempts;
  else
    raise exception 'invalid pin kind';
  end if;

  if v_expected_hash is null or p_pin is null or p_pin !~ '^[0-9]{4}$'
     or v_expires_at is null or v_expires_at<=now() or v_attempts>=5
     or public.hash_pin(p_pin) is distinct from v_expected_hash then
    if p_kind='pickup' then
      update public.deliveries set pickup_pin_attempts=least(pickup_pin_attempts+1,5) where id=p_delivery_id;
    else
      update public.deliveries set delivery_pin_attempts=least(delivery_pin_attempts+1,5) where id=p_delivery_id;
    end if;
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


-- Match the UI: work must start before it can be completed.
create or replace function public.admin_advance_item_work_order(
  p_work_order_id uuid,p_action text,p_actual_cost_yer integer default null,p_note text default null
) returns text
language plpgsql security invoker set search_path=public as $$
declare v_order public.item_work_orders%rowtype; v_item public.inventory_items%rowtype; v_status text;
begin
  if not public.is_admin() then raise exception 'admin access required'; end if;
  if p_actual_cost_yer is not null and p_actual_cost_yer<0 then raise exception 'invalid actual cost'; end if;
  select * into v_order from public.item_work_orders where id=p_work_order_id for update;
  if v_order.id is null then raise exception 'work order not found'; end if;
  select * into v_item from public.inventory_items where id=v_order.inventory_item_id for update;
  if p_action='start' then
    if v_order.status<>'queued' then raise exception 'work order is not queued'; end if;
    v_status:=case when v_order.work_type='clean' then 'cleaning' else 'repairing' end;
    update public.item_work_orders set status='in_progress',started_at=now(),notes=coalesce(nullif(trim(coalesce(p_note,'')),''),notes),updated_at=now() where id=p_work_order_id;
    update public.inventory_items set status=v_status,updated_at=now() where id=v_item.id;
  elsif p_action='complete' then
    if v_order.status<>'in_progress' then raise exception 'work order cannot be completed'; end if;
    v_status:='ready_for_distribution';
    update public.item_work_orders set status='completed',actual_cost_yer=p_actual_cost_yer,completed_at=now(),notes=coalesce(nullif(trim(coalesce(p_note,'')),''),notes),updated_at=now() where id=p_work_order_id;
    update public.inventory_items set status=v_status,ready_at=now(),updated_at=now() where id=v_item.id;
    update public.donations set status='available',updated_at=now() where id=v_item.donation_id;
  else
    raise exception 'action must be start or complete';
  end if;
  insert into public.inventory_events(inventory_item_id,actor_id,event_type,from_status,to_status,metadata)
  values(v_item.id,auth.uid(),'work_order_'||p_action,v_item.status,v_status,jsonb_build_object('work_order_id',p_work_order_id,'actual_cost_yer',p_actual_cost_yer));
  return v_status;
end $$;

