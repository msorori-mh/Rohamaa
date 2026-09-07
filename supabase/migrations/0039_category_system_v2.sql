-- Ruhamaa Category System V2
-- Adds structured item taxonomy while keeping all legacy records compatible.

alter table public.needs
  add column if not exists category_version smallint not null default 1
    check (category_version in (1,2)),
  add column if not exists category_group text,
  add column if not exists item_type_key text,
  add column if not exists item_attributes jsonb not null default '{}'::jsonb;

alter table public.donations
  add column if not exists category_version smallint not null default 1
    check (category_version in (1,2)),
  add column if not exists category_group text,
  add column if not exists item_type_key text,
  add column if not exists item_attributes jsonb not null default '{}'::jsonb;

alter table public.need_discovery_cards
  add column if not exists category_group text,
  add column if not exists item_type_key text,
  add column if not exists item_attributes jsonb not null default '{}'::jsonb;

create index if not exists needs_category_v2_match_idx
  on public.needs(category, category_group, item_type_key, status, created_at);
create index if not exists donations_category_v2_match_idx
  on public.donations(category, category_group, item_type_key, status, created_at);

create or replace function public.canonical_item_category(p_category text)
returns text
language sql
immutable
parallel safe
as $$
  select case lower(trim(coalesce(p_category,'')))
    when 'books' then 'education'
    when 'education' then 'education'
    when 'furniture' then 'home_furniture'
    when 'home' then 'home_furniture'
    when 'home_furniture' then 'home_furniture'
    when 'clothes' then 'clothes'
    when 'children' then 'children'
    when 'electronics' then 'electronics'
    when 'tools_trades' then 'tools_trades'
    when 'events' then 'events'
    else 'other'
  end;
$$;

revoke all on function public.canonical_item_category(text) from public, anon;
grant execute on function public.canonical_item_category(text) to authenticated;

create or replace function public.admin_match_candidates(p_donation_id uuid, p_limit integer default 20)
returns table(
  need_id uuid,
  need_code text,
  item_type text,
  category text,
  age_hours numeric,
  distance_km numeric,
  prior_same_category integer,
  trust_score integer,
  score numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'admin required';
  end if;

  return query
  with d as (
    select
      don.*,
      public.canonical_item_category(don.category) canonical_category,
      a.latitude dlat,
      a.longitude dlon
    from public.donations don
    left join public.addresses a on a.id = don.address_id
    where don.id = p_donation_id
      and don.status in ('submitted','under_review','available')
  ), candidates as (
    select
      n,
      p.trust_score,
      public.distance_km(d.dlat,d.dlon,a.latitude,a.longitude) dist,
      (
        select count(*)::int
        from public.needs oldn
        where oldn.user_id=n.user_id
          and public.canonical_item_category(oldn.category)=public.canonical_item_category(n.category)
          and oldn.status='fulfilled'
          and oldn.updated_at > now()-interval '120 days'
      ) prior_count,
      extract(epoch from (now()-n.created_at))/3600 ageh,
      case
        when d.item_type_key is not null and n.item_type_key is not null and d.item_type_key=n.item_type_key then 30
        when d.category_group is not null and n.category_group is not null and d.category_group=n.category_group then 10
        when lower(n.item_type)=lower(d.item_type) then 15
        when lower(n.item_type) like '%'||lower(d.item_type)||'%' then 12
        when lower(d.item_type) like '%'||lower(n.item_type)||'%' then 12
        else 0
      end item_match_points,
      (
        case
          when nullif(trim(d.item_attributes->>'size'),'') is not null
           and nullif(trim(n.item_attributes->>'size'),'') is not null
          then case
            when lower(trim(d.item_attributes->>'size'))=lower(trim(n.item_attributes->>'size')) then 15
            when coalesce(n.item_attributes->>'size_flexible','false')='true' then -3
            else -12
          end
          else 0
        end
        + case
          when nullif(trim(d.item_attributes->>'grade_level'),'') is not null
           and nullif(trim(n.item_attributes->>'grade_level'),'') is not null
          then case when lower(trim(d.item_attributes->>'grade_level'))=lower(trim(n.item_attributes->>'grade_level')) then 12 else -10 end
          else 0
        end
        + case
          when nullif(trim(d.item_attributes->>'subject'),'') is not null
           and nullif(trim(n.item_attributes->>'subject'),'') is not null
          then case when lower(trim(d.item_attributes->>'subject'))=lower(trim(n.item_attributes->>'subject')) then 8 else -6 end
          else 0
        end
        + case
          when nullif(trim(d.item_attributes->>'age_range'),'') is not null
           and nullif(trim(n.item_attributes->>'age_range'),'') is not null
          then case when lower(trim(d.item_attributes->>'age_range'))=lower(trim(n.item_attributes->>'age_range')) then 10 else -8 end
          else 0
        end
      ) attribute_points
    from d
    join public.needs n
      on n.status in ('submitted','waiting','candidate_found')
     and public.canonical_item_category(n.category)=d.canonical_category
    join public.profiles p
      on p.id=n.user_id and not p.is_suspended
    left join public.addresses a on a.id=n.address_id
    where n.user_id <> d.user_id
  )
  select
    c.n.id,
    c.n.public_code,
    c.n.item_type,
    c.n.category,
    round(c.ageh::numeric,1),
    case when c.dist is null then null else round(c.dist::numeric,1) end,
    c.prior_count,
    c.trust_score,
    round((
      20
      + c.item_match_points
      + c.attribute_points
      + least(c.ageh/24, 15)
      + case when c.dist is null then 0 when c.dist<=3 then 20 when c.dist<=7 then 12 when c.dist<=15 then 5 else 0 end
      + least(greatest(c.trust_score,0),10)
      - least(c.prior_count*8,24)
    )::numeric,2)
  from candidates c
  order by 9 desc, c.n.created_at asc
  limit greatest(1,least(p_limit,100));
end;
$$;

revoke all on function public.admin_match_candidates(uuid,integer) from public, anon;
grant execute on function public.admin_match_candidates(uuid,integer) to authenticated;

create or replace function public.admin_publish_need_discovery_card(
  p_need_id uuid,
  p_display_title text,
  p_display_detail text default null,
  p_city_label text default 'مأرب'
)
returns uuid
language plpgsql
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
  if v_need.status not in ('submitted','waiting') then
    raise exception 'need not eligible for reviewed-needs discovery';
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
    need_id, category, category_group, item_type_key, item_attributes,
    item_type, display_title, display_detail, city_label,
    is_active, published_by, published_at, updated_at
  ) values (
    v_need.id, v_need.category, v_need.category_group, v_need.item_type_key, v_need.item_attributes,
    v_need.item_type, trim(p_display_title),
    nullif(trim(coalesce(p_display_detail,'')),''),
    coalesce(nullif(trim(coalesce(p_city_label,'')),''),'مأرب'),
    true, auth.uid(), now(), now()
  )
  on conflict (need_id) do update set
    category = excluded.category,
    category_group = excluded.category_group,
    item_type_key = excluded.item_type_key,
    item_attributes = excluded.item_attributes,
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

comment on column public.needs.category_group is 'Category System V2 group key. Null means legacy/unstructured record.';
comment on column public.needs.item_type_key is 'Category System V2 precise item key. Null means legacy/unstructured record.';
comment on column public.needs.item_attributes is 'Structured V2 matching attributes such as size, grade, subject, age range and dimensions.';
comment on column public.donations.category_group is 'Category System V2 group key. Null means legacy/unstructured record.';
comment on column public.donations.item_type_key is 'Category System V2 precise item key. Null means legacy/unstructured record.';
comment on column public.donations.item_attributes is 'Structured V2 matching attributes. Financial contribution data is intentionally not part of item matching.';
