-- Sprint 3 adds preferences, confirmed locations and a transactional push outbox.
-- Existing catalogue, identities and historical publications are preserved.
begin;

alter table public.estaciones add column latitud double precision;
alter table public.estaciones add column longitud double precision;
alter table public.estaciones add column ubicacion_confirmada_en timestamptz;
alter table public.estaciones add column ubicacion_confirmada_por uuid references public.perfiles(id);
alter table public.estaciones add constraint estaciones_ubicacion_valida check (
 (latitud is null and longitud is null and ubicacion_confirmada_en is null and ubicacion_confirmada_por is null)
 or (latitud between -90 and 90 and longitud between -180 and 180 and latitud is not null and longitud is not null
 and ubicacion_confirmada_en is not null and ubicacion_confirmada_por is not null));

create table public.preferencias_conductor (
 perfil_id uuid primary key references public.perfiles(id),
 combustible_id uuid not null references public.combustibles(id),
 distancia_maxima_km integer not null check(distancia_maxima_km in (5,10,20)),
 actualizado_en timestamptz not null default now()
);
create table public.suscripciones_disponibilidad (
 perfil_id uuid not null,
 estacion_id uuid not null,
 activo boolean not null default true,
 actualizado_en timestamptz not null default now(),
 primary key(perfil_id,estacion_id),
 foreign key(perfil_id,estacion_id) references public.favoritas(perfil_id,estacion_id)
);
create table public.dispositivos_notificaciones (
 id uuid primary key default gen_random_uuid(),
 perfil_id uuid not null references public.perfiles(id),
 identificador_firebase text not null unique check(length(identificador_firebase) between 16 and 4096),
 tipo_identificador text not null default 'fid' check(tipo_identificador in ('fid','token')),
 plataforma text not null check(plataforma in ('android','ios')),
 sesion_id uuid not null,
 activo boolean not null default true,
 actualizado_en timestamptz not null default now()
);
create index dispositivos_notificaciones_perfil_idx on public.dispositivos_notificaciones(perfil_id) where activo;
create table public.cola_notificaciones (
 id uuid primary key default gen_random_uuid(),
 historial_id uuid not null references public.historial_disponibilidad(id),
 perfil_id uuid not null references public.perfiles(id),
 dispositivo_id uuid not null references public.dispositivos_notificaciones(id),
 estado text not null default 'pendiente' check(estado in ('pendiente','enviando','enviado','cancelado','fallido')),
 intentos integer not null default 0,
 disponible_en timestamptz not null default now(),
 bloqueo_hasta timestamptz,
 bloqueo_id uuid,
 respuesta_proveedor text,
 ultimo_error text,
 creado_en timestamptz not null default now(),
 actualizado_en timestamptz not null default now(),
 unique(historial_id,perfil_id,dispositivo_id)
);
create index cola_notificaciones_pendientes_idx on public.cola_notificaciones(disponible_en) where estado in ('pendiente','enviando');
create index cola_notificaciones_historial_idx on public.cola_notificaciones(historial_id);
create index preferencias_conductor_combustible_idx on public.preferencias_conductor(combustible_id);
create index suscripciones_disponibilidad_estacion_idx on public.suscripciones_disponibilidad(estacion_id) where activo;
create index dispositivos_notificaciones_sesion_idx on public.dispositivos_notificaciones(sesion_id);
create index estaciones_ubicacion_autor_idx on public.estaciones(ubicacion_confirmada_por);
create index cola_notificaciones_perfil_idx on public.cola_notificaciones(perfil_id);
create index cola_notificaciones_dispositivo_idx on public.cola_notificaciones(dispositivo_id);

alter table public.preferencias_conductor enable row level security;
alter table public.suscripciones_disponibilidad enable row level security;
alter table public.dispositivos_notificaciones enable row level security;
alter table public.cola_notificaciones enable row level security;
revoke all on public.preferencias_conductor,public.suscripciones_disponibilidad,public.dispositivos_notificaciones,public.cola_notificaciones from public,anon,authenticated;
grant all on public.preferencias_conductor,public.suscripciones_disponibilidad,public.dispositivos_notificaciones,public.cola_notificaciones to service_role;

create function private.fc3_location(s uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',t.id,'nombre',t.nombre,'direccion',t.direccion,'ciudad',c.nombre,
 'latitud',t.latitud,'longitud',t.longitud,'ubicacion_confirmada_en',t.ubicacion_confirmada_en,
 'station',private.fc_station(t.id))
 from public.estaciones t join public.empresas_operadoras e on e.id=t.empresa_id join public.ciudades c on c.id=t.ciudad_id
 where t.id=s and ((t.activo and e.activo) or private.fc_role()='administrador');
$$;

grant usage on schema private to service_role;

create function private.fc3_query(p_resource text,p_params jsonb) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid(); r text:=private.fc_role(); result jsonb; fuel uuid;
begin
 if p_resource='location' then return private.fc3_location((p_params->>'id')::uuid); end if;
 if r is null then raise exception 'Inicia sesión con una cuenta activa' using errcode='42501'; end if;
 if p_resource='preferences' then
   select to_jsonb(p)||jsonb_build_object('combustible',b.nombre,'combustible_activo',b.activo)
   into result from public.preferencias_conductor p join public.combustibles b on b.id=p.combustible_id where p.perfil_id=u;
   return result;
 elsif p_resource='subscriptions' then
   select coalesce(jsonb_agg(jsonb_build_object('id',f.estacion_id,'nombre',t.nombre,'empresa',e.denominacion,
     'disponible',t.activo and e.activo,'activo',coalesce(s.activo,false)) order by t.nombre),'[]') into result
   from public.favoritas f join public.estaciones t on t.id=f.estacion_id join public.empresas_operadoras e on e.id=t.empresa_id
   left join public.suscripciones_disponibilidad s on s.perfil_id=f.perfil_id and s.estacion_id=f.estacion_id
   where f.perfil_id=u and f.activo;
   return result;
 elsif p_resource='recommendation_candidates' then
   select p.combustible_id into fuel from public.preferencias_conductor p join public.combustibles b on b.id=p.combustible_id and b.activo where p.perfil_id=u;
   if fuel is null then raise exception 'Elige tu combustible en Preferencias' using errcode='22023'; end if;
   select coalesce(jsonb_agg(x.obj order by x.nombre),'[]') into result from (
    select t.nombre,private.fc3_location(t.id)||jsonb_build_object('combustible_id',fuel,'combustible',b.nombre,
     'estado',h.estado,'registrado_en',h.registrado_en) obj
    from public.estaciones t join public.empresas_operadoras e on e.id=t.empresa_id
    join public.estacion_combustible ec on ec.estacion_id=t.id and ec.combustible_id=fuel and ec.activo
    join public.combustibles b on b.id=ec.combustible_id and b.activo
    join lateral(select x.estado,x.registrado_en from public.historial_disponibilidad x where x.estacion_combustible_id=ec.id order by x.registrado_en desc,x.id desc limit 1)h on true
    where t.activo and e.activo and t.ubicacion_confirmada_en is not null
      and h.estado in ('disponible','limitada') and h.registrado_en>now()-interval '2 hours'
      and h.registrado_en>greatest(t.reactivado_en,e.reactivado_en,ec.reactivado_en,b.reactivado_en)
   )x;
   return jsonb_build_object('preferences',private.fc3_query('preferences','{}'),'stations',result);
 end if;
 raise exception 'Consulta desconocida' using errcode='22023';
end $$;

create function private.fc3_command(p_action text,p_data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();r text:=private.fc_role();s uuid;f uuid;v boolean;lat double precision;lon double precision;sid uuid;did uuid;
begin
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
 elsif p_action='device_disable' then
  update public.dispositivos_notificaciones set activo=false,actualizado_en=now() where perfil_id=u and identificador_firebase=p_data->>'identificador';
  return jsonb_build_object('ok',true);
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
end $$;

create function private.fc3_enqueue_notification() returns trigger language plpgsql security definer set search_path='' as $$
declare st public.estaciones;co public.empresas_operadoras;ec public.estacion_combustible;b public.combustibles;previous public.historial_disponibilidad;
begin
 if new.estado<>'disponible' then return new;end if;
 select * into ec from public.estacion_combustible where id=new.estacion_combustible_id;
 select * into st from public.estaciones where id=ec.estacion_id;
 select * into co from public.empresas_operadoras where id=st.empresa_id;
 select * into b from public.combustibles where id=ec.combustible_id;
 if not(st.activo and co.activo and ec.activo and b.activo) then return new;end if;
 select * into previous from public.historial_disponibilidad h where h.estacion_combustible_id=ec.id and h.id<>new.id
 and (h.registrado_en,h.id)<(new.registrado_en,new.id) order by h.registrado_en desc,h.id desc limit 1;
 if previous.estado='disponible' and previous.registrado_en>new.registrado_en-interval '2 hours'
  and previous.registrado_en>greatest(st.reactivado_en,co.reactivado_en,ec.reactivado_en,b.reactivado_en) then return new;end if;
 insert into public.cola_notificaciones(historial_id,perfil_id,dispositivo_id)
 select new.id,p.id,d.id from public.suscripciones_disponibilidad s
 join public.perfiles p on p.id=s.perfil_id and p.activo
 join public.preferencias_conductor pf on pf.perfil_id=p.id and pf.combustible_id=ec.combustible_id
 join public.favoritas f on f.perfil_id=p.id and f.estacion_id=st.id and f.activo
 join public.dispositivos_notificaciones d on d.perfil_id=p.id and d.activo
 join auth.sessions a on a.id=d.sesion_id and a.user_id=p.id
 where s.estacion_id=st.id and s.activo
 on conflict(historial_id,perfil_id,dispositivo_id) do nothing;
 return new;
end $$;
create trigger fc3_publicacion_aviso after insert on public.historial_disponibilidad for each row execute function private.fc3_enqueue_notification();

-- A removed favourite revokes the alert. Restoring it does not silently opt in.
create function private.fc3_favorite_alert() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if not new.activo then update public.suscripciones_disponibilidad set activo=false,actualizado_en=now() where perfil_id=new.perfil_id and estacion_id=new.estacion_id;end if;
 return new;
end $$;
create trigger fc3_favorita_aviso after update of activo on public.favoritas for each row execute function private.fc3_favorite_alert();

create function public.fc3_query(p_resource text,p_params jsonb default '{}'::jsonb) returns jsonb
language sql stable security invoker set search_path='' as $$select private.fc3_query(p_resource,p_params)$$;
create function public.fc3_command(p_action text,p_data jsonb default '{}'::jsonb) returns jsonb
language sql security invoker set search_path='' as $$select private.fc3_command(p_action,p_data)$$;
revoke all on function public.fc3_query(text,jsonb),public.fc3_command(text,jsonb) from public,anon;
grant execute on function public.fc3_query(text,jsonb) to anon,authenticated;
grant execute on function public.fc3_command(text,jsonb) to authenticated;
revoke all on function private.fc3_query(text,jsonb),private.fc3_command(text,jsonb),private.fc3_location(uuid),private.fc3_enqueue_notification(),private.fc3_favorite_alert() from public,anon,authenticated;
grant execute on function private.fc3_query(text,jsonb) to anon,authenticated;
grant execute on function private.fc3_command(text,jsonb) to authenticated;

-- The server worker claims rows with a lease; a failed send never rolls back a publication.
create function private.fc3_push_claim(p_limit integer default 20) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if (auth.jwt()->>'role') is distinct from 'service_role' then raise exception 'Servicio requerido' using errcode='42501';end if;
 update public.cola_notificaciones set estado='cancelado',actualizado_en=now()
 where estado in ('pendiente','enviando') and not exists(
  select 1 from public.historial_disponibilidad h
  join public.estacion_combustible ec on ec.id=h.estacion_combustible_id and ec.activo
  join public.combustibles b on b.id=ec.combustible_id and b.activo
  join public.estaciones t on t.id=ec.estacion_id and t.activo
  join public.empresas_operadoras e on e.id=t.empresa_id and e.activo
  join public.perfiles p on p.id=cola_notificaciones.perfil_id and p.activo
  join public.preferencias_conductor pf on pf.perfil_id=p.id and pf.combustible_id=b.id
  join public.favoritas f on f.perfil_id=p.id and f.estacion_id=t.id and f.activo
  join public.suscripciones_disponibilidad s on s.perfil_id=p.id and s.estacion_id=t.id and s.activo
  join public.dispositivos_notificaciones d on d.id=cola_notificaciones.dispositivo_id and d.perfil_id=p.id and d.activo
  join auth.sessions a on a.id=d.sesion_id and a.user_id=p.id
  join lateral(select x.id,x.estado,x.registrado_en from public.historial_disponibilidad x where x.estacion_combustible_id=ec.id order by x.registrado_en desc,x.id desc limit 1) last on true
  where h.id=cola_notificaciones.historial_id and h.estado='disponible' and last.estado='disponible'
  and last.registrado_en>now()-interval '2 hours' and last.registrado_en>greatest(t.reactivado_en,e.reactivado_en,ec.reactivado_en,b.reactivado_en)
 );
 with selected as (
  select q.id from public.cola_notificaciones q where q.intentos<5 and q.disponible_en<=now()
  and (q.estado='pendiente' or (q.estado='enviando' and q.bloqueo_hasta<now()))
  order by q.creado_en for update skip locked limit least(greatest(p_limit,1),50)
 ), claimed as (
  update public.cola_notificaciones q set estado='enviando',intentos=intentos+1,bloqueo_hasta=now()+interval '2 minutes',bloqueo_id=gen_random_uuid(),actualizado_en=now()
  from selected where q.id=selected.id returning q.*
 )
 select coalesce(jsonb_agg(jsonb_build_object('id',q.id,'bloqueo_id',q.bloqueo_id,'dispositivo_id',d.id,
 'identificador',d.identificador_firebase,'tipo',d.tipo_identificador,'estacion_id',t.id,
 'titulo',t.nombre,'cuerpo',b.nombre||' está disponible según la nueva publicación del responsable.','historial_id',h.id)),'[]') into result
 from claimed q join public.dispositivos_notificaciones d on d.id=q.dispositivo_id
 join public.historial_disponibilidad h on h.id=q.historial_id join public.estacion_combustible ec on ec.id=h.estacion_combustible_id
 join public.estaciones t on t.id=ec.estacion_id join public.combustibles b on b.id=ec.combustible_id;
 return result;
end $$;
revoke all on function private.fc3_push_claim(integer) from public,anon,authenticated;
grant execute on function private.fc3_push_claim(integer) to service_role;
create function public.fc3_push_claim(p_limit integer default 20) returns jsonb
language sql security invoker set search_path='' as $$select private.fc3_push_claim(p_limit)$$;
create function public.fc3_push_complete(p_id uuid,p_bloqueo uuid,p_success boolean,p_invalid_device boolean default false,p_message text default null) returns void
language plpgsql security invoker set search_path='' as $$
begin
 if current_user<>'service_role' then raise exception 'Servicio requerido' using errcode='42501';end if;
 if p_invalid_device then
  update public.dispositivos_notificaciones set activo=false,actualizado_en=now() where id=(select dispositivo_id from public.cola_notificaciones where id=p_id and bloqueo_id=p_bloqueo);
 end if;
 update public.cola_notificaciones set estado=case when p_success then 'enviado' when p_invalid_device then 'cancelado' when intentos>=5 then 'fallido' else 'pendiente' end,
  respuesta_proveedor=case when p_success then left(p_message,300) else respuesta_proveedor end,
  ultimo_error=case when p_success then null else left(p_message,300) end,
  disponible_en=now()+least(intentos*interval '1 minute',interval '10 minutes'),bloqueo_hasta=null,bloqueo_id=null,actualizado_en=now()
 where id=p_id and bloqueo_id=p_bloqueo and estado='enviando';
end $$;
revoke all on function public.fc3_push_claim(integer),public.fc3_push_complete(uuid,uuid,boolean,boolean,text) from public,anon,authenticated;
grant execute on function public.fc3_push_claim(integer),public.fc3_push_complete(uuid,uuid,boolean,boolean,text) to service_role;

commit;
