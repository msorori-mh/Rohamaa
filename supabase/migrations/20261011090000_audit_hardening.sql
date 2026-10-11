-- Audit hardening (1/2): server-controlled inserts, input length limits,
-- per-delivery PIN salting, phase-correct delivery failure handling,
-- cash-pledge confirmation, service withdrawal, reviewer photo access and
-- atomic staff provisioning. Forward-only; no operational rows are deleted.

-- ---------------------------------------------------------------------------
-- 1. Server-controlled public codes and initial workflow state.
-- ---------------------------------------------------------------------------
-- SECURITY INVOKER on purpose: current_user is the PostgREST request role, so
-- service-role fixtures, migrations and SECURITY DEFINER RPCs are untouched.
-- gen_random_uuid() is a core function, so no cross-schema EXECUTE is needed.
create or replace function public.enforce_item_insert_defaults()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if current_user <> 'authenticated' then return new; end if;
  new.public_code := 'RHM-MRB-'
    || case when tg_table_name = 'donations' then 'DON' else 'NEED' end
    || '-' || to_char(now(), 'YYMMDD')
    || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
  new.status := 'submitted';
  new.created_at := now();
  new.updated_at := now();
  return new;
end;
$$;

create or replace function public.enforce_contribution_insert_defaults()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if current_user <> 'authenticated' then return new; end if;
  new.public_code := 'RHM-MRB-CTR-' || to_char(now(), 'YYMMDD')
    || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
  new.status := 'pending';
  new.verified_by := null;
  new.verified_at := null;
  new.courier_received := null;
  new.courier_confirmed_at := null;
  new.courier_confirmed_by := null;
  new.created_at := now();
  return new;
end;
$$;

-- Cash handed to a courier is acknowledged by that courier before an admin
-- verifies the contribution. The columns are server-written only.
alter table public.contributions
  add column if not exists courier_received boolean,
  add column if not exists courier_confirmed_at timestamptz,
  add column if not exists courier_confirmed_by uuid references public.profiles(id) on delete set null;
create index if not exists contributions_courier_confirmed_by_idx
  on public.contributions(courier_confirmed_by);

drop trigger if exists donations_enforce_insert_defaults on public.donations;
create trigger donations_enforce_insert_defaults
before insert on public.donations
for each row execute function public.enforce_item_insert_defaults();

drop trigger if exists needs_enforce_insert_defaults on public.needs;
create trigger needs_enforce_insert_defaults
before insert on public.needs
for each row execute function public.enforce_item_insert_defaults();

drop trigger if exists contributions_enforce_insert_defaults on public.contributions;
create trigger contributions_enforce_insert_defaults
before insert on public.contributions
for each row execute function public.enforce_contribution_insert_defaults();

-- Trigger functions are never RPC endpoints; triggers fire regardless of EXECUTE.
revoke all on function public.enforce_item_insert_defaults() from public, anon, authenticated;
revoke all on function public.enforce_contribution_insert_defaults() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Length limits on user-writable free text. NOT VALID: existing production
--    rows are not re-checked, new and updated rows are.
-- ---------------------------------------------------------------------------
do $$
declare
  v_rule record;
  v_name text;
begin
  for v_rule in
    select * from (values
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
    ) as rules(table_name, column_name, max_length)
  loop
    v_name := v_rule.table_name || '_' || v_rule.column_name || '_max_length';
    execute format('alter table public.%I drop constraint if exists %I', v_rule.table_name, v_name);
    execute format(
      'alter table public.%I add constraint %I check (char_length(%I) <= %s) not valid',
      v_rule.table_name, v_name, v_rule.column_name, v_rule.max_length
    );
  end loop;
end $$;

-- Structured attributes are client-supplied JSON; bound their serialized size.
alter table public.needs drop constraint if exists needs_item_attributes_max_size;
alter table public.needs add constraint needs_item_attributes_max_size
  check (char_length(item_attributes::text) <= 4000) not valid;
alter table public.donations drop constraint if exists donations_item_attributes_max_size;
alter table public.donations add constraint donations_item_attributes_max_size
  check (char_length(item_attributes::text) <= 4000) not valid;

-- ---------------------------------------------------------------------------
-- 3. Handoff PINs: salted per delivery, attempts and expiry unchanged.
--    A PIN issued before this migration simply has to be issued again.
-- ---------------------------------------------------------------------------
create or replace function public.user_issue_handoff_pin(p_delivery_id uuid, p_kind text)
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_bytes bytea;
  v_pin text;
  v_donor uuid;
  v_recipient uuid;
  v_status public.delivery_status;
begin
  if not public.is_active_user() then raise exception 'account suspended'; end if;
  select d.user_id, n.user_id, del.status into v_donor, v_recipient, v_status
  from public.deliveries del
  join public.matches m on m.id = del.match_id
  join public.donations d on d.id = m.donation_id
  join public.needs n on n.id = m.need_id
  where del.id = p_delivery_id for update of del;
  if not found then raise exception 'delivery not found'; end if;

  if p_kind = 'pickup' then
    if v_donor <> auth.uid() then raise exception 'not pickup owner'; end if;
    if v_status <> 'heading_to_pickup' then raise exception 'pickup PIN unavailable in this state'; end if;
  elsif p_kind = 'delivery' then
    if v_recipient <> auth.uid() then raise exception 'not delivery owner'; end if;
    if v_status <> 'heading_to_recipient' then raise exception 'delivery PIN unavailable in this state'; end if;
  else
    raise exception 'invalid handoff kind';
  end if;

  v_bytes := gen_random_bytes(2);
  v_pin := lpad((((get_byte(v_bytes, 0) * 256) + get_byte(v_bytes, 1)) % 10000)::text, 4, '0');
  if p_kind = 'pickup' then
    update public.deliveries
    set pickup_pin_hash = public.hash_pin(p_delivery_id::text || ':' || v_pin),
        pickup_pin_expires_at = now() + interval '10 minutes',
        pickup_pin_attempts = 0
    where id = p_delivery_id;
  else
    update public.deliveries
    set delivery_pin_hash = public.hash_pin(p_delivery_id::text || ':' || v_pin),
        delivery_pin_expires_at = now() + interval '10 minutes',
        delivery_pin_attempts = 0
    where id = p_delivery_id;
  end if;
  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), 'issue_handoff_pin', 'delivery', p_delivery_id, jsonb_build_object('kind', p_kind));
  return v_pin;
end;
$$;

create or replace function public.verify_delivery_pin(
  p_delivery_id uuid,
  p_pin text,
  p_kind text,
  p_latitude double precision default null,
  p_longitude double precision default null
)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_delivery public.deliveries;
  v_expected_hash text;
  v_expires_at timestamptz;
  v_attempts integer;
  v_issued boolean;
begin
  if not public.is_courier() or not public.is_active_user() then raise exception 'active courier required'; end if;
  select * into v_delivery from public.deliveries where id = p_delivery_id for update;
  if not found then return false; end if;
  if v_delivery.courier_id is distinct from auth.uid() then raise exception 'not assigned courier'; end if;

  if p_kind = 'pickup' then
    if v_delivery.status <> 'heading_to_pickup' then raise exception 'pickup is not ready for verification'; end if;
    v_expected_hash := v_delivery.pickup_pin_hash;
    v_expires_at := v_delivery.pickup_pin_expires_at;
    v_attempts := v_delivery.pickup_pin_attempts;
  elsif p_kind = 'delivery' then
    if v_delivery.status <> 'heading_to_recipient' then raise exception 'dropoff is not ready for verification'; end if;
    v_expected_hash := v_delivery.delivery_pin_hash;
    v_expires_at := v_delivery.delivery_pin_expires_at;
    v_attempts := v_delivery.delivery_pin_attempts;
  else
    raise exception 'invalid pin kind';
  end if;

  -- A PIN that was never issued, or has expired, is not courier misconduct.
  v_issued := v_expected_hash is not null and v_expires_at is not null and v_expires_at > now();

  if not v_issued or p_pin is null or p_pin !~ '^[0-9]{4}$' or v_attempts >= 5
     or public.hash_pin(p_delivery_id::text || ':' || p_pin) is distinct from v_expected_hash then
    if p_kind = 'pickup' then
      update public.deliveries set pickup_pin_attempts = least(pickup_pin_attempts + 1, 5) where id = p_delivery_id;
    else
      update public.deliveries set delivery_pin_attempts = least(delivery_pin_attempts + 1, 5) where id = p_delivery_id;
    end if;
    if v_issued then
      insert into public.risk_flags(user_id, delivery_id, rule_code, severity, details)
      values (auth.uid(), p_delivery_id, 'INVALID_DELIVERY_PIN', 'medium', jsonb_build_object('kind', p_kind));
    end if;
    return false;
  end if;

  if p_kind = 'pickup' then
    update public.deliveries
    set status = 'picked_up', picked_up_at = now(), pickup_pin_hash = null, pickup_pin_expires_at = null
    where id = p_delivery_id;
    update public.donations set status = 'picked_up', updated_at = now()
    where id = (select m.donation_id from public.matches m where m.id = v_delivery.match_id);
  else
    update public.deliveries
    set status = 'delivered', delivered_at = now(), delivery_pin_hash = null, delivery_pin_expires_at = null
    where id = p_delivery_id;
    update public.donations set status = 'delivered', updated_at = now()
    where id = (select m.donation_id from public.matches m where m.id = v_delivery.match_id);
    update public.needs set status = 'fulfilled', updated_at = now()
    where id = (select m.need_id from public.matches m where m.id = v_delivery.match_id);
  end if;

  insert into public.delivery_events(delivery_id, actor_id, event_type, latitude, longitude)
  values (p_delivery_id, auth.uid(),
    case when p_kind = 'pickup' then 'pickup_pin_verified' else 'delivery_pin_verified' end,
    p_latitude, p_longitude);
  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  values (auth.uid(),
    case when p_kind = 'pickup' then 'confirm_delivery_pickup' else 'confirm_delivery_dropoff' end,
    'delivery', p_delivery_id, '{}'::jsonb);
  return true;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Delivery failure, reassignment and cancellation.
--    'rescheduled' = waiting for an admin; 'failed' = closed by an admin.
-- ---------------------------------------------------------------------------
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

create or replace function public.courier_respond_delivery(
  p_delivery_id uuid,
  p_accept boolean,
  p_reason text default null
)
returns public.delivery_status
language plpgsql
security definer
set search_path = public
as $$
declare
  v_delivery public.deliveries;
  v_next public.delivery_status;
begin
  if not public.is_courier() or not public.is_active_user() then raise exception 'active courier required'; end if;
  if p_accept is null then raise exception 'response required'; end if;
  select * into v_delivery from public.deliveries
  where id = p_delivery_id and courier_id = auth.uid() for update;
  if not found then raise exception 'delivery not assigned to courier'; end if;
  if v_delivery.status <> 'assigned' then raise exception 'assignment is no longer awaiting response'; end if;

  if p_accept then
    if v_delivery.offer_expires_at is not null and v_delivery.offer_expires_at < now() then
      raise exception 'assignment offer expired';
    end if;
    -- A task reassigned after the item was collected resumes at the dropoff
    -- phase; it must never ask the donor for a second pickup.
    if v_delivery.picked_up_at is not null then
      v_next := 'picked_up'::public.delivery_status;
    else
      v_next := 'heading_to_pickup'::public.delivery_status;
    end if;
    update public.deliveries
    set status = v_next, courier_responded_at = now(), rejection_reason = null
    where id = p_delivery_id;
    insert into public.delivery_events(delivery_id, actor_id, event_type, metadata)
    values (p_delivery_id, auth.uid(), 'courier_accepted', jsonb_build_object(
      'dispatch_attempt', v_delivery.dispatch_attempt, 'resumed_status', v_next::text
    ));
  else
    if p_reason is null or p_reason not in ('unavailable', 'too_far', 'vehicle_issue', 'schedule_conflict', 'other') then
      raise exception 'valid rejection reason required';
    end if;
    update public.deliveries
    set status = 'rescheduled', courier_responded_at = now(), rejection_reason = p_reason,
        courier_id = null, vehicle_id = null
    where id = p_delivery_id;
    v_next := 'rescheduled'::public.delivery_status;
    insert into public.delivery_events(delivery_id, actor_id, event_type, metadata)
    values (p_delivery_id, auth.uid(), 'courier_rejected', jsonb_build_object(
      'reason', p_reason, 'dispatch_attempt', v_delivery.dispatch_attempt
    ));
  end if;

  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), case when p_accept then 'courier_accept_delivery' else 'courier_reject_delivery' end,
    'delivery', p_delivery_id,
    jsonb_build_object('reason', p_reason, 'dispatch_attempt', v_delivery.dispatch_attempt));
  return v_next;
end;
$$;

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
  v_picked boolean;
begin
  if not public.is_admin() then raise exception 'admin required'; end if;
  if v_reason is null or char_length(v_reason) < 3 then raise exception 'cancellation reason required'; end if;
  if char_length(v_reason) > 500 then raise exception 'cancellation reason too long'; end if;
  select * into v_delivery from public.deliveries where id = p_delivery_id for update;
  if not found then raise exception 'delivery not found'; end if;
  if v_delivery.status in ('delivered', 'failed') then raise exception 'delivery is already closed'; end if;

  select m.donation_id, m.need_id into v_donation, v_need
  from public.matches m where m.id = v_delivery.match_id;
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
    'donation_id', v_donation, 'need_id', v_need
  ));
end;
$$;

-- Same return shape; closed deliveries leave the dispatch queue.
create or replace function public.admin_delivery_dispatch_queue()
returns table(
  delivery_id uuid, public_code text, status public.delivery_status,
  assigned_at timestamptz, offer_expires_at timestamptz, dispatch_attempt integer,
  courier_id uuid, courier_name text, vehicle_id uuid, vehicle_code text,
  rejection_reason text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'admin required'; end if;
  return query
  select d.id, d.public_code, d.status, d.assigned_at, d.offer_expires_at, d.dispatch_attempt,
         d.courier_id, p.full_name, d.vehicle_id, v.code, d.rejection_reason
  from public.deliveries d
  left join public.profiles p on p.id = d.courier_id
  left join public.vehicles v on v.id = d.vehicle_id
  where d.status not in ('delivered', 'failed')
  order by case d.status when 'rescheduled' then 1 when 'assigned' then 2 else 3 end,
           d.assigned_at nulls first;
end;
$$;

-- Same return shape; contact details follow the phase the task will resume at.
create or replace function public.courier_task_details(p_delivery_id uuid)
returns table(
  delivery_id uuid, public_code text, status public.delivery_status,
  pickup_area text, pickup_description text, pickup_latitude double precision,
  pickup_longitude double precision, pickup_phone text,
  dropoff_area text, dropoff_description text, dropoff_latitude double precision,
  dropoff_longitude double precision, dropoff_phone text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_courier() or not public.is_active_user() then raise exception 'active courier required'; end if;
  return query
  select del.id, del.public_code, del.status,
    case when (del.status = 'assigned' and del.picked_up_at is null) or del.status = 'heading_to_pickup' then da.area end,
    case when del.status = 'heading_to_pickup' then da.description end,
    case when del.status = 'heading_to_pickup' then da.latitude end,
    case when del.status = 'heading_to_pickup' then da.longitude end,
    case when del.status = 'heading_to_pickup' then dp.phone end,
    case when (del.status = 'assigned' and del.picked_up_at is not null) or del.status in ('picked_up', 'heading_to_recipient') then na.area end,
    case when del.status in ('picked_up', 'heading_to_recipient') then na.description end,
    case when del.status in ('picked_up', 'heading_to_recipient') then na.latitude end,
    case when del.status in ('picked_up', 'heading_to_recipient') then na.longitude end,
    case when del.status in ('picked_up', 'heading_to_recipient') then np.phone end
  from public.deliveries del
  join public.matches m on m.id = del.match_id
  join public.donations d on d.id = m.donation_id
  join public.needs n on n.id = m.need_id
  join public.profiles dp on dp.id = d.user_id
  join public.profiles np on np.id = n.user_id
  left join public.addresses da on da.id = d.address_id
  left join public.addresses na on na.id = n.address_id
  where del.id = p_delivery_id and del.courier_id = auth.uid();
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Cash pledges: visible to, and acknowledged by, the assigned courier only.
-- ---------------------------------------------------------------------------
create or replace function public.courier_delivery_cash_pledges(p_delivery_id uuid)
returns table(contribution_id uuid, public_code text, amount_yer integer, courier_received boolean)
language plpgsql
stable
security definer
set search_path = public
as $$
#variable_conflict use_column
begin
  if not public.is_courier() or not public.is_active_user() then raise exception 'active courier required'; end if;
  return query
  select c.id, c.public_code, c.amount_yer, c.courier_received
  from public.deliveries del
  join public.matches m on m.id = del.match_id
  join public.donations d on d.id = m.donation_id
  join public.needs n on n.id = m.need_id
  join public.contributions c
    on c.payment_method = 'cash_to_courier'
   and c.status = 'pending'
   and (
     (c.donation_id = d.id and c.user_id = d.user_id)
     or (c.need_id = n.id and c.user_id = n.user_id)
     or (c.delivery_id = del.id and c.user_id in (d.user_id, n.user_id))
   )
  where del.id = p_delivery_id
    and del.courier_id = auth.uid()
    and (
      del.status in ('heading_to_pickup', 'picked_up', 'heading_to_recipient')
      or (del.status = 'delivered' and del.delivered_at > now() - interval '24 hours')
    )
  order by c.created_at, c.id;
end;
$$;

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

  update public.contributions
  set courier_received = p_received, courier_confirmed_at = now(), courier_confirmed_by = auth.uid()
  where id = p_contribution_id;

  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), 'courier_confirm_cash_pledge', 'contribution', p_contribution_id,
    jsonb_build_object('received', p_received, 'delivery_id', v_delivery));
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. Users withdraw their own service offers / requests before matching.
-- ---------------------------------------------------------------------------
create or replace function public.user_withdraw_service_offer(p_offer_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  update public.service_offers
  set status = 'cancelled', updated_at = now()
  where id = p_offer_id and user_id = auth.uid()
    and status in ('submitted', 'approved', 'paused');
  if not found then raise exception 'service offer cannot be withdrawn'; end if;
  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), 'withdraw_service_offer', 'service_offer', p_offer_id, '{}'::jsonb);
end;
$$;

create or replace function public.user_cancel_service_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  update public.service_requests
  set status = 'cancelled', updated_at = now()
  where id = p_request_id and user_id = auth.uid()
    and status in ('submitted', 'reviewing');
  if not found then raise exception 'service request cannot be cancelled'; end if;
  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), 'cancel_service_request', 'service_request', p_request_id, '{}'::jsonb);
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. Donation photos for reviewers.
-- ---------------------------------------------------------------------------
drop policy if exists "donation_image_rows_admin_select" on public.donation_images;
create policy "donation_image_rows_admin_select" on public.donation_images
for select to authenticated
using (public.is_admin());

drop policy if exists "donation_images_admin_read" on storage.objects;
create policy "donation_images_admin_read"
on storage.objects for select
to authenticated
using (bucket_id = 'donation-images' and public.is_admin());

-- storage_path is client-supplied, so only paths inside the donor's own
-- folder are ever handed to a reviewer.
create or replace function public.admin_donation_image_paths(p_donation_id uuid)
returns table(storage_path text)
language plpgsql
stable
security definer
set search_path = public
as $$
#variable_conflict use_column
begin
  if not public.is_admin() then raise exception 'admin required'; end if;
  return query
  select di.storage_path
  from public.donation_images di
  join public.donations d on d.id = di.donation_id
  where di.donation_id = p_donation_id
    and di.storage_path like d.user_id::text || '/%'
  order by di.sort_order, di.created_at, di.id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 8. Staff accounts: expiring temporary passwords and atomic provisioning.
-- ---------------------------------------------------------------------------
alter table public.profiles add column if not exists temp_password_expires_at timestamptz;
comment on column public.profiles.temp_password_expires_at is
  'When set together with force_password_change, the temporary password may no longer be exchanged after this instant.';

-- Called only by the admin-create-staff Edge Function with the service role.
-- The acting admin is passed explicitly and re-checked here, and every write
-- happens in one transaction so a failure leaves nothing half-provisioned.
create or replace function public.admin_finalize_staff_account(
  p_admin_id uuid,
  p_user_id uuid,
  p_email text,
  p_full_name text,
  p_role text,
  p_area_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text := lower(trim(coalesce(p_email, '')));
  v_name text := trim(coalesce(p_full_name, ''));
  v_area_count integer := coalesce(cardinality(p_area_ids), 0);
  v_target public.profiles;
begin
  if p_admin_id is null or not exists (
    select 1 from public.profiles a
    where a.id = p_admin_id and a.role::text = 'admin'
      and not a.is_suspended and not a.force_password_change
  ) then raise exception 'active admin required'; end if;
  if p_role is null or p_role not in ('courier', 'supervisor') then raise exception 'invalid role'; end if;
  if char_length(v_name) < 2 or char_length(v_name) > 120 then raise exception 'invalid full name'; end if;
  if char_length(v_email) < 3 or char_length(v_email) > 254 then raise exception 'invalid email'; end if;
  if v_area_count < 1 or v_area_count > 20 then raise exception 'invalid area count'; end if;
  if (select count(distinct x) from unnest(p_area_ids) as x) <> v_area_count then
    raise exception 'duplicate area';
  end if;
  if (select count(*) from public.service_areas sa where sa.id = any(p_area_ids) and sa.active) <> v_area_count then
    raise exception 'invalid area';
  end if;

  select * into v_target from public.profiles where id = p_user_id for update;
  if not found then raise exception 'profile not found'; end if;
  if v_target.is_primary_admin or v_target.role::text <> 'user' or p_user_id = p_admin_id then
    raise exception 'account cannot be provisioned as staff';
  end if;

  update public.profiles
  set full_name = v_name, staff_email = v_email, role = p_role::public.user_role,
      force_password_change = true, password_changed_at = null,
      temp_password_expires_at = now() + interval '72 hours',
      staff_created_by = p_admin_id, is_suspended = false, updated_at = now()
  where id = p_user_id;

  insert into public.staff_area_assignments(user_id, area_id, is_primary, created_by)
  select p_user_id, t.area_id, t.ord = 1, p_admin_id
  from unnest(p_area_ids) with ordinality as t(area_id, ord);

  if p_role = 'courier' then
    insert into public.couriers(user_id, active) values (p_user_id, true)
    on conflict (user_id) do update set active = true;
  end if;

  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  values (p_admin_id, 'create_staff_account', 'profile', p_user_id,
    jsonb_build_object('role', p_role, 'email', v_email, 'area_ids', to_jsonb(p_area_ids)));
end;
$$;

-- ---------------------------------------------------------------------------
-- Privileges. Supabase default privileges grant EXECUTE to every API role,
-- so each function is revoked explicitly before the intended grant.
-- ---------------------------------------------------------------------------
revoke all on function public.user_issue_handoff_pin(uuid, text) from public, anon;
revoke all on function public.verify_delivery_pin(uuid, text, text, double precision, double precision) from public, anon;
revoke all on function public.courier_report_delivery_failure(uuid, text, text, text, double precision, double precision) from public, anon;
revoke all on function public.courier_respond_delivery(uuid, boolean, text) from public, anon;
revoke all on function public.admin_reassign_delivery(uuid, uuid, uuid) from public, anon;
revoke all on function public.admin_cancel_delivery(uuid, text) from public, anon;
revoke all on function public.admin_delivery_dispatch_queue() from public, anon;
revoke all on function public.courier_task_details(uuid) from public, anon;
revoke all on function public.courier_delivery_cash_pledges(uuid) from public, anon;
revoke all on function public.courier_confirm_cash_pledge(uuid, boolean) from public, anon;
revoke all on function public.user_withdraw_service_offer(uuid) from public, anon;
revoke all on function public.user_cancel_service_request(uuid) from public, anon;
revoke all on function public.admin_donation_image_paths(uuid) from public, anon;
revoke all on function public.admin_finalize_staff_account(uuid, uuid, text, text, text, uuid[]) from public, anon, authenticated;

grant execute on function public.user_issue_handoff_pin(uuid, text) to authenticated;
grant execute on function public.verify_delivery_pin(uuid, text, text, double precision, double precision) to authenticated;
grant execute on function public.courier_report_delivery_failure(uuid, text, text, text, double precision, double precision) to authenticated;
grant execute on function public.courier_respond_delivery(uuid, boolean, text) to authenticated;
grant execute on function public.admin_reassign_delivery(uuid, uuid, uuid) to authenticated;
grant execute on function public.admin_cancel_delivery(uuid, text) to authenticated;
grant execute on function public.admin_delivery_dispatch_queue() to authenticated;
grant execute on function public.courier_task_details(uuid) to authenticated;
grant execute on function public.courier_delivery_cash_pledges(uuid) to authenticated;
grant execute on function public.courier_confirm_cash_pledge(uuid, boolean) to authenticated;
grant execute on function public.user_withdraw_service_offer(uuid) to authenticated;
grant execute on function public.user_cancel_service_request(uuid) to authenticated;
grant execute on function public.admin_donation_image_paths(uuid) to authenticated;
grant execute on function public.admin_finalize_staff_account(uuid, uuid, text, text, text, uuid[]) to service_role;

comment on function public.admin_cancel_delivery(uuid, text) is
  'Admin-only closure of a stuck delivery: releases the match, returns the need to waiting and the donation to available (or staff review if already collected).';
comment on function public.courier_delivery_cash_pledges(uuid) is
  'Pending cash-to-courier pledges of the two parties of a delivery, visible only to its assigned courier while the task is active.';
comment on function public.admin_finalize_staff_account(uuid, uuid, text, text, text, uuid[]) is
  'Service-role only. Atomically turns a freshly created auth user into a courier/supervisor on behalf of a re-verified admin.';
