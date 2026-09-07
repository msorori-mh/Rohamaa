-- Performance hardening for the new Category V2 / reviewed-needs / service partner features.
-- Keep existing unused indexes during the pilot; low traffic can make useful indexes appear unused.

create index if not exists account_deletion_requests_user_idx
  on public.account_deletion_requests(user_id);
create index if not exists donations_inspired_discovery_card_idx
  on public.donations(inspired_by_discovery_card_id)
  where inspired_by_discovery_card_id is not null;
create index if not exists need_discovery_cards_published_by_idx
  on public.need_discovery_cards(published_by)
  where published_by is not null;
create index if not exists service_incidents_reporter_idx
  on public.service_incidents(reporter_user_id, created_at desc);
create index if not exists service_incidents_resolved_by_idx
  on public.service_incidents(resolved_by)
  where resolved_by is not null;
create index if not exists service_matches_request_idx
  on public.service_matches(service_request_id, status, created_at);
create index if not exists service_matches_approved_by_idx
  on public.service_matches(approved_by)
  where approved_by is not null;
create index if not exists service_offers_user_idx
  on public.service_offers(user_id, created_at desc);
create index if not exists service_offers_area_idx
  on public.service_offers(service_area_id, category, status)
  where service_area_id is not null;
create index if not exists service_requests_user_idx
  on public.service_requests(user_id, created_at desc);
create index if not exists service_requests_area_idx
  on public.service_requests(service_area_id, category, status)
  where service_area_id is not null;
create index if not exists service_partners_area_idx
  on public.service_partners(service_area_id, verification_status)
  where service_area_id is not null;
create index if not exists service_partners_verified_by_idx
  on public.service_partners(verified_by)
  where verified_by is not null;

-- service_partners mutations are RPC-only after 0045. Keep one combined SELECT policy
-- and remove obsolete direct-mutation/admin-all policies to avoid duplicate evaluation.
drop policy if exists "partners_owner_insert" on public.service_partners;
drop policy if exists "partners_owner_update" on public.service_partners;
drop policy if exists "partners_admin_all" on public.service_partners;

-- partners_owner_select already covers owner OR admin.

-- service_incidents reporter SELECT already includes admins; participant INSERT is sufficient.
-- Replace the broad admin ALL policy with mutation-specific admin policies.
drop policy if exists "service_incidents_admin_all" on public.service_incidents;

create policy "service_incidents_admin_update"
on public.service_incidents for update to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "service_incidents_admin_delete"
on public.service_incidents for delete to authenticated
using (public.is_admin());
