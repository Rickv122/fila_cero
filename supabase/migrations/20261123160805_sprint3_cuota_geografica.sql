create table private.fc3_geo_cuotas (
 dia date primary key,
 creditos numeric not null default 0,
 siguiente_solicitud timestamptz not null default now()
);
alter table private.fc3_geo_cuotas enable row level security;
revoke all on private.fc3_geo_cuotas from public,anon,authenticated,service_role;
create function private.fc3_geo_budget(p_units numeric) returns jsonb
language plpgsql security definer set search_path='' as $$
declare d date:=(clock_timestamp() at time zone 'UTC')::date; q private.fc3_geo_cuotas; slot timestamptz;wait_ms integer;
begin
 if (auth.jwt()->>'role') is distinct from 'service_role' then raise exception 'Servicio requerido' using errcode='42501';end if;
 if p_units is null or p_units<=0 or p_units>100 then raise exception 'Consumo no válido' using errcode='22023';end if;
 insert into private.fc3_geo_cuotas(dia)values(d)on conflict(dia)do nothing;
 select * into q from private.fc3_geo_cuotas where dia=d for update;
 if q.creditos+p_units>2500 then raise exception 'Se alcanzó el límite diario del servicio geográfico' using errcode='P0001';end if;
 slot:=greatest(q.siguiente_solicitud,clock_timestamp());
 wait_ms:=greatest(0,ceil(extract(epoch from slot-clock_timestamp())*1000)::integer);
 if wait_ms>9000 then raise exception 'El servicio está ocupado. Espera unos segundos y reintenta' using errcode='P0001';end if;
 update private.fc3_geo_cuotas set creditos=creditos+p_units,siguiente_solicitud=slot+interval '300 milliseconds' where dia=d;
 return jsonb_build_object('wait_ms',wait_ms);
end $$;
revoke all on function private.fc3_geo_budget(numeric) from public,anon,authenticated;
grant execute on function private.fc3_geo_budget(numeric) to service_role;
create function public.fc3_geo_budget(p_units numeric)returns jsonb language sql security invoker set search_path='' as $$select private.fc3_geo_budget(p_units)$$;
revoke all on function public.fc3_geo_budget(numeric) from public,anon,authenticated;
grant execute on function public.fc3_geo_budget(numeric) to service_role;
