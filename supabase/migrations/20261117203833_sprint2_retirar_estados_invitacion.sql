-- Remove obsolete invitation state from the active business model.
alter table public.vinculaciones_personal rename column aceptada_en to autorizada_en;
do $cleanup$
declare f record; definition text;
begin
 for f in select pg_get_functiondef(p.oid) as source from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname in ('fc_command','fc_assigned') loop
   definition:=replace(f.source,'aceptada_en','autorizada_en');
   definition:=replace(definition,',rol_invitado=null,invitacion_vence=null','');
   execute definition;
 end loop;
end $cleanup$;
alter table public.perfiles drop column rol_invitado, drop column invitado_en, drop column invitacion_vence;
alter table public.vinculaciones_personal drop column vence_en;
create unique index vinculacion_persona_unica_vigente on public.vinculaciones_personal(perfil_id) where activo;
