-- Sanad V1: suspension enforcement and server-side contribution constraints.

create or replace function public.is_active_user()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from profiles
    where id=auth.uid() and not is_suspended
  );
$$;

revoke all on function public.is_active_user() from public, anon;
grant execute on function public.is_active_user() to authenticated;

-- Replace owner mutation policies with active-account checks.
drop policy if exists "addresses_owner_all" on public.addresses;
create policy "addresses_owner_select" on public.addresses
for select to authenticated
using (user_id=auth.uid());
create policy "addresses_owner_insert" on public.addresses
for insert to authenticated
with check (user_id=auth.uid() and public.is_active_user());
create policy "addresses_owner_update" on public.addresses
for update to authenticated
using (user_id=auth.uid() and public.is_active_user())
with check (user_id=auth.uid() and public.is_active_user());
create policy "addresses_owner_delete" on public.addresses
for delete to authenticated
using (user_id=auth.uid() and public.is_active_user());

drop policy if exists "needs_owner_insert" on public.needs;
drop policy if exists "needs_owner_update" on public.needs;
create policy "needs_owner_insert" on public.needs
for insert to authenticated
with check (user_id=auth.uid() and public.is_active_user());
create policy "needs_owner_update" on public.needs
for update to authenticated
using (user_id=auth.uid() and public.is_active_user())
with check (user_id=auth.uid() and public.is_active_user());

drop policy if exists "donations_owner_insert" on public.donations;
drop policy if exists "donations_owner_update" on public.donations;
create policy "donations_owner_insert" on public.donations
for insert to authenticated
with check (user_id=auth.uid() and public.is_active_user());
create policy "donations_owner_update" on public.donations
for update to authenticated
using (user_id=auth.uid() and public.is_active_user())
with check (user_id=auth.uid() and public.is_active_user());

drop policy if exists "contributions_owner_insert" on public.contributions;
create policy "contributions_owner_insert" on public.contributions
for insert to authenticated
with check (user_id=auth.uid() and public.is_active_user());

-- Donation image rows and Storage uploads must also respect suspension.
drop policy if exists "donation_image_rows_owner_insert" on public.donation_images;
create policy "donation_image_rows_owner_insert" on public.donation_images
for insert to authenticated
with check (
  public.is_active_user()
  and exists (
    select 1 from public.donations d
    where d.id=donation_id and d.user_id=auth.uid()
  )
);

drop policy if exists "donation_images_owner_upload" on storage.objects;
create policy "donation_images_owner_upload"
on storage.objects for insert to authenticated
with check (
  public.is_active_user()
  and bucket_id='donation-images'
  and (storage.foldername(name))[1]=auth.uid()::text
);

-- The client may only create the agreed operational contribution amounts.
alter table public.contributions
  drop constraint if exists contributions_allowed_amounts;
alter table public.contributions
  add constraint contributions_allowed_amounts
  check (amount_yer in (1000,2000,3000,4000,5000));

alter table public.contributions
  drop constraint if exists contributions_payment_method_check;
alter table public.contributions
  add constraint contributions_payment_method_check
  check (payment_method is null or payment_method='manual_transfer');

-- One active payment reference cannot fund several pending/verified contributions.
drop index if exists public.contributions_payment_reference_unique;
create unique index contributions_active_payment_reference_unique
on public.contributions(payment_reference)
where payment_reference is not null and status in ('pending','verified');

-- Sensitive user actions check suspension inside SECURITY DEFINER RPCs.
create or replace function public.user_respond_match_offer(p_match_id uuid,p_accept boolean)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_donation uuid;
  v_need uuid;
  v_need_owner uuid;
begin
  if not public.is_active_user() then raise exception 'account suspended'; end if;
  select m.donation_id,m.need_id,n.user_id into v_donation,v_need,v_need_owner
  from matches m join needs n on n.id=m.need_id
  where m.id=p_match_id and m.status='offered'
  for update of m;
  if not found then raise exception 'offer unavailable'; end if;
  if v_need_owner<>auth.uid() then raise exception 'not offer owner'; end if;
  if p_accept then
    update matches set status='accepted', responded_at=now() where id=p_match_id;
    update donations set status='matched',updated_at=now() where id=v_donation;
    update needs set status='matched',updated_at=now() where id=v_need;
  else
    update matches set status='declined', responded_at=now() where id=p_match_id;
    update donations set status='available',updated_at=now() where id=v_donation;
    update needs set status='waiting',updated_at=now() where id=v_need;
  end if;
  insert into audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values(auth.uid(),case when p_accept then 'accept_match_offer' else 'decline_match_offer' end,'match',p_match_id,'{}'::jsonb);
end;
$$;

create or replace function public.user_issue_handoff_pin(p_delivery_id uuid,p_kind text)
returns text
language plpgsql security definer set search_path = public
as $$
declare
  v_bytes bytea;
  v_pin text;
  v_donor uuid;
  v_beneficiary uuid;
  v_status public.delivery_status;
begin
  if not public.is_active_user() then raise exception 'account suspended'; end if;
  select d.user_id,n.user_id,del.status into v_donor,v_beneficiary,v_status
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
  v_bytes:=gen_random_bytes(2);
  v_pin:=lpad((((get_byte(v_bytes,0)*256)+get_byte(v_bytes,1))%10000)::text,4,'0');
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

revoke all on function public.user_respond_match_offer(uuid,boolean) from public, anon;
revoke all on function public.user_issue_handoff_pin(uuid,text) from public, anon;
grant execute on function public.user_respond_match_offer(uuid,boolean) to authenticated;
grant execute on function public.user_issue_handoff_pin(uuid,text) to authenticated;
