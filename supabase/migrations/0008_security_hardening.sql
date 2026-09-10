-- Sanad V1 critical privilege hardening.
-- RLS controls rows; column grants below prevent clients from mutating privileged fields.

-- Profiles: normal authenticated users may only edit their own human-facing profile fields.
revoke update on public.profiles from authenticated;
grant update(full_name, phone) on public.profiles to authenticated;

-- Needs/donations: clients create records but may not directly change workflow state or ownership.
revoke update on public.needs from authenticated;
revoke update on public.donations from authenticated;
grant update(description, reason, accepts_used, address_id) on public.needs to authenticated;
grant update(description, condition, address_id) on public.donations to authenticated;

-- Contributions are immutable from the client after creation; verification is admin RPC only.
revoke update, delete on public.contributions from authenticated;

-- Operational tables must never be generally readable.
alter table public.couriers enable row level security;
alter table public.vehicles enable row level security;

-- 0003 already creates this policy. Replace it during a clean replay.
drop policy if exists "courier_self_select" on public.couriers;
create policy "courier_self_select" on public.couriers for select using (user_id=auth.uid());
create policy "admin_couriers_select" on public.couriers for select using (public.is_admin());
create policy "admin_vehicles_select" on public.vehicles for select using (public.is_admin());

-- No client direct mutation of privileged operational tables.
revoke insert, update, delete on public.matches from authenticated;
revoke insert, update, delete on public.deliveries from authenticated;
revoke insert, update, delete on public.delivery_events from authenticated;
revoke insert, update, delete on public.risk_flags from authenticated;
revoke insert, update, delete on public.audit_logs from authenticated;
revoke insert, update, delete on public.couriers from authenticated;
revoke insert, update, delete on public.vehicles from authenticated;
revoke insert, update, delete on public.delivery_failures from authenticated;

create or replace function public.user_cancel_need(p_need_id uuid)
returns void
language plpgsql
security definer
set search_path=public
as $$
begin
  update needs
     set status='cancelled', updated_at=now()
   where id=p_need_id
     and user_id=auth.uid()
     and status in ('submitted','waiting','candidate_found','confirmed');
  if not found then raise exception 'need cannot be cancelled'; end if;
  insert into audit_logs(actor_id,action,entity_type,entity_id)
  values(auth.uid(),'cancel_need','need',p_need_id);
end;
$$;

create or replace function public.user_cancel_donation(p_donation_id uuid)
returns void
language plpgsql
security definer
set search_path=public
as $$
begin
  update donations
     set status='cancelled', updated_at=now()
   where id=p_donation_id
     and user_id=auth.uid()
     and status in ('draft','submitted','under_review','available');
  if not found then raise exception 'donation cannot be cancelled'; end if;
  insert into audit_logs(actor_id,action,entity_type,entity_id)
  values(auth.uid(),'cancel_donation','donation',p_donation_id);
end;
$$;

-- Ensure public helper functions are callable by authenticated clients only where intended.
revoke all on function public.admin_match_candidates(uuid,integer) from public;
revoke all on function public.admin_approve_match(uuid,uuid) from public;
revoke all on function public.admin_create_delivery(uuid,uuid,uuid,text,text) from public;
revoke all on function public.admin_verify_contribution(uuid,boolean,text) from public;
revoke all on function public.admin_resolve_risk(uuid,text) from public;
revoke all on function public.admin_set_user_suspension(uuid,boolean,text) from public;
revoke all on function public.courier_task_details(uuid) from public;
revoke all on function public.courier_report_delivery_failure(uuid,text,text,text,double precision,double precision) from public;
revoke all on function public.verify_delivery_pin(uuid,text,text,double precision,double precision) from public;

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
