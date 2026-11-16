-- Registros académicos para comprobar las cinco historias; no representan
-- abastecimiento verificado. No se crean cuentas ni contraseñas mediante SQL.
insert into public.perfiles(id,nombre,rol,activo)
select id,case email when 'admin@filacero.test' then 'Administrador'
  when 'encargado.sopocachi@filacero.test' then 'Encargado Sopocachi'
  when 'encargado.elalto@filacero.test' then 'Encargado El Alto'
  else 'Personal inactivo' end,
  case when email='admin@filacero.test' then 'administrador' else 'encargado' end,
  email<>'inactivo@filacero.test'
from auth.users where email in ('admin@filacero.test','encargado.sopocachi@filacero.test','encargado.elalto@filacero.test','inactivo@filacero.test')
on conflict(id) do nothing;

insert into public.surtidores(nombre,direccion,ciudad,latitud,longitud,creado_por)
select v.nombre,v.direccion,v.ciudad,v.latitud,v.longitud,p.id
from (values
  ('Surtidor Sopocachi','Av. Arce y calle Rosendo Gutiérrez','La Paz',-16.5120,-68.1310),
  ('Surtidor Miraflores','Av. Saavedra y calle Díaz Romero','La Paz',-16.5000,-68.1180),
  ('Surtidor Obrajes','Av. Hernando Siles y calle 17','La Paz',-16.5260,-68.1010),
  ('Surtidor El Alto Central','Av. 6 de Marzo','El Alto',-16.5100,-68.1640)
) as v(nombre,direccion,ciudad,latitud,longitud)
cross join public.perfiles p join auth.users u on u.id=p.id
where u.email='admin@filacero.test'
and not exists(select 1 from public.surtidores s where s.nombre=v.nombre);

insert into public.surtidor_combustible(surtidor_id,combustible_id)
select s.id,c.id from public.surtidores s cross join public.combustibles c
where s.nombre in ('Surtidor Sopocachi','Surtidor Miraflores','Surtidor Obrajes','Surtidor El Alto Central')
and c.nombre in ('Gasolina Especial','Diésel','GNV')
on conflict(surtidor_id,combustible_id) do nothing;

insert into public.asignaciones_encargado(perfil_id,surtidor_id,asignado_por)
select p.id,s.id,a.id from public.perfiles p join auth.users u on u.id=p.id
cross join public.surtidores s cross join public.perfiles a join auth.users ua on ua.id=a.id
where ua.email='admin@filacero.test' and
  ((u.email='encargado.sopocachi@filacero.test' and s.nombre in ('Surtidor Sopocachi','Surtidor Miraflores'))
  or (u.email='encargado.elalto@filacero.test' and s.nombre='Surtidor El Alto Central'))
on conflict(perfil_id,surtidor_id) do nothing;
