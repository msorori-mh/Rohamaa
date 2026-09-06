create or replace function public.staff_report_daily(p_from date,p_to date,p_area_id uuid default null)
returns table(day date,donations bigint,needs bigint,delivered bigint,verified_contributions_yer bigint)
language plpgsql security definer set search_path=public as $$
begin
  if not(public.is_admin() or public.is_supervisor()) then raise exception 'staff required'; end if;
  if p_area_id is not null and not public.staff_can_access_area(p_area_id) then raise exception 'area access denied'; end if;
  return query
  with days as (select generate_series(p_from,p_to,interval '1 day')::date d),
  d1 as (select d.created_at::date d,count(*) c from public.donations d left join public.addresses a on a.id=d.address_id where d.created_at::date between p_from and p_to and (public.is_admin() or public.staff_can_access_area(a.service_area_id)) and (p_area_id is null or public.area_is_within(a.service_area_id,p_area_id)) group by 1),
  n1 as (select n.created_at::date d,count(*) c from public.needs n left join public.addresses a on a.id=n.address_id where n.created_at::date between p_from and p_to and (public.is_admin() or public.staff_can_access_area(a.service_area_id)) and (p_area_id is null or public.area_is_within(a.service_area_id,p_area_id)) group by 1),
  x1 as (select del.delivered_at::date d,count(*) c from public.deliveries del join public.matches m on m.id=del.match_id join public.donations dn on dn.id=m.donation_id left join public.addresses a on a.id=dn.address_id where del.status='delivered' and del.delivered_at::date between p_from and p_to and (public.is_admin() or public.staff_can_access_area(a.service_area_id)) and (p_area_id is null or public.area_is_within(a.service_area_id,p_area_id)) group by 1),
  c1 as (select c.created_at::date d,coalesce(sum(c.amount_yer),0)::bigint s from public.contributions c where c.status='verified' and c.created_at::date between p_from and p_to group by 1)
  select days.d,coalesce(d1.c,0),coalesce(n1.c,0),coalesce(x1.c,0),coalesce(c1.s,0)
  from days left join d1 on d1.d=days.d left join n1 on n1.d=days.d left join x1 on x1.d=days.d left join c1 on c1.d=days.d order by days.d;
end $$;
revoke all on function public.staff_report_daily(date,date,uuid) from public;
grant execute on function public.staff_report_daily(date,date,uuid) to authenticated;
