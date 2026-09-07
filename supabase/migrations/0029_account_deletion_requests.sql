create table if not exists public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  requested_at timestamptz not null default now(),
  status text not null default 'pending' check (status in ('pending','processing','completed','rejected')),
  completed_at timestamptz,
  admin_note text
);

alter table public.account_deletion_requests enable row level security;

create policy "users_read_own_deletion_requests"
on public.account_deletion_requests
for select
to authenticated
using (user_id = (select auth.uid()) or public.is_admin());

create policy "admins_update_deletion_requests"
on public.account_deletion_requests
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create or replace function public.request_account_deletion()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_role text;
  v_existing uuid;
  v_id uuid;
begin
  if v_user is null then raise exception 'authentication required'; end if;

  select role into v_role from public.profiles where id = v_user;
  if v_role is null then raise exception 'profile not found'; end if;
  if v_role <> 'user' then raise exception 'staff accounts must be managed by an administrator'; end if;

  select id into v_existing
  from public.account_deletion_requests
  where user_id = v_user and status in ('pending','processing')
  order by requested_at desc
  limit 1;

  if v_existing is not null then return v_existing; end if;

  insert into public.account_deletion_requests(user_id)
  values (v_user)
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.request_account_deletion() from public, anon;
grant execute on function public.request_account_deletion() to authenticated;

grant select on public.account_deletion_requests to authenticated;
grant update on public.account_deletion_requests to authenticated;

comment on table public.account_deletion_requests is 'User account deletion requests for Google Play privacy compliance and operationally safe deletion handling.';
