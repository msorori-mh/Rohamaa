-- Sanad V1: accepted matches waiting for courier assignment.

create or replace function public.admin_accepted_matches_queue()
returns table(
  match_id uuid,
  donation_code text,
  need_code text,
  item_type text,
  accepted_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'admin required'; end if;
  return query
  select m.id,d.public_code,n.public_code,d.item_type,m.responded_at
  from matches m
  join donations d on d.id=m.donation_id
  join needs n on n.id=m.need_id
  left join deliveries del on del.match_id=m.id
  where m.status='accepted' and del.id is null
  order by m.responded_at nulls last,m.created_at;
end;
$$;

revoke all on function public.admin_accepted_matches_queue() from public, anon;
grant execute on function public.admin_accepted_matches_queue() to authenticated;
