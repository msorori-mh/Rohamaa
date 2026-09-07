-- Sanad V1: low-cost rule-based fraud signals and admin resolution.
-- Signals never auto-label a person as fraudulent; they only create review work.

create or replace function public.flag_need_risk()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recent_count integer;
  same_fulfilled integer;
begin
  select count(*) into recent_count
    from needs
   where user_id=new.user_id
     and created_at > now()-interval '24 hours'
     and id<>new.id;
  if recent_count >= 4 then
    insert into risk_flags(user_id,need_id,rule_code,severity,details)
    values(new.user_id,new.id,'HIGH_REQUEST_VELOCITY','medium',jsonb_build_object('prior_24h',recent_count));
  end if;

  select count(*) into same_fulfilled
    from needs
   where user_id=new.user_id
     and category=new.category
     and status='fulfilled'
     and updated_at > now()-interval '120 days'
     and id<>new.id;
  if same_fulfilled >= 1 then
    insert into risk_flags(user_id,need_id,rule_code,severity,details)
    values(new.user_id,new.id,'REPEAT_FULFILLED_CATEGORY','medium',jsonb_build_object('fulfilled_last_120d',same_fulfilled,'category',new.category));
  end if;
  return new;
end;
$$;

drop trigger if exists trg_flag_need_risk on needs;
create trigger trg_flag_need_risk
after insert on needs
for each row execute function public.flag_need_risk();

create or replace function public.flag_address_churn()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recent_addresses integer;
begin
  select count(*) into recent_addresses
  from addresses
  where user_id=new.user_id and created_at > now()-interval '14 days' and id<>new.id;
  if recent_addresses >= 3 then
    insert into risk_flags(user_id,rule_code,severity,details)
    values(new.user_id,'ADDRESS_CHURN','low',jsonb_build_object('addresses_last_14d',recent_addresses+1));
  end if;
  return new;
end;
$$;

drop trigger if exists trg_flag_address_churn on addresses;
create trigger trg_flag_address_churn
after insert on addresses
for each row execute function public.flag_address_churn();

create or replace function public.admin_resolve_risk(p_risk_id uuid, p_resolution text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'admin required'; end if;
  if length(trim(coalesce(p_resolution,''))) < 3 then raise exception 'resolution required'; end if;
  update risk_flags set resolved=true,resolved_by=auth.uid(),resolved_at=now(),details=details||jsonb_build_object('resolution',p_resolution)
   where id=p_risk_id and not resolved;
  insert into audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values(auth.uid(),'resolve_risk','risk_flag',p_risk_id,jsonb_build_object('resolution',p_resolution));
end;
$$;

create or replace function public.admin_set_user_suspension(p_user_id uuid, p_suspended boolean, p_reason text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'admin required'; end if;
  if p_user_id=auth.uid() and p_suspended then raise exception 'cannot suspend self'; end if;
  update profiles set is_suspended=p_suspended,updated_at=now() where id=p_user_id;
  insert into audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values(auth.uid(),case when p_suspended then 'suspend_user' else 'unsuspend_user' end,'profile',p_user_id,jsonb_build_object('reason',p_reason));
end;
$$;

-- Ensure only one default address is preferred per user without deleting old addresses.
create unique index if not exists addresses_one_default_per_user
on addresses(user_id) where is_default;
