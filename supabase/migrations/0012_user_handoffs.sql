-- Sanad V1: user-visible handoffs without exposing counterpart identity.
-- PIN plaintext is generated on demand, returned once, and only its hash is stored.

create or replace function public.user_my_handoffs()
returns table(
  delivery_id uuid,
  delivery_code text,
  handoff_kind text,
  item_code text,
  item_type text,
  delivery_status public.delivery_status,
  created_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select del.id,
         del.public_code,
         case when d.user_id=auth.uid() then 'pickup' else 'delivery' end,
         case when d.user_id=auth.uid() then d.public_code else n.public_code end,
         case when d.user_id=auth.uid() then d.item_type else n.item_type end,
         del.status,
         del.created_at
  from deliveries del
  join matches m on m.id=del.match_id
  join donations d on d.id=m.donation_id
  join needs n on n.id=m.need_id
  where d.user_id=auth.uid() or n.user_id=auth.uid()
  order by del.created_at desc;
$$;

create or replace function public.user_issue_handoff_pin(
  p_delivery_id uuid,
  p_kind text
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_bytes bytea;
  v_pin text;
  v_donor uuid;
  v_beneficiary uuid;
  v_status public.delivery_status;
begin
  select d.user_id,n.user_id,del.status
    into v_donor,v_beneficiary,v_status
  from deliveries del
  join matches m on m.id=del.match_id
  join donations d on d.id=m.donation_id
  join needs n on n.id=m.need_id
  where del.id=p_delivery_id
  for update of del;

  if not found then raise exception 'delivery not found'; end if;
  if v_status='delivered' then raise exception 'delivery already completed'; end if;

  if p_kind='pickup' then
    if v_donor<>auth.uid() then raise exception 'not pickup owner'; end if;
    if v_status not in ('assigned','heading_to_pickup','rescheduled') then raise exception 'pickup PIN unavailable in this state'; end if;
  elsif p_kind='delivery' then
    if v_beneficiary<>auth.uid() then raise exception 'not delivery owner'; end if;
    if v_status not in ('picked_up','heading_to_recipient','rescheduled') then raise exception 'delivery PIN unavailable in this state'; end if;
  else
    raise exception 'invalid handoff kind';
  end if;

  v_bytes := gen_random_bytes(2);
  v_pin := lpad((((get_byte(v_bytes,0)*256)+get_byte(v_bytes,1)) % 10000)::text,4,'0');

  if p_kind='pickup' then
    update deliveries set pickup_pin_hash=public.hash_pin(v_pin) where id=p_delivery_id;
  else
    update deliveries set delivery_pin_hash=public.hash_pin(v_pin) where id=p_delivery_id;
  end if;

  insert into audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values(auth.uid(),'issue_handoff_pin','delivery',p_delivery_id,jsonb_build_object('kind',p_kind));

  return v_pin;
end;
$$;

revoke all on function public.user_my_handoffs() from public, anon;
revoke all on function public.user_issue_handoff_pin(uuid,text) from public, anon;
grant execute on function public.user_my_handoffs() to authenticated;
grant execute on function public.user_issue_handoff_pin(uuid,text) to authenticated;
