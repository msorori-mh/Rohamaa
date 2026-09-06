-- Optimize RLS auth checks and explicitly scope policies to signed-in users.

alter policy profiles_self_select on public.profiles to authenticated using ((select auth.uid()) = id);
alter policy profiles_self_update on public.profiles to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
alter policy admin_profiles_select on public.profiles to authenticated using (public.is_admin());

alter policy addresses_owner_select on public.addresses to authenticated using (user_id = (select auth.uid()));
alter policy addresses_owner_insert on public.addresses to authenticated with check (user_id = (select auth.uid()) and public.is_active_user());
alter policy addresses_owner_update on public.addresses to authenticated using (user_id = (select auth.uid()) and public.is_active_user()) with check (user_id = (select auth.uid()) and public.is_active_user());
alter policy addresses_owner_delete on public.addresses to authenticated using (user_id = (select auth.uid()) and public.is_active_user());
alter policy admin_addresses_select on public.addresses to authenticated using (public.is_admin());

alter policy needs_owner_select on public.needs to authenticated using ((select auth.uid()) = user_id);
alter policy needs_owner_insert on public.needs to authenticated with check (user_id = (select auth.uid()) and public.is_active_user());
alter policy needs_owner_update on public.needs to authenticated using (user_id = (select auth.uid()) and public.is_active_user()) with check (user_id = (select auth.uid()) and public.is_active_user());
alter policy admin_needs_select on public.needs to authenticated using (public.is_admin());

alter policy donations_owner_select on public.donations to authenticated using ((select auth.uid()) = user_id);
alter policy donations_owner_insert on public.donations to authenticated with check (user_id = (select auth.uid()) and public.is_active_user());
alter policy donations_owner_update on public.donations to authenticated using (user_id = (select auth.uid()) and public.is_active_user()) with check (user_id = (select auth.uid()) and public.is_active_user());
alter policy admin_donations_select on public.donations to authenticated using (public.is_admin());

alter policy contributions_owner_select on public.contributions to authenticated using ((select auth.uid()) = user_id);
alter policy contributions_owner_insert on public.contributions to authenticated with check (user_id = (select auth.uid()) and public.is_active_user());
alter policy admin_contributions_select on public.contributions to authenticated using (public.is_admin());

alter policy courier_self_select on public.couriers to authenticated using (user_id = (select auth.uid()));
alter policy admin_couriers_select on public.couriers to authenticated using (public.is_admin());

alter policy courier_assigned_deliveries_select on public.deliveries to authenticated using (courier_id = (select auth.uid()));
alter policy admin_deliveries_select on public.deliveries to authenticated using (public.is_admin());

alter policy courier_delivery_events_insert on public.delivery_events to authenticated with check (
  actor_id = (select auth.uid())
  and exists (select 1 from public.deliveries d where d.id = delivery_id and d.courier_id = (select auth.uid()))
);

alter policy courier_failure_select_own on public.delivery_failures to authenticated using (courier_id = (select auth.uid()));
alter policy admin_failure_select on public.delivery_failures to authenticated using (public.is_admin());

alter policy donation_image_rows_owner_select on public.donation_images to authenticated using (
  exists (select 1 from public.donations d where d.id = donation_id and d.user_id = (select auth.uid()))
);
alter policy donation_image_rows_owner_insert on public.donation_images to authenticated with check (
  public.is_active_user() and exists (select 1 from public.donations d where d.id = donation_id and d.user_id = (select auth.uid()))
);
alter policy donation_image_rows_owner_delete on public.donation_images to authenticated using (
  exists (select 1 from public.donations d where d.id = donation_id and d.user_id = (select auth.uid()))
);

alter policy admin_matches_select on public.matches to authenticated using (public.is_admin());
alter policy admin_risk_flags_select on public.risk_flags to authenticated using (public.is_admin());
alter policy admin_audit_logs_select on public.audit_logs to authenticated using (public.is_admin());
alter policy admin_vehicles_select on public.vehicles to authenticated using (public.is_admin());
