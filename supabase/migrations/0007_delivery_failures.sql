-- Sanad V1: delivery failure / reschedule tracking and no-show signals.

create table if not exists public.delivery_failures (
  id uuid primary key default gen_random_uuid(),
  delivery_id uuid not null references public.deliveries(id) on delete cascade,
  courier_id uuid not null references public.profiles(id),
  party text not null check (party in ('donor','beneficiary','courier','other')),
  reason_code text not null check (reason_code in ('no_answer','not_present','wrong_address','item_not_ready','item_rejected','vehicle_issue','weather','other')),
  note text,
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default now()
);

alter table public.delivery_failures enable row level security;
create policy "courier_failure_select_own" on public.delivery_failures for select using (courier_id=auth.uid());
create policy "admin_failure_select" on public.delivery_failures for select using (public.is_admin());

create or replace function public.courier_report_delivery_failure(
  p_delivery_id uuid,
  p_party text,
  p_reason_code text,
  p_note text default null,
  p_latitude double precision default null,
  p_longitude double precision default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_user_id uuid;
  v_recent integer;
begin
  if not public.is_courier() then raise exception 'courier required'; end if;
  if not exists(select 1 from deliveries where id=p_delivery_id and courier_id=auth.uid()) then raise exception 'delivery not assigned'; end if;
  if p_party not in ('donor','beneficiary','courier','other') then raise exception 'invalid party'; end if;
  if p_reason_code not in ('no_answer','not_present','wrong_address','item_not_ready','item_rejected','vehicle_issue','weather','other') then raise exception 'invalid reason'; end if;

  insert into delivery_failures(delivery_id,courier_id,party,reason_code,note,latitude,longitude)
  values(p_delivery_id,auth.uid(),p_party,p_reason_code,p_note,p_latitude,p_longitude)
  returning id into v_id;

  update deliveries set status='rescheduled' where id=p_delivery_id and status<>'delivered';
  insert into delivery_events(delivery_id,actor_id,event_type,latitude,longitude,metadata)
  values(p_delivery_id,auth.uid(),'delivery_failure',p_latitude,p_longitude,jsonb_build_object('party',p_party,'reason_code',p_reason_code,'note',p_note));

  if p_party in ('donor','beneficiary') and p_reason_code in ('no_answer','not_present','wrong_address','item_not_ready') then
    if p_party='donor' then
      select d.user_id into v_user_id from deliveries del join matches m on m.id=del.match_id join donations d on d.id=m.donation_id where del.id=p_delivery_id;
    else
      select n.user_id into v_user_id from deliveries del join matches m on m.id=del.match_id join needs n on n.id=m.need_id where del.id=p_delivery_id;
    end if;

    select count(*) into v_recent
    from delivery_failures df
    join deliveries del on del.id=df.delivery_id
    join matches m on m.id=del.match_id
    left join donations d on d.id=m.donation_id
    left join needs n on n.id=m.need_id
    where df.created_at>now()-interval '60 days'
      and df.reason_code in ('no_answer','not_present','wrong_address','item_not_ready')
      and ((df.party='donor' and d.user_id=v_user_id) or (df.party='beneficiary' and n.user_id=v_user_id));

    if v_recent>=2 then
      insert into risk_flags(user_id,delivery_id,rule_code,severity,details)
      values(v_user_id,p_delivery_id,'REPEATED_DELIVERY_NO_SHOW','medium',jsonb_build_object('failures_60d',v_recent,'latest_reason',p_reason_code));
    end if;
  end if;

  return v_id;
end;
$$;

create index if not exists delivery_failures_delivery_idx on delivery_failures(delivery_id,created_at desc);
create index if not exists delivery_failures_courier_idx on delivery_failures(courier_id,created_at desc);
