-- Real-time operations alerts to Telegram.
-- Database changes call the telegram-notify Edge Function asynchronously
-- (pg_net), so the alert goes out within seconds of the change.
-- The shared secret lives in Supabase Vault as 'telegram_notify_secret'.
-- If the secret is missing, nothing is sent and business writes still succeed.

create extension if not exists pg_net with schema extensions;

create or replace function public.notify_telegram(p_payload jsonb)
returns void
language plpgsql
security definer
set search_path = public, extensions, vault
as $$
declare
  v_secret text;
begin
  select decrypted_secret into v_secret
  from vault.decrypted_secrets
  where name = 'telegram_notify_secret';
  if v_secret is null then return; end if;

  perform net.http_post(
    url := 'https://vclicpejajxadsbuakdw.supabase.co/functions/v1/telegram-notify',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-notify-secret', v_secret),
    body := p_payload
  );
exception when others then
  -- Alerting must never block the operation that triggered it.
  null;
end;
$$;

revoke execute on function public.notify_telegram(jsonb) from anon, authenticated, public;

create or replace function public.trg_notify_audit_telegram()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if NEW.action in (
    'create_staff_account', 'set_service_partner_status', 'create_delivery', 'reassign_delivery',
    'prepare_account_deletion', 'complete_account_deletion', 'reject_account_deletion',
    'create_service_area', 'activate_service_area', 'deactivate_service_area',
    'set_user_role', 'suspend_user', 'reject_contribution', 'verify_contribution'
  ) then
    perform public.notify_telegram(jsonb_build_object(
      'source', 'audit',
      'action', NEW.action,
      'entity_type', NEW.entity_type,
      'entity_id', NEW.entity_id,
      'metadata', NEW.metadata
    ));
  end if;
  return null;
end;
$$;

drop trigger if exists audit_notify_telegram on public.audit_logs;
create trigger audit_notify_telegram
  after insert on public.audit_logs
  for each row execute function public.trg_notify_audit_telegram();

create or replace function public.trg_notify_need_telegram()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.notify_telegram(jsonb_build_object(
    'source', 'need', 'public_code', NEW.public_code,
    'category', NEW.category, 'item_type', NEW.item_type
  ));
  return null;
end;
$$;

drop trigger if exists needs_notify_telegram on public.needs;
create trigger needs_notify_telegram
  after insert on public.needs
  for each row execute function public.trg_notify_need_telegram();

create or replace function public.trg_notify_donation_telegram()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.notify_telegram(jsonb_build_object(
    'source', 'donation', 'public_code', NEW.public_code,
    'category', NEW.category, 'item_type', NEW.item_type
  ));
  return null;
end;
$$;

drop trigger if exists donations_notify_telegram on public.donations;
create trigger donations_notify_telegram
  after insert on public.donations
  for each row execute function public.trg_notify_donation_telegram();
