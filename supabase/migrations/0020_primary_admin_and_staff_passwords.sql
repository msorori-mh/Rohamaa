alter table public.profiles add column if not exists password_changed_at timestamptz;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_primary boolean := lower(coalesce(new.email,''))=lower('msorori201201@gmail.com');
begin
  insert into public.profiles(id,full_name,role,is_primary_admin,force_password_change,created_at,updated_at)
  values(new.id,coalesce(new.raw_user_meta_data->>'full_name',new.raw_user_meta_data->>'name'),case when v_primary then 'admin'::public.user_role else 'user'::public.user_role end,v_primary,v_primary,now(),now())
  on conflict(id) do update set
    full_name=coalesce(excluded.full_name,public.profiles.full_name),
    role=case when v_primary then 'admin'::public.user_role else public.profiles.role end,
    is_primary_admin=case when v_primary then true else public.profiles.is_primary_admin end,
    force_password_change=case when v_primary and public.profiles.password_changed_at is null then true else public.profiles.force_password_change end,
    updated_at=now();
  return new;
end $$;

create or replace function public.my_staff_status()
returns table(role public.user_role,force_password_change boolean,is_primary_admin boolean)
language sql stable security definer set search_path=public as $$
  select p.role,p.force_password_change,p.is_primary_admin from public.profiles p where p.id=(select auth.uid()) and not p.is_suspended
$$;
revoke all on function public.my_staff_status() from public;
grant execute on function public.my_staff_status() to authenticated;
