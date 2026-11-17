-- Revised Sprint 2. Previous rows are retained outside the exposed API schema.
begin;
create schema if not exists historico_sprint2;
revoke all on schema historico_sprint2 from public,anon,authenticated;
alter table public.perfiles set schema historico_sprint2;
alter table public.surtidores set schema historico_sprint2;
alter table public.combustibles set schema historico_sprint2;
alter table public.surtidor_combustible set schema historico_sprint2;
alter table public.asignaciones_encargado set schema historico_sprint2;
alter table public.historial_disponibilidad set schema historico_sprint2;
revoke all on all tables in schema historico_sprint2 from public,anon,authenticated;
drop function public.consultar_gasolineras(text,text,uuid,boolean,boolean,integer);
drop function public.actualizar_disponibilidad(uuid,jsonb);
drop function public.asignar_encargado(uuid,uuid,boolean);
drop function public.cambiar_estado_surtidor(uuid,boolean);
drop function public.guardar_surtidor(uuid,text,text,text,double precision,double precision,uuid[]);
revoke all on all functions in schema private from public,anon,authenticated;

create sequence private.perfil_codigo;
create sequence private.empresa_codigo;
create sequence private.estacion_codigo;
create table public.perfiles (
 id uuid primary key references auth.users(id) on delete restrict,
 codigo text not null unique default ('PER-'||lpad(nextval('private.perfil_codigo')::text,4,'0')),
 nombre text not null check(length(trim(nombre)) between 2 and 100),
 contacto text not null default '' check(length(contacto)<=100),
 rol text not null default 'conductor' check(rol in ('administrador','responsable','conductor')),
 activo boolean not null default true,
 rol_invitado text check(rol_invitado in ('administrador','responsable')),
 invitado_en timestamptz, invitacion_vence timestamptz,
 creado_en timestamptz not null default now()
);
create table public.empresas_operadoras (
 id uuid primary key default gen_random_uuid(),
 codigo text not null unique default ('EMP-'||lpad(nextval('private.empresa_codigo')::text,4,'0')),
 denominacion text not null check(length(trim(denominacion)) between 2 and 160),
 fuente_url text not null default '', verificado_en date,
 activo boolean not null default true, reactivado_en timestamptz not null default now(),
 creado_en timestamptz not null default now()
);
create unique index empresa_denominacion_unique on public.empresas_operadoras(lower(trim(denominacion)));
create table public.ciudades (
 id uuid primary key default gen_random_uuid(), nombre text not null,
 departamento text not null,activo boolean not null default true,unique(departamento,nombre)
);
create table public.estaciones (
 id uuid primary key default gen_random_uuid(),
 codigo text not null unique default ('EST-'||lpad(nextval('private.estacion_codigo')::text,4,'0')),
 empresa_id uuid not null references public.empresas_operadoras,
 ciudad_id uuid not null references public.ciudades,
 nombre text not null check(length(trim(nombre)) between 2 and 120),
 direccion text not null check(length(trim(direccion)) between 4 and 240),
 licencia text not null default '', fuente_url text not null default '',
 activo boolean not null default true, reactivado_en timestamptz not null default now(),
 creado_en timestamptz not null default now(), actualizado_en timestamptz not null default now(),
 unique(empresa_id,nombre,direccion)
);
create table public.combustibles (
 id uuid primary key default gen_random_uuid(),nombre text not null unique,
 activo boolean not null default true,reactivado_en timestamptz not null default now()
);
create table public.estacion_combustible (
 id uuid primary key default gen_random_uuid(),
 estacion_id uuid not null references public.estaciones,
 combustible_id uuid not null references public.combustibles,
 activo boolean not null default true,reactivado_en timestamptz not null default now(),
 unique(estacion_id,combustible_id)
);
create table public.vinculaciones_personal (
 id uuid primary key default gen_random_uuid(),perfil_id uuid not null references public.perfiles,
 empresa_id uuid not null references public.empresas_operadoras,
 inicio timestamptz not null default now(),fin timestamptz,
 aceptada_en timestamptz, vence_en timestamptz not null default (now()+interval '7 days'),
 activo boolean not null default true,autorizado_por uuid not null references public.perfiles,
 check(fin is null or fin>=inicio)
);
create unique index vinculacion_unica_vigente on public.vinculaciones_personal(perfil_id,empresa_id) where activo;
create table public.asignaciones_responsables (
 id uuid primary key default gen_random_uuid(),vinculacion_id uuid not null references public.vinculaciones_personal,
 estacion_id uuid not null references public.estaciones,inicio timestamptz not null default now(),fin timestamptz,
 activo boolean not null default true,asignado_por uuid not null references public.perfiles,
 check(fin is null or fin>=inicio)
);
create unique index asignacion_unica_vigente on public.asignaciones_responsables(vinculacion_id,estacion_id) where activo;
create table public.historial_disponibilidad (
 id uuid primary key default gen_random_uuid(),
 estacion_combustible_id uuid not null references public.estacion_combustible,
 autor_perfil_id uuid not null references public.perfiles,
 estado text not null check(estado in ('disponible','limitada','agotado')),
 registrado_en timestamptz not null default now(),
 operacion_id uuid not null,
 unique(operacion_id,estacion_combustible_id)
);
create table public.favoritas (
 perfil_id uuid not null references public.perfiles,estacion_id uuid not null references public.estaciones,
 activo boolean not null default true,creado_en timestamptz not null default now(),actualizado_en timestamptz not null default now(),
 primary key(perfil_id,estacion_id)
);
create table public.auditoria_cuentas (
 id uuid primary key default gen_random_uuid(),cuenta_afectada_id uuid not null references public.perfiles,
 actor_id uuid references public.perfiles,accion text not null,
 registrado_en timestamptz not null default now(),detalle jsonb not null default '{}'
);
create index estaciones_empresa_idx on public.estaciones(empresa_id);
create index estaciones_ciudad_idx on public.estaciones(ciudad_id);
create index ec_combustible_idx on public.estacion_combustible(combustible_id);
create index vinc_empresa_idx on public.vinculaciones_personal(empresa_id);
create index vinc_autor_idx on public.vinculaciones_personal(autorizado_por);
create index asign_estacion_idx on public.asignaciones_responsables(estacion_id);
create index asign_autor_idx on public.asignaciones_responsables(asignado_por);
create index historial_ultimo_idx on public.historial_disponibilidad(estacion_combustible_id,registrado_en desc,id desc);
create index historial_autor_idx on public.historial_disponibilidad(autor_perfil_id);
create index favoritas_estacion_idx on public.favoritas(estacion_id);
create index auditoria_cuenta_idx on public.auditoria_cuentas(cuenta_afectada_id,registrado_en desc);
create index auditoria_actor_idx on public.auditoria_cuentas(actor_id);

-- Preserve access identities. Only the controlled bootstrap administrator remains enabled.
insert into public.perfiles(id,nombre,rol,activo,creado_en)
select id,nombre,case when rol='administrador' then rol else 'responsable' end,
       activo and rol='administrador',creado_en from historico_sprint2.perfiles;

create function private.fc_auth_profile() returns trigger language plpgsql security definer set search_path='' as $$
declare n text;
begin
 n:=trim(coalesce(new.raw_user_meta_data->>'nombre',''));
 if length(n)<2 then n:='Usuario'; end if;
 insert into public.perfiles(id,nombre,rol) values(new.id,left(n,100),'conductor');
 insert into public.auditoria_cuentas(cuenta_afectada_id,actor_id,accion) values(new.id,new.id,'cuenta_creada');
 return new;
end $$;
create trigger fc_auth_profile after insert on auth.users for each row execute function private.fc_auth_profile();

create function private.fc_role() returns text language sql stable security definer set search_path='' as $$
 select p.rol from public.perfiles p join auth.users u on u.id=p.id
 where p.id=(select auth.uid()) and p.activo and u.email_confirmed_at is not null
$$;
create function private.fc_assigned(s uuid) returns boolean language sql stable security definer set search_path='' as $$
 select private.fc_role()='responsable' and exists(
 select 1 from public.asignaciones_responsables a
 join public.vinculaciones_personal v on v.id=a.vinculacion_id
 join public.empresas_operadoras e on e.id=v.empresa_id
 join public.estaciones t on t.id=a.estacion_id and t.empresa_id=v.empresa_id
 where a.estacion_id=s and v.perfil_id=(select auth.uid()) and a.activo and a.fin is null
 and v.activo and v.fin is null and v.aceptada_en is not null and e.activo and t.activo)
$$;
create function private.fc_station(s uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',t.id,'codigo',t.codigo,'nombre',t.nombre,'direccion',t.direccion,
 'empresa_id',t.empresa_id,'empresa',e.denominacion,'ciudad_id',t.ciudad_id,'ciudad',c.nombre,
 'licencia',t.licencia,'fuente_url',t.fuente_url,'activo',t.activo,'disponible',t.activo and e.activo,
 'favorita',exists(select 1 from public.favoritas f where f.estacion_id=t.id and f.perfil_id=(select auth.uid()) and f.activo and private.fc_role() is not null),
 'puede_publicar',private.fc_assigned(t.id),
 'combustibles',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'relacion_id',ec.id,'nombre',b.nombre,
 'estado',case when t.activo and e.activo and h.registrado_en>greatest(t.reactivado_en,e.reactivado_en,ec.reactivado_en,b.reactivado_en)
 and h.registrado_en>now()-interval '2 hours' then h.estado else 'sin_actualizar' end,
 'registrado_en',h.registrado_en) order by b.nombre)
 from public.estacion_combustible ec join public.combustibles b on b.id=ec.combustible_id
 left join lateral(select x.estado,x.registrado_en from public.historial_disponibilidad x where x.estacion_combustible_id=ec.id order by x.registrado_en desc,x.id desc limit 1) h on true
 where ec.estacion_id=t.id and ec.activo and b.activo),'[]'::jsonb))
 from public.estaciones t join public.empresas_operadoras e on e.id=t.empresa_id join public.ciudades c on c.id=t.ciudad_id where t.id=s
$$;

create function private.fc_query(p_resource text,p_params jsonb) returns jsonb language plpgsql stable security definer set search_path='' as $$
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
   case when p.rol_invitado is not null or a.email_confirmed_at is null then 'pending' when p.activo then 'active' else 'inactive' end estado
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

create function private.fc_command(p_action text,p_data jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
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
 elsif p_action in ('user_save','user_state','user_role','invite_stage','invite_cancel') then
   select * into p from public.perfiles where id=target for update;
   if p.id is null then raise exception 'Cuenta no encontrada'; end if;
   old_role:=p.rol;
   if p_action='user_save' then
     update public.perfiles set nombre=trim(p_data->>'nombre'),contacto=trim(coalesce(p_data->>'contacto','')) where id=target;
   elsif p_action='user_state' then
     b:=(p_data->>'activo')::boolean;
     if target=u and not b then raise exception 'No puedes desactivar tu propia cuenta'; end if;
     if not b and p.rol='administrador' and p.activo and (select count(*) from public.perfiles where rol='administrador' and activo)<=1 then raise exception 'Debe quedar un administrador activo'; end if;
     update public.perfiles set activo=b where id=target;
   elsif p_action='user_role' then
     role_new:=p_data->>'rol';
     if role_new not in ('administrador','responsable','conductor') or role_new is null then raise exception 'Rol inválido'; end if;
     if target=u and role_new<>'administrador' then raise exception 'No puedes quitarte tu rol administrativo'; end if;
     if p.rol='administrador' and p.activo and role_new<>'administrador' and (select count(*) from public.perfiles where rol='administrador' and activo)<=1 then raise exception 'Debe quedar un administrador activo'; end if;
     if role_new<>p.rol then
       update public.asignaciones_responsables set activo=false,fin=now() where activo and vinculacion_id in(select id from public.vinculaciones_personal where perfil_id=target);
     end if;
     update public.perfiles set rol=role_new,rol_invitado=null,invitacion_vence=null where id=target;
   elsif p_action='invite_cancel' then
     update public.perfiles set rol_invitado=null,invitacion_vence=null where id=target;
     update public.vinculaciones_personal set activo=false,fin=now() where perfil_id=target and activo and aceptada_en is null;
   else
     role_new:=p_data->>'rol';
     if role_new not in ('administrador','responsable') or role_new is null then raise exception 'Rol de personal inválido'; end if;
     if target=u then raise exception 'No puedes invitarte a cambiar de rol'; end if;
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
   insert into public.asignaciones_responsables(id,vinculacion_id,estacion_id,asignado_por) values(target,v.id,t.id,u);
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

create function public.fc_query(p_resource text,p_params jsonb default '{}') returns jsonb language sql stable security invoker set search_path='' as $$select private.fc_query(p_resource,p_params)$$;
create function public.fc_command(p_action text,p_data jsonb default '{}') returns jsonb language sql security invoker set search_path='' as $$select private.fc_command(p_action,p_data)$$;
-- No direct client writes or table reads. All exposed operations validate the current identity.
do $$declare t text;begin
 foreach t in array array['perfiles','empresas_operadoras','ciudades','estaciones','combustibles','estacion_combustible','vinculaciones_personal','asignaciones_responsables','historial_disponibilidad','favoritas','auditoria_cuentas'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated',t);
 execute format('grant all on public.%I to service_role',t);
 end loop;
end $$;
revoke all on all functions in schema private from public,anon,authenticated;
revoke all on function public.fc_query(text,jsonb),public.fc_command(text,jsonb) from public;
grant usage on schema private to anon,authenticated;
grant execute on function private.fc_query(text,jsonb) to anon,authenticated;
grant execute on function private.fc_command(text,jsonb) to authenticated;
grant execute on function public.fc_query(text,jsonb) to anon,authenticated;
grant execute on function public.fc_command(text,jsonb) to authenticated;

insert into public.ciudades(nombre,departamento) values('La Paz','La Paz'),('El Alto','La Paz');
insert into public.combustibles(nombre) values('Gasolina Premium'),('Gasolina Especial'),('Gasolina Especial (+)'),('Super Etanol 92'),('Diésel Oil');
insert into public.empresas_operadoras(denominacion,fuente_url,verificado_en)
select x,'https://www.anh.gob.bo/w2026/contenido.php?D=2&R=1&s=40',date '2026-11-17'
from unnest(array['Automóvil Club Boliviano','BASSAM LIMITADA','ESTACION DE SERVICIO "C. REDENTOR" S.R.L.']) x;
insert into public.estaciones(empresa_id,ciudad_id,nombre,direccion,licencia,fuente_url)
select e.id,c.id,x.nombre,x.direccion,x.licencia,e.fuente_url from (values
('Automóvil Club Boliviano','La Paz','San Jorge','Av. 6 de Agosto Nº 2993','ANH00305-CLES01-LIC09/2026'),
('Automóvil Club Boliviano','La Paz','Calacoto','Calle 12 esq. Gral. Inofuentes Nº 7823','ANH00305-CLES02-LIC09/2026'),
('BASSAM LIMITADA','La Paz','Obrajes','Av. Hernando Siles Nº 4554','ANH01398-CLES01-LIC09/2026'),
('ESTACION DE SERVICIO "C. REDENTOR" S.R.L.','El Alto','Senkata','Av. 6 de Marzo Nº 110','ANH04972-CLES01-LIC09/2026')
) x(empresa,ciudad,nombre,direccion,licencia)
join public.empresas_operadoras e on e.denominacion=x.empresa join public.ciudades c on c.nombre=x.ciudad;
insert into public.estacion_combustible(estacion_id,combustible_id)
select t.id,b.id from public.estaciones t cross join public.combustibles b
where b.nombre in ('Gasolina Especial','Gasolina Especial (+)')
or (t.nombre in ('San Jorge','Calacoto') and b.nombre='Gasolina Premium')
or (t.nombre='Calacoto' and b.nombre='Super Etanol 92')
or (t.nombre in ('Obrajes','Senkata') and b.nombre='Diésel Oil');
comment on table public.estaciones is 'Catálogo documentado ANH. Los productos habilitados no acreditan existencias actuales.';
comment on table public.historial_disponibilidad is 'Publicaciones inmutables; vigencia de dos horas derivada al consultar. Sin datos de existencias iniciales inventados.';
notify pgrst,'reload schema';
commit;
