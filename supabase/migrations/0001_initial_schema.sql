create extension if not exists pgcrypto;

create type public.user_role as enum ('user','courier','admin');
create type public.donation_status as enum ('draft','submitted','under_review','available','matched','pickup_scheduled','picked_up','out_for_delivery','delivered','cancelled','rejected');
create type public.need_status as enum ('submitted','waiting','candidate_found','confirmed','matched','delivery_scheduled','fulfilled','cancelled','expired');
create type public.delivery_status as enum ('assigned','heading_to_pickup','picked_up','heading_to_recipient','delivered','failed','rescheduled');
create type public.contribution_status as enum ('pending','verified','rejected','refunded');
create type public.risk_severity as enum ('low','medium','high','critical');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  role public.user_role not null default 'user',
  trust_score integer not null default 0,
  is_suspended boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  label text,
  area text,
  description text,
  latitude double precision,
  longitude double precision,
  is_default boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.needs (
  id uuid primary key default gen_random_uuid(),
  public_code text unique not null,
  user_id uuid not null references public.profiles(id) on delete cascade,
  category text not null,
  item_type text not null,
  description text,
  reason text,
  accepts_used boolean not null default true,
  address_id uuid references public.addresses(id),
  status public.need_status not null default 'submitted',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.donations (
  id uuid primary key default gen_random_uuid(),
  public_code text unique not null,
  user_id uuid not null references public.profiles(id) on delete cascade,
  category text not null,
  item_type text not null,
  condition text,
  description text,
  address_id uuid references public.addresses(id),
  status public.donation_status not null default 'submitted',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.donation_images (
  id uuid primary key default gen_random_uuid(),
  donation_id uuid not null references public.donations(id) on delete cascade,
  storage_path text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table public.matches (
  id uuid primary key default gen_random_uuid(),
  donation_id uuid not null references public.donations(id) on delete cascade,
  need_id uuid not null references public.needs(id) on delete cascade,
  score numeric(6,2) not null default 0,
  score_details jsonb not null default '{}'::jsonb,
  approved_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  unique(donation_id, need_id)
);

create table public.couriers (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.vehicles (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  kind text not null default 'electric_motorbike',
  active boolean not null default true,
  notes text,
  created_at timestamptz not null default now()
);

create table public.deliveries (
  id uuid primary key default gen_random_uuid(),
  public_code text unique not null,
  match_id uuid not null unique references public.matches(id) on delete cascade,
  courier_id uuid references public.couriers(user_id),
  vehicle_id uuid references public.vehicles(id),
  status public.delivery_status not null default 'assigned',
  pickup_pin_hash text,
  delivery_pin_hash text,
  assigned_at timestamptz,
  picked_up_at timestamptz,
  delivered_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.delivery_events (
  id bigint generated always as identity primary key,
  delivery_id uuid not null references public.deliveries(id) on delete cascade,
  actor_id uuid references public.profiles(id),
  event_type text not null,
  latitude double precision,
  longitude double precision,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.contributions (
  id uuid primary key default gen_random_uuid(),
  public_code text unique not null,
  user_id uuid not null references public.profiles(id) on delete cascade,
  donation_id uuid references public.donations(id) on delete set null,
  need_id uuid references public.needs(id) on delete set null,
  delivery_id uuid references public.deliveries(id) on delete set null,
  amount_yer integer not null check (amount_yer > 0),
  payment_method text,
  payment_reference text,
  status public.contribution_status not null default 'pending',
  verified_by uuid references public.profiles(id),
  verified_at timestamptz,
  created_at timestamptz not null default now()
);

create unique index contributions_payment_reference_unique
on public.contributions(payment_reference)
where payment_reference is not null and status = 'verified';

create table public.risk_flags (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  need_id uuid references public.needs(id) on delete cascade,
  donation_id uuid references public.donations(id) on delete cascade,
  delivery_id uuid references public.deliveries(id) on delete cascade,
  rule_code text not null,
  severity public.risk_severity not null default 'medium',
  details jsonb not null default '{}'::jsonb,
  resolved boolean not null default false,
  resolved_by uuid references public.profiles(id),
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id),
  action text not null,
  entity_type text not null,
  entity_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'));
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.addresses enable row level security;
alter table public.needs enable row level security;
alter table public.donations enable row level security;
alter table public.donation_images enable row level security;
alter table public.matches enable row level security;
alter table public.deliveries enable row level security;
alter table public.delivery_events enable row level security;
alter table public.contributions enable row level security;
alter table public.risk_flags enable row level security;
alter table public.audit_logs enable row level security;

create policy "profiles_self_select" on public.profiles for select using (auth.uid() = id);
create policy "profiles_self_update" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);
create policy "addresses_owner_all" on public.addresses for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "needs_owner_select" on public.needs for select using (auth.uid() = user_id);
create policy "needs_owner_insert" on public.needs for insert with check (auth.uid() = user_id);
create policy "needs_owner_update" on public.needs for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "donations_owner_select" on public.donations for select using (auth.uid() = user_id);
create policy "donations_owner_insert" on public.donations for insert with check (auth.uid() = user_id);
create policy "donations_owner_update" on public.donations for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "contributions_owner_select" on public.contributions for select using (auth.uid() = user_id);
create policy "contributions_owner_insert" on public.contributions for insert with check (auth.uid() = user_id);

-- Admin/courier access should be served through trusted server-side functions using the service role.
-- Never expose the service-role key in the mobile app.
