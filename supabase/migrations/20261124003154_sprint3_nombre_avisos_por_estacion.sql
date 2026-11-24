-- Rename the opt-in table while retaining rows, keys, RLS and the public RPC contract.
begin;
alter table public.suscripciones_disponibilidad rename to avisos_por_estacion;

do $rename_alerts$
declare obj record; rewritten integer := 0;
begin
  for obj in
    select conname from pg_catalog.pg_constraint
    where conrelid='public.avisos_por_estacion'::regclass
      and conname like 'suscripciones_disponibilidad%'
  loop
    execute format('alter table public.avisos_por_estacion rename constraint %I to %I',
      obj.conname,replace(obj.conname,'suscripciones_disponibilidad','avisos_por_estacion'));
  end loop;
  for obj in
    select i.relname from pg_catalog.pg_index x
    join pg_catalog.pg_class i on i.oid=x.indexrelid
    where x.indrelid='public.avisos_por_estacion'::regclass
      and i.relname like 'suscripciones_disponibilidad%'
  loop
    execute format('alter index public.%I rename to %I',
      obj.relname,replace(obj.relname,'suscripciones_disponibilidad','avisos_por_estacion'));
  end loop;
  for obj in
    select p.oid,pg_catalog.pg_get_functiondef(p.oid) as definition
    from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
    where n.nspname in ('public','private') and p.prokind='f'
      and pg_catalog.pg_get_functiondef(p.oid) like '%public.suscripciones_disponibilidad%'
  loop
    execute replace(obj.definition,'public.suscripciones_disponibilidad','public.avisos_por_estacion');
    rewritten := rewritten + 1;
  end loop;
  if rewritten < 5 then raise exception 'Expected all five alert functions to be updated'; end if;
end
$rename_alerts$;
comment on table public.avisos_por_estacion is
  'Elección del conductor de recibir avisos de disponibilidad para cada estación favorita.';
commit;
