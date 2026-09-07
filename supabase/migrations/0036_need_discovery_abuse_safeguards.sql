create or replace function public.discovery_need_cards(
  p_category text default null,
  p_limit integer default 30
)
returns table (
  card_id uuid,
  category text,
  item_type text,
  display_title text,
  display_detail text,
  city_label text,
  wait_days integer,
  published_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select
    c.id,
    c.category,
    c.item_type,
    c.display_title,
    c.display_detail,
    c.city_label,
    greatest(0, floor(extract(epoch from (now() - n.created_at)) / 86400)::int) as wait_days,
    c.published_at
  from public.need_discovery_cards c
  join public.needs n on n.id = c.need_id
  join public.profiles p on p.id = n.user_id
  where c.is_active
    and not p.is_suspended
    and n.user_id <> auth.uid()
    and n.status in ('submitted','waiting','candidate_found')
    and (p_category is null or p_category = '' or lower(c.category) = lower(p_category))
  order by n.created_at asc, c.published_at asc
  limit greatest(1, least(coalesce(p_limit,30), 50));
$$;

revoke all on function public.discovery_need_cards(text, integer) from public, anon;
grant execute on function public.discovery_need_cards(text, integer) to authenticated;

create or replace function public.admin_publish_need_discovery_card(
  p_need_id uuid,
  p_display_title text,
  p_display_detail text default null,
  p_city_label text default 'مأرب'
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_need public.needs%rowtype;
  v_id uuid;
  v_other_active integer;
begin
  if not public.is_admin() then raise exception 'admin access required'; end if;

  select * into v_need from public.needs where id = p_need_id;
  if v_need.id is null then raise exception 'need not found'; end if;
  if v_need.status not in ('submitted','waiting','candidate_found') then
    raise exception 'need is not eligible for discovery';
  end if;
  if length(trim(coalesce(p_display_title,''))) < 3 then
    raise exception 'display title is required';
  end if;

  select count(*)::integer into v_other_active
  from public.need_discovery_cards c
  join public.needs n on n.id = c.need_id
  where c.is_active
    and n.user_id = v_need.user_id
    and c.need_id <> v_need.id;

  if v_other_active >= 2 then
    raise exception 'this account already has the maximum number of public need cards';
  end if;

  insert into public.need_discovery_cards(
    need_id, category, item_type, display_title, display_detail, city_label,
    is_active, published_by, published_at, updated_at
  ) values (
    v_need.id, v_need.category, v_need.item_type, trim(p_display_title),
    nullif(trim(coalesce(p_display_detail,'')),''),
    coalesce(nullif(trim(coalesce(p_city_label,'')),''),'مأرب'),
    true, auth.uid(), now(), now()
  )
  on conflict (need_id) do update set
    category = excluded.category,
    item_type = excluded.item_type,
    display_title = excluded.display_title,
    display_detail = excluded.display_detail,
    city_label = excluded.city_label,
    is_active = true,
    published_by = auth.uid(),
    published_at = now(),
    updated_at = now()
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.admin_publish_need_discovery_card(uuid,text,text,text) from public, anon;
grant execute on function public.admin_publish_need_discovery_card(uuid,text,text,text) to authenticated;

create or replace function public.flag_unusual_need_request_pattern()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_open_count integer;
  v_recent_count integer;
begin
  select count(*)::integer into v_open_count
  from public.needs
  where user_id = new.user_id
    and status in ('submitted','waiting','candidate_found','confirmed');

  select count(*)::integer into v_recent_count
  from public.needs
  where user_id = new.user_id
    and created_at >= now() - interval '30 days';

  if v_open_count >= 5
     and not exists (
       select 1 from public.risk_flags
       where user_id = new.user_id
         and rule_code = 'many_open_needs'
         and not resolved
         and created_at >= now() - interval '30 days'
     ) then
    insert into public.risk_flags(user_id, need_id, rule_code, severity, details)
    values (
      new.user_id,
      new.id,
      'many_open_needs',
      'low',
      jsonb_build_object('open_need_count', v_open_count)
    );
  end if;

  if v_recent_count >= 8
     and not exists (
       select 1 from public.risk_flags
       where user_id = new.user_id
         and rule_code = 'high_need_request_velocity'
         and not resolved
         and created_at >= now() - interval '30 days'
     ) then
    insert into public.risk_flags(user_id, need_id, rule_code, severity, details)
    values (
      new.user_id,
      new.id,
      'high_need_request_velocity',
      'medium',
      jsonb_build_object('needs_last_30_days', v_recent_count)
    );
  end if;

  return new;
end;
$$;

revoke all on function public.flag_unusual_need_request_pattern() from public, anon, authenticated;

drop trigger if exists needs_flag_unusual_request_pattern on public.needs;
create trigger needs_flag_unusual_request_pattern
after insert on public.needs
for each row execute function public.flag_unusual_need_request_pattern();

comment on function public.flag_unusual_need_request_pattern() is
'Creates review signals for unusually dense need-request patterns without automatically blocking or deprioritizing a user.';
