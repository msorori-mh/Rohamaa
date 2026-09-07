alter table public.profiles add column if not exists staff_email text;
create unique index if not exists profiles_staff_email_unique on public.profiles(lower(staff_email)) where staff_email is not null;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_primary boolean := lower(coalesce(new.email,''))=lower('msorori201201@gmail.com');
begin
  insert into public.profiles(id,full_name,role,is_primary_admin,force_password_change,staff_email,created_at,updated_at)
  values(new.id,coalesce(new.raw_user_meta_data->>'full_name',new.raw_user_meta_data->>'name'),case when v_primary then 'admin'::public.user_role else 'user'::public.user_role end,v_primary,v_primary,case when v_primary then lower(new.email) else null end,now(),now())
  on conflict(id) do update set
    full_name=coalesce(excluded.full_name,public.profiles.full_name),
    role=case when v_primary then 'admin'::public.user_role else public.profiles.role end,
    is_primary_admin=case when v_primary then true else public.profiles.is_primary_admin end,
    force_password_change=case when v_primary and public.profiles.password_changed_at is null then true else public.profiles.force_password_change end,
    staff_email=case when v_primary then lower(new.email) else public.profiles.staff_email end,
    updated_at=now();
  return new;
end $$;

create or replace function public.admin_set_user_role(p_user_id uuid,p_role public.user_role)
returns void language plpgsql security definer set search_path=public as $$
declare v_primary boolean; begin
  if not public.is_admin() then raise exception 'admin required'; end if;
  select is_primary_admin into v_primary from public.profiles where id=p_user_id;
  if coalesce(v_primary,false) then raise exception 'primary admin role cannot be changed'; end if;
  if p_role='admin' then raise exception 'creating additional admins is disabled'; end if;
  if p_role not in ('user','courier','supervisor') then raise exception 'invalid role'; end if;
  update public.profiles set role=p_role,updated_at=now() where id=p_user_id;
  if p_role='courier' then
    insert into public.couriers(user_id,active) values(p_user_id,true) on conflict(user_id) do update set active=true;
  else update public.couriers set active=false where user_id=p_user_id; end if;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values((select auth.uid()),'set_user_role','profile',p_user_id,jsonb_build_object('role',p_role));
end $$;
revoke all on function public.admin_set_user_role(uuid,public.user_role) from public;
grant execute on function public.admin_set_user_role(uuid,public.user_role) to authenticated;
