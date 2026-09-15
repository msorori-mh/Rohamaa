-- Ataa display identity only. No role, workflow, table or user-data changes.
-- Preserve signature, ownership, grants, SECURITY mode and search_path verbatim.
do $ataa$
declare
  fn regprocedure;
  before_def text;
  after_def text;
  signature text;
begin
  foreach signature in array array[
    'public.notify_partner_verification()',
    'public.notify_item_match_status()',
    'public.validate_business_service_offer()'
  ] loop
    fn := to_regprocedure(signature);
    if fn is null then raise exception 'Required branding target missing: %', signature; end if;
    before_def := pg_get_functiondef(fn);
    after_def := replace(before_def, 'تحديث حالة شريك رحماء', 'تحديث حالة شريك عطاء');
    after_def := replace(after_def,
      'وجد فريق رحماء عطاءً مناسبًا لاحتياجك. راجع العرض واتخذ قرارك.',
      'وجد فريق عطاء شيئًا مناسبًا لاحتياجك. راجع العرض واتخذ قرارك.');
    after_def := replace(after_def, 'verified Ruhamaa partner', 'verified Ataa partner');
    if after_def <> before_def then execute after_def; end if;
    if position('رحماء' in after_def)>0 or position('Ruhamaa' in after_def)>0 then
      raise exception 'Unexpected old brand in %', signature;
    end if;
  end loop;
end
$ataa$;
