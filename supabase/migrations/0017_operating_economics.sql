-- Sanad V1: operating economics for the Marib pilot.

create table public.operating_expenses (
  id uuid primary key default gen_random_uuid(),
  category text not null check (category in ('courier_salary','vehicle_maintenance','electricity','telecom','hosting','supplies','other')),
  amount_yer integer not null check (amount_yer > 0),
  expense_date date not null default current_date,
  note text,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

alter table public.operating_expenses enable row level security;
create policy "admin_operating_expenses_select" on public.operating_expenses
for select to authenticated using (public.is_admin());

revoke all on public.operating_expenses from anon;
revoke insert,update,delete,truncate,trigger,references on public.operating_expenses from authenticated;
grant select on public.operating_expenses to authenticated;

create or replace function public.admin_add_operating_expense(
  p_category text,
  p_amount_yer integer,
  p_expense_date date default current_date,
  p_note text default null
)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_id uuid;
begin
  if not public.is_admin() then raise exception 'admin required'; end if;
  if p_category not in ('courier_salary','vehicle_maintenance','electricity','telecom','hosting','supplies','other') then
    raise exception 'invalid expense category';
  end if;
  if p_amount_yer<=0 then raise exception 'amount must be positive'; end if;

  insert into operating_expenses(category,amount_yer,expense_date,note,created_by)
  values(p_category,p_amount_yer,coalesce(p_expense_date,current_date),p_note,auth.uid())
  returning id into v_id;

  insert into audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values(auth.uid(),'add_operating_expense','operating_expense',v_id,
         jsonb_build_object('category',p_category,'amount_yer',p_amount_yer,'expense_date',p_expense_date,'note',p_note));
  return v_id;
end;
$$;

create or replace function public.admin_operating_metrics(
  p_from date,
  p_to date
)
returns table(
  expense_yer bigint,
  verified_contributions_yer bigint,
  delivered_count bigint,
  cost_per_delivery_yer numeric,
  contribution_coverage_pct numeric
)
language plpgsql
security definer
set search_path=public
as $$
declare
  v_expense bigint;
  v_contrib bigint;
  v_delivered bigint;
begin
  if not public.is_admin() then raise exception 'admin required'; end if;
  if p_to<p_from then raise exception 'invalid date range'; end if;

  select coalesce(sum(amount_yer),0)::bigint into v_expense
  from operating_expenses
  where expense_date between p_from and p_to;

  select coalesce(sum(amount_yer),0)::bigint into v_contrib
  from contributions
  where status='verified'
    and coalesce(verified_at,created_at)>=p_from::timestamptz
    and coalesce(verified_at,created_at)<(p_to+1)::timestamptz;

  select count(*)::bigint into v_delivered
  from deliveries
  where status='delivered'
    and delivered_at>=p_from::timestamptz
    and delivered_at<(p_to+1)::timestamptz;

  return query select
    v_expense,
    v_contrib,
    v_delivered,
    case when v_delivered=0 then null else round(v_expense::numeric/v_delivered,2) end,
    case when v_expense=0 then null else round(v_contrib::numeric*100/v_expense,2) end;
end;
$$;

revoke all on function public.admin_add_operating_expense(text,integer,date,text) from public,anon;
revoke all on function public.admin_operating_metrics(date,date) from public,anon;
grant execute on function public.admin_add_operating_expense(text,integer,date,text) to authenticated;
grant execute on function public.admin_operating_metrics(date,date) to authenticated;

create index operating_expenses_date_idx on public.operating_expenses(expense_date,category);
