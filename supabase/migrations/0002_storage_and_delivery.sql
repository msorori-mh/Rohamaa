-- Sanad V1: donation storage, delivery verification helpers, and contribution safety.

insert into storage.buckets (id, name, public)
values ('donation-images', 'donation-images', false)
on conflict (id) do nothing;

create policy "donation_images_owner_upload"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'donation-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "donation_images_owner_read"
on storage.objects for select
to authenticated
using (
  bucket_id = 'donation-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "donation_images_owner_delete"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'donation-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create or replace function public.generate_public_code(prefix text)
returns text
language plpgsql
security definer
set search_path = public
as $$
begin
  return prefix || '-' || to_char(now(), 'YYMMDD') || '-' || upper(substr(encode(gen_random_bytes(5), 'hex'), 1, 8));
end;
$$;

create or replace function public.hash_pin(pin text)
returns text
language sql
immutable
as $$
  select encode(digest(pin, 'sha256'), 'hex');
$$;

create or replace function public.verify_delivery_pin(
  p_delivery_id uuid,
  p_pin text,
  p_kind text,
  p_latitude double precision default null,
  p_longitude double precision default null
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  d public.deliveries;
  expected_hash text;
  next_status public.delivery_status;
begin
  select * into d from public.deliveries where id = p_delivery_id for update;
  if not found then return false; end if;

  if d.courier_id <> auth.uid() then
    raise exception 'not assigned courier';
  end if;

  if p_kind = 'pickup' then
    expected_hash := d.pickup_pin_hash;
    next_status := 'picked_up';
  elsif p_kind = 'delivery' then
    expected_hash := d.delivery_pin_hash;
    next_status := 'delivered';
  else
    raise exception 'invalid pin kind';
  end if;

  if expected_hash is null or public.hash_pin(p_pin) <> expected_hash then
    insert into public.risk_flags (user_id, delivery_id, rule_code, severity, details)
    values (auth.uid(), p_delivery_id, 'INVALID_DELIVERY_PIN', 'medium', jsonb_build_object('kind', p_kind));
    return false;
  end if;

  update public.deliveries
  set status = next_status,
      picked_up_at = case when p_kind = 'pickup' then now() else picked_up_at end,
      delivered_at = case when p_kind = 'delivery' then now() else delivered_at end
  where id = p_delivery_id;

  insert into public.delivery_events(delivery_id, actor_id, event_type, latitude, longitude)
  values (p_delivery_id, auth.uid(), case when p_kind='pickup' then 'pickup_pin_verified' else 'delivery_pin_verified' end, p_latitude, p_longitude);

  return true;
end;
$$;

-- User-facing contribution creation uses RLS; verification remains an admin/server operation.
create index if not exists contributions_user_created_idx on public.contributions(user_id, created_at desc);
create index if not exists needs_user_status_idx on public.needs(user_id, status);
create index if not exists donations_user_status_idx on public.donations(user_id, status);
create index if not exists deliveries_courier_status_idx on public.deliveries(courier_id, status);
