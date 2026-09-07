-- Ruhamaa Verified Partner Services V1
-- Businesses/shops/workshops are verified entities, not marketplace listings.

create table if not exists public.service_partners (
  id uuid primary key default gen_random_uuid(),
  public_code text not null unique,
  owner_user_id uuid not null references public.profiles(id) on delete cascade,
  service_area_id uuid references public.service_areas(id) on delete set null,
  display_name text not null,
  partner_kind text not null check (partner_kind in (
    'salon','clothing_shop','event_setup','repair_shop','printing_shop','workshop','other'
  )),
  description text,
  contact_phone text,
  monthly_case_capacity integer not null default 4 check (monthly_case_capacity between 1 and 100),
  verification_status text not null default 'pending' check (verification_status in ('pending','verified','rejected','suspended')),
  verified_by uuid references public.profiles(id) on delete set null,
  verified_at timestamptz,
  admin_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.service_partners enable row level security;

create policy "partners_owner_select"
on public.service_partners for select to authenticated
using (owner_user_id = (select auth.uid()) or public.is_admin());

create policy "partners_owner_insert"
on public.service_partners for insert to authenticated
with check (
  owner_user_id = (select auth.uid())
  and verification_status = 'pending'
  and public.is_active_user()
);

create policy "partners_owner_update"
on public.service_partners for update to authenticated
using (owner_user_id = (select auth.uid()) and public.is_active_user())
with check (owner_user_id = (select auth.uid()) and public.is_active_user());

create policy "partners_admin_all"
on public.service_partners for all to authenticated
using (public.is_admin()) with check (public.is_admin());

grant select, insert, update on public.service_partners to authenticated;

alter table public.service_offers
  add column if not exists partner_id uuid references public.service_partners(id) on delete set null;

create index if not exists service_partners_owner_status_idx
  on public.service_partners(owner_user_id, verification_status, created_at);
create index if not exists service_offers_partner_idx
  on public.service_offers(partner_id, status, verification_status);

create or replace function public.protect_service_partner_verification()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if not public.is_admin() then
    if tg_op = 'UPDATE' then
      if new.verification_status is distinct from old.verification_status
         or new.verified_by is distinct from old.verified_by
         or new.verified_at is distinct from old.verified_at
         or new.admin_note is distinct from old.admin_note then
        raise exception 'partner verification fields are staff-managed';
      end if;
    end if;
    new.verification_status := 'pending';
    new.verified_by := null;
    new.verified_at := null;
    new.admin_note := null;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists protect_service_partner_verification_trigger on public.service_partners;
create trigger protect_service_partner_verification_trigger
before insert or update on public.service_partners
for each row execute function public.protect_service_partner_verification();

create or replace function public.validate_business_service_offer()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_owner uuid;
  v_status text;
begin
  if new.provider_kind = 'person' then
    new.partner_id := null;
    return new;
  end if;

  if new.partner_id is null then
    raise exception 'business service offers require a verified Ruhamaa partner';
  end if;

  select owner_user_id, verification_status
    into v_owner, v_status
  from public.service_partners
  where id = new.partner_id;

  if v_owner is null then raise exception 'partner not found'; end if;
  if v_owner <> new.user_id then raise exception 'partner must belong to offer owner'; end if;
  if v_status <> 'verified' then raise exception 'partner must be verified before creating a business offer'; end if;
  return new;
end;
$$;

drop trigger if exists service_offers_validate_partner on public.service_offers;
create trigger service_offers_validate_partner
before insert or update of provider_kind, partner_id, user_id
on public.service_offers
for each row execute function public.validate_business_service_offer();

create or replace function public.admin_set_service_partner_status(
  p_partner_id uuid,
  p_status text,
  p_note text default null
)
returns void
language plpgsql
set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'admin access required'; end if;
  if p_status not in ('verified','rejected','suspended') then raise exception 'invalid partner status'; end if;

  update public.service_partners
  set verification_status = p_status,
      verified_by = case when p_status='verified' then auth.uid() else verified_by end,
      verified_at = case when p_status='verified' then now() else verified_at end,
      admin_note = nullif(trim(coalesce(p_note,'')),''),
      updated_at = now()
  where id = p_partner_id;

  if not found then raise exception 'partner not found'; end if;

  if p_status in ('rejected','suspended') then
    update public.service_offers
    set status='paused', updated_at=now()
    where partner_id=p_partner_id and status in ('submitted','approved');
  end if;

  insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values(auth.uid(),'set_service_partner_status','service_partner',p_partner_id,jsonb_build_object('status',p_status));
end;
$$;

revoke all on function public.admin_set_service_partner_status(uuid,text,text) from public, anon;
grant execute on function public.admin_set_service_partner_status(uuid,text,text) to authenticated;

comment on table public.service_partners is
  'Verified shops/businesses/workshops contributing reviewed free services. Partners are never browsed as a marketplace.';
comment on column public.service_partners.monthly_case_capacity is
  'Operational capacity, not a ranking or advertising field.';
