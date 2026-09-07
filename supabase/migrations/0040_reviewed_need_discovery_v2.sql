-- Structured reviewed-needs discovery for Category System V2.
-- Keeps the original RPC for backward compatibility and introduces a V2 RPC.

create or replace function public.discovery_need_cards_v2(
  p_category text default null,
  p_limit integer default 30
)
returns table(
  card_id uuid,
  category text,
  category_group text,
  item_type_key text,
  item_attributes jsonb,
  item_type text,
  display_title text,
  display_detail text,
  city_label text,
  wait_days integer,
  published_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    c.id,
    public.canonical_item_category(c.category),
    c.category_group,
    c.item_type_key,
    c.item_attributes,
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
    and n.status in ('submitted','waiting')
    and (
      p_category is null
      or p_category = ''
      or public.canonical_item_category(c.category) = public.canonical_item_category(p_category)
    )
  order by n.created_at asc, c.published_at asc
  limit greatest(1, least(coalesce(p_limit,30), 50));
$$;

revoke all on function public.discovery_need_cards_v2(text,integer) from public, anon;
grant execute on function public.discovery_need_cards_v2(text,integer) to authenticated;

comment on function public.discovery_need_cards_v2(text,integer) is
  'Anonymous-to-parties, staff-reviewed need cards with Category V2 structure. Does not expose beneficiary identity or private reason.';
