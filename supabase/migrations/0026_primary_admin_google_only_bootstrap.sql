create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public as $$
declare
  v_provider text:=coalesce(new.raw_app_meta_data->>'provider','');
  v_primary boolean:=lower(coalesce(new.email,''))=lower('msorori201201@gmail.com') and v_provider='google';
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
