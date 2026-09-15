-- Disposable PostgreSQL fixture: reviewed production definitions, no user data.
create role anon; create role authenticated; create role service_role;
CREATE OR REPLACE FUNCTION public.notify_item_match_status()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.notify_partner_verification()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.validate_business_service_offer()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$ declare v_owner uuid; v_status text; v_kind text; begin if new.provider_kind='person' then new.partner_id:=null; return new; end if; if new.partner_id is null then raise exception 'business service offers require a verified Ruhamaa partner'; end if; select owner_user_id,verification_status,partner_kind into v_owner,v_status,v_kind from public.service_partners where id=new.partner_id; if v_owner is null then raise exception 'partner not found'; end if; if v_owner<>new.user_id then raise exception 'partner must belong to offer owner'; end if; if v_status<>'verified' then raise exception 'partner must be verified before creating a business offer'; end if; if v_kind='salon' and new.category<>'beauty_wedding' then raise exception 'salon partners may offer wedding/beauty services only'; elsif v_kind='clothing_shop' and new.category<>'beauty_wedding' then raise exception 'clothing shop partners may offer occasion clothing services only'; elsif v_kind='event_setup' and new.category<>'event_setup' then raise exception 'event setup partners may offer event setup services only'; elsif v_kind='repair_shop' and new.category not in ('appliance_repair','device_repair') then raise exception 'repair partners may offer appliance/device repair only'; elsif v_kind='printing_shop' and new.category<>'printing_stationery' then raise exception 'printing partners may offer printing/stationery services only'; elsif v_kind='workshop' and new.category not in ('carpentry','tailoring','painting','moving_assembly','appliance_repair','device_repair') then raise exception 'workshop service is outside the verified V1 scope'; end if; return new; end; $function$
;

revoke all on function public.notify_partner_verification(), public.notify_item_match_status() from public;
grant execute on function public.notify_partner_verification(), public.notify_item_match_status() to service_role;
grant execute on function public.validate_business_service_offer() to anon, authenticated, service_role;
create temporary table identity_before as select oid, prosrc, proowner, prosecdef, proconfig, proacl, proargtypes, prorettype from pg_proc where oid in ('public.notify_partner_verification()'::regprocedure,'public.notify_item_match_status()'::regprocedure,'public.validate_business_service_offer()'::regprocedure);

