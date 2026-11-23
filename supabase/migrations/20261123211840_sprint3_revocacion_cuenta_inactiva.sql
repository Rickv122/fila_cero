-- Allow logout after deactivation without allowing other inactive-account actions.
begin;
CREATE OR REPLACE FUNCTION private.fc3_command(p_action text, p_data jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid();r text:=private.fc_role();s uuid;f uuid;v boolean;lat double precision;lon double precision;sid uuid;did uuid;
begin
 -- A person can revoke their own device even after account deactivation.
 if p_action='device_disable' then
  if u is null then raise exception 'Inicia sesión para revocar el dispositivo' using errcode='42501';end if;
  update public.dispositivos_notificaciones set activo=false,actualizado_en=now()
   where perfil_id=u and identificador_firebase=p_data->>'identificador';
  return jsonb_build_object('ok',true);
 end if;
 if r is null then raise exception 'Inicia sesión con una cuenta activa' using errcode='42501'; end if;
 if p_action='preferences_save' then
  f:=(p_data->>'combustible_id')::uuid;
  if not exists(select 1 from public.combustibles where id=f and activo) then raise exception 'Selecciona un combustible activo' using errcode='22023';end if;
  if (p_data->>'distancia_maxima_km')::integer not in (5,10,20) or p_data->>'distancia_maxima_km' is null then raise exception 'Elige una distancia de 5, 10 o 20 km' using errcode='22023';end if;
  insert into public.preferencias_conductor(perfil_id,combustible_id,distancia_maxima_km) values(u,f,(p_data->>'distancia_maxima_km')::integer)
  on conflict(perfil_id) do update set combustible_id=excluded.combustible_id,distancia_maxima_km=excluded.distancia_maxima_km,actualizado_en=now();
  return private.fc3_query('preferences','{}');
 elsif p_action='station_save_location' then
  if r<>'administrador' then raise exception 'Acceso administrativo requerido' using errcode='42501';end if;
  perform private.fc_command('station_save',p_data);
  if p_data ? 'latitud' or p_data ? 'longitud' then perform private.fc3_command('location_save',p_data);end if;
  return private.fc3_location((p_data->>'id')::uuid);
 elsif p_action='location_save' then
  if r<>'administrador' then raise exception 'Acceso administrativo requerido' using errcode='42501';end if;
  s:=(p_data->>'id')::uuid;lat:=(p_data->>'latitud')::double precision;lon:=(p_data->>'longitud')::double precision;
  if lat is null or lon is null or not(lat between -90 and 90 and lon between -180 and 180) then raise exception 'Selecciona una ubicación válida' using errcode='22023';end if;
  if length(trim(coalesce(p_data->>'direccion','')))<3 then raise exception 'Revisa la dirección de la estación' using errcode='22023';end if;
  update public.estaciones set latitud=lat,longitud=lon,ubicacion_confirmada_en=now(),ubicacion_confirmada_por=u,
   direccion=trim(p_data->>'direccion'),actualizado_en=now() where id=s;
  if not found then raise exception 'La estación no existe' using errcode='22023';end if;
  return private.fc3_location(s);
 elsif p_action='device_register' then
  sid:=nullif(auth.jwt()->>'session_id','')::uuid;
  if sid is null then raise exception 'Se requiere una sesión de usuario' using errcode='42501';end if;
  if length(coalesce(p_data->>'identificador','')) not between 16 and 4096 or p_data->>'plataforma' not in ('android','ios') or p_data->>'tipo' not in ('fid','token') then raise exception 'Dispositivo no válido' using errcode='22023';end if;
  insert into public.dispositivos_notificaciones(perfil_id,identificador_firebase,tipo_identificador,plataforma,sesion_id)
  values(u,p_data->>'identificador',p_data->>'tipo',p_data->>'plataforma',sid)
  on conflict(identificador_firebase) do update set perfil_id=u,tipo_identificador=excluded.tipo_identificador,plataforma=excluded.plataforma,
  sesion_id=sid,activo=true,actualizado_en=now() returning id into did;
  return jsonb_build_object('id',did);
 elsif p_action='subscription_save' then
  s:=(p_data->>'id')::uuid;v:=(p_data->>'activo')::boolean;
  if v is null then raise exception 'Selecciona el estado de los avisos' using errcode='22023';end if;
  if v then
   if not exists(select 1 from public.preferencias_conductor p join public.combustibles b on b.id=p.combustible_id and b.activo where p.perfil_id=u) then raise exception 'Configura primero tu combustible' using errcode='22023';end if;
   if not exists(select 1 from public.dispositivos_notificaciones d where d.perfil_id=u and d.activo and d.sesion_id=nullif(auth.jwt()->>'session_id','')::uuid) then raise exception 'Activa el permiso de notificaciones en este teléfono' using errcode='22023';end if;
   if not exists(select 1 from public.favoritas a join public.estaciones t on t.id=a.estacion_id and t.activo join public.empresas_operadoras e on e.id=t.empresa_id and e.activo where a.perfil_id=u and a.estacion_id=s and a.activo) then raise exception 'Guarda una estación activa en tus favoritas' using errcode='22023';end if;
  end if;
  if not exists(select 1 from public.favoritas a where a.perfil_id=u and a.estacion_id=s) then raise exception 'La estación no está en tus favoritas' using errcode='22023';end if;
  insert into public.suscripciones_disponibilidad(perfil_id,estacion_id,activo) values(u,s,v)
   on conflict(perfil_id,estacion_id) do update set activo=excluded.activo,actualizado_en=now();
  return jsonb_build_object('ok',true);
 end if;
 raise exception 'Operación desconocida' using errcode='22023';
end $function$;
commit;
