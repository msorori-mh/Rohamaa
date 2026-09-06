-- Sanad Marib pilot assets.
insert into public.vehicles(code,kind,active,notes)
values
  ('BIKE-01','electric_motorbike',true,'Pilot electric delivery motorbike #1'),
  ('BIKE-02','electric_motorbike',true,'Pilot electric delivery motorbike #2')
on conflict (code) do update
set active=excluded.active,
    kind=excluded.kind,
    notes=excluded.notes;
