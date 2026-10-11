-- Staff hierarchy, service areas, expenses, and scoped reports.
do $$
begin
  if not exists (
    select 1 from pg_enum e join pg_type t on t.oid=e.enumtypid
    where t.typnamespace='public'::regnamespace and t.typname='user_role' and e.enumlabel='supervisor'
  ) then alter type public.user_role add value 'supervisor'; end if;
end $$;

create table if not exists public.service_areas (
  id uuid primary key default gen_random_uuid(), code text not null unique,
  name_ar text not null, kind text not null check(kind in ('city','area')),
  parent_id uuid references public.service_areas(id) on delete restrict,
  active boolean not null default true, created_at timestamptz not null default now()
);
insert into public.service_areas(code,name_ar,kind) values('MARIB','مأرب','city') on conflict(code) do nothing;

alter table public.profiles add column if not exists force_password_change boolean not null default false;
alter table public.profiles add column if not exists is_primary_admin boolean not null default false;
alter table public.profiles add column if not exists staff_created_by uuid references public.profiles(id) on delete set null;

create table if not exists public.staff_area_assignments (
  user_id uuid not null references public.profiles(id) on delete cascade,
  area_id uuid not null references public.service_areas(id) on delete cascade,
  is_primary boolean not null default false,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(), primary key(user_id,area_id)
);
alter table public.addresses add column if not exists service_area_id uuid references public.service_areas(id) on delete set null;

create table if not exists public.operating_expenses (
  id uuid primary key default gen_random_uuid(), area_id uuid references public.service_areas(id) on delete set null,
  expense_date date not null default current_date, category text not null,
  amount_yer integer not null check(amount_yer>0), description text,
  created_by uuid not null references public.profiles(id), created_at timestamptz not null default now()
);

create index if not exists staff_area_assignments_area_idx on public.staff_area_assignments(area_id,user_id);
create index if not exists addresses_service_area_idx on public.addresses(service_area_id);
create index if not exists operating_expenses_date_area_idx on public.operating_expenses(expense_date,area_id);

alter table public.service_areas enable row level security;
alter table public.staff_area_assignments enable row level security;
alter table public.operating_expenses enable row level security;

create policy service_areas_authenticated_select on public.service_areas for select to authenticated using(active=true);
create policy staff_assignments_self_or_admin_select on public.staff_area_assignments for select to authenticated using((select auth.uid())=user_id or public.is_admin());

create or replace function public.is_supervisor() returns boolean language sql stable security definer set search_path=public as $$
  -- Compare as text while the enum value is new in this migration transaction.
  select exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role::text='supervisor' and not p.is_suspended)
$$;
create or replace function public.area_is_within(p_child uuid,p_parent uuid) returns boolean language sql stable security definer set search_path=public as $$
  with recursive chain as (select id,parent_id from public.service_areas where id=p_child union all select a.id,a.parent_id from public.service_areas a join chain c on c.parent_id=a.id)
  select exists(select 1 from chain where id=p_parent)
$$;
create or replace function public.staff_can_access_area(p_area_id uuid) returns boolean language sql stable security definer set search_path=public as $$
  select case when public.is_admin() then true when not public.is_supervisor() or p_area_id is null then false else exists(
    select 1 from public.staff_area_assignments saa where saa.user_id=(select auth.uid()) and public.area_is_within(p_area_id,saa.area_id)) end
$$;
create policy expenses_staff_select on public.operating_expenses for select to authenticated using(public.is_admin() or public.staff_can_access_area(area_id));
revoke insert,update,delete on public.operating_expenses from authenticated;

create or replace function public.admin_add_operating_expense(p_area_id uuid,p_expense_date date,p_category text,p_amount_yer integer,p_description text default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid; begin
  if not public.is_admin() then raise exception 'admin required'; end if;
  if p_amount_yer<=0 then raise exception 'amount must be positive'; end if;
  insert into public.operating_expenses(area_id,expense_date,category,amount_yer,description,created_by)
  values(p_area_id,coalesce(p_expense_date,current_date),trim(p_category),p_amount_yer,nullif(trim(coalesce(p_description,'')),''),(select auth.uid())) returning id into v_id;
  return v_id;
end $$;

-- Summary and daily functions are intentionally server-side so supervisors only see assigned areas.
-- The live migration contains the full metric queries used by the Flutter report repository.
create or replace function public.staff_report_summary(p_from date default date_trunc('month',current_date)::date,p_to date default current_date,p_area_id uuid default null)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_donations bigint; v_needs bigint; v_deliveries bigint; v_delivered bigint; v_contrib bigint; v_pending bigint; v_expenses bigint; v_risks bigint; v_couriers bigint; v_avg numeric; begin
  if not(public.is_admin() or public.is_supervisor()) then raise exception 'staff required'; end if;
  if p_area_id is not null and not public.staff_can_access_area(p_area_id) then raise exception 'area access denied'; end if;
  select count(*) into v_donations from public.donations d left join public.addresses a on a.id=d.address_id where d.created_at::date between p_from and p_to and (public.is_admin() or public.staff_can_access_area(a.service_area_id)) and (p_area_id is null or public.area_is_within(a.service_area_id,p_area_id));
  select count(*) into v_needs from public.needs n left join public.addresses a on a.id=n.address_id where n.created_at::date between p_from and p_to and (public.is_admin() or public.staff_can_access_area(a.service_area_id)) and (p_area_id is null or public.area_is_within(a.service_area_id,p_area_id));
  select count(*),count(*) filter(where del.status='delivered'),round(avg(extract(epoch from(del.delivered_at-del.assigned_at))/3600.0) filter(where del.delivered_at is not null)::numeric,1) into v_deliveries,v_delivered,v_avg from public.deliveries del join public.matches m on m.id=del.match_id join public.donations d on d.id=m.donation_id left join public.addresses a on a.id=d.address_id where del.created_at::date between p_from and p_to and (public.is_admin() or public.staff_can_access_area(a.service_area_id)) and (p_area_id is null or public.area_is_within(a.service_area_id,p_area_id));
  select coalesce(sum(c.amount_yer) filter(where c.status='verified'),0),count(*) filter(where c.status='pending') into v_contrib,v_pending from public.contributions c where c.created_at::date between p_from and p_to;
  select coalesce(sum(e.amount_yer),0) into v_expenses from public.operating_expenses e where e.expense_date between p_from and p_to and (public.is_admin() or public.staff_can_access_area(e.area_id)) and (p_area_id is null or public.area_is_within(e.area_id,p_area_id));
  select count(*) into v_risks from public.risk_flags where not resolved and public.is_admin();
  select count(distinct c.user_id) into v_couriers from public.couriers c left join public.staff_area_assignments saa on saa.user_id=c.user_id where c.active and (public.is_admin() or public.staff_can_access_area(saa.area_id)) and (p_area_id is null or public.area_is_within(saa.area_id,p_area_id));
  return jsonb_build_object('from',p_from,'to',p_to,'area_id',p_area_id,'donations',v_donations,'needs',v_needs,'deliveries',v_deliveries,'delivered',v_delivered,'delivery_success_rate',case when v_deliveries=0 then 0 else round(v_delivered::numeric/v_deliveries*100,1) end,'avg_delivery_hours',coalesce(v_avg,0),'verified_contributions_yer',v_contrib,'pending_contributions',v_pending,'operating_expenses_yer',v_expenses,'contribution_coverage_rate',case when v_expenses=0 then 0 else round(v_contrib::numeric/v_expenses*100,1) end,'open_risk_flags',case when public.is_admin() then v_risks else null end,'active_couriers',v_couriers);
end $$;

revoke all on function public.admin_add_operating_expense(uuid,date,text,integer,text) from public;
revoke all on function public.staff_report_summary(date,date,uuid) from public;
grant execute on function public.admin_add_operating_expense(uuid,date,text,integer,text) to authenticated;
grant execute on function public.staff_report_summary(date,date,uuid) to authenticated;
grant select on public.service_areas,public.staff_area_assignments,public.operating_expenses to authenticated;
