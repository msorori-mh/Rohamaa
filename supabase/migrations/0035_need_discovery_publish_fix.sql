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

  return v_id;
end;
$$;

revoke all on function public.admin_publish_need_discovery_card(uuid,text,text,text) from public, anon;
grant execute on function public.admin_publish_need_discovery_card(uuid,text,text,text) to authenticated;

comment on function public.admin_publish_need_discovery_card(uuid,text,text,text) is
'Publishes an admin-curated anonymous discovery card without changing the underlying need workflow status.';
