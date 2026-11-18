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
   on conflict(perfil_id,estacion_id) do update set activo=excluded.activo,actualizado_en=now();
   return jsonb_build_object('ok',true);
 elsif p_action='invitation_reply' then
   b:=(p_data->>'accept')::boolean;
   if nullif(p_data->>'id','') is not null then
     select * into v from public.vinculaciones_personal where id=(p_data->>'id')::uuid and perfil_id=u and activo and aceptada_en is null and vence_en>now() for update;
     if v.id is null then raise exception 'Invitación vencida o cancelada'; end if;
     if b and not exists(select 1 from public.empresas_operadoras e where e.id=v.empresa_id and e.activo) then raise exception 'Empresa no disponible'; end if;
     update public.vinculaciones_personal set aceptada_en=case when b then now() end,activo=b,fin=case when not b then now() end where id=v.id;
     if b then update public.perfiles set rol='responsable',rol_invitado=null,invitacion_vence=null where id=u and rol='conductor'; end if;
   else
     select * into p from public.perfiles where id=u and rol_invitado is not null and invitacion_vence>now() for update;
     if p.id is null then raise exception 'Invitación vencida o cancelada'; end if;
     if b and p.rol_invitado='responsable' and not exists(select 1 from public.vinculaciones_personal x where x.perfil_id=u and x.activo and x.aceptada_en is not null) then raise exception 'Primero acepta la vinculación empresarial'; end if;
     update public.perfiles set rol=case when b then rol_invitado else rol end,rol_invitado=null,invitacion_vence=null where id=u;
   end if;
   insert into public.auditoria_cuentas(cuenta_afectada_id,actor_id,accion) values(u,u,case when b then 'invitacion_aceptada' else 'invitacion_rechazada' end);
   return jsonb_build_object('ok',true);
 elsif p_action='publish' then
   target:=(p_data->>'id')::uuid;operation:=(p_data->>'operation')::uuid;
   if not coalesce(private.fc_assigned(target),false) then raise exception 'No tienes una asignación vigente para esta estación'; end if;
   if jsonb_typeof(p_data->'changes') is distinct from 'array' or jsonb_array_length(p_data->'changes')=0 then raise exception 'Selecciona al menos un combustible'; end if;
   if exists(select 1 from jsonb_array_elements(p_data->'changes') x where x->>'estado' not in ('disponible','limitada','agotado') or x->>'estado' is null
     or not exists(select 1 from public.estacion_combustible ec join public.combustibles f on f.id=ec.combustible_id where ec.estacion_id=target and ec.combustible_id=(x->>'id')::uuid and ec.activo and f.activo)) then raise exception 'Combustible o estado inválido'; end if;
   if (select count(*)<>count(distinct x->>'id') from jsonb_array_elements(p_data->'changes') x) then raise exception 'Combustible duplicado'; end if;
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
   update public.empresas_operadoras set activo=b,reactivado_en=case when b and not activo then now() else reactivado_en end where id=target;
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
   on conflict(id) do update set empresa_id=excluded.empresa_id,ciudad_id=excluded.ciudad_id,nombre=excluded.nombre,direccion=excluded.direccion,licencia=excluded.licencia,fuente_url=excluded.fuente_url,actualizado_en=now();
   update public.estacion_combustible set activo=false where estacion_id=target and combustible_id not in(select value::uuid from jsonb_array_elements_text(p_data->'combustibles'));
   insert into public.estacion_combustible(estacion_id,combustible_id)
   select target,value::uuid from jsonb_array_elements_text(p_data->'combustibles')
   on conflict(estacion_id,combustible_id) do update set activo=true,reactivado_en=case when not estacion_combustible.activo then now() else estacion_combustible.reactivado_en end;
 elsif p_action='station_state' then
   b:=(p_data->>'activo')::boolean;
   update public.estaciones set activo=b,reactivado_en=case when b and not activo then now() else reactivado_en end,actualizado_en=now() where id=target;
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
       update public.asignaciones_responsables set activo=false,fin=now() where activo and vinculacion_id in(select id from public.vinculaciones_personal where perfil_id=target);
     end if;
     update public.perfiles set rol=role_new,rol_invitado=null,invitacion_vence=null where id=target;
   elsif p_action='invite_renew' then
     if p.rol_invitado is null then raise exception 'No hay invitación pendiente'; end if;
     update public.perfiles set invitacion_vence=now()+interval '7 days' where id=target;
     update public.vinculaciones_personal set vence_en=now()+interval '7 days' where perfil_id=target and activo and aceptada_en is null;
   elsif p_action='invite_cancel' then
     update public.perfiles set rol_invitado=null,invitacion_vence=null where id=target;
     update public.vinculaciones_personal set activo=false,fin=now() where perfil_id=target and activo and aceptada_en is null;
   else
     role_new:=p_data->>'rol';
     if role_new not in ('administrador','responsable') or role_new is null then raise exception 'Rol de personal inválido'; end if;
     if target=u then raise exception 'No puedes invitarte a cambiar de rol'; end if;
     if p.rol='administrador' and role_new='responsable' then raise exception 'El cambio de administrador a responsable requiere Cambiar rol y su confirmación'; end if;
     if role_new='responsable' then
       eid:=(p_data->>'empresa_id')::uuid;
       if not exists(select 1 from public.empresas_operadoras e where e.id=eid and e.activo) then raise exception 'Empresa activa requerida'; end if;
       insert into public.vinculaciones_personal(perfil_id,empresa_id,autorizado_por) values(target,eid,u)
       on conflict(perfil_id,empresa_id) where activo do update set vence_en=case when vinculaciones_personal.aceptada_en is null then now()+interval '7 days' else vinculaciones_personal.vence_en end;
     end if;
     update public.perfiles set rol_invitado=role_new,invitado_en=now(),invitacion_vence=now()+interval '7 days' where id=target;
   end if;
   insert into public.auditoria_cuentas(cuenta_afectada_id,actor_id,accion,detalle)
   values(target,u,p_action,jsonb_build_object('rol_anterior',old_role,'rol_nuevo',(select rol from public.perfiles where id=target),'activo',(select activo from public.perfiles where id=target)));
 elsif p_action='membership_end' then
   select * into v from public.vinculaciones_personal where id=target for update;
   if v.id is null then raise exception 'Vinculación no encontrada'; end if;
   update public.vinculaciones_personal set activo=false,fin=now() where id=target;
   update public.asignaciones_responsables set activo=false,fin=now() where vinculacion_id=target and activo;
   insert into public.auditoria_cuentas(cuenta_afectada_id,actor_id,accion,detalle) values(v.perfil_id,u,p_action,jsonb_build_object('vinculacion',target));
 elsif p_action='assignment_add' then
   select * into v from public.vinculaciones_personal where id=(p_data->>'vinculacion_id')::uuid;
   select * into t from public.estaciones where id=(p_data->>'estacion_id')::uuid;
   if v.id is null or t.id is null or not v.activo or v.fin is not null or v.aceptada_en is null or not t.activo or v.empresa_id<>t.empresa_id
   or not exists(select 1 from public.empresas_operadoras e where e.id=v.empresa_id and e.activo)
   or not exists(select 1 from public.perfiles z join auth.users au on au.id=z.id where z.id=v.perfil_id and z.activo and z.rol='responsable' and au.email_confirmed_at is not null)
   then raise exception 'La persona, empresa, vinculación y estación deben estar habilitadas y pertenecer a la misma empresa'; end if;
   insert into public.asignaciones_responsables(id,vinculacion_id,estacion_id,asignado_por) values(target,v.id,t.id,u) on conflict(id) do nothing;
   insert into public.auditoria_cuentas(cuenta_afectada_id,actor_id,accion,detalle) values(v.perfil_id,u,p_action,jsonb_build_object('estacion',t.id));
 elsif p_action='assignment_end' then
   select * into a from public.asignaciones_responsables where id=target;
   if a.id is null then raise exception 'Asignación no encontrada'; end if;
   update public.asignaciones_responsables set activo=false,fin=now() where id=target;
   insert into public.auditoria_cuentas(cuenta_afectada_id,actor_id,accion,detalle) select perfil_id,u,p_action,jsonb_build_object('asignacion',target) from public.vinculaciones_personal where id=a.vinculacion_id;
 else raise exception 'Operación desconocida';
 end if;
 return jsonb_build_object('ok',true,'id',target);
end $$;

create or replace function private.fc_auth_profile() returns trigger language plpgsql security definer set search_path='' as $$
declare n text;
begin
 n:=trim(coalesce(new.raw_user_meta_data->>'nombre',''));
 if length(n)<2 or length(n)>100 then raise exception 'Nombre requerido: entre 2 y 100 caracteres'; end if;
 insert into public.perfiles(id,nombre,rol) values(new.id,left(n,100),'conductor');
 insert into public.auditoria_cuentas(cuenta_afectada_id,actor_id,accion) values(new.id,new.id,'cuenta_creada');
 return new;
end $$;


do $$declare t text;begin
 foreach t in array array['perfiles','empresas_operadoras','ciudades','estaciones','combustibles','estacion_combustible','vinculaciones_personal','asignaciones_responsables','historial_disponibilidad','favoritas','auditoria_cuentas'] loop
 execute format('create policy solo_operaciones_autorizadas on public.%I for all to anon,authenticated using(false) with check(false)',t);
 end loop;
end $$;

notify pgrst,'reload schema';
commit;
