begin;
create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron with schema pg_catalog;

create table private.fc3_worker_config (
 singleton boolean primary key default true check(singleton),
 endpoint text not null check(endpoint='https://oejouwwxngyafftzfkux.supabase.co/functions/v1/notify-worker'),
 secret text not null check(length(secret)>=32)
);
alter table private.fc3_worker_config enable row level security;
revoke all on private.fc3_worker_config from public,anon,authenticated,service_role;

create function private.fc3_configure_worker(p_secret text) returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.jwt()->>'role' is distinct from 'service_role' then raise exception 'Servicio requerido' using errcode='42501';end if;
 insert into private.fc3_worker_config(singleton,endpoint,secret)
 values(true,'https://oejouwwxngyafftzfkux.supabase.co/functions/v1/notify-worker',p_secret)
 on conflict(singleton) do update set secret=excluded.secret;
end $$;
create function public.fc3_configure_worker(p_secret text) returns void
language sql security invoker set search_path='' as $$select private.fc3_configure_worker(p_secret)$$;
revoke all on function private.fc3_configure_worker(text), public.fc3_configure_worker(text) from public,anon,authenticated;
grant execute on function private.fc3_configure_worker(text), public.fc3_configure_worker(text) to service_role;

create function private.fc3_wake_worker() returns void
language plpgsql security definer set search_path='' as $$
declare cfg private.fc3_worker_config;
begin
 if not exists(select 1 from public.cola_notificaciones where intentos<5 and disponible_en<=now()
 and (estado='pendiente' or (estado='enviando' and bloqueo_hasta<now()))) then return;end if;
 select * into cfg from private.fc3_worker_config where singleton;
 if not found then return;end if;
 perform net.http_post(url:=cfg.endpoint,headers:=jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||cfg.secret),body:='{}'::jsonb,timeout_milliseconds:=5000);
exception when others then
 raise warning 'No se pudo despertar el proceso de avisos; se reintentará.';
end $$;
revoke all on function private.fc3_wake_worker() from public,anon,authenticated;
create function private.fc3_queue_wakeup() returns trigger
language plpgsql security definer set search_path='' as $$
begin perform private.fc3_wake_worker();return null;end $$;
revoke all on function private.fc3_queue_wakeup() from public,anon,authenticated;
create trigger fc3_nuevo_aviso after insert on public.cola_notificaciones for each statement execute function private.fc3_queue_wakeup();
select cron.schedule('filacero_push_retry','* * * * *','select private.fc3_wake_worker()');

-- Include the recipient without exposing device identifiers to mobile clients.
alter function private.fc3_push_claim(integer) rename to fc3_push_claim_rows;
create function private.fc3_push_claim(p_limit integer default 20) returns jsonb
language plpgsql security definer set search_path='' as $$
declare jobs jsonb; result jsonb;
begin
 if auth.jwt()->>'role' is distinct from 'service_role' then raise exception 'Servicio requerido' using errcode='42501';end if;
 jobs:=private.fc3_push_claim_rows(p_limit);
 select coalesce(jsonb_agg(j.value||jsonb_build_object('perfil_id',q.perfil_id)),'[]') into result
 from jsonb_array_elements(jobs) j(value) join public.cola_notificaciones q on q.id=(j.value->>'id')::uuid;
 return result;
end $$;
-- SQL wrappers are recreated so their stored dependency points at the new function.
create or replace function public.fc3_push_claim(p_limit integer default 20) returns jsonb
language sql security invoker set search_path='' as $$select private.fc3_push_claim(p_limit)$$;
revoke all on function private.fc3_push_claim(integer),private.fc3_push_claim_rows(integer) from public,anon,authenticated;
grant execute on function private.fc3_push_claim(integer) to service_role;
commit;
