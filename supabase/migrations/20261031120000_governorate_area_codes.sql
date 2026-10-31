-- Governorates (محافظات) are a fixed list with stable codes. Areas created under a
-- governorate get an automatic code: <GOVERNORATE_CODE>-<3-digit sequence>, e.g. SAN-001.
-- Admins choose the governorate and type only the area name; they never type codes.

alter table public.service_areas add column if not exists seq integer;
create unique index if not exists service_areas_parent_seq_uidx
  on public.service_areas(parent_id, seq) where seq is not null;

-- Seed the 22 governorates. Marib keeps its existing code MARIB.
insert into public.service_areas(code, name_ar, kind) values
  ('SAA',  'أمانة العاصمة', 'city'),
  ('SAN',  'صنعاء',         'city'),
  ('ADN',  'عدن',           'city'),
  ('TAI',  'تعز',           'city'),
  ('HOD',  'الحديدة',       'city'),
  ('IBB',  'إب',            'city'),
  ('DHM',  'ذمار',          'city'),
  ('BAY',  'البيضاء',       'city'),
  ('LAH',  'لحج',           'city'),
  ('ABN',  'أبين',          'city'),
  ('SHB',  'شبوة',          'city'),
  ('HAD',  'حضرموت',        'city'),
  ('MAH',  'المهرة',        'city'),
  ('SOC',  'سقطرى',         'city'),
  ('DAL',  'الضالع',        'city'),
  ('HAJ',  'حجة',           'city'),
  ('SAD',  'صعدة',          'city'),
  ('JOF',  'الجوف',         'city'),
  ('AMR',  'عمران',         'city'),
  ('RAY',  'ريمة',          'city'),
  ('MHW',  'المحويت',       'city')
on conflict (code) do nothing;

create or replace function public.admin_create_area(p_name_ar text, p_parent_id uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
  v_parent_code text;
  v_seq integer;
  v_name text := trim(p_name_ar);
begin
  if not public.is_admin() then raise exception 'admin required'; end if;
  if length(v_name) < 2 then raise exception 'area name required'; end if;
  if p_parent_id is null then raise exception 'governorate required'; end if;

  -- Lock the governorate row so two concurrent inserts cannot take the same sequence.
  select code into v_parent_code from public.service_areas
    where id = p_parent_id and kind = 'city' and active for update;
  if v_parent_code is null then raise exception 'invalid governorate'; end if;

  select coalesce(max(seq), 0) + 1 into v_seq from public.service_areas where parent_id = p_parent_id;

  insert into public.service_areas(code, name_ar, kind, parent_id, seq)
  values (v_parent_code || '-' || lpad(v_seq::text, 3, '0'), v_name, 'area', p_parent_id, v_seq)
  returning id into v_id;

  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  values ((select auth.uid()), 'create_service_area', 'service_area', v_id,
          jsonb_build_object('name_ar', v_name, 'kind', 'area', 'parent_id', p_parent_id, 'seq', v_seq));
  return v_id;
end $$;

revoke all on function public.admin_create_area(text, uuid) from public;
grant execute on function public.admin_create_area(text, uuid) to authenticated;
