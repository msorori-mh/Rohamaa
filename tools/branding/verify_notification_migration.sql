do $$
begin
  if (select count(*) from identity_before) <> 3 then raise exception 'Fixture count mismatch'; end if;
  if exists(select 1 from identity_before b join pg_proc p on p.oid=b.oid
    where row(p.proowner,p.prosecdef,p.proconfig,p.proacl,p.proargtypes,p.prorettype)
      is distinct from row(b.proowner,b.prosecdef,b.proconfig,b.proacl,b.proargtypes,b.prorettype)) then
    raise exception 'Migration changed function security/signature metadata';
  end if;
  if exists(select 1 from identity_before b join pg_proc p on p.oid=b.oid where p.prosrc <>
    replace(replace(replace(b.prosrc,
      'تحديث حالة شريك رحماء','تحديث حالة شريك عطاء'),
      'وجد فريق رحماء عطاءً مناسبًا لاحتياجك. راجع العرض واتخذ قرارك.',
      'وجد فريق عطاء شيئًا مناسبًا لاحتياجك. راجع العرض واتخذ قرارك.'),
      'verified Ruhamaa partner','verified Ataa partner')) then
    raise exception 'Function behavior changed beyond the reviewed identity literals';
  end if;
end $$;
select 'PASS: three definitions changed only approved literals; ACL/security/signatures preserved; repeated apply safe' as result;
