-- Community impact reporting across items, skills, reviewed needs, and verified partners.

create or replace function public.staff_report_community_impact(
  p_from date default date_trunc('month', current_date)::date,
  p_to date default current_date,
  p_area_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_from timestamptz := p_from::timestamptz;
  v_to timestamptz := (p_to + 1)::timestamptz;
  v_v2_donations bigint := 0;
  v_v2_needs bigint := 0;
  v_delivered_items bigint := 0;
  v_reviewed_cards bigint := 0;
  v_inspired_donations bigint := 0;
  v_service_offers bigint := 0;
  v_service_requests bigint := 0;
  v_completed_services bigint := 0;
  v_completed_service_hours numeric := 0;
  v_completed_partner_services bigint := 0;
  v_verified_partners bigint := 0;
  v_service_incidents bigint := 0;
  v_resolved_service_incidents bigint := 0;
begin
  if not (public.is_admin() or public.is_supervisor()) then raise exception 'staff required'; end if;
  if p_area_id is not null and not public.staff_can_access_area(p_area_id) then raise exception 'area access denied'; end if;

  select count(*) into v_v2_donations
  from public.donations d
  left join public.addresses a on a.id=d.address_id
  where d.created_at>=v_from and d.created_at<v_to
    and d.category_version=2
    and (public.is_admin() or (a.service_area_id is not null and public.staff_can_access_area(a.service_area_id)))
    and (p_area_id is null or (a.service_area_id is not null and public.area_is_within(a.service_area_id,p_area_id)));

  select count(*) into v_v2_needs
  from public.needs n
  left join public.addresses a on a.id=n.address_id
  where n.created_at>=v_from and n.created_at<v_to
    and n.category_version=2
    and (public.is_admin() or (a.service_area_id is not null and public.staff_can_access_area(a.service_area_id)))
    and (p_area_id is null or (a.service_area_id is not null and public.area_is_within(a.service_area_id,p_area_id)));

  select count(*) into v_delivered_items
  from public.deliveries del
  join public.matches m on m.id=del.match_id
  join public.donations d on d.id=m.donation_id
  left join public.addresses a on a.id=d.address_id
  where del.status='delivered'
    and del.delivered_at>=v_from and del.delivered_at<v_to
    and (public.is_admin() or (a.service_area_id is not null and public.staff_can_access_area(a.service_area_id)))
    and (p_area_id is null or (a.service_area_id is not null and public.area_is_within(a.service_area_id,p_area_id)));

  select count(*) into v_reviewed_cards
  from public.need_discovery_cards c
  join public.needs n on n.id=c.need_id
  left join public.addresses a on a.id=n.address_id
  where c.published_at>=v_from and c.published_at<v_to
    and (public.is_admin() or (a.service_area_id is not null and public.staff_can_access_area(a.service_area_id)))
    and (p_area_id is null or (a.service_area_id is not null and public.area_is_within(a.service_area_id,p_area_id)));

  select count(*) into v_inspired_donations
  from public.donations d
  left join public.addresses a on a.id=d.address_id
  where d.created_at>=v_from and d.created_at<v_to
    and d.inspired_by_discovery_card_id is not null
    and (public.is_admin() or (a.service_area_id is not null and public.staff_can_access_area(a.service_area_id)))
    and (p_area_id is null or (a.service_area_id is not null and public.area_is_within(a.service_area_id,p_area_id)));

  select count(*) into v_service_offers
  from public.service_offers o
  where o.created_at>=v_from and o.created_at<v_to
    and (public.is_admin() or (o.service_area_id is not null and public.staff_can_access_area(o.service_area_id)))
    and (p_area_id is null or (o.service_area_id is not null and public.area_is_within(o.service_area_id,p_area_id)));

  select count(*) into v_service_requests
  from public.service_requests r
  where r.created_at>=v_from and r.created_at<v_to
    and (public.is_admin() or (r.service_area_id is not null and public.staff_can_access_area(r.service_area_id)))
    and (p_area_id is null or (r.service_area_id is not null and public.area_is_within(r.service_area_id,p_area_id)));

  select
    count(*),
    coalesce(sum(least(o.available_hours, coalesce(r.estimated_hours,o.available_hours))),0),
    count(*) filter (where o.partner_id is not null)
  into v_completed_services, v_completed_service_hours, v_completed_partner_services
  from public.service_matches sm
  join public.service_offers o on o.id=sm.service_offer_id
  join public.service_requests r on r.id=sm.service_request_id
  where sm.status='completed'
    and sm.updated_at>=v_from and sm.updated_at<v_to
    and (public.is_admin() or (r.service_area_id is not null and public.staff_can_access_area(r.service_area_id)))
    and (p_area_id is null or (r.service_area_id is not null and public.area_is_within(r.service_area_id,p_area_id)));

  select count(*) into v_verified_partners
  from public.service_partners p
  where p.verification_status='verified'
    and p.verified_at>=v_from and p.verified_at<v_to
    and (public.is_admin() or (p.service_area_id is not null and public.staff_can_access_area(p.service_area_id)))
    and (p_area_id is null or (p.service_area_id is not null and public.area_is_within(p.service_area_id,p_area_id)));

  select
    count(*),
    count(*) filter (where si.status in ('resolved','dismissed'))
  into v_service_incidents, v_resolved_service_incidents
  from public.service_incidents si
  join public.service_matches sm on sm.id=si.service_match_id
  join public.service_requests r on r.id=sm.service_request_id
  where si.created_at>=v_from and si.created_at<v_to
    and (public.is_admin() or (r.service_area_id is not null and public.staff_can_access_area(r.service_area_id)))
    and (p_area_id is null or (r.service_area_id is not null and public.area_is_within(r.service_area_id,p_area_id)));

  return jsonb_build_object(
    'from',p_from,
    'to',p_to,
    'area_id',p_area_id,
    'v2_donations',v_v2_donations,
    'v2_needs',v_v2_needs,
    'delivered_items',v_delivered_items,
    'reviewed_need_cards',v_reviewed_cards,
    'inspired_donations',v_inspired_donations,
    'reviewed_need_inspiration_rate',case when v_reviewed_cards=0 then 0 else round((v_inspired_donations::numeric/v_reviewed_cards)*100,1) end,
    'service_offers',v_service_offers,
    'service_requests',v_service_requests,
    'completed_services',v_completed_services,
    'completed_service_hours_estimate',round(coalesce(v_completed_service_hours,0),1),
    'completed_partner_services',v_completed_partner_services,
    'verified_partners',v_verified_partners,
    'service_incidents',v_service_incidents,
    'resolved_service_incidents',v_resolved_service_incidents
  );
end;
$$;

revoke all on function public.staff_report_community_impact(date,date,uuid) from public, anon;
grant execute on function public.staff_report_community_impact(date,date,uuid) to authenticated;

comment on function public.staff_report_community_impact(date,date,uuid) is
  'Area-scoped staff impact report. Completed service hours are an estimate based on matched offer/request hours, not time tracking.';
