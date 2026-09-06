create or replace function public.staff_report_couriers(p_from date,p_to date,p_area_id uuid default null)
returns table(courier_id uuid,courier_name text,assigned bigint,delivered bigint,unsuccessful bigint,success_rate numeric,avg_delivery_hours numeric)
language plpgsql security definer set search_path=public as $$
begin
  if not(public.is_admin() or public.is_supervisor()) then raise exception 'staff required'; end if;
  if p_area_id is not null and not public.staff_can_access_area(p_area_id) then raise exception 'area access denied'; end if;
  return query
  select del.courier_id,coalesce(p.full_name,'موصل بدون اسم')::text,count(*)::bigint,
    count(*) filter(where del.status='delivered')::bigint,
    count(*) filter(where del.status in('failed','rescheduled'))::bigint,
    case when count(*)=0 then 0 else round((count(*) filter(where del.status='delivered')::numeric/count(*))*100,1) end,
    coalesce(round(avg(extract(epoch from(del.delivered_at-del.assigned_at))/3600.0) filter(where del.delivered_at is not null and del.assigned_at is not null)::numeric,1),0)
  from public.deliveries del
  join public.profiles p on p.id=del.courier_id
  join public.matches m on m.id=del.match_id
  join public.donations d on d.id=m.donation_id
  left join public.addresses a on a.id=d.address_id
  where del.created_at::date between p_from and p_to and del.courier_id is not null
    and (public.is_admin() or (a.service_area_id is not null and public.staff_can_access_area(a.service_area_id)))
    and (p_area_id is null or (a.service_area_id is not null and public.area_is_within(a.service_area_id,p_area_id)))
  group by del.courier_id,p.full_name order by 4 desc,3 desc;
end $$;
revoke execute on function public.staff_report_couriers(date,date,uuid) from anon, public;
grant execute on function public.staff_report_couriers(date,date,uuid) to authenticated;
