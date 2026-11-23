-- Run against the FilaCero evaluation project. Everything, including queued
-- HTTP requests, is rolled back. No credentials or generated IDs are embedded.
begin;
do $$
declare driver uuid; admin_id uuid; manager uuid; session_id uuid; station uuid; fuel uuid; device uuid; result jsonb; n integer;
begin
 select id into strict driver from auth.users where email='valentina.rojas@filacero.test';
 select id into strict admin_id from auth.users where email='marcela.salvatierra@filacero.test';
 select id into strict manager from auth.users where email='mateo.quispe@filacero.test';
 select id into strict session_id from auth.sessions where user_id=driver order by created_at desc limit 1;
 select id into strict station from public.estaciones where nombre='San Jorge';
 select id into strict fuel from public.combustibles where nombre='Gasolina Especial';
 perform set_config('request.jwt.claims',jsonb_build_object('sub',driver,'role','authenticated','session_id',session_id)::text,true);
 perform public.fc3_command('preferences_save',jsonb_build_object('combustible_id',fuel,'distancia_maxima_km',10));
 begin
  perform public.fc3_command('preferences_save',jsonb_build_object('combustible_id',fuel,'distancia_maxima_km',9));
  raise exception 'Se aceptó una distancia inválida';
 exception when sqlstate '22023' then null;end;
 if (public.fc3_query('preferences','{}')->>'distancia_maxima_km')::integer<>10 then raise exception 'El fallo reemplazó preferencias guardadas';end if;
 begin
  perform public.fc3_command('location_save',jsonb_build_object('id',station,'latitud',0,'longitud',0,'direccion','Cambio prohibido'));
  raise exception 'Un conductor modificó una ubicación';
 exception when sqlstate '42501' then null;end;
 perform public.fc_command('favorite',jsonb_build_object('id',station,'activo',true));
 result:=public.fc3_command('device_register',jsonb_build_object('identificador','rollback-only-no-real-device','tipo','fid','plataforma','android'));
 device:=(result->>'id')::uuid;
 perform public.fc3_command('subscription_save',jsonb_build_object('id',station,'activo',true));
 select count(*) into n from public.cola_notificaciones where dispositivo_id=device;
 if n<>0 then raise exception 'Activación generó avisos históricos';end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',manager,'role','authenticated')::text,true);
 perform public.fc_command('publish',jsonb_build_object('id',station,'operation',gen_random_uuid(),'changes',jsonb_build_array(jsonb_build_object('id',fuel,'estado','limitada'))));
 perform public.fc_command('publish',jsonb_build_object('id',station,'operation',gen_random_uuid(),'changes',jsonb_build_array(jsonb_build_object('id',fuel,'estado','disponible'))));
 select count(*) into n from public.cola_notificaciones where dispositivo_id=device;
 if n<>1 then raise exception 'Transición disponible no generó exactamente un aviso: %',n;end if;
 perform public.fc_command('publish',jsonb_build_object('id',station,'operation',gen_random_uuid(),'changes',jsonb_build_array(jsonb_build_object('id',fuel,'estado','disponible'))));
 select count(*) into n from public.cola_notificaciones where dispositivo_id=device;
 if n<>1 then raise exception 'Se duplicó un aviso por publicación disponible repetida';end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',driver,'role','authenticated','session_id',session_id)::text,true);
 perform public.fc_command('favorite',jsonb_build_object('id',station,'activo',false));
 if exists(select 1 from public.suscripciones_disponibilidad where perfil_id=driver and estacion_id=station and activo) then raise exception 'Quitar favorita no revocó suscripción';end if;
 perform set_config('request.jwt.claims','{"role":"service_role"}',true);
 perform public.fc3_push_claim(20);
 if exists(select 1 from public.cola_notificaciones where dispositivo_id=device and estado<>'cancelado') then raise exception 'La cola no canceló avisos sin favorita';end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',admin_id,'role','authenticated')::text,true);
 if public.fc3_query('preferences','{}')->>'perfil_id'=driver::text then raise exception 'Preferencias ajenas expuestas';end if;
 raise notice 'PASS: preferencias, permisos, opt-in, transición, deduplicación y cancelación.';
end $$;
rollback;
