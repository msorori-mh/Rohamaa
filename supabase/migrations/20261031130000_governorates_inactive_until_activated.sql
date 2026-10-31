-- Governorates stay hidden until an admin activates them for operations.
-- Marib remains active. Admins can read inactive rows so they can activate them.
update public.service_areas set active = false
  where kind = 'city' and code <> 'MARIB' and active;

drop policy if exists service_areas_admin_select on public.service_areas;
create policy service_areas_admin_select on public.service_areas
  for select to authenticated using (public.is_admin());
