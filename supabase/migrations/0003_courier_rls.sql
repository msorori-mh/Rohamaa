-- Courier-scoped read access. Sensitive counterpart identity/address data must be exposed later through narrow RPCs/views.

alter table public.couriers enable row level security;
alter table public.vehicles enable row level security;

create policy "courier_self_select" on public.couriers
for select to authenticated
using (user_id = auth.uid());

create policy "courier_assigned_deliveries_select" on public.deliveries
for select to authenticated
using (courier_id = auth.uid());

create policy "courier_delivery_events_insert" on public.delivery_events
for insert to authenticated
with check (
  actor_id = auth.uid()
  and exists (
    select 1 from public.deliveries d
    where d.id = delivery_id and d.courier_id = auth.uid()
  )
);
