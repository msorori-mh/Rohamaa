-- Audit hardening (2/2): account state for the app shell, the account
-- deletion pipeline, and the queues that surface it. The auth user itself is
-- soft-deleted by the admin-delete-account Edge Function between the
-- "prepare" and "complete" steps defined here.

-- ---------------------------------------------------------------------------
-- 1. Account state. Works for suspended and temporary-password accounts so
--    the app can explain why access is limited.
-- ---------------------------------------------------------------------------
create or replace function public.my_account_state()
returns table(role text, is_suspended boolean, force_password_change boolean, deletion_status text)
language sql
stable
security definer
set search_path = public
as $$
  select p.role::text, p.is_suspended, p.force_password_change,
    (select r.status from public.account_deletion_requests r
      where r.user_id = p.id order by r.requested_at desc, r.id desc limit 1)
  from public.profiles p
  where p.id = (select auth.uid());
$$;

-- ---------------------------------------------------------------------------
-- 2. The user may withdraw a request that staff has not started processing.
-- ---------------------------------------------------------------------------
create or replace function public.cancel_account_deletion_request()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_ids uuid[];
begin
  if v_user is null then raise exception 'authentication required'; end if;
  with removed as (
    delete from public.account_deletion_requests
    where user_id = v_user and status = 'pending'
    returning id
  )
  select array_agg(id) into v_ids from removed;
  if v_ids is null then raise exception 'no pending deletion request'; end if;
  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  values (v_user, 'cancel_account_deletion_request', 'profile', v_user,
    jsonb_build_object('request_ids', to_jsonb(v_ids)));
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Admin queue.
-- ---------------------------------------------------------------------------
create or replace function public.admin_account_deletion_queue()
returns table(
  request_id uuid, user_id uuid, full_name text, requested_at timestamptz,
  status text, open_operations integer
)
language plpgsql
stable
security definer
set search_path = public
as $$
#variable_conflict use_column
begin
  if not public.is_admin() then raise exception 'admin required'; end if;
  return query
  select r.id, r.user_id, p.full_name, r.requested_at, r.status,
    (
      (select count(*) from public.needs n
        where n.user_id = r.user_id
          and n.status in ('submitted', 'waiting', 'candidate_found', 'confirmed', 'matched', 'delivery_scheduled'))
      + (select count(*) from public.donations d
          where d.user_id = r.user_id
            and d.status in ('draft', 'submitted', 'under_review', 'available', 'matched', 'pickup_scheduled', 'picked_up', 'out_for_delivery'))
      + (select count(*) from public.service_offers o
          where o.user_id = r.user_id and o.status in ('submitted', 'approved', 'paused', 'matched'))
      + (select count(*) from public.service_requests sr
          where sr.user_id = r.user_id and sr.status in ('submitted', 'reviewing', 'matched', 'scheduled'))
    )::integer
  from public.account_deletion_requests r
  left join public.profiles p on p.id = r.user_id
  where r.status in ('pending', 'processing')
  order by r.requested_at, r.id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Prepare: close the user's open work and scrub personal data while the
--    operational history that other people depend on stays intact.
--    Safe to call again while the request is 'processing' (retry).
-- ---------------------------------------------------------------------------
create or replace function public.admin_prepare_account_deletion(p_request_id uuid, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin uuid := auth.uid();
  v_note text := nullif(trim(coalesce(p_note, '')), '');
  v_request public.account_deletion_requests;
  v_user uuid;
  v_role text;
  v_item record;
  v_service record;
  v_paths text[] := '{}'::text[];
  v_objects text[];
  v_matches integer := 0;
  v_needs integer := 0;
  v_donations integer := 0;
  v_service_matches integer := 0;
  v_offers integer := 0;
  v_requests integer := 0;
  v_contributions integer := 0;
  v_addresses_deleted integer := 0;
  v_addresses_blanked integer := 0;
begin
  if not public.is_admin() then raise exception 'admin required'; end if;
  if char_length(v_note) > 500 then raise exception 'note too long'; end if;

  select * into v_request from public.account_deletion_requests where id = p_request_id for update;
  if not found then raise exception 'deletion request not found'; end if;
  if v_request.status not in ('pending', 'processing') then raise exception 'deletion request is not open'; end if;
  v_user := v_request.user_id;
  if v_user is null then raise exception 'deletion request has no account'; end if;
  if v_user = v_admin then raise exception 'cannot delete own account'; end if;

  select p.role::text into v_role from public.profiles p where p.id = v_user for update;
  if v_role is null then raise exception 'profile not found'; end if;
  if v_role <> 'user' then raise exception 'staff accounts must be managed by an administrator'; end if;

  -- A courier may be on the way to, or holding an item for, this person.
  if exists (
    select 1
    from public.deliveries del
    join public.matches m on m.id = del.match_id
    join public.donations d on d.id = m.donation_id
    join public.needs n on n.id = m.need_id
    where del.status not in ('delivered', 'failed')
      and (d.user_id = v_user or n.user_id = v_user)
  ) then raise exception 'delivery in progress'; end if;

  -- Item matches that never reached a delivery: release the other party.
  for v_item in
    select m.id as match_id, m.donation_id, m.need_id,
           d.user_id as donor_id, n.user_id as recipient_id
    from public.matches m
    join public.donations d on d.id = m.donation_id
    join public.needs n on n.id = m.need_id
    where m.status in ('offered', 'accepted')
      and (d.user_id = v_user or n.user_id = v_user)
      and not exists (select 1 from public.deliveries del where del.match_id = m.id)
    for update of m
  loop
    update public.matches set status = 'cancelled', responded_at = coalesce(responded_at, now())
    where id = v_item.match_id;
    if v_item.donor_id <> v_user then
      update public.donations set status = 'available', updated_at = now()
      where id = v_item.donation_id and status in ('under_review', 'matched', 'pickup_scheduled');
    end if;
    if v_item.recipient_id <> v_user then
      update public.needs set status = 'waiting', updated_at = now()
      where id = v_item.need_id and status in ('candidate_found', 'confirmed', 'matched', 'delivery_scheduled');
    end if;
    v_matches := v_matches + 1;
  end loop;

  -- Same end state as user_cancel_need / user_cancel_donation.
  update public.needs set status = 'cancelled', updated_at = now()
  where user_id = v_user
    and status in ('submitted', 'waiting', 'candidate_found', 'confirmed', 'matched', 'delivery_scheduled');
  get diagnostics v_needs = row_count;

  -- Items already received into the warehouse belong to the programme and
  -- stay in its inventory flow; only donations still with the user are closed.
  update public.donations d set status = 'cancelled', updated_at = now()
  where d.user_id = v_user
    and d.status in ('draft', 'submitted', 'under_review', 'available', 'matched', 'pickup_scheduled')
    and not exists (select 1 from public.inventory_items i where i.donation_id = d.id);
  get diagnostics v_donations = row_count;

  -- Service matches still in flight: release the other party.
  for v_service in
    select sm.id as match_id, sm.service_offer_id, sm.service_request_id,
           o.user_id as provider_id, r.user_id as requester_id
    from public.service_matches sm
    join public.service_offers o on o.id = sm.service_offer_id
    join public.service_requests r on r.id = sm.service_request_id
    where sm.status in ('proposed', 'accepted', 'scheduled')
      and (o.user_id = v_user or r.user_id = v_user)
    for update of sm
  loop
    update public.service_matches set status = 'cancelled', updated_at = now()
    where id = v_service.match_id;
    if v_service.provider_id <> v_user then
      update public.service_offers set status = 'approved', updated_at = now()
      where id = v_service.service_offer_id and status = 'matched';
    end if;
    if v_service.requester_id <> v_user then
      update public.service_requests set status = 'reviewing', updated_at = now()
      where id = v_service.service_request_id and status in ('matched', 'scheduled');
    end if;
    v_service_matches := v_service_matches + 1;
  end loop;

  update public.service_offers set status = 'cancelled', updated_at = now()
  where user_id = v_user and status in ('submitted', 'approved', 'paused', 'matched');
  get diagnostics v_offers = row_count;

  update public.service_requests set status = 'cancelled', updated_at = now()
  where user_id = v_user and status in ('submitted', 'reviewing', 'matched', 'scheduled');
  get diagnostics v_requests = row_count;

  -- A partner record cannot be removed (work orders reference it); retire it
  -- and drop its contact details.
  update public.service_partners
  set verification_status = 'suspended', display_name = 'شريك محذوف',
      description = null, contact_phone = null,
      admin_note = 'account deleted', updated_at = now()
  where owner_user_id = v_user;

  -- Cash that was promised but never verified will not be collected.
  update public.contributions
  set status = 'rejected', verified_by = v_admin, verified_at = now()
  where user_id = v_user and status = 'pending';
  get diagnostics v_contributions = row_count;

  -- Addresses: remove what nothing references, blank the rest.
  delete from public.addresses a
  where a.user_id = v_user
    and not exists (select 1 from public.needs n where n.address_id = a.id)
    and not exists (select 1 from public.donations d where d.address_id = a.id);
  get diagnostics v_addresses_deleted = row_count;

  update public.addresses
  set label = null, description = null, latitude = null, longitude = null, is_default = false
  where user_id = v_user;
  get diagnostics v_addresses_blanked = row_count;

  update public.profiles
  set full_name = null, phone = null, is_suspended = true, updated_at = now()
  where id = v_user;

  -- The inbox is private data; the status changes above also wrote into it.
  delete from public.user_notifications where user_id = v_user;

  -- Photo objects. storage_path is client-supplied, so only objects inside
  -- the user's own folder are ever returned for removal.
  select coalesce(array_agg(distinct di.storage_path), '{}'::text[]) into v_paths
  from public.donation_images di
  join public.donations d on d.id = di.donation_id
  where d.user_id = v_user and di.storage_path like v_user::text || '/%';

  begin
    select coalesce(array_agg(o.name), '{}'::text[]) into v_objects
    from storage.objects o
    where o.bucket_id = 'donation-images' and o.name like v_user::text || '/%';
    select coalesce(array_agg(distinct x), '{}'::text[]) into v_paths
    from unnest(v_paths || v_objects) as x;
  exception when insufficient_privilege or undefined_table or undefined_column then
    -- Fall back to the paths recorded by the application.
    null;
  end;

  update public.account_deletion_requests
  set status = 'processing', admin_note = coalesce(v_note, admin_note)
  where id = p_request_id;

  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  values (v_admin, 'prepare_account_deletion', 'profile', v_user, jsonb_build_object(
    'request_id', p_request_id, 'matches_cancelled', v_matches, 'needs_cancelled', v_needs,
    'donations_cancelled', v_donations, 'service_matches_cancelled', v_service_matches,
    'service_offers_cancelled', v_offers, 'service_requests_cancelled', v_requests,
    'contributions_rejected', v_contributions, 'addresses_deleted', v_addresses_deleted,
    'addresses_blanked', v_addresses_blanked, 'storage_objects', cardinality(v_paths)
  ));

  return jsonb_build_object('user_id', v_user, 'storage_paths', to_jsonb(v_paths));
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Complete / reject.
-- ---------------------------------------------------------------------------
create or replace function public.admin_complete_account_deletion(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin uuid := auth.uid();
  v_request public.account_deletion_requests;
  v_user uuid;
  v_remaining boolean := false;
  v_images integer := 0;
begin
  if not public.is_admin() then raise exception 'admin required'; end if;
  select * into v_request from public.account_deletion_requests where id = p_request_id for update;
  if not found then raise exception 'deletion request not found'; end if;
  if v_request.status <> 'processing' then raise exception 'deletion request is not being processed'; end if;
  v_user := v_request.user_id;

  if v_user is not null then
    begin
      select exists (
        select 1 from storage.objects o
        where o.bucket_id = 'donation-images' and o.name like v_user::text || '/%'
      ) into v_remaining;
    exception when insufficient_privilege or undefined_table or undefined_column then
      v_remaining := false;
    end;
    if v_remaining then raise exception 'storage objects remain'; end if;

    delete from public.donation_images di
    using public.donations d
    where d.id = di.donation_id and d.user_id = v_user;
    get diagnostics v_images = row_count;

    delete from public.user_notifications where user_id = v_user;
  end if;

  update public.account_deletion_requests
  set status = 'completed', completed_at = now()
  where id = p_request_id;

  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  values (v_admin, 'complete_account_deletion', 'profile', v_user,
    jsonb_build_object('request_id', p_request_id, 'image_rows_removed', v_images));
end;
$$;

create or replace function public.admin_reject_account_deletion(p_request_id uuid, p_note text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin uuid := auth.uid();
  v_note text := nullif(trim(coalesce(p_note, '')), '');
  v_request public.account_deletion_requests;
begin
  if not public.is_admin() then raise exception 'admin required'; end if;
  if char_length(v_note) > 500 then raise exception 'note too long'; end if;
  select * into v_request from public.account_deletion_requests where id = p_request_id for update;
  if not found then raise exception 'deletion request not found'; end if;
  -- Once prepared, personal data is already scrubbed and cannot be restored.
  if v_request.status <> 'pending' then raise exception 'deletion request is not pending'; end if;

  update public.account_deletion_requests
  set status = 'rejected', admin_note = v_note, completed_at = now()
  where id = p_request_id;

  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  values (v_admin, 'reject_account_deletion', 'profile', v_request.user_id,
    jsonb_build_object('request_id', p_request_id, 'note', v_note));
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. Queues. Return shapes are unchanged: a closed ('failed') delivery no
--    longer asks anyone for action, and open deletion requests are listed for
--    admins under action_key 'account_deletions'.
-- ---------------------------------------------------------------------------
create or replace function public.admin_operations_overview(p_limit integer default 50)
returns table(
  queue_key text,
  queue_kind text,
  entity_id uuid,
  public_code text,
  title text,
  subtitle text,
  priority integer,
  age_hours numeric,
  action_key text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'admin access required'; end if;
  return query
  select * from (
    select 'risk:'||rf.id, 'risk'::text, rf.id,
           left(rf.id::text,8), 'إشارة مخاطر: '||rf.rule_code,
           'الأولوية '||rf.severity::text,
           case rf.severity when 'critical' then 100 when 'high' then 90 when 'medium' then 70 else 50 end,
           round((extract(epoch from now()-rf.created_at)/3600)::numeric,1), 'risks'::text
    from public.risk_flags rf where not rf.resolved
    union all
    select 'incident:'||si.id, 'service_incident', si.id,
           left(si.id::text,8), 'بلاغ خدمة: '||si.incident_type,
           'الحالة '||si.status, 95,
           round((extract(epoch from now()-si.created_at)/3600)::numeric,1), 'incidents'
    from public.service_incidents si where si.status in ('open','reviewing')
    union all
    select 'delivery:'||d.id, 'delivery', d.id, d.public_code,
           'توصيل يحتاج إعادة تنسيق', 'الحالة '||d.status::text, 82,
           round((extract(epoch from now()-d.created_at)/3600)::numeric,1), 'deliveries'
    from public.deliveries d where d.status = 'rescheduled'
    union all
    select 'account_deletion:'||adr.id, 'account_deletion', adr.id,
           left(adr.id::text,8), 'طلب حذف حساب ينتظر المعالجة',
           'الحالة '||adr.status, 85,
           round((extract(epoch from now()-adr.requested_at)/3600)::numeric,1), 'account_deletions'
    from public.account_deletion_requests adr where adr.status in ('pending','processing')
    union all
    select 'match:'||m.id, 'accepted_match', m.id, d.public_code,
           'مطابقة مقبولة تنتظر التوصيل', d.item_type, 80,
           round((extract(epoch from now()-coalesce(m.responded_at,m.created_at))/3600)::numeric,1), 'accepted_matches'
    from public.matches m join public.donations d on d.id=m.donation_id
    where m.status='accepted' and not exists(select 1 from public.deliveries del where del.match_id=m.id)
    union all
    select 'contribution:'||c.id, 'contribution', c.id, c.public_code,
           'مساهمة تشغيلية تنتظر التحقق', c.amount_yer||' ر.ي', 75,
           round((extract(epoch from now()-c.created_at)/3600)::numeric,1), 'contributions'
    from public.contributions c where c.status='pending'
    union all
    select 'partner:'||p.id, 'partner', p.id, p.public_code,
           'منشأة تنتظر التحقق', p.display_name, 72,
           round((extract(epoch from now()-p.created_at)/3600)::numeric,1), 'partners'
    from public.service_partners p where p.verification_status='pending'
    union all
    select 'donation:'||d.id, 'donation', d.id, d.public_code,
           'عطاء ينتظر المعالجة', d.item_type,
           case when d.status='submitted' then 65 else 55 end,
           round((extract(epoch from now()-d.created_at)/3600)::numeric,1), 'item_matching'
    from public.donations d where d.status in ('submitted','under_review','available')
    union all
    select 'need:'||n.id, 'need', n.id, n.public_code,
           'احتياج ينتظر المراجعة أو المطابقة', n.item_type,
           case when n.status='submitted' then 68 else 58 end,
           round((extract(epoch from now()-n.created_at)/3600)::numeric,1), 'needs'
    from public.needs n where n.status in ('submitted','waiting','candidate_found')
    union all
    select 'service_offer:'||o.id, 'service_offer', o.id, o.public_code,
           'عرض مهارة ينتظر المراجعة', o.title, 60,
           round((extract(epoch from now()-o.created_at)/3600)::numeric,1), 'service_matching'
    from public.service_offers o where o.status='submitted'
    union all
    select 'service_request:'||r.id, 'service_request', r.id, r.public_code,
           'طلب خدمة ينتظر المعالجة', r.title, 62,
           round((extract(epoch from now()-r.created_at)/3600)::numeric,1), 'service_matching'
    from public.service_requests r where r.status in ('submitted','reviewing')
  ) queue(queue_key,queue_kind,entity_id,public_code,title,subtitle,priority,age_hours,action_key)
  order by queue.priority desc, queue.age_hours desc
  limit greatest(1,least(coalesce(p_limit,50),100));
end;
$$;

create or replace function public.user_operations_center(p_limit integer default 100)
returns table(operation_kind text,operation_id uuid,public_code text,title text,status text,updated_at timestamptz,action_route text,requires_action boolean)
language sql stable security definer set search_path=public as $$
  select * from (
    select case when i.id is null then 'donation' else 'item_processing' end,d.id,d.public_code,d.item_type,
      coalesce(i.status,d.status::text),greatest(d.updated_at,coalesce(i.updated_at,d.updated_at)),'/handoffs'::text,false
    from public.donations d left join public.inventory_items i on i.donation_id=d.id where d.user_id=(select auth.uid())
    union all
    select 'need',n.id,n.public_code,n.item_type,n.status::text,n.updated_at,'/handoffs',false from public.needs n where n.user_id=(select auth.uid())
    union all
    select 'item_match',m.id,n.public_code,d.item_type,m.status,coalesce(m.responded_at,m.created_at),case when m.status='offered' then '/offers' else '/handoffs' end,m.status='offered'
    from public.matches m join public.needs n on n.id=m.need_id join public.donations d on d.id=m.donation_id where n.user_id=(select auth.uid()) and m.status='offered'
    union all
    select 'delivery',del.id,del.public_code,case when d.user_id=(select auth.uid()) then d.item_type else n.item_type end,del.status::text,
      coalesce(del.delivered_at,del.picked_up_at,del.assigned_at,del.created_at),'/handoffs',del.status='rescheduled'
    from public.deliveries del join public.matches m on m.id=del.match_id join public.donations d on d.id=m.donation_id join public.needs n on n.id=m.need_id
    where d.user_id=(select auth.uid()) or n.user_id=(select auth.uid())
    union all
    select 'service_offer',o.id,o.public_code,o.title,o.status,o.updated_at,'/my-services',o.status='rejected' from public.service_offers o where o.user_id=(select auth.uid())
    union all
    select 'service_request',r.id,r.public_code,r.title,r.status,r.updated_at,'/my-services',r.status='rejected' from public.service_requests r where r.user_id=(select auth.uid())
    union all
    select 'service_match',sm.id,case when o.user_id=(select auth.uid()) then o.public_code else r.public_code end,
      case when o.user_id=(select auth.uid()) then o.title else r.title end,sm.status,sm.updated_at,'/my-services',sm.status='proposed'
    from public.service_matches sm join public.service_offers o on o.id=sm.service_offer_id join public.service_requests r on r.id=sm.service_request_id
    where o.user_id=(select auth.uid()) or r.user_id=(select auth.uid())
  ) operations(operation_kind,operation_id,public_code,title,status,updated_at,action_route,requires_action)
  order by operations.requires_action desc,operations.updated_at desc limit greatest(1,least(coalesce(p_limit,100),200));
$$;

-- ---------------------------------------------------------------------------
-- Privileges.
-- ---------------------------------------------------------------------------
revoke all on function public.my_account_state() from public, anon;
revoke all on function public.cancel_account_deletion_request() from public, anon;
revoke all on function public.admin_account_deletion_queue() from public, anon;
revoke all on function public.admin_prepare_account_deletion(uuid, text) from public, anon;
revoke all on function public.admin_complete_account_deletion(uuid) from public, anon;
revoke all on function public.admin_reject_account_deletion(uuid, text) from public, anon;
revoke all on function public.admin_operations_overview(integer) from public, anon;
revoke all on function public.user_operations_center(integer) from public, anon;

grant execute on function public.my_account_state() to authenticated;
grant execute on function public.cancel_account_deletion_request() to authenticated;
grant execute on function public.admin_account_deletion_queue() to authenticated;
grant execute on function public.admin_prepare_account_deletion(uuid, text) to authenticated;
grant execute on function public.admin_complete_account_deletion(uuid) to authenticated;
grant execute on function public.admin_reject_account_deletion(uuid, text) to authenticated;
grant execute on function public.admin_operations_overview(integer) to authenticated;
grant execute on function public.user_operations_center(integer) to authenticated;

comment on function public.admin_prepare_account_deletion(uuid, text) is
  'Admin-only step 1 of account deletion: refuses while a delivery is in progress, closes open work, scrubs profile and address data, and returns the storage objects to remove.';
comment on function public.admin_complete_account_deletion(uuid) is
  'Admin-only final step of account deletion, called after the photos and the auth identity were removed.';
