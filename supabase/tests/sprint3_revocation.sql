-- Regression: inactive people may revoke their own device while all other
-- protected operations remain denied. Fixture data is rolled back.
begin;
do $$
declare u uuid; other_user uuid; own_device uuid; other_device uuid; denied boolean;
begin
 select id into strict u from auth.users where email='valentina.rojas@filacero.test';
 select id into strict other_user from auth.users where email='ana.mendoza@filacero.test';
 insert into public.dispositivos_notificaciones(perfil_id,identificador_firebase,tipo_identificador,plataforma,sesion_id)
 values(u,'rollback-inactive-own-device','fid','android',gen_random_uuid()) returning id into own_device;
 insert into public.dispositivos_notificaciones(perfil_id,identificador_firebase,tipo_identificador,plataforma,sesion_id)
 values(other_user,'rollback-inactive-other-device','fid','android',gen_random_uuid()) returning id into other_device;
 update public.perfiles set activo=false where id=u;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',u,'role','authenticated')::text,true);
 perform public.fc3_command('device_disable','{"identificador":"rollback-inactive-own-device"}');
 if (select activo from public.dispositivos_notificaciones where id=own_device) then raise exception 'La cuenta inactiva no pudo revocar su dispositivo';end if;
 perform public.fc3_command('device_disable','{"identificador":"rollback-inactive-other-device"}');
 if not (select activo from public.dispositivos_notificaciones where id=other_device) then raise exception 'Se pudo revocar el dispositivo ajeno';end if;
 denied:=false;
 begin perform public.fc3_command('preferences_save','{}');exception when sqlstate '42501' then denied:=true;end;
 if not denied then raise exception 'La cuenta inactiva obtuvo acceso a preferencias';end if;
 denied:=false;
 begin perform public.fc3_command('device_register','{}');exception when sqlstate '42501' then denied:=true;end;
 if not denied then raise exception 'La cuenta inactiva pudo registrar un dispositivo';end if;
 perform set_config('request.jwt.claims','{}',true);
 denied:=false;
 begin perform public.fc3_command('device_disable','{"identificador":"rollback-inactive-other-device"}');exception when sqlstate '42501' then denied:=true;end;
 if not denied then raise exception 'Una solicitud sin identidad pudo revocar dispositivos';end if;
 raise notice 'PASS: revocación propia inactiva, aislamiento, bloqueo de otras acciones y solicitud anónima.';
end $$;
rollback;
