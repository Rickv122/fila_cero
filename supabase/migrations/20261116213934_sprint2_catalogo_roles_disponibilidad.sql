-- Sprint 2: catálogo, identidad de personal, asignaciones y disponibilidad.
-- Sin tablas de reportes de conductores, GPS, favoritos ni notificaciones.
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to anon, authenticated;

create table public.perfiles (
  id uuid primary key references auth.users(id) on delete restrict,
  nombre text not null check (length(btrim(nombre)) between 2 and 100),
  rol text not null check (rol in ('administrador','encargado')),
  activo boolean not null default true,
  creado_en timestamptz not null default now()
);
create table public.surtidores (
  id uuid primary key default gen_random_uuid(),
  nombre text not null check (length(btrim(nombre)) between 1 and 120),
  direccion text not null check (length(btrim(direccion)) between 1 and 240),
  ciudad text not null check (ciudad in ('La Paz','El Alto')),
  latitud double precision not null check (latitud between -90 and 90),
  longitud double precision not null check (longitud between -180 and 180),
  activo boolean not null default true,
  creado_por uuid references public.perfiles(id) on delete restrict,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  cambiado_estado_en timestamptz not null default now()
);
create table public.combustibles (
  id uuid primary key default gen_random_uuid(),
  nombre text not null unique check (length(btrim(nombre)) between 1 and 40),
  activo boolean not null default true
);
create table public.surtidor_combustible (
  surtidor_id uuid not null references public.surtidores(id) on delete restrict,
  combustible_id uuid not null references public.combustibles(id) on delete restrict,
  activo boolean not null default true,
  estado text not null default 'sin_informacion' check (estado in ('hay','poco','no_hay','sin_informacion')),
  actualizado_por uuid references public.perfiles(id) on delete restrict,
  informado_por text,
  actualizado_en timestamptz,
  primary key (surtidor_id,combustible_id)
);
create table public.asignaciones_encargado (
  perfil_id uuid not null references public.perfiles(id) on delete restrict,
  surtidor_id uuid not null references public.surtidores(id) on delete restrict,
  activo boolean not null default true,
  asignado_por uuid not null references public.perfiles(id) on delete restrict,
  actualizado_en timestamptz not null default now(),
  primary key (perfil_id,surtidor_id)
);
create table public.historial_disponibilidad (
  id uuid primary key default gen_random_uuid(),
  surtidor_id uuid not null,
  combustible_id uuid not null,
  estado_anterior text not null check (estado_anterior in ('hay','poco','no_hay','sin_informacion')),
  estado_nuevo text not null check (estado_nuevo in ('hay','poco','no_hay')),
  autor_id uuid not null references public.perfiles(id) on delete restrict,
  autor_nombre text not null,
  creado_en timestamptz not null default now(),
  activo boolean not null default true,
  foreign key (surtidor_id,combustible_id) references public.surtidor_combustible(surtidor_id,combustible_id) on delete restrict
);
create index surtidores_orden_idx on public.surtidores(activo,ciudad,nombre,id);
create index surtidores_autor_idx on public.surtidores(creado_por);
create index sc_combustible_idx on public.surtidor_combustible(combustible_id,surtidor_id);
create index sc_autor_idx on public.surtidor_combustible(actualizado_por);
create index asignaciones_estacion_idx on public.asignaciones_encargado(surtidor_id,perfil_id);
create index asignaciones_autor_idx on public.asignaciones_encargado(asignado_por);
create index historial_estacion_fecha_idx on public.historial_disponibilidad(surtidor_id,creado_en desc);
create index historial_combustible_idx on public.historial_disponibilidad(surtidor_id,combustible_id);
create index historial_autor_idx on public.historial_disponibilidad(autor_id);

-- Estas funciones privadas leen perfiles protegidos y evitan recursión de RLS.
create function private.rol_actual() returns text language sql stable security definer set search_path = ''
as $$ select p.rol from public.perfiles p where p.id = (select auth.uid()) and p.activo $$;
create function private.es_encargado(p_surtidor uuid) returns boolean language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.asignaciones_encargado a join public.surtidores s on s.id=a.surtidor_id
  where a.perfil_id=(select auth.uid()) and a.surtidor_id=p_surtidor and a.activo and s.activo
    and (select private.rol_actual())='encargado') $$;
revoke all on function private.rol_actual(), private.es_encargado(uuid) from public;
grant execute on function private.rol_actual(), private.es_encargado(uuid) to anon, authenticated;

alter table public.perfiles enable row level security;
alter table public.surtidores enable row level security;
alter table public.combustibles enable row level security;
alter table public.surtidor_combustible enable row level security;
alter table public.asignaciones_encargado enable row level security;
alter table public.historial_disponibilidad enable row level security;

revoke all on public.perfiles, public.surtidores, public.combustibles, public.surtidor_combustible,
  public.asignaciones_encargado, public.historial_disponibilidad from anon, authenticated;
grant select on public.surtidores, public.combustibles, public.surtidor_combustible to anon, authenticated;
grant select on public.perfiles, public.asignaciones_encargado, public.historial_disponibilidad to authenticated;

create policy perfiles_lectura on public.perfiles for select to authenticated
  using (id=(select auth.uid()) or (select private.rol_actual())='administrador');
create policy surtidores_lectura on public.surtidores for select to anon, authenticated
  using (activo or (select private.rol_actual())='administrador');
create policy combustibles_lectura on public.combustibles for select to anon, authenticated
  using (activo or (select private.rol_actual())='administrador');
create policy sc_lectura on public.surtidor_combustible for select to anon, authenticated
  using ((select private.rol_actual())='administrador' or (activo and exists
    (select 1 from public.surtidores s where s.id=surtidor_id and s.activo)));
create policy asignaciones_lectura on public.asignaciones_encargado for select to authenticated
  using ((select private.rol_actual())='administrador' or (perfil_id=(select auth.uid()) and (select private.rol_actual())='encargado'));
create policy historial_lectura on public.historial_disponibilidad for select to authenticated
  using ((select private.rol_actual())='administrador' or private.es_encargado(surtidor_id));

-- Los cambios de varias tablas son atómicos. Las funciones con privilegios están
-- en private, comprueban identidad/rol en cada llamada y no están expuestas a REST.
create function private.guardar_surtidor(p_id uuid,p_nombre text,p_direccion text,p_ciudad text,
  p_latitud double precision,p_longitud double precision,p_combustibles uuid[]) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_count int;
begin
  if private.rol_actual() is distinct from 'administrador' then raise exception 'Solo el administrador gestiona el catálogo.' using errcode='42501'; end if;
  if p_nombre is null or length(btrim(p_nombre)) not between 1 and 120
    or p_direccion is null or length(btrim(p_direccion)) not between 1 and 240
    or p_ciudad is null or p_ciudad not in ('La Paz','El Alto')
    or p_latitud is null or not (p_latitud between -90 and 90)
    or p_longitud is null or not (p_longitud between -180 and 180)
    or coalesce(cardinality(p_combustibles),0)=0 then raise exception 'Revisa nombre, dirección, ciudad, coordenadas y combustibles.' using errcode='22023'; end if;
  select count(*) into v_count from public.combustibles where id=any(p_combustibles) and activo;
  if v_count <> (select count(distinct x) from unnest(p_combustibles) x) or array_position(p_combustibles,null) is not null
    then raise exception 'Combustible no válido.' using errcode='22023'; end if;
  if p_id is null then
    insert into public.surtidores(nombre,direccion,ciudad,latitud,longitud,creado_por)
      values(btrim(p_nombre),btrim(p_direccion),p_ciudad,p_latitud,p_longitud,auth.uid()) returning id into v_id;
  else
    select id into v_id from public.surtidores where id=p_id for update;
    if v_id is null then raise exception 'Gasolinera no encontrada.' using errcode='22023'; end if;
    update public.surtidores set nombre=btrim(p_nombre),direccion=btrim(p_direccion),ciudad=p_ciudad,
      latitud=p_latitud,longitud=p_longitud,actualizado_en=now() where id=v_id;
  end if;
  update public.surtidor_combustible set activo=false where surtidor_id=v_id and not(combustible_id=any(p_combustibles));
  insert into public.surtidor_combustible(surtidor_id,combustible_id)
    select v_id,x from (select distinct unnest(p_combustibles) x) t
    on conflict(surtidor_id,combustible_id) do update set activo=true;
  return v_id;
end $$;

create function private.cambiar_estado_surtidor(p_id uuid,p_activo boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare v public.surtidores;
begin
  if private.rol_actual() is distinct from 'administrador' then raise exception 'Solo el administrador cambia el estado del catálogo.' using errcode='42501'; end if;
  select * into v from public.surtidores where id=p_id for update;
  if not found or p_activo is null then raise exception 'Gasolinera no encontrada.' using errcode='22023'; end if;
  if p_activo and not exists(select 1 from public.surtidor_combustible sc join public.combustibles c on c.id=sc.combustible_id where sc.surtidor_id=p_id and sc.activo and c.activo)
    then raise exception 'Selecciona al menos un combustible activo antes de reactivar.' using errcode='22023'; end if;
  if v.activo is distinct from p_activo then
    update public.surtidores set activo=p_activo,actualizado_en=now(),cambiado_estado_en=now() where id=p_id;
  end if;
end $$;

create function private.asignar_encargado(p_surtidor uuid,p_perfil uuid,p_activo boolean) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if private.rol_actual() is distinct from 'administrador' then raise exception 'Solo el administrador asigna encargados.' using errcode='42501'; end if;
  perform 1 from public.surtidores where id=p_surtidor for update;
  if not found or p_activo is null then raise exception 'Gasolinera no encontrada.' using errcode='22023'; end if;
  if not exists(select 1 from public.perfiles where id=p_perfil and rol='encargado' and activo)
    then raise exception 'Selecciona un encargado autorizado y activo.' using errcode='22023'; end if;
  insert into public.asignaciones_encargado(perfil_id,surtidor_id,activo,asignado_por)
    values(p_perfil,p_surtidor,p_activo,auth.uid()) on conflict(perfil_id,surtidor_id)
    do update set activo=excluded.activo,asignado_por=excluded.asignado_por,actualizado_en=now();
end $$;

create function private.actualizar_disponibilidad(p_surtidor uuid,p_cambios jsonb) returns void
language plpgsql security definer set search_path = '' as $$
declare v_s public.surtidores; v_sc public.surtidor_combustible; v_item jsonb; v_estado text; v_id uuid; v_nombre text;
begin
  if private.rol_actual() is distinct from 'encargado' then raise exception 'Solo el encargado asignado puede publicar disponibilidad.' using errcode='42501'; end if;
  select * into v_s from public.surtidores where id=p_surtidor for update;
  if not found or not private.es_encargado(p_surtidor) then raise exception 'No tienes una asignación activa para esta gasolinera.' using errcode='42501'; end if;
  if p_cambios is null or jsonb_typeof(p_cambios)<>'array' or jsonb_array_length(p_cambios) not between 1 and 20
    then raise exception 'Selecciona disponibilidad por combustible.' using errcode='22023'; end if;
  if (select count(*) from jsonb_array_elements(p_cambios)) <> (select count(distinct x->>'combustible_id') from jsonb_array_elements(p_cambios) x)
    then raise exception 'No repitas combustibles.' using errcode='22023'; end if;
  select nombre into v_nombre from public.perfiles where id=auth.uid();
  for v_item in select * from jsonb_array_elements(p_cambios) loop
    v_id=(v_item->>'combustible_id')::uuid; v_estado=v_item->>'estado';
    if v_estado is null or v_estado not in ('hay','poco','no_hay') then raise exception 'Estado no válido.' using errcode='22023'; end if;
    select sc.* into v_sc from public.surtidor_combustible sc join public.combustibles c on c.id=sc.combustible_id
      where sc.surtidor_id=p_surtidor and sc.combustible_id=v_id and sc.activo and c.activo for update of sc;
    if not found then raise exception 'El combustible no está habilitado en esta gasolinera.' using errcode='22023'; end if;
    insert into public.historial_disponibilidad(surtidor_id,combustible_id,estado_anterior,estado_nuevo,autor_id,autor_nombre)
      values(p_surtidor,v_id,v_sc.estado,v_estado,auth.uid(),v_nombre);
    update public.surtidor_combustible set estado=v_estado,actualizado_por=auth.uid(),informado_por=v_nombre,actualizado_en=clock_timestamp()
      where surtidor_id=p_surtidor and combustible_id=v_id;
  end loop;
end $$;

-- Envoltorios invoker: no aceptan autor, fecha, rol ni identificador de otra cuenta.
create function public.guardar_surtidor(p_id uuid,p_nombre text,p_direccion text,p_ciudad text,p_latitud double precision,p_longitud double precision,p_combustibles uuid[])
returns uuid language sql security invoker set search_path='' as $$ select private.guardar_surtidor(p_id,p_nombre,p_direccion,p_ciudad,p_latitud,p_longitud,p_combustibles) $$;
create function public.cambiar_estado_surtidor(p_id uuid,p_activo boolean) returns void language sql security invoker set search_path=''
as $$ select private.cambiar_estado_surtidor(p_id,p_activo) $$;
create function public.asignar_encargado(p_surtidor uuid,p_perfil uuid,p_activo boolean) returns void language sql security invoker set search_path=''
as $$ select private.asignar_encargado(p_surtidor,p_perfil,p_activo) $$;
create function public.actualizar_disponibilidad(p_surtidor uuid,p_cambios jsonb) returns void language sql security invoker set search_path=''
as $$ select private.actualizar_disponibilidad(p_surtidor,p_cambios) $$;

create function public.consultar_gasolineras(p_nombre text default '',p_ciudad text default null,p_combustible uuid default null,
  p_inactivas boolean default false,p_asignadas boolean default false,p_pagina integer default 0)
returns jsonb language sql stable security invoker set search_path='' as $$
with seleccion as (
  select s.* from public.surtidores s
  where s.activo=not p_inactivas
    and (not p_inactivas or (select private.rol_actual())='administrador')
    and (not p_asignadas or private.es_encargado(s.id))
    and (coalesce(p_ciudad,'')='' or s.ciudad=p_ciudad)
    and (coalesce(p_nombre,'')='' or strpos(lower(s.nombre),lower(btrim(p_nombre)))>0)
    and (p_combustible is null or exists(select 1 from public.surtidor_combustible sc join public.combustibles c on c.id=sc.combustible_id
      where sc.surtidor_id=s.id and sc.combustible_id=p_combustible and sc.activo and c.activo))
  order by lower(s.nombre),s.id limit 21 offset greatest(p_pagina,0)*20
), pagina as (
  select * from seleccion order by lower(nombre),id limit 20
)
select jsonb_build_object('hay_mas',(select count(*)>20 from seleccion),'elementos',coalesce(jsonb_agg(
  jsonb_build_object('id',s.id,'nombre',s.nombre,'direccion',s.direccion,'ciudad',s.ciudad,'latitud',s.latitud,'longitud',s.longitud,'activo',s.activo,
    'combustibles',(select coalesce(jsonb_agg(jsonb_build_object('combustible_id',c.id,'nombre',c.nombre,
      'estado',case when sc.actualizado_en is null or sc.actualizado_en<=now()-interval '2 hours' or sc.actualizado_en<s.cambiado_estado_en then 'sin_informacion' else sc.estado end,
      'actualizado_en',sc.actualizado_en,'informado_por',sc.informado_por) order by c.nombre),'[]'::jsonb)
      from public.surtidor_combustible sc join public.combustibles c on c.id=sc.combustible_id
      where sc.surtidor_id=s.id and sc.activo and c.activo)) order by lower(s.nombre),s.id),'[]'::jsonb)) from pagina s
$$;

revoke all on function private.guardar_surtidor(uuid,text,text,text,double precision,double precision,uuid[]),private.cambiar_estado_surtidor(uuid,boolean),
 private.asignar_encargado(uuid,uuid,boolean),private.actualizar_disponibilidad(uuid,jsonb) from public,anon;
grant execute on function private.guardar_surtidor(uuid,text,text,text,double precision,double precision,uuid[]),private.cambiar_estado_surtidor(uuid,boolean),
 private.asignar_encargado(uuid,uuid,boolean),private.actualizar_disponibilidad(uuid,jsonb) to authenticated;
revoke all on function public.guardar_surtidor(uuid,text,text,text,double precision,double precision,uuid[]),public.cambiar_estado_surtidor(uuid,boolean),
 public.asignar_encargado(uuid,uuid,boolean),public.actualizar_disponibilidad(uuid,jsonb) from public,anon;
grant execute on function public.guardar_surtidor(uuid,text,text,text,double precision,double precision,uuid[]),public.cambiar_estado_surtidor(uuid,boolean),
 public.asignar_encargado(uuid,uuid,boolean),public.actualizar_disponibilidad(uuid,jsonb) to authenticated;
revoke all on function public.consultar_gasolineras(text,text,uuid,boolean,boolean,integer) from public;
grant execute on function public.consultar_gasolineras(text,text,uuid,boolean,boolean,integer) to anon,authenticated;

insert into public.combustibles(nombre) values ('Gasolina Especial'),('Gasolina Premium'),('Diésel'),('GNV');
