-- New contribution flow: optional operational support is pledged in-app
-- and handed as cash to a Ruhamaa courier at pickup or delivery.
-- manual_transfer remains allowed only for legacy records.

alter table public.contributions
  drop constraint if exists contributions_payment_method_check;

alter table public.contributions
  add constraint contributions_payment_method_check
  check (
    payment_method is null
    or payment_method in ('manual_transfer', 'cash_to_courier')
  );

comment on column public.contributions.payment_method is
  'Contribution collection method. New app flow uses cash_to_courier; manual_transfer is retained only for legacy records.';
