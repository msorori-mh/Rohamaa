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
set search_path to 'public'
as $function$
begin
  if not public.is_admin() then
    raise exception 'admin required';
  end if;

  return query
  with d as (
    select don.*, a.latitude dlat, a.longitude dlon
    from donations don
    left join addresses a on a.id = don.address_id
    where don.id = p_donation_id
      and don.status in ('submitted','under_review','available')
  ), candidates as (
    select
      n,
      p.trust_score,
      a.latitude nlat,
      a.longitude nlon,
      public.distance_km(d.dlat,d.dlon,a.latitude,a.longitude) dist,
      (select count(*)::int
         from needs oldn
        where oldn.user_id=n.user_id
          and oldn.category=n.category
          and oldn.status='fulfilled'
          and oldn.updated_at > now()-interval '120 days') prior_count,
      extract(epoch from (now()-n.created_at))/3600 ageh,
      case
        when lower(n.item_type)=lower(d.item_type) then 15
        when lower(n.item_type) like '%'||lower(d.item_type)||'%' then 12
        when lower(d.item_type) like '%'||lower(n.item_type)||'%' then 12
        else 0
      end item_match_points
    from d
    join needs n
      on n.status in ('submitted','waiting','candidate_found')
    join profiles p
      on p.id=n.user_id and not p.is_suspended
    left join addresses a on a.id=n.address_id
    where lower(n.category)=lower(d.category)
      and n.user_id <> d.user_id
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
      25
      + c.item_match_points
      + least(c.ageh/24, 15)
      + case when c.dist is null then 0 when c.dist<=3 then 20 when c.dist<=7 then 12 when c.dist<=15 then 5 else 0 end
      + least(greatest(c.trust_score,0),10)
      - least(c.prior_count*8,24)
    )::numeric,2)
  from candidates c
  order by 9 desc, c.n.created_at asc
  limit greatest(1,least(p_limit,100));
end;
$function$;

comment on function public.admin_match_candidates(uuid, integer) is
  'Admin-only matching candidates: same category is sufficient for candidacy, item text similarity adds score, and self-matches are excluded.';
