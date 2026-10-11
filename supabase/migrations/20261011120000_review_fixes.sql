-- Security review fixes for the audit hardening migrations (20261011090000 /
-- 20261011090100). Forward-only: nothing in those files is edited, every
-- function is redefined with its existing signature, and no operational row is
-- deleted except the public discovery cards of a deleted account.

-- ---------------------------------------------------------------------------
-- 1. Length limits as triggers instead of NOT VALID CHECK constraints.
--    A CHECK constraint is re-evaluated on every UPDATE of a row, so a legacy
--    over-length value would have blocked unrelated changes (for example a
--    status transition). The trigger only looks at a limited column when it is
--    inserted or when its value actually changes.
-- ---------------------------------------------------------------------------
create or replace function public.enforce_text_length_limits()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_new jsonb;
  v_old jsonb;
  v_index integer := 0;
  v_column text;
  v_max integer;
  v_value text;
begin
  -- Arguments are (column, max_length) pairs.
  v_new := to_jsonb(new);
  if tg_op = 'UPDATE' then v_old := to_jsonb(old); end if;
  while v_index + 1 < tg_nargs loop
    v_column := tg_argv[v_index];
    v_max := tg_argv[v_index + 1]::integer;
    v_value := v_new ->> v_column;
    if v_value is not null and char_length(v_value) > v_max
       and (v_old is null or v_value is distinct from (v_old ->> v_column)) then
      raise exception 'value too long for %', v_column using errcode = '22001';
    end if;
    v_index := v_index + 2;
  end loop;
  return new;
end;
$$;

-- Trigger functions are never RPC endpoints; triggers fire regardless of EXECUTE.
revoke all on function public.enforce_text_length_limits() from public, anon, authenticated;

do $$
declare
  v_rule record;
  v_table record;
begin
  create temporary table review_length_rules (
    table_name text not null,
    column_name text not null,
    max_length integer not null,
    constraint_name text not null
  ) on commit drop;

  insert into review_length_rules(table_name, column_name, max_length, constraint_name)
  select r.table_name, r.column_name, r.max_length,
         r.table_name || '_' || r.column_name || '_max_length'
  from (values
    ('profiles','full_name',120),
    ('profiles','phone',20),
    ('addresses','label',120),
    ('addresses','area',160),
    ('addresses','description',2000),
    ('needs','public_code',64),
    ('needs','category',60),
    ('needs','category_group',60),
    ('needs','item_type_key',80),
    ('needs','item_type',160),
    ('needs','description',2000),
    ('needs','reason',2000),
    ('donations','public_code',64),
    ('donations','category',60),
    ('donations','category_group',60),
    ('donations','item_type_key',80),
    ('donations','item_type',160),
    ('donations','condition',160),
    ('donations','description',2000),
    ('donation_images','storage_path',300),
    ('contributions','public_code',64),
    ('contributions','payment_reference',120),
    ('service_offers','public_code',64),
    ('service_offers','service_type',160),
    ('service_offers','title',160),
    ('service_offers','description',2000),
    ('service_offers','availability_note',2000),
    ('service_requests','public_code',64),
    ('service_requests','service_type',160),
    ('service_requests','title',160),
    ('service_requests','details',2000),
    ('service_requests','preferred_time_note',2000),
    ('service_matches','operational_note',2000),
    ('service_partners','display_name',160),
    ('service_partners','description',2000),
    ('service_partners','contact_phone',20),
    ('service_partners','admin_note',2000),
    ('service_incidents','description',2000),
    ('service_incidents','resolution',2000),
    ('delivery_failures','note',2000),
    ('account_deletion_requests','admin_note',2000),
    ('need_discovery_cards','display_title',160),
    ('need_discovery_cards','display_detail',2000)
  ) as r(table_name, column_name, max_length);

  -- The serialized size of the structured attributes (jsonb ->> yields the
  -- same text as a cast to text).
  insert into review_length_rules(table_name, column_name, max_length, constraint_name)
  values
    ('needs','item_attributes',4000,'needs_item_attributes_max_size'),
    ('donations','item_attributes',4000,'donations_item_attributes_max_size');

  for v_rule in select * from review_length_rules loop
    execute format('alter table public.%I drop constraint if exists %I',
      v_rule.table_name, v_rule.constraint_name);
  end loop;

  for v_table in
    select r.table_name,
           string_agg(format('%I', r.column_name), ', ' order by r.column_name) as columns,
           string_agg(format('%L, %L', r.column_name, r.max_length::text), ', ' order by r.column_name) as arguments
    from review_length_rules r
    group by r.table_name
  loop
    execute format('drop trigger if exists %I on public.%I',
      v_table.table_name || '_text_length_limits', v_table.table_name);
    execute format(
      'create trigger %I before insert or update of %s on public.%I '
      || 'for each row execute function public.enforce_text_length_limits(%s)',
      v_table.table_name || '_text_length_limits', v_table.columns, v_table.table_name, v_table.arguments
    );
  end loop;
end $$;

-- Sign-up must never fail because an identity provider sent a very long name.
-- Identical to the previous definition except for left(..., 120).
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public as $$
declare
  v_provider text:=coalesce(new.raw_app_meta_data->>'provider','');
  v_primary boolean:=lower(coalesce(new.email,''))=lower('msorori201201@gmail.com') and v_provider='google';
begin
  insert into public.profiles(id,full_name,role,is_primary_admin,force_password_change,staff_email,created_at,updated_at)
  values(new.id,left(coalesce(new.raw_user_meta_data->>'full_name',new.raw_user_meta_data->>'name'),120),case when v_primary then 'admin'::public.user_role else 'user'::public.user_role end,v_primary,v_primary,case when v_primary then lower(new.email) else null end,now(),now())
  on conflict(id) do update set
    full_name=coalesce(excluded.full_name,public.profiles.full_name),
    role=case when v_primary then 'admin'::public.user_role else public.profiles.role end,
    is_primary_admin=case when v_primary then true else public.profiles.is_primary_admin end,
    force_password_change=case when v_primary and public.profiles.password_changed_at is null then true else public.profiles.force_password_change end,
    staff_email=case when v_primary then lower(new.email) else public.profiles.staff_email end,
    updated_at=now();
  return new;
end $$;

-- ---------------------------------------------------------------------------
-- 2. Account deletion pipeline lock-down.
--    Requests are only ever written by SECURITY DEFINER functions; the staff
--    note is not readable through the API.
-- ---------------------------------------------------------------------------
drop policy if exists "admins_update_deletion_requests" on public.account_deletion_requests;
revoke all on table public.account_deletion_requests from public, anon, authenticated;
grant select (id, user_id, requested_at, status, completed_at)
  on table public.account_deletion_requests to authenticated;

create or replace function public.request_account_deletion()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_role text;
  v_suspended boolean;
  v_existing uuid;
  v_id uuid;
begin
  if v_user is null then raise exception 'authentication required'; end if;

  select p.role::text, p.is_suspended into v_role, v_suspended
  from public.profiles p where p.id = v_user;
  if v_role is null then raise exception 'profile not found'; end if;
  if v_role <> 'user' then raise exception 'staff accounts must be managed by an administrator'; end if;
  -- A suspended account (including one whose deletion is already being
  -- processed) cannot open requests; staff handle it from the admin queue.
  if v_suspended then raise exception 'account suspended'; end if;
  if exists (
    select 1 from public.account_deletion_requests r
    where r.user_id = v_user and r.status = 'completed'
  ) then raise exception 'account already deleted'; end if;

  select r.id into v_existing
  from public.account_deletion_requests r
  where r.user_id = v_user and r.status in ('pending','processing')
  order by r.requested_at desc
  limit 1;

  if v_existing is not null then return v_existing; end if;

  insert into public.account_deletion_requests(user_id)
  values (v_user)
  returning id into v_id;

  return v_id;
end;
$$;

-- A scrubbed account must never be reactivated.
create or replace function public.admin_set_user_suspension(p_user_id uuid, p_suspended boolean, p_reason text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'admin required'; end if;
  if p_user_id=auth.uid() and p_suspended then raise exception 'cannot suspend self'; end if;
  if p_suspended is not true and exists (
    select 1 from public.account_deletion_requests r
    where r.user_id = p_user_id and r.status in ('processing', 'completed')
  ) then raise exception 'account deletion in progress'; end if;
  update public.profiles set is_suspended=p_suspended,updated_at=now() where id=p_user_id;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values(auth.uid(),case when p_suspended then 'suspend_user' else 'unsuspend_user' end,'profile',p_user_id,jsonb_build_object('reason',p_reason));
end;
$$;

-- Prepare: same signature and result as before, with a complete scrub.
-- Safe to call again while the request is 'processing' (retry).
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
  v_other uuid;
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
  v_cards integer := 0;
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

  -- A former courier may still be the assigned courier of an open task.
  if exists (
    select 1 from public.deliveries del
    where del.courier_id = v_user and del.status not in ('delivered', 'failed')
  ) then raise exception 'courier has open deliveries'; end if;

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
    -- The match trigger only announces new offers, so the person who was
    -- waiting on this match is told explicitly. Deduplicated per match.
    v_other := case when v_item.donor_id = v_user then v_item.recipient_id else v_item.donor_id end;
    if v_other is not null and v_other <> v_user then
      perform public.insert_user_notification(
        v_other, 'item_match_cancelled', 'تم إلغاء المطابقة',
        'أُلغيت مطابقة سابقة لأن الطرف الآخر لم يعد متاحًا. عاد سجلك إلى قائمة الانتظار وسنبحث لك عن خيار مناسب آخر.',
        'matches', v_item.match_id, '/handoffs',
        'matches:' || v_item.match_id || ':cancelled:account_deletion'
      );
    end if;
    v_matches := v_matches + 1;
  end loop;

  -- Same end state as user_cancel_need / user_cancel_donation.
  update public.needs set status = 'cancelled', updated_at = now()
  where user_id = v_user
    and status in ('submitted', 'waiting', 'candidate_found', 'confirmed', 'matched', 'delivery_scheduled');
  get diagnostics v_needs = row_count;

  -- Only donations still with the user are closed. Two kinds stay open:
  --  * items already received into the warehouse (they belong to the
  --    programme and stay in its inventory flow);
  --  * items a courier already collected (the latest delivery was picked up
  --    and then cancelled): they are physically with staff and are left in
  --    'under_review' so warehouse intake can still receive them.
  update public.donations d set status = 'cancelled', updated_at = now()
  where d.user_id = v_user
    and d.status in ('draft', 'submitted', 'under_review', 'available', 'matched', 'pickup_scheduled')
    and not exists (select 1 from public.inventory_items i where i.donation_id = d.id)
    and not coalesce((
      select del.picked_up_at is not null
      from public.deliveries del
      join public.matches m on m.id = del.match_id
      where m.donation_id = d.id
      order by del.created_at desc, del.id desc
      limit 1
    ), false);
  get diagnostics v_donations = row_count;

  -- Service matches still in flight: release the other party. The service
  -- match trigger notifies both parties of the status change.
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

  -- Free text the user wrote. The rows stay because other people's history
  -- and the programme's statistics reference them.
  update public.needs
  set description = null, reason = null, item_attributes = '{}'::jsonb
  where user_id = v_user
    and (description is not null or reason is not null or item_attributes <> '{}'::jsonb);

  update public.donations
  set description = null, condition = null, item_attributes = '{}'::jsonb
  where user_id = v_user
    and (description is not null or condition is not null or item_attributes <> '{}'::jsonb);

  -- title (and details) are NOT NULL, so they get a placeholder.
  update public.service_offers
  set title = 'محذوف', description = null, availability_note = null
  where user_id = v_user
    and (title <> 'محذوف' or description is not null or availability_note is not null);

  update public.service_requests
  set title = 'محذوف', details = 'محذوف', preferred_time_note = null
  where user_id = v_user
    and (title <> 'محذوف' or details <> 'محذوف' or preferred_time_note is not null);

  update public.service_matches sm
  set operational_note = null
  where sm.operational_note is not null
    and (
      exists (select 1 from public.service_offers o where o.id = sm.service_offer_id and o.user_id = v_user)
      or exists (select 1 from public.service_requests r where r.id = sm.service_request_id and r.user_id = v_user)
    );

  -- description is NOT NULL.
  update public.service_incidents
  set description = '[deleted]'
  where reporter_user_id = v_user and description <> '[deleted]';

  update public.contributions
  set payment_reference = null
  where user_id = v_user and payment_reference is not null;

  -- Location traces and courier notes of the handoffs this person took part in.
  update public.delivery_events e
  set latitude = null, longitude = null, metadata = e.metadata - 'note'
  where (e.latitude is not null or e.longitude is not null or e.metadata ? 'note')
    and e.delivery_id in (
      select del.id
      from public.deliveries del
      join public.matches m on m.id = del.match_id
      join public.donations d on d.id = m.donation_id
      join public.needs n on n.id = m.need_id
      where d.user_id = v_user or n.user_id = v_user
    );

  update public.delivery_failures f
  set note = null, latitude = null, longitude = null
  where (f.note is not null or f.latitude is not null or f.longitude is not null)
    and f.delivery_id in (
      select del.id
      from public.deliveries del
      join public.matches m on m.id = del.match_id
      join public.donations d on d.id = m.donation_id
      join public.needs n on n.id = m.need_id
      where d.user_id = v_user or n.user_id = v_user
    );

  -- The flag itself (rule, severity, resolution state) is kept for abuse review.
  update public.risk_flags
  set details = '{}'::jsonb
  where user_id = v_user and details <> '{}'::jsonb;

  -- Public discovery cards carry reviewed text about this person's needs.
  -- Nothing reacts to the delete: donations.inspired_by_discovery_card_id is
  -- ON DELETE SET NULL and the table has no triggers.
  delete from public.need_discovery_cards c
  using public.needs n
  where n.id = c.need_id and n.user_id = v_user;
  get diagnostics v_cards = row_count;

  -- Addresses: remove what nothing references, blank the rest.
  delete from public.addresses a
  where a.user_id = v_user
    and not exists (select 1 from public.needs n where n.address_id = a.id)
    and not exists (select 1 from public.donations d where d.address_id = a.id);
  get diagnostics v_addresses_deleted = row_count;

  update public.addresses
  set label = null, area = null, description = null, latitude = null, longitude = null, is_default = false
  where user_id = v_user;
  get diagnostics v_addresses_blanked = row_count;

  -- staff_email is nullable; its unique index ignores nulls.
  update public.profiles
  set full_name = null, phone = null, staff_email = null, is_suspended = true, updated_at = now()
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
    'addresses_blanked', v_addresses_blanked, 'discovery_cards_deleted', v_cards,
    'storage_objects', cardinality(v_paths)
  ));

  return jsonb_build_object('user_id', v_user, 'storage_paths', to_jsonb(v_paths));
end;
$$;

-- Complete: only once the person can no longer sign in.
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

  -- The auth identity must be gone (hard delete) or soft-deleted first.
  if exists (
    select 1 from auth.users u where u.id = v_user and u.deleted_at is null
  ) then raise exception 'auth identity still active'; end if;

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

-- ---------------------------------------------------------------------------
-- 3. Delivery custody and stuck states.
-- ---------------------------------------------------------------------------
-- Unchanged except that the match row is locked before it is checked, so two
-- admins cannot both pass the checks for the same match.
create or replace function public.admin_create_delivery(
  p_match_id uuid,
  p_courier_id uuid,
  p_vehicle_id uuid default null,
  p_pickup_pin text default null,
  p_delivery_pin text default null
)
returns table(delivery_id uuid, public_code text, pickup_pin text, delivery_pin text)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_id uuid;
  v_code text;
  v_match_status text;
begin
  if not public.is_admin() then raise exception 'admin required'; end if;
  if p_pickup_pin is not null or p_delivery_pin is not null then raise exception 'admin PIN issuance is disabled'; end if;
  select m.status into v_match_status from public.matches m where m.id=p_match_id for update;
  if not found or v_match_status is distinct from 'accepted' then raise exception 'match must be accepted first'; end if;
  if exists(select 1 from public.deliveries del where del.match_id=p_match_id) then raise exception 'delivery already exists'; end if;
  if not exists(select 1 from public.couriers c where c.user_id=p_courier_id and c.active) then raise exception 'courier inactive'; end if;

  v_code := 'RHM-MRB-DEL-' || to_char(now(),'YYMMDD') || '-' || upper(substr(encode(gen_random_bytes(5),'hex'),1,8));
  insert into public.deliveries(
    public_code,match_id,courier_id,vehicle_id,status,pickup_pin_hash,
    delivery_pin_hash,assigned_at,offer_expires_at,dispatch_attempt
  ) values (
    v_code,p_match_id,p_courier_id,p_vehicle_id,'assigned',null,
    null,now(),now()+interval '30 minutes',1
  ) returning id into v_id;

  update public.donations set status='pickup_scheduled',updated_at=now()
   where id=(select m.donation_id from public.matches m where m.id=p_match_id);
  update public.needs set status='delivery_scheduled',updated_at=now()
   where id=(select m.need_id from public.matches m where m.id=p_match_id);

  insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values(auth.uid(),'create_delivery','delivery',v_id,jsonb_build_object(
    'courier_id',p_courier_id,'vehicle_id',p_vehicle_id,'dispatch_attempt',1
  ));
  insert into public.delivery_events(delivery_id,actor_id,event_type,metadata)
  values(v_id,auth.uid(),'courier_assigned',jsonb_build_object(
    'courier_id',p_courier_id,'vehicle_id',p_vehicle_id,'dispatch_attempt',1
  ));

  return query select v_id,v_code,null::text,null::text;
end;
$$;

-- A collected item stays with the courier who collected it. If that courier
-- cannot finish, the admin closes the task with admin_cancel_delivery so the
-- item goes back through staff review / warehouse intake.
create or replace function public.admin_reassign_delivery(
  p_delivery_id uuid,
  p_courier_id uuid,
  p_vehicle_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_delivery public.deliveries;
  v_collector uuid;
begin
  if not public.is_admin() then raise exception 'admin required'; end if;
  select * into v_delivery from public.deliveries where id = p_delivery_id for update;
  if not found then raise exception 'delivery not found'; end if;
  -- 'failed' is the closed state written by admin_cancel_delivery.
  if v_delivery.status not in ('assigned', 'rescheduled') then
    raise exception 'delivery cannot be reassigned in its current state';
  end if;
  if not exists (
    select 1 from public.couriers c join public.profiles p on p.id = c.user_id
    where c.user_id = p_courier_id and c.active and p.role::text = 'courier' and not p.is_suspended
  ) then raise exception 'courier inactive'; end if;
  if p_vehicle_id is not null and not exists (
    select 1 from public.vehicles v where v.id = p_vehicle_id and v.active
  ) then raise exception 'vehicle inactive'; end if;

  if v_delivery.picked_up_at is not null then
    -- courier_id may have been cleared since the pickup, so the collector is
    -- read from the pickup evidence; the current courier is the fallback for
    -- rows collected before that event existed.
    select e.actor_id into v_collector
    from public.delivery_events e
    where e.delivery_id = p_delivery_id and e.event_type = 'pickup_pin_verified'
    order by e.created_at desc, e.id desc
    limit 1;
    v_collector := coalesce(v_collector, v_delivery.courier_id);
    if v_collector is null or p_courier_id is distinct from v_collector then
      raise exception 'collected item cannot change courier';
    end if;
  end if;

  update public.deliveries
  set courier_id = p_courier_id, vehicle_id = p_vehicle_id, status = 'assigned', assigned_at = now(),
      courier_responded_at = null, offer_expires_at = now() + interval '30 minutes',
      rejection_reason = null, dispatch_attempt = dispatch_attempt + 1,
      pickup_pin_hash = null, delivery_pin_hash = null,
      pickup_pin_expires_at = null, delivery_pin_expires_at = null,
      pickup_pin_attempts = 0, delivery_pin_attempts = 0
  where id = p_delivery_id;

  insert into public.delivery_events(delivery_id, actor_id, event_type, metadata)
  values (p_delivery_id, auth.uid(), 'courier_reassigned', jsonb_build_object(
    'previous_courier_id', v_delivery.courier_id, 'courier_id', p_courier_id,
    'vehicle_id', p_vehicle_id, 'dispatch_attempt', v_delivery.dispatch_attempt + 1,
    'after_pickup', v_delivery.picked_up_at is not null
  ));
  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), 'reassign_delivery', 'delivery', p_delivery_id, jsonb_build_object(
    'previous_courier_id', v_delivery.courier_id, 'courier_id', p_courier_id,
    'vehicle_id', p_vehicle_id, 'dispatch_attempt', v_delivery.dispatch_attempt + 1,
    'after_pickup', v_delivery.picked_up_at is not null
  ));
end;
$$;

-- An accepted task whose courier went silent: the admin parks it in
-- 'rescheduled' (exactly what a courier failure report does) so it can be
-- reassigned or cancelled. The courier is kept as the custody record.
create or replace function public.admin_pause_delivery(p_delivery_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_delivery public.deliveries;
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
begin
  if not public.is_admin() then raise exception 'admin required'; end if;
  if v_reason is null or char_length(v_reason) < 3 then raise exception 'pause reason required'; end if;
  if char_length(v_reason) > 500 then raise exception 'pause reason too long'; end if;
  select * into v_delivery from public.deliveries where id = p_delivery_id for update;
  if not found then raise exception 'delivery not found'; end if;
  if v_delivery.status not in ('heading_to_pickup', 'picked_up', 'heading_to_recipient') then
    raise exception 'delivery cannot be paused in its current state';
  end if;

  update public.deliveries
  set status = 'rescheduled', offer_expires_at = null,
      pickup_pin_hash = null, delivery_pin_hash = null,
      pickup_pin_expires_at = null, delivery_pin_expires_at = null,
      pickup_pin_attempts = 0, delivery_pin_attempts = 0
  where id = p_delivery_id;

  insert into public.delivery_events(delivery_id, actor_id, event_type, metadata)
  values (p_delivery_id, auth.uid(), 'delivery_paused', jsonb_build_object(
    'reason', v_reason, 'paused_in_status', v_delivery.status::text,
    'courier_id', v_delivery.courier_id,
    'after_pickup', v_delivery.picked_up_at is not null,
    'dispatch_attempt', v_delivery.dispatch_attempt
  ));
  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), 'pause_delivery', 'delivery', p_delivery_id, jsonb_build_object(
    'reason', v_reason, 'paused_in_status', v_delivery.status::text,
    'courier_id', v_delivery.courier_id,
    'after_pickup', v_delivery.picked_up_at is not null
  ));
end;
$$;

-- Unchanged except for the phase check: once the item is collected the donor
-- is no longer part of the handoff and cannot be blamed for a failure.
create or replace function public.courier_report_delivery_failure(
  p_delivery_id uuid,
  p_party text,
  p_reason_code text,
  p_note text default null,
  p_latitude double precision default null,
  p_longitude double precision default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_user_id uuid;
  v_recent integer;
  v_delivery public.deliveries;
  v_note text := nullif(trim(coalesce(p_note, '')), '');
begin
  if not public.is_courier() or not public.is_active_user() then raise exception 'active courier required'; end if;
  select * into v_delivery from public.deliveries
  where id = p_delivery_id and courier_id = auth.uid() for update;
  if not found then raise exception 'delivery not assigned'; end if;
  -- Before acceptance the courier declines instead; after closure nothing is left to report.
  if v_delivery.status not in ('heading_to_pickup', 'picked_up', 'heading_to_recipient') then
    raise exception 'failure cannot be reported in this state';
  end if;
  if p_party is null or p_party not in ('donor', 'beneficiary', 'courier', 'other') then raise exception 'invalid party'; end if;
  if v_delivery.picked_up_at is not null and p_party = 'donor' then
    raise exception 'invalid party for this phase';
  end if;
  if p_reason_code is null or p_reason_code not in ('no_answer', 'not_present', 'wrong_address', 'item_not_ready', 'item_rejected', 'vehicle_issue', 'weather', 'other') then
    raise exception 'invalid reason';
  end if;
  if char_length(v_note) > 2000 then raise exception 'note too long'; end if;

  insert into public.delivery_failures(delivery_id, courier_id, party, reason_code, note, latitude, longitude)
  values (p_delivery_id, auth.uid(), p_party, p_reason_code, v_note, p_latitude, p_longitude)
  returning id into v_id;

  -- The courier keeps read access to the paused task but every courier action
  -- is state-gated, so nothing can happen until an admin reassigns or cancels.
  update public.deliveries
  set status = 'rescheduled', offer_expires_at = null,
      pickup_pin_hash = null, delivery_pin_hash = null,
      pickup_pin_expires_at = null, delivery_pin_expires_at = null,
      pickup_pin_attempts = 0, delivery_pin_attempts = 0
  where id = p_delivery_id;

  insert into public.delivery_events(delivery_id, actor_id, event_type, latitude, longitude, metadata)
  values (p_delivery_id, auth.uid(), 'delivery_failure', p_latitude, p_longitude, jsonb_build_object(
    'party', p_party, 'reason_code', p_reason_code, 'note', v_note,
    'failed_in_status', v_delivery.status::text,
    'after_pickup', v_delivery.picked_up_at is not null,
    'dispatch_attempt', v_delivery.dispatch_attempt
  ));
  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), 'report_delivery_failure', 'delivery', p_delivery_id, jsonb_build_object(
    'party', p_party, 'reason_code', p_reason_code,
    'failed_in_status', v_delivery.status::text, 'failure_id', v_id
  ));

  if p_party in ('donor', 'beneficiary') and p_reason_code in ('no_answer', 'not_present', 'wrong_address', 'item_not_ready') then
    if p_party = 'donor' then
      select d.user_id into v_user_id
      from public.matches m join public.donations d on d.id = m.donation_id
      where m.id = v_delivery.match_id;
    else
      select n.user_id into v_user_id
      from public.matches m join public.needs n on n.id = m.need_id
      where m.id = v_delivery.match_id;
    end if;

    select count(*) into v_recent
    from public.delivery_failures df
    join public.deliveries del on del.id = df.delivery_id
    join public.matches m on m.id = del.match_id
    left join public.donations d on d.id = m.donation_id
    left join public.needs n on n.id = m.need_id
    where df.created_at > now() - interval '60 days'
      and df.reason_code in ('no_answer', 'not_present', 'wrong_address', 'item_not_ready')
      and ((df.party = 'donor' and d.user_id = v_user_id) or (df.party = 'beneficiary' and n.user_id = v_user_id));

    if v_recent >= 2 then
      insert into public.risk_flags(user_id, delivery_id, rule_code, severity, details)
      values (v_user_id, p_delivery_id, 'REPEATED_DELIVERY_NO_SHOW', 'medium',
        jsonb_build_object('failures_60d', v_recent, 'latest_reason', p_reason_code));
    end if;
  end if;

  return v_id;
end;
$$;

-- Unchanged except that cash pledges which can only ever be collected on this
-- delivery are closed with it.
create or replace function public.admin_cancel_delivery(p_delivery_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_delivery public.deliveries;
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
  v_donation uuid;
  v_need uuid;
  v_donor uuid;
  v_recipient uuid;
  v_picked boolean;
  v_pledges integer := 0;
begin
  if not public.is_admin() then raise exception 'admin required'; end if;
  if v_reason is null or char_length(v_reason) < 3 then raise exception 'cancellation reason required'; end if;
  if char_length(v_reason) > 500 then raise exception 'cancellation reason too long'; end if;
  select * into v_delivery from public.deliveries where id = p_delivery_id for update;
  if not found then raise exception 'delivery not found'; end if;
  if v_delivery.status in ('delivered', 'failed') then raise exception 'delivery is already closed'; end if;

  select m.donation_id, m.need_id, d.user_id, n.user_id
  into v_donation, v_need, v_donor, v_recipient
  from public.matches m
  join public.donations d on d.id = m.donation_id
  join public.needs n on n.id = m.need_id
  where m.id = v_delivery.match_id;
  v_picked := v_delivery.picked_up_at is not null;

  update public.deliveries
  set status = 'failed', courier_id = null, vehicle_id = null, offer_expires_at = null,
      pickup_pin_hash = null, delivery_pin_hash = null,
      pickup_pin_expires_at = null, delivery_pin_expires_at = null,
      pickup_pin_attempts = 0, delivery_pin_attempts = 0
  where id = p_delivery_id;

  -- Release the pair so both records can be matched again.
  update public.matches set status = 'cancelled'
  where id = v_delivery.match_id and status in ('offered', 'accepted');

  if v_picked then
    -- The item already left the donor: hand it to staff review / warehouse intake.
    update public.donations set status = 'under_review', updated_at = now()
    where id = v_donation and status in ('picked_up', 'out_for_delivery');
  else
    update public.donations set status = 'available', updated_at = now()
    where id = v_donation and status in ('matched', 'pickup_scheduled');
  end if;
  update public.needs set status = 'waiting', updated_at = now()
  where id = v_need and status in ('matched', 'delivery_scheduled');

  -- Cash pledges. Only a pledge linked to this delivery alone is closed: no
  -- other delivery can ever show it to a courier. A pledge that (also) points
  -- at the donation or the need is deliberately left pending, because both
  -- records return to the queue and the next delivery's courier collects it.
  -- A pledge the courier already confirmed as received stays pending for the
  -- normal admin verification.
  update public.contributions c
  set status = 'rejected', verified_by = auth.uid(), verified_at = now()
  where c.delivery_id = p_delivery_id
    and c.donation_id is null and c.need_id is null
    and c.status = 'pending'
    and c.payment_method = 'cash_to_courier'
    and c.courier_received is distinct from true
    and c.user_id in (v_donor, v_recipient);
  get diagnostics v_pledges = row_count;

  insert into public.delivery_events(delivery_id, actor_id, event_type, metadata)
  values (p_delivery_id, auth.uid(), 'delivery_cancelled', jsonb_build_object(
    'reason', v_reason, 'previous_status', v_delivery.status::text,
    'previous_courier_id', v_delivery.courier_id, 'after_pickup', v_picked,
    'dispatch_attempt', v_delivery.dispatch_attempt
  ));
  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), 'cancel_delivery', 'delivery', p_delivery_id, jsonb_build_object(
    'reason', v_reason, 'previous_status', v_delivery.status::text,
    'previous_courier_id', v_delivery.courier_id, 'after_pickup', v_picked,
    'donation_id', v_donation, 'need_id', v_need, 'pledges_rejected', v_pledges
  ));
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Cash pledges: the courier answers once, and an admin cannot verify cash
--    the courier reported as not received.
-- ---------------------------------------------------------------------------
create or replace function public.courier_confirm_cash_pledge(p_contribution_id uuid, p_received boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_contribution public.contributions;
  v_delivery uuid;
begin
  if not public.is_courier() or not public.is_active_user() then raise exception 'active courier required'; end if;
  if p_received is null then raise exception 'answer required'; end if;
  select * into v_contribution from public.contributions where id = p_contribution_id for update;
  if not found or v_contribution.payment_method is distinct from 'cash_to_courier'
     or v_contribution.status <> 'pending' then
    raise exception 'pledge is not awaiting courier confirmation';
  end if;

  select del.id into v_delivery
  from public.deliveries del
  join public.matches m on m.id = del.match_id
  join public.donations d on d.id = m.donation_id
  join public.needs n on n.id = m.need_id
  where del.courier_id = auth.uid()
    and (
      del.status in ('heading_to_pickup', 'picked_up', 'heading_to_recipient')
      or (del.status = 'delivered' and del.delivered_at > now() - interval '24 hours')
    )
    and (
      (v_contribution.donation_id = d.id and v_contribution.user_id = d.user_id)
      or (v_contribution.need_id = n.id and v_contribution.user_id = n.user_id)
      or (v_contribution.delivery_id = del.id and v_contribution.user_id in (d.user_id, n.user_id))
    )
  order by del.assigned_at desc nulls last
  limit 1;
  if v_delivery is null then raise exception 'pledge is not linked to your delivery'; end if;

  -- Write-once: a later change of mind goes through an admin.
  if v_contribution.courier_received is not null then raise exception 'pledge already answered'; end if;

  update public.contributions
  set courier_received = p_received, courier_confirmed_at = now(), courier_confirmed_by = auth.uid()
  where id = p_contribution_id;

  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), 'courier_confirm_cash_pledge', 'contribution', p_contribution_id,
    jsonb_build_object('received', p_received, 'delivery_id', v_delivery));
end;
$$;

-- Same signature, idempotency and messages as 0058. A pledge the courier has
-- not answered (courier_received is null) can still be reviewed, so pledges
-- without a delivery are not stuck.
create or replace function public.admin_verify_contribution(
  p_contribution_id uuid,
  p_verified boolean,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_contribution public.contributions;
begin
  if not public.is_admin() then
    raise exception 'admin required';
  end if;

  select * into v_contribution from public.contributions
  where id = p_contribution_id for update;
  if not found or v_contribution.status <> 'pending' then
    raise exception 'contribution is no longer pending';
  end if;
  if p_verified and v_contribution.payment_method = 'cash_to_courier'
     and v_contribution.courier_received is false then
    raise exception 'courier reported cash not received';
  end if;

  update public.contributions
     set status = case
                    when p_verified then 'verified'::public.contribution_status
                    else 'rejected'::public.contribution_status
                  end,
         verified_by = auth.uid(),
         verified_at = now()
   where id = p_contribution_id;

  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  values (
    auth.uid(),
    case when p_verified then 'verify_contribution' else 'reject_contribution' end,
    'contribution',
    p_contribution_id,
    jsonb_build_object('note', p_note)
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Handoff PINs issued before the per-delivery salt can never verify.
--    Clear them on every open delivery so the owner simply issues a new one.
--    status is not touched, so no notification trigger fires.
-- ---------------------------------------------------------------------------
update public.deliveries
set pickup_pin_hash = null, delivery_pin_hash = null,
    pickup_pin_expires_at = null, delivery_pin_expires_at = null,
    pickup_pin_attempts = 0, delivery_pin_attempts = 0
where status <> 'delivered'
  and (pickup_pin_hash is not null or delivery_pin_hash is not null
       or pickup_pin_expires_at is not null or delivery_pin_expires_at is not null
       or pickup_pin_attempts <> 0 or delivery_pin_attempts <> 0);

-- ---------------------------------------------------------------------------
-- 6. Role changes: a demoted account must not stay locked behind a staff
--    temporary-password flag that it can no longer clear.
-- ---------------------------------------------------------------------------
create or replace function public.admin_set_user_role(p_user_id uuid,p_role public.user_role)
returns void language plpgsql security definer set search_path=public as $$
declare v_primary boolean; begin
  if not public.is_admin() then raise exception 'admin required'; end if;
  select is_primary_admin into v_primary from public.profiles where id=p_user_id;
  if coalesce(v_primary,false) then raise exception 'primary admin role cannot be changed'; end if;
  if p_role='admin' then raise exception 'creating additional admins is disabled'; end if;
  if p_role not in ('user','courier','supervisor') then raise exception 'invalid role'; end if;
  update public.profiles set role=p_role,updated_at=now() where id=p_user_id;
  if p_role='user' then
    update public.profiles set force_password_change=false,temp_password_expires_at=null where id=p_user_id;
  end if;
  if p_role='courier' then
    insert into public.couriers(user_id,active) values(p_user_id,true) on conflict(user_id) do update set active=true;
  else update public.couriers set active=false where user_id=p_user_id; end if;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values((select auth.uid()),'set_user_role','profile',p_user_id,jsonb_build_object('role',p_role));
end $$;

-- ---------------------------------------------------------------------------
-- 7. Staff passwords. Everything here is callable by the service role only,
--    i.e. by the Edge Functions after they authenticated the caller.
-- ---------------------------------------------------------------------------
create table if not exists public.staff_password_attempts (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  failed_count integer not null default 0,
  window_started_at timestamptz not null default now()
);
-- RLS without policies: no API role can read or write the counters.
alter table public.staff_password_attempts enable row level security;
revoke all on table public.staff_password_attempts from public, anon, authenticated;

comment on table public.staff_password_attempts is
  'Failed current-password checks of staff-change-password: 5 failures within 15 minutes lock further attempts until the window ends.';

-- Compares against the hash the auth server stores, without creating a
-- session and without the per-IP sign-in rate limit.
create or replace function public.staff_verify_password(p_user uuid, p_password text)
returns boolean
language plpgsql
stable
security definer
set search_path = extensions, public
as $$
declare
  v_hash text;
begin
  if p_user is null or p_password is null then return false; end if;
  select u.encrypted_password into v_hash
  from auth.users u
  where u.id = p_user and u.deleted_at is null;
  if v_hash is null or v_hash = '' then return false; end if;
  return v_hash = crypt(p_password, v_hash);
end;
$$;

create or replace function public.staff_password_is_locked(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.staff_password_attempts a
    where a.user_id = p_user
      and a.failed_count >= 5
      and a.window_started_at > now() - interval '15 minutes'
  );
$$;

-- Returns the number of failures in the current window.
create or replace function public.staff_password_register_failure(p_user uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  insert into public.staff_password_attempts as a (user_id, failed_count, window_started_at)
  values (p_user, 1, now())
  on conflict (user_id) do update
  set failed_count = case
        when a.window_started_at <= now() - interval '15 minutes' then 1
        else a.failed_count + 1
      end,
      window_started_at = case
        when a.window_started_at <= now() - interval '15 minutes' then now()
        else a.window_started_at
      end
  returning a.failed_count into v_count;
  return v_count;
end;
$$;

create or replace function public.staff_password_reset_attempts(p_user uuid)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.staff_password_attempts where user_id = p_user;
$$;

-- Ends every session of an account. Returns false when the auth schema does
-- not allow it, so the caller can report that instead of failing.
create or replace function public.staff_revoke_sessions(p_user uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user is null then return false; end if;
  -- Refresh tokens reference their session with ON DELETE CASCADE.
  delete from auth.sessions where user_id = p_user;
  return true;
exception when insufficient_privilege or undefined_table or undefined_column then
  return false;
end;
$$;

-- Second half of admin-reset-staff-password: the Edge Function has already
-- set the new temporary password; this forces its exchange and records who
-- did it. The acting admin is passed explicitly and re-checked here.
create or replace function public.admin_mark_staff_password_reset(p_admin_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_target public.profiles;
begin
  if p_admin_id is null or not exists (
    select 1 from public.profiles a
    where a.id = p_admin_id and a.role::text = 'admin'
      and not a.is_suspended and not a.force_password_change
  ) then raise exception 'active admin required'; end if;

  select * into v_target from public.profiles where id = p_user_id for update;
  if not found then raise exception 'profile not found'; end if;
  if v_target.is_primary_admin or v_target.role::text not in ('courier', 'supervisor') then
    raise exception 'not staff';
  end if;

  update public.profiles
  set force_password_change = true, password_changed_at = null,
      temp_password_expires_at = now() + interval '72 hours', updated_at = now()
  where id = p_user_id;

  delete from public.staff_password_attempts where user_id = p_user_id;

  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  values (p_admin_id, 'reset_staff_password', 'profile', p_user_id,
    jsonb_build_object('role', v_target.role::text));
end;
$$;

-- admin-create-staff marks the auth user it creates as pending until the
-- profile is finalized. This returns such a half-provisioned user so a retry
-- can resume it; an account that is already staff, or was not created by that
-- function, is never returned.
create or replace function public.pending_staff_user_id(p_email text)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select u.id
  from auth.users u
  join public.profiles p on p.id = u.id
  where lower(u.email) = lower(trim(coalesce(p_email, '')))
    and u.deleted_at is null
    and u.raw_app_meta_data ->> 'pending_staff' = 'true'
    and p.role::text = 'user'
    and not p.is_primary_admin
    and p.staff_created_by is null
  order by u.created_at desc
  limit 1;
$$;

-- ---------------------------------------------------------------------------
-- Privileges. Supabase default privileges grant EXECUTE to every API role,
-- so each function is revoked explicitly before the intended grant.
-- ---------------------------------------------------------------------------
-- handle_new_user keeps the privileges it already had (create or replace
-- preserves them); the auth trigger is deliberately left untouched.
revoke all on function public.request_account_deletion() from public, anon;
revoke all on function public.admin_set_user_suspension(uuid, boolean, text) from public, anon;
revoke all on function public.admin_prepare_account_deletion(uuid, text) from public, anon;
revoke all on function public.admin_complete_account_deletion(uuid) from public, anon;
revoke all on function public.admin_create_delivery(uuid, uuid, uuid, text, text) from public, anon;
revoke all on function public.admin_reassign_delivery(uuid, uuid, uuid) from public, anon;
revoke all on function public.admin_pause_delivery(uuid, text) from public, anon;
revoke all on function public.courier_report_delivery_failure(uuid, text, text, text, double precision, double precision) from public, anon;
revoke all on function public.admin_cancel_delivery(uuid, text) from public, anon;
revoke all on function public.courier_confirm_cash_pledge(uuid, boolean) from public, anon;
revoke all on function public.admin_verify_contribution(uuid, boolean, text) from public, anon;
revoke all on function public.admin_set_user_role(uuid, public.user_role) from public, anon;

grant execute on function public.request_account_deletion() to authenticated;
grant execute on function public.admin_set_user_suspension(uuid, boolean, text) to authenticated;
grant execute on function public.admin_prepare_account_deletion(uuid, text) to authenticated;
grant execute on function public.admin_complete_account_deletion(uuid) to authenticated;
grant execute on function public.admin_create_delivery(uuid, uuid, uuid, text, text) to authenticated;
grant execute on function public.admin_reassign_delivery(uuid, uuid, uuid) to authenticated;
grant execute on function public.admin_pause_delivery(uuid, text) to authenticated;
grant execute on function public.courier_report_delivery_failure(uuid, text, text, text, double precision, double precision) to authenticated;
grant execute on function public.admin_cancel_delivery(uuid, text) to authenticated;
grant execute on function public.courier_confirm_cash_pledge(uuid, boolean) to authenticated;
grant execute on function public.admin_verify_contribution(uuid, boolean, text) to authenticated;
grant execute on function public.admin_set_user_role(uuid, public.user_role) to authenticated;

revoke all on function public.staff_verify_password(uuid, text) from public, anon, authenticated;
revoke all on function public.staff_password_is_locked(uuid) from public, anon, authenticated;
revoke all on function public.staff_password_register_failure(uuid) from public, anon, authenticated;
revoke all on function public.staff_password_reset_attempts(uuid) from public, anon, authenticated;
revoke all on function public.staff_revoke_sessions(uuid) from public, anon, authenticated;
revoke all on function public.admin_mark_staff_password_reset(uuid, uuid) from public, anon, authenticated;
revoke all on function public.pending_staff_user_id(text) from public, anon, authenticated;

grant execute on function public.staff_verify_password(uuid, text) to service_role;
grant execute on function public.staff_password_is_locked(uuid) to service_role;
grant execute on function public.staff_password_register_failure(uuid) to service_role;
grant execute on function public.staff_password_reset_attempts(uuid) to service_role;
grant execute on function public.staff_revoke_sessions(uuid) to service_role;
grant execute on function public.admin_mark_staff_password_reset(uuid, uuid) to service_role;
grant execute on function public.pending_staff_user_id(text) to service_role;

comment on function public.admin_pause_delivery(uuid, text) is
  'Admin-only: parks an accepted delivery whose courier is unreachable in ''rescheduled'' so it can be reassigned or cancelled.';
comment on function public.admin_reassign_delivery(uuid, uuid, uuid) is
  'Admin-only reassignment of an assigned/rescheduled delivery. A collected item can only go back to the courier who collected it.';
comment on function public.staff_verify_password(uuid, text) is
  'Service-role only. True when the password matches the stored hash of the account; creates no session.';
comment on function public.admin_mark_staff_password_reset(uuid, uuid) is
  'Service-role only. Forces a courier/supervisor to exchange the temporary password an admin just set, and audits it.';
