begin;
create or replace function private.fc_command(p_action text,p_data jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare r text; u uuid:=auth.uid(); target uuid; eid uuid; v public.vinculaciones_personal; a public.asignaciones_responsables;
 t public.estaciones; p public.perfiles; old_role text; b boolean; j jsonb; role_new text; n text; cnt int; operation uuid; result jsonb;
begin
 -- Serialize authorization-changing transactions with publications. Row checks see committed revocations.
 perform pg_advisory_xact_lock(17062026);
 r:=private.fc_role();
 if r is null then raise exception 'Cuenta activa y confirmada requerida'; end if;
 if p_action='profile_save' then
   update public.perfiles set nombre=trim(p_data->>'nombre'),contacto=trim(coalesce(p_data->>'contacto','')) where id=u;
   return jsonb_build_object('ok',true);
 elsif p_action='favorite' then
   target:=(p_data->>'id')::uuid;b:=(p_data->>'activo')::boolean;
   if b and not exists(select 1 from public.estaciones s join public.empresas_operadoras e on e.id=s.empresa_id where s.id=target and s.activo and e.activo) then raise exception 'Estación no disponible'; end if;
   insert into public.favoritas(perfil_id,estacion_id,activo) values(u,target,b)
   on conflict(perfil_id,estacion_id) do update set activo=excluded.activo,actualizado_en=clock_timestamp();
   return jsonb_build_object('ok',true);
 elsif p_action='invitation_reply' then
   b:=(p_data->>'accept')::boolean;
   if nullif(p_data->>'id','') is not null then
     select * into v from public.vinculaciones_personal where id=(p_data->>'id')::uuid and perfil_id=u and activo and aceptada_en is null and vence_en>clock_timestamp() for update;
     if v.id is null then raise exception 'Invitación vencida o cancelada'; end if;
     if b and not exists(select 1 from public.empresas_operadoras e where e.id=v.empresa_id and e.activo) then raise exception 'Empresa no disponible'; end if;
     update public.vinculaciones_personal set aceptada_en=case when b then clock_timestamp() end,activo=b,fin=case when not b then clock_timestamp() end where id=v.id;
     if b then update public.perfiles set rol='responsable',rol_invitado=null,invitacion_vence=null where id=u and rol='conductor'; end if;
   else
     select * into p from public.perfiles where id=u and rol_invitado is not null and invitacion_vence>clock_timestamp() for update;
     if p.id is null then raise exception 'Invitación vencida o cancelada'; end if;
     if b and p.rol_invitado='responsable' and not exists(select 1 from public.vinculaciones_personal x where x.perfil_id=u and x.activo and x.aceptada_en is not null) then raise exception 'Primero acepta la vinculación empresarial'; end if;
     if b and p.rol_invitado<>p.rol then
       update public.asignaciones_responsables set activo=false,fin=clock_timestamp() where activo and vinculacion_id in(select id from public.vinculaciones_personal where perfil_id=u);
     end if;
     update public.perfiles set rol=case when b then rol_invitado else rol end,rol_invitado=null,invitacion_vence=null where id=u;
   end if;
   return jsonb_build_object('ok',true);
 elsif p_action='publish' then
   target:=(p_data->>'id')::uuid;operation:=(p_data->>'operation')::uuid;
   if not coalesce(private.fc_assigned(target),false) then raise exception 'No tienes una asignación vigente para esta estación'; end if;
   if jsonb_typeof(p_data->'changes') is distinct from 'array' or jsonb_array_length(p_data->'changes')=0 then raise exception 'Selecciona al menos un combustible'; end if;
   if exists(select 1 from jsonb_array_elements(p_data->'changes') x where x->>'estado' not in ('disponible','limitada','agotado') or x->>'estado' is null
     or not exists(select 1 from public.estacion_combustible ec join public.combustibles f on f.id=ec.combustible_id where ec.estacion_id=target and ec.combustible_id=(x->>'id')::uuid and ec.activo and f.activo)) then raise exception 'Combustible o estado inválido'; end if;
   if (select count(*)<>count(distinct x->>'id') from jsonb_array_elements(p_data->'changes') x) then raise exception 'Combustible duplicado'; end if;
   if exists(select 1 from public.historial_disponibilidad h where h.operacion_id=operation) then
     if exists(select 1 from public.historial_disponibilidad h join public.estacion_combustible ec on ec.id=h.estacion_combustible_id where h.operacion_id=operation and (h.autor_perfil_id<>u or ec.estacion_id<>target)) then raise exception 'Identificador de publicación ya utilizado'; end if;
     select jsonb_agg(jsonb_build_object('id',ec.combustible_id,'estado',h.estado) order by ec.combustible_id::text) into result
     from public.historial_disponibilidad h join public.estacion_combustible ec on ec.id=h.estacion_combustible_id where h.operacion_id=operation;
     if result is distinct from (select jsonb_agg(jsonb_build_object('id',x->>'id','estado',x->>'estado') order by x->>'id') from jsonb_array_elements(p_data->'changes') x) then raise exception 'La publicación ya se guardó con otros valores. Actualiza el detalle antes de publicar de nuevo'; end if;
     return jsonb_build_object('ok',true,'ya_guardado',true);
   end if;
   insert into public.historial_disponibilidad(estacion_combustible_id,autor_perfil_id,estado,operacion_id)
   select ec.id,u,x->>'estado',operation from jsonb_array_elements(p_data->'changes') x
   join public.estacion_combustible ec on ec.estacion_id=target and ec.combustible_id=(x->>'id')::uuid
   on conflict(operacion_id,estacion_combustible_id) do nothing;
   return jsonb_build_object('ok',true);
 end if;
 if r<>'administrador' then raise exception 'Acceso administrativo requerido'; end if;
 target:=nullif(p_data->>'id','')::uuid;
 if p_action='company_save' then
   insert into public.empresas_operadoras(id,denominacion,fuente_url) values(target,trim(p_data->>'denominacion'),trim(coalesce(p_data->>'fuente_url','')))
   on conflict(id) do update set denominacion=excluded.denominacion,fuente_url=excluded.fuente_url;
 elsif p_action='company_state' then
   b:=(p_data->>'activo')::boolean;
   update public.empresas_operadoras set activo=b,reactivado_en=case when b and not activo then clock_timestamp() else reactivado_en end where id=target;
   if not found then raise exception 'Empresa no encontrada'; end if;
 elsif p_action='station_save' then
   eid:=(p_data->>'empresa_id')::uuid;
   select * into t from public.estaciones where id=target for update;
   if not exists(select 1 from public.empresas_operadoras e where e.id=eid and e.activo) then raise exception 'Selecciona una empresa activa'; end if;
   if t.id is not null and t.empresa_id<>eid and (
     exists(select 1 from public.asignaciones_responsables x where x.estacion_id=t.id) or
     exists(select 1 from public.historial_disponibilidad h join public.estacion_combustible ec on ec.id=h.estacion_combustible_id where ec.estacion_id=t.id)) then raise exception 'Transferir esta estación requiere un procedimiento fuera de esta versión'; end if;
   if not exists(select 1 from public.ciudades c where c.id=(p_data->>'ciudad_id')::uuid and c.activo) then raise exception 'Ciudad inválida'; end if;
   if jsonb_typeof(p_data->'combustibles') is distinct from 'array' or jsonb_array_length(p_data->'combustibles')=0 then raise exception 'Selecciona al menos un combustible'; end if;
   if exists(select 1 from jsonb_array_elements_text(p_data->'combustibles') x where not exists(select 1 from public.combustibles f where f.id=x::uuid and f.activo)) then raise exception 'Combustible inválido'; end if;
   insert into public.estaciones(id,empresa_id,ciudad_id,nombre,direccion,licencia,fuente_url)
   values(target,eid,(p_data->>'ciudad_id')::uuid,trim(p_data->>'nombre'),trim(p_data->>'direccion'),coalesce(p_data->>'licencia',''),coalesce(p_data->>'fuente_url',''))
   on conflict(id) do update set empresa_id=excluded.empresa_id,ciudad_id=excluded.ciudad_id,nombre=excluded.nombre,direccion=excluded.direccion,licencia=excluded.licencia,fuente_url=excluded.fuente_url,actualizado_en=clock_timestamp();
   update public.estacion_combustible set activo=false where estacion_id=target and combustible_id not in(select value::uuid from jsonb_array_elements_text(p_data->'combustibles'));
   insert into public.estacion_combustible(estacion_id,combustible_id)
   select target,value::uuid from jsonb_array_elements_text(p_data->'combustibles')
   on conflict(estacion_id,combustible_id) do update set activo=true,reactivado_en=case when not estacion_combustible.activo then clock_timestamp() else estacion_combustible.reactivado_en end;
 elsif p_action='station_state' then
   b:=(p_data->>'activo')::boolean;
   update public.estaciones set activo=b,reactivado_en=case when b and not activo then clock_timestamp() else reactivado_en end,actualizado_en=clock_timestamp() where id=target;
   if not found then raise exception 'Estación no encontrada'; end if;
 elsif p_action in ('user_save','user_state','user_role','invite_stage','invite_cancel','invite_renew') then
   select * into p from public.perfiles where id=target for update;
   if p.id is null then raise exception 'Cuenta no encontrada'; end if;
   old_role:=p.rol;
   if p_action='user_save' then
     update public.perfiles set nombre=trim(p_data->>'nombre'),contacto=trim(coalesce(p_data->>'contacto','')) where id=target;
   elsif p_action='user_state' then
     b:=(p_data->>'activo')::boolean;
     if target=u and not b then raise exception 'No puedes desactivar tu propia cuenta'; end if;
     if not b and p.rol='administrador' and p.activo and (select count(*) from public.perfiles z join auth.users au on au.id=z.id where z.rol='administrador' and z.activo and au.email_confirmed_at is not null)<=1 then raise exception 'Debe quedar un administrador activo'; end if;
     update public.perfiles set activo=b where id=target;
   elsif p_action='user_role' then
     role_new:=p_data->>'rol';
     if role_new not in ('administrador','responsable','conductor') or role_new is null then raise exception 'Rol inválido'; end if;
     if target=u and role_new<>'administrador' then raise exception 'No puedes quitarte tu rol administrativo'; end if;
     if p.rol='administrador' and p.activo and role_new<>'administrador' and (select count(*) from public.perfiles z join auth.users au on au.id=z.id where z.rol='administrador' and z.activo and au.email_confirmed_at is not null)<=1 then raise exception 'Debe quedar un administrador activo'; end if;
     if role_new<>p.rol then
       update public.asignaciones_responsables set activo=false,fin=clock_timestamp() where activo and vinculacion_id in(select id from public.vinculaciones_personal where perfil_id=target);
     end if;
     update public.perfiles set rol=role_new,rol_invitado=null,invitacion_vence=null where id=target;
   elsif p_action='invite_renew' then
     if p.rol_invitado is null then raise exception 'No hay invitación pendiente'; end if;
     update public.perfiles set invitacion_vence=clock_timestamp()+interval '7 days' where id=target;
     update public.vinculaciones_personal set vence_en=clock_timestamp()+interval '7 days' where perfil_id=target and activo and aceptada_en is null;
   elsif p_action='invite_cancel' then
     update public.perfiles set rol_invitado=null,invitacion_vence=null where id=target;
     update public.vinculaciones_personal set activo=false,fin=clock_timestamp() where perfil_id=target and activo and aceptada_en is null;
   else
     role_new:=p_data->>'rol';
     if role_new not in ('administrador','responsable') or role_new is null then raise exception 'Rol de personal inválido'; end if;
     if target=u then raise exception 'No puedes invitarte a cambiar de rol'; end if;
     if p.rol='administrador' and role_new='responsable' then raise exception 'El cambio de administrador a responsable requiere Cambiar rol y su confirmación'; end if;
     if role_new='responsable' then
       eid:=(p_data->>'empresa_id')::uuid;
       if not exists(select 1 from public.empresas_operadoras e where e.id=eid and e.activo) then raise exception 'Empresa activa requerida'; end if;
       insert into public.vinculaciones_personal(perfil_id,empresa_id,autorizado_por) values(target,eid,u)
       on conflict(perfil_id,empresa_id) where activo do update set vence_en=case when vinculaciones_personal.aceptada_en is null then clock_timestamp()+interval '7 days' else vinculaciones_personal.vence_en end;
     end if;
     update public.perfiles set rol_invitado=role_new,invitado_en=clock_timestamp(),invitacion_vence=clock_timestamp()+interval '7 days' where id=target;
   end if;
 elsif p_action='membership_end' then
   select * into v from public.vinculaciones_personal where id=target for update;
   if v.id is null then raise exception 'Vinculación no encontrada'; end if;
   update public.vinculaciones_personal set activo=false,fin=clock_timestamp() where id=target;
   update public.asignaciones_responsables set activo=false,fin=clock_timestamp() where vinculacion_id=target and activo;
 elsif p_action='assignment_add' then
   select * into v from public.vinculaciones_personal where id=(p_data->>'vinculacion_id')::uuid;
   select * into t from public.estaciones where id=(p_data->>'estacion_id')::uuid;
   if v.id is null or t.id is null or not v.activo or v.fin is not null or v.aceptada_en is null or not t.activo or v.empresa_id<>t.empresa_id
   or not exists(select 1 from public.empresas_operadoras e where e.id=v.empresa_id and e.activo)
   or not exists(select 1 from public.perfiles z join auth.users au on au.id=z.id where z.id=v.perfil_id and z.activo and z.rol='responsable' and au.email_confirmed_at is not null)
   then raise exception 'La persona, empresa, vinculación y estación deben estar habilitadas y pertenecer a la misma empresa'; end if;
   insert into public.asignaciones_responsables(id,vinculacion_id,estacion_id,asignado_por) values(target,v.id,t.id,u) on conflict(id) do nothing;
 elsif p_action='assignment_end' then
   select * into a from public.asignaciones_responsables where id=target;
   if a.id is null then raise exception 'Asignación no encontrada'; end if;
   update public.asignaciones_responsables set activo=false,fin=clock_timestamp() where id=target;
 else raise exception 'Operación desconocida';
 end if;
 return jsonb_build_object('ok',true,'id',target);
end $$;



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

 end if;
 raise exception 'Consulta desconocida';
end $$;



create or replace function private.fc_auth_profile() returns trigger language plpgsql security definer set search_path='' as $$
declare n text;
begin
 n:=trim(coalesce(new.raw_user_meta_data->>'nombre',''));
 if length(n)<2 or length(n)>100 then raise exception 'Nombre requerido: entre 2 y 100 caracteres'; end if;
 insert into public.perfiles(id,nombre,rol) values(new.id,left(n,100),'conductor');
 return new;
end $$;



alter table public.auditoria_cuentas set schema historico_sprint2;
revoke all on historico_sprint2.auditoria_cuentas from public,anon,authenticated;
notify pgrst,'reload schema';
commit;
