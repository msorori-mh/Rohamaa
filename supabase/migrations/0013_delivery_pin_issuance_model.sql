-- Sanad V1: admin creates delivery without plaintext PINs.
-- Donor/beneficiary issue a fresh PIN on demand through user_issue_handoff_pin().

create or replace function public.admin_create_delivery(
  p_match_id uuid,
  p_courier_id uuid,
  p_vehicle_id uuid default null,
  p_pickup_pin text default null,
  p_delivery_pin text default null
)
returns table(delivery_id uuid, public_code text, pickup_pin text, delivery_pin text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_code text;
begin
  if not public.is_admin() then raise exception 'admin required'; end if;
  if p_pickup_pin is not null or p_delivery_pin is not null then
    raise exception 'admin PIN issuance is disabled';
  end if;
  if not exists(select 1 from couriers where user_id=p_courier_id and active) then
    raise exception 'courier inactive';
  end if;

  v_code := 'SND-MRB-DEL-' || to_char(now(),'YYMMDD') || '-' || upper(substr(encode(gen_random_bytes(5),'hex'),1,8));

  insert into deliveries(public_code,match_id,courier_id,vehicle_id,status,pickup_pin_hash,delivery_pin_hash,assigned_at)
  values(v_code,p_match_id,p_courier_id,p_vehicle_id,'assigned',null,null,now())
  returning id into v_id;

  update donations d set status='pickup_scheduled',updated_at=now()
   where d.id=(select donation_id from matches where id=p_match_id);
  update needs n set status='delivery_scheduled',updated_at=now()
   where n.id=(select need_id from matches where id=p_match_id);

  insert into audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values(auth.uid(),'create_delivery','delivery',v_id,jsonb_build_object('courier_id',p_courier_id,'vehicle_id',p_vehicle_id));

  return query select v_id,v_code,null::text,null::text;
end;
$$;

revoke all on function public.admin_create_delivery(uuid,uuid,uuid,text,text) from public, anon;
grant execute on function public.admin_create_delivery(uuid,uuid,uuid,text,text) to authenticated;
