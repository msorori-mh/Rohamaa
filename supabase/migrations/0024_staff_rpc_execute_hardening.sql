revoke execute on function public.admin_add_operating_expense(uuid,date,text,integer,text) from anon, public;
revoke execute on function public.admin_create_service_area(text,text,text,uuid) from anon, public;
revoke execute on function public.admin_set_service_area_active(uuid,boolean) from anon, public;
revoke execute on function public.my_staff_status() from anon, public;
-- A fresh checkout first defines this RPC in 0052, which also applies its
-- grants. Harden it here only on older deployments where it already exists.
do $$
begin
  if to_regprocedure('public.staff_report_daily(date,date,uuid)') is not null then
    revoke execute on function public.staff_report_daily(date,date,uuid) from anon, public;
    grant execute on function public.staff_report_daily(date,date,uuid) to authenticated;
  end if;
end $$;
revoke execute on function public.staff_report_summary(date,date,uuid) from anon, public;
revoke execute on function public.staff_can_access_area(uuid) from anon, public;
revoke execute on function public.is_supervisor() from anon, public;
revoke execute on function public.area_is_within(uuid,uuid) from anon, public;

grant execute on function public.admin_add_operating_expense(uuid,date,text,integer,text) to authenticated;
grant execute on function public.admin_create_service_area(text,text,text,uuid) to authenticated;
grant execute on function public.admin_set_service_area_active(uuid,boolean) to authenticated;
grant execute on function public.my_staff_status() to authenticated;
grant execute on function public.staff_report_summary(date,date,uuid) to authenticated;
grant execute on function public.staff_can_access_area(uuid) to authenticated;

revoke execute on function public.is_supervisor() from authenticated;
revoke execute on function public.area_is_within(uuid,uuid) from authenticated;
