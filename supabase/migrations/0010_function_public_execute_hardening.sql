-- PostgreSQL grants EXECUTE on new functions to PUBLIC by default.
-- Sanad explicitly exposes only authenticated application RPCs.

revoke all on all functions in schema public from public;

-- Helpers used by RLS policies.
grant execute on function public.is_admin() to authenticated;
grant execute on function public.is_courier() to authenticated;

-- User operations.
grant execute on function public.user_cancel_need(uuid) to authenticated;
grant execute on function public.user_cancel_donation(uuid) to authenticated;

-- Courier operations.
grant execute on function public.courier_task_details(uuid) to authenticated;
grant execute on function public.courier_report_delivery_failure(uuid,text,text,text,double precision,double precision) to authenticated;
grant execute on function public.verify_delivery_pin(uuid,text,text,double precision,double precision) to authenticated;

-- Admin operations. Each RPC performs an internal admin role check.
grant execute on function public.admin_match_candidates(uuid,integer) to authenticated;
grant execute on function public.admin_approve_match(uuid,uuid) to authenticated;
grant execute on function public.admin_create_delivery(uuid,uuid,uuid,text,text) to authenticated;
grant execute on function public.admin_verify_contribution(uuid,boolean,text) to authenticated;
grant execute on function public.admin_resolve_risk(uuid,text) to authenticated;
grant execute on function public.admin_set_user_suspension(uuid,boolean,text) to authenticated;
