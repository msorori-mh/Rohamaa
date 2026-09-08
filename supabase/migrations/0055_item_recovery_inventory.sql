-- Ruhamaa P2: non-food/non-medical item intake, A-D inspection,
-- cleaning/repair work orders, warehouse inventory, and recycling outcomes.

create table public.warehouses (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  service_area_id uuid references public.service_areas(id) on delete set null,
  address_note text,
  active boolean not null default true,
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.inventory_items (
  id uuid primary key default gen_random_uuid(),
  public_code text not null unique,
  donation_id uuid not null unique references public.donations(id) on delete restrict,
  warehouse_id uuid not null references public.warehouses(id) on delete restrict,
  bin_location text,
  grade text check (grade is null or grade in ('A','B','C','D')),
  disposition text check (disposition is null or disposition in ('direct','clean','repair','recycle')),
  status text not null default 'inspection_pending' check (status in (
    'inspection_pending','cleaning_queued','cleaning','repair_queued','repairing',
    'ready_for_distribution','recycling','recycled','withdrawn'
  )),
  inspection_note text,
  inspected_by uuid references public.profiles(id) on delete set null,
  inspected_at timestamptz,
  ready_at timestamptz,
  exited_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.item_work_orders (
  id uuid primary key default gen_random_uuid(),
  public_code text not null unique,
  inventory_item_id uuid not null references public.inventory_items(id) on delete restrict,
  work_type text not null check (work_type in ('clean','repair')),
  partner_id uuid references public.service_partners(id) on delete set null,
  status text not null default 'queued' check (status in ('queued','in_progress','completed','cancelled')),
  estimated_cost_yer integer check (estimated_cost_yer is null or estimated_cost_yer >= 0),
  actual_cost_yer integer check (actual_cost_yer is null or actual_cost_yer >= 0),
  notes text,
  assigned_by uuid references public.profiles(id) on delete set null,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(inventory_item_id,work_type)
);

create table public.item_recycling_records (
  id uuid primary key default gen_random_uuid(),
  public_code text not null unique,
  inventory_item_id uuid not null unique references public.inventory_items(id) on delete restrict,
  partner_id uuid references public.service_partners(id) on delete set null,
  material_type text,
  weight_kg numeric(10,2) check (weight_kg is null or weight_kg >= 0),
  proceeds_yer integer check (proceeds_yer is null or proceeds_yer >= 0),
  status text not null default 'queued' check (status in ('queued','handed_over','confirmed','cancelled')),
  notes text,
  confirmed_by uuid references public.profiles(id) on delete set null,
  handed_over_at timestamptz,
  confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.inventory_events (
  id bigint generated always as identity primary key,
  inventory_item_id uuid not null references public.inventory_items(id) on delete restrict,
  actor_id uuid references public.profiles(id) on delete set null,
  event_type text not null,
  from_status text,
  to_status text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index warehouses_active_idx on public.warehouses(active,created_at);
create index inventory_items_queue_idx on public.inventory_items(status,created_at);
create index inventory_items_warehouse_idx on public.inventory_items(warehouse_id,status,created_at);
create index item_work_orders_queue_idx on public.item_work_orders(status,work_type,created_at);
create index item_work_orders_partner_idx on public.item_work_orders(partner_id,status) where partner_id is not null;
create index item_recycling_queue_idx on public.item_recycling_records(status,created_at);
create index inventory_events_item_idx on public.inventory_events(inventory_item_id,created_at desc);

alter table public.warehouses enable row level security;
alter table public.inventory_items enable row level security;
alter table public.item_work_orders enable row level security;
alter table public.item_recycling_records enable row level security;
alter table public.inventory_events enable row level security;

revoke all on table public.warehouses,public.inventory_items,public.item_work_orders,
  public.item_recycling_records,public.inventory_events from anon,authenticated;
revoke all on sequence public.inventory_events_id_seq from anon,authenticated;
grant select,insert,update on table public.warehouses to authenticated;
grant select,insert,update on table public.inventory_items to authenticated;
grant select,insert,update on table public.item_work_orders to authenticated;
grant select,insert,update on table public.item_recycling_records to authenticated;
grant select,insert on table public.inventory_events to authenticated;
grant usage,select on sequence public.inventory_events_id_seq to authenticated;

create policy "admins_manage_warehouses" on public.warehouses for all to authenticated
using (public.is_admin()) with check (public.is_admin());
create policy "admins_manage_inventory" on public.inventory_items for all to authenticated
using (public.is_admin()) with check (public.is_admin());
create policy "admins_manage_work_orders" on public.item_work_orders for all to authenticated
using (public.is_admin()) with check (public.is_admin());
create policy "admins_manage_recycling" on public.item_recycling_records for all to authenticated
using (public.is_admin()) with check (public.is_admin());
create policy "admins_read_inventory_events" on public.inventory_events for select to authenticated
using (public.is_admin());
create policy "admins_insert_inventory_events" on public.inventory_events for insert to authenticated
with check (public.is_admin() and actor_id=(select auth.uid()));

create or replace function public.recovery_code(p_prefix text)
returns text language sql volatile security invoker set search_path=public as $$
  select p_prefix||'-MRB-'||to_char(now(),'YYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
$$;

create or replace function public.admin_create_warehouse(
  p_code text,p_name text,p_service_area_id uuid default null,p_address_note text default null
) returns uuid
language plpgsql security invoker set search_path=public as $$
declare v_id uuid;
begin
  if not public.is_admin() then raise exception 'admin access required'; end if;
  if length(trim(coalesce(p_code,'')))<2 or length(trim(coalesce(p_name,'')))<3 then
    raise exception 'warehouse code and name are required';
  end if;
  insert into public.warehouses(code,name,service_area_id,address_note,created_by)
  values(upper(trim(p_code)),trim(p_name),p_service_area_id,nullif(trim(coalesce(p_address_note,'')),''),auth.uid())
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.admin_inventory_intake_candidates()
returns table(donation_id uuid,public_code text,item_type text,condition text,created_at timestamptz)
language plpgsql stable security invoker set search_path=public as $$
begin
  if not public.is_admin() then raise exception 'admin access required'; end if;
  return query
  select d.id,d.public_code,d.item_type,d.condition,d.created_at
  from public.donations d
  where d.status in ('submitted','under_review','available')
    and not exists(select 1 from public.inventory_items i where i.donation_id=d.id)
  order by d.created_at;
end $$;

create or replace function public.admin_receive_inventory_item(
  p_donation_id uuid,p_warehouse_id uuid,p_bin_location text default null
) returns uuid
language plpgsql security invoker set search_path=public as $$
declare v_id uuid; v_code text;
begin
  if not public.is_admin() then raise exception 'admin access required'; end if;
  if not exists(select 1 from public.warehouses where id=p_warehouse_id and active) then
    raise exception 'active warehouse required';
  end if;
  if not exists(select 1 from public.donations where id=p_donation_id and status in ('submitted','under_review','available') for update) then
    raise exception 'donation unavailable for intake';
  end if;
  if exists(select 1 from public.inventory_items where donation_id=p_donation_id) then
    raise exception 'donation already received';
  end if;
  v_code:=public.recovery_code('INV');
  insert into public.inventory_items(public_code,donation_id,warehouse_id,bin_location)
  values(v_code,p_donation_id,p_warehouse_id,nullif(trim(coalesce(p_bin_location,'')),'')) returning id into v_id;
  update public.donations set status='under_review',updated_at=now() where id=p_donation_id;
  insert into public.inventory_events(inventory_item_id,actor_id,event_type,to_status,metadata)
  values(v_id,auth.uid(),'received','inspection_pending',jsonb_build_object('warehouse_id',p_warehouse_id,'bin_location',p_bin_location));
  return v_id;
end $$;

create or replace function public.admin_inspect_inventory_item(
  p_inventory_item_id uuid,p_grade text,p_note text default null,p_estimated_cost_yer integer default null
) returns text
language plpgsql security invoker set search_path=public as $$
declare v_item public.inventory_items%rowtype; v_status text; v_disposition text; v_work text;
begin
  if not public.is_admin() then raise exception 'admin access required'; end if;
  if p_grade not in ('A','B','C','D') then raise exception 'grade must be A, B, C or D'; end if;
  if p_estimated_cost_yer is not null and p_estimated_cost_yer<0 then raise exception 'invalid estimated cost'; end if;
  select * into v_item from public.inventory_items where id=p_inventory_item_id for update;
  if v_item.id is null then raise exception 'inventory item not found'; end if;
  if v_item.status<>'inspection_pending' then raise exception 'item already inspected'; end if;
  v_status:=case p_grade when 'A' then 'ready_for_distribution' when 'B' then 'cleaning_queued' when 'C' then 'repair_queued' else 'recycling' end;
  v_disposition:=case p_grade when 'A' then 'direct' when 'B' then 'clean' when 'C' then 'repair' else 'recycle' end;
  update public.inventory_items set grade=p_grade,disposition=v_disposition,status=v_status,
    inspection_note=nullif(trim(coalesce(p_note,'')),''),inspected_by=auth.uid(),inspected_at=now(),
    ready_at=case when p_grade='A' then now() else null end,updated_at=now()
  where id=p_inventory_item_id;
  if p_grade in ('B','C') then
    v_work:=case when p_grade='B' then 'clean' else 'repair' end;
    insert into public.item_work_orders(public_code,inventory_item_id,work_type,estimated_cost_yer,notes,assigned_by)
    values(public.recovery_code('WRK'),p_inventory_item_id,v_work,p_estimated_cost_yer,nullif(trim(coalesce(p_note,'')),''),auth.uid());
  elsif p_grade='D' then
    insert into public.item_recycling_records(public_code,inventory_item_id,notes)
    values(public.recovery_code('RCY'),p_inventory_item_id,nullif(trim(coalesce(p_note,'')),''));
  else
    update public.donations set status='available',updated_at=now() where id=v_item.donation_id;
  end if;
  insert into public.inventory_events(inventory_item_id,actor_id,event_type,from_status,to_status,metadata)
  values(p_inventory_item_id,auth.uid(),'inspected',v_item.status,v_status,jsonb_build_object('grade',p_grade,'disposition',v_disposition,'estimated_cost_yer',p_estimated_cost_yer));
  return v_status;
end $$;

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
    if v_order.status not in ('queued','in_progress') then raise exception 'work order cannot be completed'; end if;
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

create or replace function public.admin_confirm_item_recycling(
  p_recycling_id uuid,p_material_type text default null,p_weight_kg numeric default null,
  p_proceeds_yer integer default null,p_note text default null
) returns void
language plpgsql security invoker set search_path=public as $$
declare v_record public.item_recycling_records%rowtype; v_item public.inventory_items%rowtype;
begin
  if not public.is_admin() then raise exception 'admin access required'; end if;
  if p_weight_kg is not null and p_weight_kg<0 then raise exception 'invalid weight'; end if;
  if p_proceeds_yer is not null and p_proceeds_yer<0 then raise exception 'invalid proceeds'; end if;
  select * into v_record from public.item_recycling_records where id=p_recycling_id for update;
  if v_record.id is null then raise exception 'recycling record not found'; end if;
  if v_record.status not in ('queued','handed_over') then raise exception 'recycling already closed'; end if;
  select * into v_item from public.inventory_items where id=v_record.inventory_item_id for update;
  update public.item_recycling_records set status='confirmed',material_type=nullif(trim(coalesce(p_material_type,'')),''),
    weight_kg=p_weight_kg,proceeds_yer=p_proceeds_yer,notes=coalesce(nullif(trim(coalesce(p_note,'')),''),notes),
    confirmed_by=auth.uid(),confirmed_at=now(),updated_at=now() where id=p_recycling_id;
  update public.inventory_items set status='recycled',exited_at=now(),updated_at=now() where id=v_item.id;
  update public.donations set status='rejected',updated_at=now() where id=v_item.donation_id;
  insert into public.inventory_events(inventory_item_id,actor_id,event_type,from_status,to_status,metadata)
  values(v_item.id,auth.uid(),'recycling_confirmed',v_item.status,'recycled',jsonb_build_object('recycling_id',p_recycling_id,'material_type',p_material_type,'weight_kg',p_weight_kg,'proceeds_yer',p_proceeds_yer));
end $$;

create or replace function public.admin_inventory_queue()
returns table(
  inventory_item_id uuid,inventory_code text,donation_code text,item_type text,warehouse_name text,
  bin_location text,grade text,disposition text,status text,created_at timestamptz,
  work_order_id uuid,work_order_code text,work_order_status text,recycling_id uuid,recycling_code text
)
language plpgsql stable security invoker set search_path=public as $$
begin
  if not public.is_admin() then raise exception 'admin access required'; end if;
  return query
  select i.id,i.public_code,d.public_code,d.item_type,w.name,i.bin_location,i.grade,i.disposition,i.status,i.created_at,
    wo.id,wo.public_code,wo.status,rr.id,rr.public_code
  from public.inventory_items i
  join public.donations d on d.id=i.donation_id
  join public.warehouses w on w.id=i.warehouse_id
  left join public.item_work_orders wo on wo.inventory_item_id=i.id and wo.status<>'cancelled'
  left join public.item_recycling_records rr on rr.inventory_item_id=i.id and rr.status<>'cancelled'
  order by case i.status when 'inspection_pending' then 1 when 'repairing' then 2 when 'cleaning' then 3 when 'repair_queued' then 4 when 'cleaning_queued' then 5 when 'recycling' then 6 else 7 end,i.created_at;
end $$;

create or replace function public.admin_inventory_summary()
returns jsonb language plpgsql stable security invoker set search_path=public as $$
begin
  if not public.is_admin() then raise exception 'admin access required'; end if;
  return jsonb_build_object(
    'awaiting_inspection',(select count(*) from public.inventory_items where status='inspection_pending'),
    'cleaning',(select count(*) from public.inventory_items where status in ('cleaning_queued','cleaning')),
    'repairing',(select count(*) from public.inventory_items where status in ('repair_queued','repairing')),
    'ready',(select count(*) from public.inventory_items where status='ready_for_distribution'),
    'recycled',(select count(*) from public.inventory_items where status='recycled'),
    'repair_cost_yer',(select coalesce(sum(actual_cost_yer),0) from public.item_work_orders where status='completed'),
    'recycling_proceeds_yer',(select coalesce(sum(proceeds_yer),0) from public.item_recycling_records where status='confirmed')
  );
end $$;

create or replace function public.admin_recovery_priorities(p_limit integer default 50)
returns table(
  queue_key text,queue_kind text,entity_id uuid,public_code text,title text,subtitle text,
  priority integer,age_hours numeric,action_key text
)
language plpgsql stable security invoker set search_path=public as $$
begin
  if not public.is_admin() then raise exception 'admin access required'; end if;
  return query
  select 'recovery:'||i.id,'item_recovery'::text,d.id,i.public_code,
    case i.status
      when 'inspection_pending' then 'عطاء ينتظر الفحص'
      when 'cleaning_queued' then 'عطاء ينتظر التنظيف'
      when 'cleaning' then 'تنظيف عطاء جارٍ'
      when 'repair_queued' then 'عطاء ينتظر الإصلاح'
      when 'repairing' then 'إصلاح عطاء جارٍ'
      when 'recycling' then 'عطاء ينتظر تأكيد التدوير'
      else 'عطاء داخل مسار التأهيل'
    end,
    d.item_type||' • '||w.name,
    case i.status when 'inspection_pending' then 78 when 'repair_queued' then 77
      when 'cleaning_queued' then 76 when 'repairing' then 74 when 'cleaning' then 73
      when 'recycling' then 70 else 50 end,
    round((extract(epoch from now()-i.updated_at)/3600)::numeric,1),'recovery'::text
  from public.inventory_items i
  join public.donations d on d.id=i.donation_id
  join public.warehouses w on w.id=i.warehouse_id
  where i.status in ('inspection_pending','cleaning_queued','cleaning','repair_queued','repairing','recycling')
  order by 7 desc,8 desc
  limit greatest(1,least(coalesce(p_limit,50),100));
end $$;

create or replace function public.notify_inventory_status()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_owner uuid; v_donation_code text;
begin
  if tg_op='UPDATE' and new.status is not distinct from old.status then return new; end if;
  select d.user_id,d.public_code into v_owner,v_donation_code from public.donations d where d.id=new.donation_id;
  perform public.insert_user_notification(
    v_owner,'inventory_status','تحديث تجهيز العطاء',
    'تم تحديث مرحلة تجهيز العطاء '||v_donation_code||'. افتح مركز المتابعة لمعرفة الخطوة التالية.',
    'inventory_items',new.id,'/handoffs','inventory_items:'||new.id||':'||new.status
  );
  return new;
end $$;

create trigger inventory_items_status_notification
after insert or update of status on public.inventory_items
for each row execute function public.notify_inventory_status();

create or replace function public.notify_owned_record_status()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_owner uuid; v_code text; v_title text; v_route text; v_status text;
begin
  if tg_op<>'UPDATE' or new.status::text is not distinct from old.status::text then return new; end if;
  v_owner:=new.user_id; v_code:=new.public_code; v_status:=new.status::text;
  if tg_table_name='donations' then
    if exists(select 1 from public.inventory_items i where i.donation_id=new.id) then return new; end if;
    v_title:='تحديث حالة العطاء'; v_route:='/handoffs';
    if v_status not in ('available','matched','cancelled','rejected') then return new; end if;
  elsif tg_table_name='needs' then
    v_title:='تحديث حالة الاحتياج'; v_route:='/handoffs';
    if v_status not in ('waiting','matched','fulfilled','cancelled','expired') then return new; end if;
  elsif tg_table_name='service_offers' then
    v_title:='تحديث عرض المهارة'; v_route:='/my-services';
    if v_status not in ('approved','paused','rejected','cancelled') then return new; end if;
  elsif tg_table_name='service_requests' then
    v_title:='تحديث طلب الخدمة'; v_route:='/my-services';
    if v_status not in ('reviewing','rejected','cancelled') then return new; end if;
  else return new;
  end if;
  perform public.insert_user_notification(v_owner,tg_table_name||'_status',v_title,
    'تم تحديث حالة العملية '||v_code||'. افتح مركز المتابعة لمعرفة الخطوة التالية.',
    tg_table_name,new.id,v_route,tg_table_name||':'||new.id||':'||v_status);
  return new;
end $$;

create or replace function public.user_operations_center(p_limit integer default 100)
returns table(operation_kind text,operation_id uuid,public_code text,title text,status text,updated_at timestamptz,action_route text,requires_action boolean)
language sql stable security definer set search_path=public as $$
  select * from (
    select case when i.id is null then 'donation' else 'item_processing' end,d.id,d.public_code,d.item_type,
      coalesce(i.status,d.status::text),greatest(d.updated_at,coalesce(i.updated_at,d.updated_at)),'/handoffs'::text,false
    from public.donations d left join public.inventory_items i on i.donation_id=d.id where d.user_id=(select auth.uid())
    union all
    select 'need',n.id,n.public_code,n.item_type,n.status::text,n.updated_at,'/handoffs',false from public.needs n where n.user_id=(select auth.uid())
    union all
    select 'item_match',m.id,n.public_code,d.item_type,m.status,coalesce(m.responded_at,m.created_at),case when m.status='offered' then '/offers' else '/handoffs' end,m.status='offered'
    from public.matches m join public.needs n on n.id=m.need_id join public.donations d on d.id=m.donation_id where n.user_id=(select auth.uid()) and m.status='offered'
    union all
    select 'delivery',del.id,del.public_code,case when d.user_id=(select auth.uid()) then d.item_type else n.item_type end,del.status::text,
      coalesce(del.delivered_at,del.picked_up_at,del.assigned_at,del.created_at),'/handoffs',del.status in ('failed','rescheduled')
    from public.deliveries del join public.matches m on m.id=del.match_id join public.donations d on d.id=m.donation_id join public.needs n on n.id=m.need_id
    where d.user_id=(select auth.uid()) or n.user_id=(select auth.uid())
    union all
    select 'service_offer',o.id,o.public_code,o.title,o.status,o.updated_at,'/my-services',o.status='rejected' from public.service_offers o where o.user_id=(select auth.uid())
    union all
    select 'service_request',r.id,r.public_code,r.title,r.status,r.updated_at,'/my-services',r.status='rejected' from public.service_requests r where r.user_id=(select auth.uid())
    union all
    select 'service_match',sm.id,case when o.user_id=(select auth.uid()) then o.public_code else r.public_code end,
      case when o.user_id=(select auth.uid()) then o.title else r.title end,sm.status,sm.updated_at,'/my-services',sm.status='proposed'
    from public.service_matches sm join public.service_offers o on o.id=sm.service_offer_id join public.service_requests r on r.id=sm.service_request_id
    where o.user_id=(select auth.uid()) or r.user_id=(select auth.uid())
  ) operations(operation_kind,operation_id,public_code,title,status,updated_at,action_route,requires_action)
  order by operations.requires_action desc,operations.updated_at desc limit greatest(1,least(coalesce(p_limit,100),200));
$$;

revoke all on function public.recovery_code(text) from public,anon,authenticated;
revoke all on function public.admin_create_warehouse(text,text,uuid,text) from public,anon;
revoke all on function public.admin_inventory_intake_candidates() from public,anon;
revoke all on function public.admin_receive_inventory_item(uuid,uuid,text) from public,anon;
revoke all on function public.admin_inspect_inventory_item(uuid,text,text,integer) from public,anon;
revoke all on function public.admin_advance_item_work_order(uuid,text,integer,text) from public,anon;
revoke all on function public.admin_confirm_item_recycling(uuid,text,numeric,integer,text) from public,anon;
revoke all on function public.admin_inventory_queue() from public,anon;
revoke all on function public.admin_inventory_summary() from public,anon;
revoke all on function public.admin_recovery_priorities(integer) from public,anon;
revoke all on function public.notify_inventory_status() from public,anon,authenticated;
revoke all on function public.user_operations_center(integer) from public,anon;
grant execute on function public.admin_create_warehouse(text,text,uuid,text) to authenticated;
grant execute on function public.recovery_code(text) to authenticated;
grant execute on function public.admin_inventory_intake_candidates() to authenticated;
grant execute on function public.admin_receive_inventory_item(uuid,uuid,text) to authenticated;
grant execute on function public.admin_inspect_inventory_item(uuid,text,text,integer) to authenticated;
grant execute on function public.admin_advance_item_work_order(uuid,text,integer,text) to authenticated;
grant execute on function public.admin_confirm_item_recycling(uuid,text,numeric,integer,text) to authenticated;
grant execute on function public.admin_inventory_queue() to authenticated;
grant execute on function public.admin_inventory_summary() to authenticated;
grant execute on function public.admin_recovery_priorities(integer) to authenticated;
grant execute on function public.user_operations_center(integer) to authenticated;

comment on table public.inventory_items is 'One privacy-protected recovery/inventory record per non-food, non-medical donated item.';
comment on table public.inventory_events is 'Append-only operational evidence for intake, inspection, processing and recycling transitions.';
