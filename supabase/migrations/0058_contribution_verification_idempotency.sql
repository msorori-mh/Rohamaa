-- Prevent repeated taps or stale admin screens from writing duplicate audit rows.
create or replace function public.admin_verify_contribution(
  p_contribution_id uuid,
  p_verified boolean,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_updated integer;
begin
  if not public.is_admin() then
    raise exception 'admin required';
  end if;

  update public.contributions
     set status = case
                    when p_verified then 'verified'::public.contribution_status
                    else 'rejected'::public.contribution_status
                  end,
         verified_by = auth.uid(),
         verified_at = now()
   where id = p_contribution_id
     and status = 'pending';

  get diagnostics v_updated = row_count;
  if v_updated <> 1 then
    raise exception 'contribution is no longer pending';
  end if;

  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  values (
    auth.uid(),
    case when p_verified then 'verify_contribution' else 'reject_contribution' end,
    'contribution',
    p_contribution_id,
    jsonb_build_object('note', p_note)
  );
end;
$$;

revoke all on function public.admin_verify_contribution(uuid, boolean, text)
  from public, anon;
grant execute on function public.admin_verify_contribution(uuid, boolean, text)
  to authenticated;

comment on function public.admin_verify_contribution(uuid, boolean, text) is
  'Admin-only, single-transition verification of a pending cash contribution with one audit event.';
