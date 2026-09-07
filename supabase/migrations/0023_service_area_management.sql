create or replace function public.admin_create_service_area(p_code text,p_name_ar text,p_kind text,p_parent_id uuid default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid; v_code text:=upper(trim(p_code)); v_name text:=trim(p_name_ar); begin
  if not public.is_admin() then raise exception 'admin required'; end if;
  if v_code !~ '^[A-Z0-9_-]{2,30}$' then raise exception 'invalid area code'; end if;
  if length(v_name)<2 then raise exception 'area name required'; end if;
  if p_kind not in ('city','area') then raise exception 'invalid area kind'; end if;
  if p_kind='area' and p_parent_id is null then raise exception 'parent city/area required'; end if;
  if p_parent_id is not null and not exists(select 1 from public.service_areas where id=p_parent_id and active) then raise exception 'invalid parent'; end if;
  insert into public.service_areas(code,name_ar,kind,parent_id) values(v_code,v_name,p_kind,p_parent_id) returning id into v_id;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values((select auth.uid()),'create_service_area','service_area',v_id,jsonb_build_object('code',v_code,'name_ar',v_name,'kind',p_kind,'parent_id',p_parent_id));
  return v_id;
end $$;

create or replace function public.admin_set_service_area_active(p_area_id uuid,p_active boolean)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not public.is_admin() then raise exception 'admin required'; end if;
  if not p_active and exists(select 1 from public.staff_area_assignments where area_id=p_area_id) then raise exception 'area has assigned staff'; end if;
  update public.service_areas set active=p_active where id=p_area_id;
  if not found then raise exception 'area not found'; end if;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values((select auth.uid()),case when p_active then 'activate_service_area' else 'deactivate_service_area' end,'service_area',p_area_id,'{}'::jsonb);
end $$;

revoke all on function public.admin_create_service_area(text,text,text,uuid) from public;
revoke all on function public.admin_set_service_area_active(uuid,boolean) from public;
grant execute on function public.admin_create_service_area(text,text,text,uuid) to authenticated;
grant execute on function public.admin_set_service_area_active(uuid,boolean) to authenticated;
