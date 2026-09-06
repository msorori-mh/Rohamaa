-- Sanad V1: tighten Data API privileges. All app operations require Google-authenticated sessions.

-- Anonymous users need no table/sequence/function access in V1.
revoke all privileges on all tables in schema public from anon;
revoke all privileges on all sequences in schema public from anon;
revoke all privileges on all functions in schema public from anon;

-- Remove broad object-management privileges from authenticated clients.
revoke truncate, trigger, references on all tables in schema public from authenticated;

-- Community-facing tables.
grant select on public.profiles to authenticated;
grant select, insert, update, delete on public.addresses to authenticated;
grant select, insert on public.needs to authenticated;
grant select, insert on public.donations to authenticated;
grant select, insert, delete on public.donation_images to authenticated;
grant select, insert on public.contributions to authenticated;

-- Operational tables are readable only when their RLS policies allow it.
grant select on public.matches to authenticated;
grant select on public.couriers to authenticated;
grant select on public.vehicles to authenticated;
grant select on public.deliveries to authenticated;
grant select on public.delivery_events to authenticated;
grant select on public.delivery_failures to authenticated;
grant select on public.risk_flags to authenticated;
grant select on public.audit_logs to authenticated;

-- Identity-backed tables use UUID/default values, but keep identity sequence access narrow.
grant usage, select on all sequences in schema public to authenticated;

-- Trigger/internal helpers are not public API endpoints.
revoke all on function public.handle_new_user() from anon, authenticated;
revoke all on function public.flag_need_risk() from anon, authenticated;
revoke all on function public.flag_address_churn() from anon, authenticated;
revoke all on function public.generate_public_code(text) from anon, authenticated;
revoke all on function public.is_admin() from anon;
revoke all on function public.is_courier() from anon;

-- Policy evaluation and application RPCs require authenticated execution.
grant execute on function public.is_admin() to authenticated;
grant execute on function public.is_courier() to authenticated;
grant execute on function public.admin_match_candidates(uuid,integer) to authenticated;
grant execute on function public.admin_approve_match(uuid,uuid) to authenticated;
grant execute on function public.admin_create_delivery(uuid,uuid,uuid,text,text) to authenticated;
grant execute on function public.admin_verify_contribution(uuid,boolean,text) to authenticated;
grant execute on function public.admin_resolve_risk(uuid,text) to authenticated;
grant execute on function public.admin_set_user_suspension(uuid,boolean,text) to authenticated;
grant execute on function public.courier_task_details(uuid) to authenticated;
grant execute on function public.courier_report_delivery_failure(uuid,text,text,text,double precision,double precision) to authenticated;
grant execute on function public.verify_delivery_pin(uuid,text,text,double precision,double precision) to authenticated;
grant execute on function public.user_cancel_need(uuid) to authenticated;
grant execute on function public.user_cancel_donation(uuid) to authenticated;
