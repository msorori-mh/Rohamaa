create or replace function public.sync_need_discovery_visibility()
returns trigger
language plpgsql
security definer
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

revoke all on function public.sync_need_discovery_visibility() from public, anon, authenticated;

comment on function public.sync_need_discovery_visibility() is
'Internal trigger function that hides public discovery cards when the underlying need leaves the open discovery workflow. Not callable by app roles.';
