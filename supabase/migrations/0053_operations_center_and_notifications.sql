-- Ruhamaa P1: unified user operations center, private in-app notifications,
-- and an admin priority queue. No historical notifications are backfilled.

create table public.user_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  notification_type text not null,
  title text not null,
  body text not null,
  entity_type text not null,
  entity_id uuid not null,
  action_route text not null check (action_route in ('/offers','/handoffs','/my-services','/partners')),
  metadata jsonb not null default '{}'::jsonb,
  dedupe_key text,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create unique index user_notifications_dedupe_idx
  on public.user_notifications(user_id, dedupe_key)
  where dedupe_key is not null;
create index user_notifications_inbox_idx
  on public.user_notifications(user_id, read_at, created_at desc);

alter table public.user_notifications enable row level security;
revoke all on table public.user_notifications from anon, authenticated;
grant select, update(read_at) on table public.user_notifications to authenticated;

create policy "users_read_own_notifications"
on public.user_notifications for select to authenticated
using (user_id = (select auth.uid()));

create policy "users_mark_own_notifications_read"
on public.user_notifications for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create or replace function public.insert_user_notification(
  p_user_id uuid,
  p_type text,
  p_title text,
  p_body text,
  p_entity_type text,
  p_entity_id uuid,
  p_action_route text,
  p_dedupe_key text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user_id is null then return; end if;
  insert into public.user_notifications(
    user_id, notification_type, title, body, entity_type, entity_id,
    action_route, dedupe_key
  ) values (
    p_user_id, p_type, p_title, p_body, p_entity_type, p_entity_id,
    p_action_route, p_dedupe_key
  ) on conflict (user_id, dedupe_key) where dedupe_key is not null do nothing;
end;
$$;

create or replace function public.notify_owned_record_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
  v_code text;
  v_title text;
  v_route text;
  v_status text;
begin
  if tg_op <> 'UPDATE' or new.status::text is not distinct from old.status::text then
    return new;
  end if;

  v_owner := new.user_id;
  v_code := new.public_code;
  v_status := new.status::text;

  if tg_table_name = 'donations' then
    v_title := 'تحديث حالة العطاء'; v_route := '/handoffs';
    if v_status not in ('available','matched','cancelled','rejected') then return new; end if;
  elsif tg_table_name = 'needs' then
    v_title := 'تحديث حالة الاحتياج'; v_route := '/handoffs';
    if v_status not in ('waiting','matched','fulfilled','cancelled','expired') then return new; end if;
  elsif tg_table_name = 'service_offers' then
    v_title := 'تحديث عرض المهارة'; v_route := '/my-services';
    if v_status not in ('approved','paused','rejected','cancelled') then return new; end if;
  elsif tg_table_name = 'service_requests' then
    v_title := 'تحديث طلب الخدمة'; v_route := '/my-services';
    if v_status not in ('reviewing','rejected','cancelled') then return new; end if;
  else
    return new;
  end if;

  perform public.insert_user_notification(
    v_owner, tg_table_name || '_status', v_title,
    'تم تحديث حالة العملية ' || v_code || '. افتح مركز المتابعة لمعرفة الخطوة التالية.',
    tg_table_name, new.id, v_route,
    tg_table_name || ':' || new.id || ':' || v_status
  );
  return new;
end;
$$;

create or replace function public.notify_partner_verification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE' and new.verification_status is distinct from old.verification_status then
    perform public.insert_user_notification(
      new.owner_user_id, 'partner_verification', 'تحديث حالة شريك رحماء',
      'تم تحديث حالة المنشأة ' || new.public_code || '. افتح صفحة الشركاء للاطلاع على التفاصيل.',
      'service_partners', new.id, '/partners',
      'service_partners:' || new.id || ':' || new.verification_status
    );
  end if;
  return new;
end;
$$;

create or replace function public.notify_contribution_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE' and new.status::text is distinct from old.status::text then
    perform public.insert_user_notification(
      new.user_id, 'contribution_status', 'تحديث المساهمة التشغيلية',
      'تم تحديث حالة المساهمة ' || new.public_code || '. افتح مركز المتابعة للاطلاع على التفاصيل.',
      'contributions', new.id, '/handoffs',
      'contributions:' || new.id || ':' || new.status::text
    );
  end if;
  return new;
end;
$$;

create or replace function public.notify_item_match_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_recipient uuid;
begin
  if new.status <> 'offered' then return new; end if;

  select n.user_id
    into v_recipient
  from public.donations d
  join public.needs n on n.id = new.need_id
  where d.id = new.donation_id;

  perform public.insert_user_notification(
    v_recipient, 'item_match_status',
    'لديك عرض مناسب',
    'وجد فريق رحماء عطاءً مناسبًا لاحتياجك. راجع العرض واتخذ قرارك.',
    'matches', new.id, '/offers',
    'matches:' || new.id || ':' || new.status
  );
  return new;
end;
$$;

create or replace function public.notify_delivery_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_donor uuid;
  v_recipient uuid;
begin
  if tg_op = 'UPDATE' and new.status::text is not distinct from old.status::text then return new; end if;
  select d.user_id, n.user_id into v_donor, v_recipient
  from public.matches m
  join public.donations d on d.id=m.donation_id
  join public.needs n on n.id=m.need_id
  where m.id=new.match_id;

  perform public.insert_user_notification(
    v_donor, 'delivery_status', 'تحديث استلام العطاء',
    'تم تحديث رحلة ' || new.public_code || '. افتح تبويب التسليم لمعرفة الخطوة الحالية.',
    'deliveries', new.id, '/handoffs',
    'deliveries:donor:' || new.id || ':' || new.status::text
  );
  perform public.insert_user_notification(
    v_recipient, 'delivery_status', 'تحديث تسليم العطاء',
    'تم تحديث رحلة ' || new.public_code || '. افتح تبويب التسليم لمعرفة الخطوة الحالية.',
    'deliveries', new.id, '/handoffs',
    'deliveries:recipient:' || new.id || ':' || new.status::text
  );
  return new;
end;
$$;

create or replace function public.notify_service_match_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_provider uuid;
  v_requester uuid;
begin
  if tg_op = 'UPDATE' and new.status is not distinct from old.status then return new; end if;
  select o.user_id, r.user_id into v_provider, v_requester
  from public.service_offers o
  join public.service_requests r on r.id=new.service_request_id
  where o.id=new.service_offer_id;

  perform public.insert_user_notification(
    v_provider, 'service_match_status', 'تحديث عملية خدمة',
    'تم تحديث عملية الوقت والمهارة. افتح صفحة خدماتي لمعرفة الخطوة التالية.',
    'service_matches', new.id, '/my-services',
    'service_matches:provider:' || new.id || ':' || new.status
  );
  perform public.insert_user_notification(
    v_requester, 'service_match_status', 'تحديث عملية خدمة',
    'تم تحديث عملية الوقت والمهارة. افتح صفحة خدماتي لمعرفة الخطوة التالية.',
    'service_matches', new.id, '/my-services',
    'service_matches:requester:' || new.id || ':' || new.status
  );
  return new;
end;
$$;

create trigger donations_status_notification
after update of status on public.donations
for each row execute function public.notify_owned_record_status();
create trigger needs_status_notification
after update of status on public.needs
for each row execute function public.notify_owned_record_status();
create trigger service_offers_status_notification
after update of status on public.service_offers
for each row execute function public.notify_owned_record_status();
create trigger service_requests_status_notification
after update of status on public.service_requests
for each row execute function public.notify_owned_record_status();
create trigger service_partners_verification_notification
after update of verification_status on public.service_partners
for each row execute function public.notify_partner_verification();
create trigger contributions_status_notification
after update of status on public.contributions
for each row execute function public.notify_contribution_status();
create trigger matches_status_notification
after insert or update of status on public.matches
for each row execute function public.notify_item_match_status();
create trigger deliveries_status_notification
after insert or update of status on public.deliveries
for each row execute function public.notify_delivery_status();
create trigger service_matches_status_notification
after insert or update of status on public.service_matches
for each row execute function public.notify_service_match_status();

create or replace function public.user_operations_center(p_limit integer default 100)
returns table(
  operation_kind text,
  operation_id uuid,
  public_code text,
  title text,
  status text,
  updated_at timestamptz,
  action_route text,
  requires_action boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select * from (
    select 'donation'::text, d.id, d.public_code, d.item_type, d.status::text,
           d.updated_at, '/handoffs'::text, false
    from public.donations d where d.user_id=(select auth.uid())
    union all
    select 'need', n.id, n.public_code, n.item_type, n.status::text,
           n.updated_at, '/handoffs', false
    from public.needs n where n.user_id=(select auth.uid())
    union all
    select 'item_match', m.id, n.public_code, d.item_type, m.status,
           coalesce(m.responded_at,m.created_at),
           case when m.status='offered' then '/offers' else '/handoffs' end,
           m.status='offered'
    from public.matches m
    join public.needs n on n.id=m.need_id
    join public.donations d on d.id=m.donation_id
    where n.user_id=(select auth.uid()) and m.status='offered'
    union all
    select 'delivery', del.id, del.public_code,
           case when d.user_id=(select auth.uid()) then d.item_type else n.item_type end,
           del.status::text, coalesce(del.delivered_at,del.picked_up_at,del.assigned_at,del.created_at),
           '/handoffs', del.status in ('failed','rescheduled')
    from public.deliveries del
    join public.matches m on m.id=del.match_id
    join public.donations d on d.id=m.donation_id
    join public.needs n on n.id=m.need_id
    where d.user_id=(select auth.uid()) or n.user_id=(select auth.uid())
    union all
    select 'service_offer', o.id, o.public_code, o.title, o.status,
           o.updated_at, '/my-services', o.status='rejected'
    from public.service_offers o where o.user_id=(select auth.uid())
    union all
    select 'service_request', r.id, r.public_code, r.title, r.status,
           r.updated_at, '/my-services', r.status='rejected'
    from public.service_requests r where r.user_id=(select auth.uid())
    union all
    select 'service_match', sm.id,
           case when o.user_id=(select auth.uid()) then o.public_code else r.public_code end,
           case when o.user_id=(select auth.uid()) then o.title else r.title end,
           sm.status, sm.updated_at, '/my-services', sm.status='proposed'
    from public.service_matches sm
    join public.service_offers o on o.id=sm.service_offer_id
    join public.service_requests r on r.id=sm.service_request_id
    where o.user_id=(select auth.uid()) or r.user_id=(select auth.uid())
  ) operations(operation_kind,operation_id,public_code,title,status,updated_at,action_route,requires_action)
  order by operations.requires_action desc, operations.updated_at desc
  limit greatest(1,least(coalesce(p_limit,100),200));
$$;

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
           'توصيل يحتاج إعادة تنسيق', 'الحالة '||d.status::text,
           case when d.status='failed' then 92 else 82 end,
           round((extract(epoch from now()-d.created_at)/3600)::numeric,1), 'deliveries'
    from public.deliveries d where d.status in ('failed','rescheduled')
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

revoke all on function public.insert_user_notification(uuid,text,text,text,text,uuid,text,text) from public, anon, authenticated;
revoke all on function public.notify_owned_record_status() from public, anon, authenticated;
revoke all on function public.notify_partner_verification() from public, anon, authenticated;
revoke all on function public.notify_contribution_status() from public, anon, authenticated;
revoke all on function public.notify_item_match_status() from public, anon, authenticated;
revoke all on function public.notify_delivery_status() from public, anon, authenticated;
revoke all on function public.notify_service_match_status() from public, anon, authenticated;
revoke all on function public.user_operations_center(integer) from public, anon;
revoke all on function public.admin_operations_overview(integer) from public, anon;
grant execute on function public.user_operations_center(integer) to authenticated;
grant execute on function public.admin_operations_overview(integer) to authenticated;

comment on table public.user_notifications is
  'Private in-app notifications generated only by trusted database status transitions.';
comment on function public.user_operations_center(integer) is
  'Returns only the signed-in participant operations without counterpart identity or contact data.';
comment on function public.admin_operations_overview(integer) is
  'Returns a privacy-minimized operational priority queue for active administrators.';
