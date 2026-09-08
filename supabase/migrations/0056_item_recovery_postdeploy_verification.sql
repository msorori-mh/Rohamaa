-- Atomic post-deploy verification for P2. Synthetic rows are created inside a
-- nested block and deliberately rolled back after all A-D paths pass.

do $$
declare
  v_user uuid;
  v_admin uuid;
  v_warehouse uuid;
  v_donation uuid;
  v_item uuid;
  v_work uuid;
  v_recycling uuid;
  v_before_donations integer;
  v_before_warehouses integer;
  v_before_items integer;
  v_before_events integer;
  v_before_notifications integer;
  v_synthetic_events integer;
  v_synthetic_notifications integer;
  v_original_sub text;
  v_denied boolean := false;
  v_grade text;
begin
  select id into v_user from public.profiles where role='user' order by created_at limit 1;
  select id into v_admin from public.profiles where role='admin' order by created_at limit 1;
  if v_user is null or v_admin is null then
    raise exception 'item-recovery verification requires one user and one admin';
  end if;

  if exists(
    select 1 from (values
      ('warehouses'::text),('inventory_items'),('item_work_orders'),
      ('item_recycling_records'),('inventory_events')
    ) as required(table_name)
    where not (select c.relrowsecurity from pg_class c where c.oid=('public.'||required.table_name)::regclass)
  ) then
    raise exception 'P2 RLS is not enabled on every operational table';
  end if;

  if has_table_privilege('anon','public.inventory_items','select')
     or has_table_privilege('authenticated','public.inventory_items','delete')
     or has_table_privilege('authenticated','public.inventory_events','update')
     or has_table_privilege('authenticated','public.inventory_events','delete')
     or not has_table_privilege('authenticated','public.inventory_items','select')
     or not has_table_privilege('authenticated','public.inventory_events','insert') then
    raise exception 'P2 grants are not least-privilege';
  end if;

  select count(*) into v_before_donations from public.donations;
  select count(*) into v_before_warehouses from public.warehouses;
  select count(*) into v_before_items from public.inventory_items;
  select count(*) into v_before_events from public.inventory_events;
  select count(*) into v_before_notifications from public.user_notifications;
  v_original_sub := current_setting('request.jwt.claim.sub',true);

  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  begin
    v_warehouse := public.admin_create_warehouse(
      'VRF-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),
      'مستودع تحقق P2',null,'synthetic rollback-only location'
    );

    foreach v_grade in array array['A','B','C','D'] loop
      insert into public.donations(public_code,user_id,category,item_type,status)
      values(
        'RHM-P2-'||v_grade||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),
        v_user,'other','عنصر تحقق '||v_grade,'submitted'
      ) returning id into v_donation;

      v_item := public.admin_receive_inventory_item(v_donation,v_warehouse,'VERIFY-'||v_grade);
      perform public.admin_inspect_inventory_item(v_item,v_grade,'synthetic verification',100);

      if v_grade in ('B','C') then
        select id into v_work from public.item_work_orders where inventory_item_id=v_item;
        perform public.admin_advance_item_work_order(v_work,'start',null,'verification start');
        perform public.admin_advance_item_work_order(v_work,'complete',125,'verification complete');
        if not exists(select 1 from public.inventory_items where id=v_item and status='ready_for_distribution') then
          raise exception 'grade % did not reach ready_for_distribution',v_grade;
        end if;
      elsif v_grade='A' then
        if not exists(select 1 from public.inventory_items where id=v_item and status='ready_for_distribution') then
          raise exception 'grade A did not become ready directly';
        end if;
      else
        select id into v_recycling from public.item_recycling_records where inventory_item_id=v_item;
        perform public.admin_confirm_item_recycling(v_recycling,'mixed',2.50,75,'verification recycling');
        if not exists(select 1 from public.inventory_items where id=v_item and status='recycled') then
          raise exception 'grade D did not reach recycled';
        end if;
      end if;
    end loop;

    select count(*) into v_synthetic_events
    from public.inventory_events where metadata->>'bin_location' like 'VERIFY-%'
       or inventory_item_id in (
         select i.id from public.inventory_items i join public.donations d on d.id=i.donation_id
         where d.item_type like 'عنصر تحقق %'
       );
    if v_synthetic_events <> 13 then
      raise exception 'expected 13 P2 events, found %',v_synthetic_events;
    end if;

    select count(*) into v_synthetic_notifications
    from public.user_notifications
    where user_id=v_user and entity_type='inventory_items'
      and entity_id in (
        select i.id from public.inventory_items i join public.donations d on d.id=i.donation_id
        where d.item_type like 'عنصر تحقق %'
      );
    if v_synthetic_notifications <> 13 then
      raise exception 'expected 13 P2 notifications, found %',v_synthetic_notifications;
    end if;

    perform 1 from public.admin_inventory_queue() limit 1;
    perform 1 from public.admin_recovery_priorities(50) limit 1;
    perform public.admin_inventory_summary();
    perform set_config('request.jwt.claim.sub',v_user::text,true);
    if not exists(
      select 1 from public.user_operations_center(100)
      where operation_kind='item_processing' and title like 'عنصر تحقق %'
    ) then
      raise exception 'donor operations center did not expose the privacy-safe processing state';
    end if;

    raise no_data_found;
  exception when no_data_found then
    null;
  end;

  if (select count(*) from public.donations)<>v_before_donations
     or (select count(*) from public.warehouses)<>v_before_warehouses
     or (select count(*) from public.inventory_items)<>v_before_items
     or (select count(*) from public.inventory_events)<>v_before_events
     or (select count(*) from public.user_notifications)<>v_before_notifications then
    raise exception 'synthetic P2 rows were not rolled back';
  end if;

  perform set_config('request.jwt.claim.sub',v_user::text,true);
  begin
    perform public.admin_inventory_summary();
  exception when others then
    if sqlerrm='admin access required' then v_denied:=true; else raise; end if;
  end;
  if not v_denied then raise exception 'non-admin unexpectedly reached P2 admin RPC'; end if;
  perform set_config('request.jwt.claim.sub',coalesce(v_original_sub,''),true);
end $$;
