-- P2 advisor hardening: cover every new foreign key that can participate in
-- parent updates/deletes or operational joins.

create index warehouses_service_area_idx on public.warehouses(service_area_id) where service_area_id is not null;
create index warehouses_created_by_idx on public.warehouses(created_by);
create index inventory_items_inspected_by_idx on public.inventory_items(inspected_by) where inspected_by is not null;
create index item_work_orders_assigned_by_idx on public.item_work_orders(assigned_by) where assigned_by is not null;
create index item_recycling_partner_idx on public.item_recycling_records(partner_id) where partner_id is not null;
create index item_recycling_confirmed_by_idx on public.item_recycling_records(confirmed_by) where confirmed_by is not null;
create index inventory_events_actor_idx on public.inventory_events(actor_id) where actor_id is not null;
