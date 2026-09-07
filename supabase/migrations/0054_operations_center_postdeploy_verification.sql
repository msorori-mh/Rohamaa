-- Atomic post-deploy verification for P1. The nested exception rolls back all
-- synthetic rows while allowing the migration to fail closed on any assertion.

do $$
declare
  v_user uuid;
  v_admin uuid;
  v_donation uuid;
  v_before integer;
  v_after integer;
  v_original_sub text;
begin
  select id into v_user from public.profiles where role='user' order by created_at limit 1;
  select id into v_admin from public.profiles where role='admin' order by created_at limit 1;
  if v_user is null or v_admin is null then
    raise exception 'operations-center verification requires one user and one admin';
  end if;

  if not (select relrowsecurity from pg_class where oid='public.user_notifications'::regclass) then
    raise exception 'user_notifications RLS is not enabled';
  end if;
  if has_table_privilege('anon','public.user_notifications','select')
     or has_table_privilege('authenticated','public.user_notifications','insert')
     or has_table_privilege('authenticated','public.user_notifications','delete')
     or has_column_privilege('authenticated','public.user_notifications','body','update')
     or not has_table_privilege('authenticated','public.user_notifications','select')
     or not has_column_privilege('authenticated','public.user_notifications','read_at','update') then
    raise exception 'user_notifications grants are not least-privilege';
  end if;

  select count(*) into v_before from public.user_notifications;
  begin
    insert into public.donations(public_code,user_id,category,item_type,status)
    values('RHM-VERIFY-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,12)),v_user,'other','verification','submitted')
    returning id into v_donation;

    update public.donations set status='available',updated_at=now() where id=v_donation;
    select count(*) into v_after
    from public.user_notifications
    where user_id=v_user and entity_type='donations' and entity_id=v_donation;

    if v_after <> 1 then
      raise exception 'expected exactly one owner notification, found %',v_after;
    end if;
    raise no_data_found;
  exception when no_data_found then
    null;
  end;

  if (select count(*) from public.user_notifications) <> v_before then
    raise exception 'synthetic notification was not rolled back';
  end if;

  v_original_sub := current_setting('request.jwt.claim.sub',true);
  perform set_config('request.jwt.claim.sub',v_user::text,true);
  perform 1 from public.user_operations_center(5) limit 1;
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  perform 1 from public.admin_operations_overview(5) limit 1;
  perform set_config('request.jwt.claim.sub',coalesce(v_original_sub,''),true);
end $$;
