-- Sanad V1: audited role management for pilot operations.

create or replace function public.admin_set_user_role(
  p_user_id uuid,
  p_role public.user_role
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old_role public.user_role;
begin
  if not public.is_admin() then raise exception 'admin required'; end if;
  if p_user_id = auth.uid() and p_role <> 'admin' then
    raise exception 'admin cannot remove own admin role';
  end if;

  select role into v_old_role from profiles where id=p_user_id for update;
  if not found then raise exception 'user not found'; end if;

  update profiles set role=p_role, updated_at=now() where id=p_user_id;

  if p_role='courier' then
    insert into couriers(user_id,active) values(p_user_id,true)
    on conflict(user_id) do update set active=true;
  elsif v_old_role='courier' then
    update couriers set active=false where user_id=p_user_id;
  end if;

  insert into audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values(auth.uid(),'set_user_role','profile',p_user_id,
         jsonb_build_object('old_role',v_old_role,'new_role',p_role));
end;
$$;

revoke all on function public.admin_set_user_role(uuid,public.user_role) from public, anon;
grant execute on function public.admin_set_user_role(uuid,public.user_role) to authenticated;
