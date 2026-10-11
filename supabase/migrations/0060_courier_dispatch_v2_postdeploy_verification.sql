-- Fail-closed structural and privilege verification for Courier Dispatch V2.
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='deliveries' and column_name='courier_responded_at'
  ) or not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='deliveries' and column_name='offer_expires_at'
  ) or not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='deliveries' and column_name='dispatch_attempt'
  ) then raise exception 'courier dispatch columns are incomplete'; end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid='public.user_notifications'::regclass
      and conname='user_notifications_action_route_check'
      and pg_get_constraintdef(oid) like '%/courier%'
  ) then raise exception 'courier notification route is not allowed'; end if;

  if has_function_privilege('anon','public.courier_respond_delivery(uuid,boolean,text)','execute')
     or has_function_privilege('anon','public.courier_start_dropoff(uuid)','execute')
     or has_function_privilege('anon','public.admin_reassign_delivery(uuid,uuid,uuid)','execute')
     or has_function_privilege('anon','public.admin_delivery_dispatch_queue()','execute')
     or not has_function_privilege('authenticated','public.courier_respond_delivery(uuid,boolean,text)','execute')
     or not has_function_privilege('authenticated','public.admin_reassign_delivery(uuid,uuid,uuid)','execute') then
    raise exception 'courier dispatch function grants are invalid';
  end if;

  if has_table_privilege('authenticated','public.user_notifications','insert')
     or has_table_privilege('authenticated','public.user_notifications','delete') then
    raise exception 'notification table lost least-privilege grants';
  end if;

  if exists(select 1 from pg_publication where pubname='supabase_realtime')
     and not exists(
       select 1 from pg_publication_tables
       where pubname='supabase_realtime' and schemaname='public' and tablename='deliveries'
     ) then raise exception 'deliveries realtime publication is missing'; end if;
end $$;
