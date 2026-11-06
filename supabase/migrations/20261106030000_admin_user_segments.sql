-- Admin drill-down for user statistics.
-- 1) Extends the aggregate statistics with donation and need totals.
-- 2) Adds a paged list of users for one statistics segment (admin only).

create or replace function public.admin_user_statistics()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result jsonb;
begin
  if not public.is_admin() then raise exception 'admin required'; end if;

  with donors as (
    select distinct user_id from public.donations
  ),
  beneficiaries as (
    select distinct user_id from public.needs
  ),
  activity as (
    select p.id
    from public.profiles p
    join auth.users u on u.id = p.id
    where u.last_sign_in_at >= now() - interval '30 days'
  )
  select jsonb_build_object(
    'total_users', (select count(*) from public.profiles),
    'by_role', jsonb_build_object(
      'user', (select count(*) from public.profiles where role::text = 'user'),
      'courier', (select count(*) from public.profiles where role::text = 'courier'),
      'supervisor', (select count(*) from public.profiles where role::text = 'supervisor'),
      'admin', (select count(*) from public.profiles where role::text = 'admin')
    ),
    'suspended', (select count(*) from public.profiles where is_suspended),
    'new_last_7_days', (select count(*) from public.profiles where created_at >= now() - interval '7 days'),
    'new_last_30_days', (select count(*) from public.profiles where created_at >= now() - interval '30 days'),
    'active_last_30_days', (select count(*) from activity),
    'donors', (select count(*) from donors),
    'beneficiaries', (select count(*) from beneficiaries),
    'donors_and_beneficiaries', (
      select count(*) from donors d join beneficiaries b on b.user_id = d.user_id
    ),
    'neither', (
      select count(*) from public.profiles p
      where not exists (select 1 from donors d where d.user_id = p.id)
        and not exists (select 1 from beneficiaries b where b.user_id = p.id)
    ),
    'donations_total', (select count(*) from public.donations),
    'needs_total', (select count(*) from public.needs),
    'donations_last_30_days', (select count(*) from public.donations where created_at >= now() - interval '30 days'),
    'needs_last_30_days', (select count(*) from public.needs where created_at >= now() - interval '30 days')
  ) into v_result;

  return v_result;
end;
$$;

revoke execute on function public.admin_user_statistics() from anon, public;
grant execute on function public.admin_user_statistics() to authenticated;

create or replace function public.admin_user_segment(
  p_segment text,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table(
  user_id uuid,
  user_name text,
  user_phone text,
  user_role text,
  user_suspended boolean,
  user_created_at timestamptz,
  user_last_sign_in_at timestamptz,
  donations_count bigint,
  needs_count bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'admin required'; end if;
  if p_segment not in (
    'all', 'donors', 'beneficiaries', 'both', 'neither',
    'new_7_days', 'new_30_days', 'active_30_days', 'suspended',
    'role_user', 'role_courier', 'role_supervisor', 'role_admin'
  ) then
    raise exception 'invalid segment';
  end if;

  return query
  select
    p.id,
    p.full_name,
    p.phone,
    p.role::text,
    p.is_suspended,
    p.created_at,
    u.last_sign_in_at,
    (select count(*) from public.donations d where d.user_id = p.id),
    (select count(*) from public.needs n where n.user_id = p.id)
  from public.profiles p
  left join auth.users u on u.id = p.id
  where
    (p_segment = 'all')
    or (p_segment = 'donors' and exists (select 1 from public.donations d where d.user_id = p.id))
    or (p_segment = 'beneficiaries' and exists (select 1 from public.needs n where n.user_id = p.id))
    or (p_segment = 'both'
        and exists (select 1 from public.donations d where d.user_id = p.id)
        and exists (select 1 from public.needs n where n.user_id = p.id))
    or (p_segment = 'neither'
        and not exists (select 1 from public.donations d where d.user_id = p.id)
        and not exists (select 1 from public.needs n where n.user_id = p.id))
    or (p_segment = 'new_7_days' and p.created_at >= now() - interval '7 days')
    or (p_segment = 'new_30_days' and p.created_at >= now() - interval '30 days')
    or (p_segment = 'active_30_days' and u.last_sign_in_at >= now() - interval '30 days')
    or (p_segment = 'suspended' and p.is_suspended)
    or (p_segment = 'role_user' and p.role::text = 'user')
    or (p_segment = 'role_courier' and p.role::text = 'courier')
    or (p_segment = 'role_supervisor' and p.role::text = 'supervisor')
    or (p_segment = 'role_admin' and p.role::text = 'admin')
  order by p.created_at desc
  limit least(greatest(coalesce(p_limit, 50), 1), 200)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

revoke execute on function public.admin_user_segment(text, integer, integer) from anon, public;
grant execute on function public.admin_user_segment(text, integer, integer) to authenticated;
