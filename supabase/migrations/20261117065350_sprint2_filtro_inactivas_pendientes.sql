begin;
create or replace function private.fc_query(p_resource text,p_params jsonb) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare r text:=private.fc_role(); u uuid:=auth.uid(); result jsonb; s uuid; mode text;
begin
 if p_resource='profile' then
   select to_jsonb(p)||jsonb_build_object('email',a.email,'confirmado',a.email_confirmed_at is not null,'email_pendiente',a.email_change)
   into result from public.perfiles p join auth.users a on a.id=p.id where p.id=u;
   return result;
 elsif p_resource='options' then
   return jsonb_build_object('empresas',coalesce((select jsonb_agg(to_jsonb(e) order by e.denominacion) from public.empresas_operadoras e where e.activo or r='administrador'),'[]'),
   'ciudades',coalesce((select jsonb_agg(to_jsonb(c) order by c.nombre) from public.ciudades c where c.activo),'[]'),
   'combustibles',coalesce((select jsonb_agg(to_jsonb(b) order by b.nombre) from public.combustibles b where b.activo),'[]'));
 elsif p_resource='catalog' then
   mode:=coalesce(p_params->>'mode','public');
   if mode='admin' and r is distinct from 'administrador' then raise exception 'Acceso administrativo requerido'; end if;
   if mode='assigned' and r is distinct from 'responsable' then raise exception 'Cuenta de responsable requerida'; end if;
   if mode='favorites' and r is null then raise exception 'Cuenta activa y confirmada requerida'; end if;
   select coalesce(jsonb_agg(x.obj order by x.nombre,x.id),'[]') into result from (
     select t.id,t.nombre,case when mode='favorites' and not(t.activo and e.activo)
     then jsonb_build_object('id',t.id,'nombre',t.nombre,'disponible',false,'favorita',true,'combustibles','[]'::jsonb)
     else private.fc_station(t.id) end obj
     from public.estaciones t join public.empresas_operadoras e on e.id=t.empresa_id
     where (case mode when 'admin' then (coalesce(p_params->>'status','all')='all' or t.activo=(p_params->>'status'='active'))
       when 'assigned' then private.fc_assigned(t.id)
       when 'favorites' then exists(select 1 from public.favoritas f where f.perfil_id=u and f.estacion_id=t.id and f.activo)
       else t.activo and e.activo end)
     and (coalesce(p_params->>'name','')='' or t.nombre ilike '%'||(p_params->>'name')||'%' or e.denominacion ilike '%'||(p_params->>'name')||'%')
     and (nullif(p_params->>'company','') is null or t.empresa_id=(p_params->>'company')::uuid)
     and (nullif(p_params->>'city','') is null or t.ciudad_id=(p_params->>'city')::uuid)
     and (nullif(p_params->>'fuel','') is null or exists(select 1 from public.estacion_combustible ec where ec.estacion_id=t.id and ec.combustible_id=(p_params->>'fuel')::uuid and ec.activo))
     order by t.nombre,t.id limit 21 offset greatest(0,coalesce((p_params->>'page')::int,0))*20
   ) x;
   return jsonb_build_object('rows',case when jsonb_array_length(result)>20 then result-20 else result end,'has_more',jsonb_array_length(result)>20);
 elsif p_resource='station' then
   s:=(p_params->>'id')::uuid;
   if not exists(select 1 from public.estaciones t join public.empresas_operadoras e on e.id=t.empresa_id where t.id=s and ((t.activo and e.activo) or r='administrador')) then raise exception 'Estación no disponible'; end if;
   return private.fc_station(s);
 elsif p_resource='invitations' then
   if r is null then raise exception 'Cuenta activa y confirmada requerida'; end if;
   select coalesce(jsonb_agg(to_jsonb(v)||jsonb_build_object('empresa',e.denominacion) order by v.inicio desc),'[]') into result
   from public.vinculaciones_personal v join public.empresas_operadoras e on e.id=v.empresa_id where v.perfil_id=u and v.activo;
   return jsonb_build_object('vinculos',result,'rol_invitado',(select p.rol_invitado from public.perfiles p where p.id=u),
   'vence',(select p.invitacion_vence from public.perfiles p where p.id=u));
 elsif p_resource='history' then
   s:=(p_params->>'id')::uuid;
   if not coalesce(r='administrador' or private.fc_assigned(s),false) then raise exception 'Sin autorización para el historial'; end if;
   select coalesce(jsonb_agg(to_jsonb(x) order by x.registrado_en desc,x.id desc),'[]') into result from(
   select h.id,h.estado,h.registrado_en,h.autor_perfil_id,p.nombre autor,p.codigo autor_codigo,b.nombre combustible
   from public.historial_disponibilidad h join public.estacion_combustible ec on ec.id=h.estacion_combustible_id
   join public.combustibles b on b.id=ec.combustible_id join public.perfiles p on p.id=h.autor_perfil_id
   where ec.estacion_id=s order by h.registrado_en desc,h.id desc limit 100) x;
   return result;
 end if;
 if r is distinct from 'administrador' then raise exception 'Acceso administrativo requerido'; end if;
 if p_resource='companies' then
   select coalesce(jsonb_agg(to_jsonb(e) order by e.denominacion),'[]') into result from public.empresas_operadoras e
   where (coalesce(p_params->>'status','all')='all' or e.activo=(p_params->>'status'='active'))
   and e.denominacion ilike '%'||coalesce(p_params->>'name','')||'%'; return result;
 elsif p_resource in ('users','user','lookup_email') then
   select coalesce(jsonb_agg(to_jsonb(x) order by x.nombre,x.id),'[]') into result from (
   select p.*,a.email,a.email_confirmed_at is not null confirmado,
   case when not p.activo then 'inactive' when p.rol_invitado is not null or a.email_confirmed_at is null then 'pending' else 'active' end estado
   from public.perfiles p join auth.users a on a.id=p.id
   where (p_resource<>'user' or p.id=(p_params->>'id')::uuid)
   and (p_resource<>'lookup_email' or lower(a.email)=lower(p_params->>'email'))
   and (nullif(p_params->>'role','') is null or p.rol=p_params->>'role')
   and (p.nombre ilike '%'||coalesce(p_params->>'name','')||'%' or a.email ilike '%'||coalesce(p_params->>'name','')||'%')
   order by p.nombre,p.id limit 500) x
   where coalesce(p_params->>'status','all')='all' or x.estado=p_params->>'status';
   return case when p_resource='user' then result->0 else result end;
 elsif p_resource='memberships' then
   select coalesce(jsonb_agg(to_jsonb(v)||jsonb_build_object('empresa',e.denominacion,'empresa_activa',e.activo) order by v.inicio desc),'[]') into result
   from public.vinculaciones_personal v join public.empresas_operadoras e on e.id=v.empresa_id where v.perfil_id=(p_params->>'id')::uuid;return result;
 elsif p_resource='assignments' then
   select coalesce(jsonb_agg(to_jsonb(a)||jsonb_build_object('estacion',t.nombre,'empresa',e.denominacion) order by a.inicio desc),'[]') into result
   from public.asignaciones_responsables a join public.vinculaciones_personal v on v.id=a.vinculacion_id
   join public.estaciones t on t.id=a.estacion_id join public.empresas_operadoras e on e.id=t.empresa_id
   where v.perfil_id=(p_params->>'id')::uuid; return result;
 elsif p_resource='audit' then
   select coalesce(jsonb_agg(to_jsonb(x) order by x.registrado_en desc,x.id desc),'[]') into result from(
   select a.*,p.nombre actor from public.auditoria_cuentas a left join public.perfiles p on p.id=a.actor_id
   where a.cuenta_afectada_id=(p_params->>'id')::uuid order by a.registrado_en desc,a.id desc limit 150) x;return result;
 end if;
 raise exception 'Consulta desconocida';
end $$;


notify pgrst,'reload schema';
commit;
