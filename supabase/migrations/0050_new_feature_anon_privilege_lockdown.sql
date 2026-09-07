-- Anonymous visitors do not need direct table access to the new operational features.
-- Authentication/public intro/legal routes do not depend on these grants.

revoke all privileges on table public.service_partners from anon;
revoke all privileges on table public.service_incidents from anon;
revoke all privileges on table public.service_offers from anon;
revoke all privileges on table public.service_requests from anon;
revoke all privileges on table public.service_matches from anon;
revoke all privileges on table public.need_discovery_cards from anon;

-- Explicit authenticated privileges required by the Flutter client.
-- service_partners: direct read only; mutations are RPC-mediated.
grant select on table public.service_partners to authenticated;

-- incidents: participants create/read; admin resolves under RLS/RPC.
grant select, insert, update on table public.service_incidents to authenticated;

-- time/skills app workflows.
grant select, insert, update on table public.service_offers to authenticated;
grant select, insert, update on table public.service_requests to authenticated;
grant select, insert, update, delete on table public.service_matches to authenticated;

-- staff reviewed-needs administration reads snapshots directly;
-- publish/unpublish remains RPC mediated.
grant select on table public.need_discovery_cards to authenticated;
