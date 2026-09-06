-- Supabase Advisor hardening for Sanad pilot.

alter function public.distance_km(double precision,double precision,double precision,double precision) set search_path = public;
alter function public.hash_pin(text) set search_path = public;

revoke execute on function public.distance_km(double precision,double precision,double precision,double precision) from public, anon, authenticated;
revoke execute on function public.hash_pin(text) from public, anon, authenticated;

create index if not exists audit_logs_actor_id_idx on public.audit_logs(actor_id);
create index if not exists contributions_delivery_id_idx on public.contributions(delivery_id);
create index if not exists contributions_donation_id_idx on public.contributions(donation_id);
create index if not exists contributions_need_id_idx on public.contributions(need_id);
create index if not exists contributions_verified_by_idx on public.contributions(verified_by);
create index if not exists deliveries_vehicle_id_idx on public.deliveries(vehicle_id);
create index if not exists delivery_events_actor_id_idx on public.delivery_events(actor_id);
create index if not exists delivery_events_delivery_id_idx on public.delivery_events(delivery_id);
create index if not exists donation_images_donation_id_idx on public.donation_images(donation_id);
create index if not exists donations_address_id_idx on public.donations(address_id);
create index if not exists matches_approved_by_idx on public.matches(approved_by);
create index if not exists matches_need_id_idx on public.matches(need_id);
create index if not exists needs_address_id_idx on public.needs(address_id);
create index if not exists risk_flags_delivery_id_idx on public.risk_flags(delivery_id);
create index if not exists risk_flags_donation_id_idx on public.risk_flags(donation_id);
create index if not exists risk_flags_need_id_idx on public.risk_flags(need_id);
create index if not exists risk_flags_resolved_by_idx on public.risk_flags(resolved_by);
create index if not exists risk_flags_user_id_idx on public.risk_flags(user_id);
