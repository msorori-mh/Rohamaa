-- Private participant service history for safety follow-up and incident reporting.

create or replace function public.user_service_history(p_limit integer default 50)
returns table(
  match_id uuid,
  my_side text,
  service_title text,
  service_type text,
  category text,
  status text,
  scheduled_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    m.id,
    case when o.user_id = auth.uid() then 'provider' else 'requester' end,
    case when o.user_id = auth.uid() then r.title else o.title end,
    r.service_type,
    r.category,
    m.status,
    m.scheduled_at,
    m.updated_at
  from public.service_matches m
  join public.service_offers o on o.id = m.service_offer_id
  join public.service_requests r on r.id = m.service_request_id
  where (o.user_id = auth.uid() or r.user_id = auth.uid())
    and m.status in ('accepted','scheduled','completed','cancelled')
  order by m.updated_at desc
  limit greatest(1, least(coalesce(p_limit,50), 100));
$$;

revoke all on function public.user_service_history(integer) from public, anon;
grant execute on function public.user_service_history(integer) to authenticated;

comment on function public.user_service_history(integer) is
  'Returns participant-safe service history without exposing the other party identity or contact data.';
