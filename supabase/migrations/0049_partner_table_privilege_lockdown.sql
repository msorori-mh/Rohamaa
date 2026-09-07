-- The client only needs SELECT on service_partners.
-- Registration and verification mutations are RPC-only.

revoke all privileges on table public.service_partners from authenticated;
grant select on table public.service_partners to authenticated;

comment on table public.service_partners is
  'Verified Ruhamaa partner records. Authenticated clients have SELECT only; registration and verification are RPC-mediated.';
