-- Close the remaining unindexed FK notices and remove duplicate SELECT evaluation
-- from the time/skills service_matches policies.

create index if not exists operating_expenses_area_idx
  on public.operating_expenses(area_id, expense_date desc);
create index if not exists operating_expenses_created_by_idx
  on public.operating_expenses(created_by)
  where created_by is not null;
create index if not exists profiles_staff_created_by_idx
  on public.profiles(staff_created_by)
  where staff_created_by is not null;
create index if not exists service_areas_parent_idx
  on public.service_areas(parent_id)
  where parent_id is not null;
create index if not exists staff_area_assignments_created_by_idx
  on public.staff_area_assignments(created_by)
  where created_by is not null;

-- users_read_own_service_matches already includes public.is_admin() for SELECT.
-- Replace the broad admin ALL policy with mutation-specific policies.
drop policy if exists "admins_manage_service_matches" on public.service_matches;

create policy "admins_insert_service_matches"
on public.service_matches for insert to authenticated
with check (public.is_admin());

create policy "admins_update_service_matches"
on public.service_matches for update to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "admins_delete_service_matches"
on public.service_matches for delete to authenticated
using (public.is_admin());
