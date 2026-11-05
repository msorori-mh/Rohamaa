-- Aggregate user counts for the admin dashboard.
-- Returns only totals and counts; no individual user is identified.

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
    )
  ) into v_result;

  return v_result;
end;
$$;

revoke execute on function public.admin_user_statistics() from anon, public;
grant execute on function public.admin_user_statistics() to authenticated;
