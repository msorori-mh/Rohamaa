create table if not exists public.need_discovery_cards (
  id uuid primary key default gen_random_uuid(),
  need_id uuid not null unique references public.needs(id) on delete cascade,
  category text not null,
  item_type text not null,
  display_title text not null,
  display_detail text,
  city_label text not null default 'مأرب',
  is_active boolean not null default true,
  published_by uuid references public.profiles(id) on delete set null,
  published_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.donations
  add column if not exists inspired_by_discovery_card_id uuid
  references public.need_discovery_cards(id) on delete set null;

create index if not exists need_discovery_cards_active_idx
  on public.need_discovery_cards(is_active, category, published_at desc);

alter table public.need_discovery_cards enable row level security;

create policy "admins_manage_need_discovery_cards"
on public.need_discovery_cards
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

grant select, insert, update, delete on public.need_discovery_cards to authenticated;

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

  if v_need.status = 'submitted' then
    update public.needs set status = 'waiting', updated_at = now() where id = v_need.id;
  end if;

  return v_id;
end;
$$;

create or replace function public.admin_unpublish_need_discovery_card(p_card_id uuid)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'admin access required'; end if;
  update public.need_discovery_cards
  set is_active = false, updated_at = now()
  where id = p_card_id;
end;
$$;

revoke all on function public.admin_publish_need_discovery_card(uuid,text,text,text) from public, anon;
revoke all on function public.admin_unpublish_need_discovery_card(uuid) from public, anon;
grant execute on function public.admin_publish_need_discovery_card(uuid,text,text,text) to authenticated;
grant execute on function public.admin_unpublish_need_discovery_card(uuid) to authenticated;

create or replace function public.sync_need_discovery_visibility()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.status in ('confirmed','matched','delivery_scheduled','fulfilled','cancelled','expired') then
    update public.need_discovery_cards
    set is_active = false, updated_at = now()
    where need_id = new.id and is_active;
  end if;
  return new;
end;
$$;

drop trigger if exists needs_sync_discovery_visibility on public.needs;
create trigger needs_sync_discovery_visibility
after update of status on public.needs
for each row execute function public.sync_need_discovery_visibility();

comment on table public.need_discovery_cards is
'Admin-curated, privacy-safe need cards used to inspire giving without exposing beneficiary identity or turning Ruhamaa into a marketplace.';
comment on column public.donations.inspired_by_discovery_card_id is
'Optional attribution showing which verified need card inspired a donation. It must not affect beneficiary priority or guarantee a specific recipient.';
