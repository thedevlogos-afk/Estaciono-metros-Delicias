begin;
create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron with schema pg_catalog;
create table public.push_dispositivos (
 id uuid primary key default gen_random_uuid(),user_id uuid not null references public.perfiles(user_id),endpoint text not null unique,
 p256dh text not null,auth text not null,activo boolean not null default true,creado timestamptz not null default now()
);
alter table public.push_dispositivos enable row level security;
revoke all on public.push_dispositivos from anon,authenticated;
grant select on public.push_dispositivos to authenticated;
create policy push_propio on public.push_dispositivos for select to authenticated using(user_id=auth.uid() and public.es_staff());
create table ops_private.push_config(id boolean primary key default true check(id),dispatch_key text not null,dispatch_url text not null);
create table ops_private.push_cola (
 id uuid primary key default gen_random_uuid(),dispositivo_id uuid not null references public.push_dispositivos(id),evento text not null,
 titulo text not null,cuerpo text not null,ruta text not null,estado text not null default 'pendiente',intentos integer not null default 0,
 disponible timestamptz not null default now(),lease_hasta timestamptz,creado timestamptz not null default now(),error text,
 unique(dispositivo_id,evento)
);
revoke all on all tables in schema ops_private from public,anon,authenticated;
create index push_pendiente on ops_private.push_cola(disponible) where estado in('pendiente','enviando');
create or replace function public.registrar_push(p_endpoint text,p_p256dh text,p_auth text) returns uuid
language plpgsql security definer set search_path='' as $$declare x uuid;begin
 if auth.uid() is null or not public.es_staff() then raise exception 'Acceso denegado';end if;
 if length(p_endpoint)>4096 or p_endpoint !~ '^https://(fcm[.]googleapis[.]com|updates[.]push[.]services[.]mozilla[.]com|web[.]push[.]apple[.]com|[a-z0-9.-]+[.]notify[.]windows[.]com)/' or p_endpoint is null or p_p256dh !~ '^[A-Za-z0-9_-]{80,100}={0,2}$' or p_auth !~ '^[A-Za-z0-9_-]{20,30}={0,2}$' or p_p256dh is null or p_auth is null then raise exception 'Suscripción push inválida';end if;
 if exists(select 1 from public.push_dispositivos where endpoint=p_endpoint and user_id<>auth.uid()) then raise exception 'Este dispositivo pertenece a otra sesión; desactiva sus avisos antes de cambiar de cuenta';end if;
 insert into public.push_dispositivos(user_id,endpoint,p256dh,auth) values(auth.uid(),p_endpoint,p_p256dh,p_auth)
 on conflict(endpoint) do update set p256dh=excluded.p256dh,auth=excluded.auth,activo=true returning id into x;return x;
end $$;
create or replace function public.desactivar_push(p_endpoint text) returns void
language plpgsql security definer set search_path='' as $$begin
 if auth.uid() is null then raise exception 'Acceso denegado';end if;
 update public.push_dispositivos set activo=false where endpoint=p_endpoint and user_id=auth.uid();
end $$;
create or replace function ops_private.despertar_push() returns void
language plpgsql security definer set search_path='' as $$declare c ops_private.push_config;begin
 if not exists(select 1 from ops_private.push_cola where (estado='pendiente' or (estado='enviando' and lease_hasta<now())) and disponible<=now() and intentos<6) then return;end if;
 select * into c from ops_private.push_config where id;
 if c.dispatch_key is null then return;end if;
 perform net.http_post(url:=c.dispatch_url,headers:=jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||c.dispatch_key),body:='{}'::jsonb,timeout_milliseconds:=5000);
exception when others then return; -- la cola durable conserva el evento para el siguiente intento
end $$;
create or replace function ops_private.encolar_push() returns trigger
language plpgsql security definer set search_path='' as $$begin
 if tg_table_name='alertas' then
 insert into ops_private.push_cola(dispositivo_id,evento,titulo,cuerpo,ruta)
 select d.id,'alerta:'||new.id,'Reporte asignado','Tienes una verificación pendiente. Abre la app para atenderla.','/panel?ver=alertas' from public.push_dispositivos d join public.perfiles p on p.user_id=d.user_id where d.activo and p.activo and d.user_id=new.inspector_id on conflict do nothing;
 else
 insert into ops_private.push_cola(dispositivo_id,evento,titulo,cuerpo,ruta)
 select d.id,'reporte:'||new.id,'Nuevo reporte ciudadano','Hay un reporte nuevo en el Centro de Operaciones.','/admin' from public.push_dispositivos d join public.perfiles p on p.user_id=d.user_id where d.activo and p.activo and p.rol='admin' on conflict do nothing;
 end if;
 perform ops_private.despertar_push();return new;
end $$;
create trigger alertas_push after insert on public.alertas for each row execute function ops_private.encolar_push();
create trigger reportes_push after insert on public.reportes for each row execute function ops_private.encolar_push();
create or replace function public.probar_push() returns integer
language plpgsql security definer set search_path='' as $$declare n integer;begin
 if auth.uid() is null or not public.es_staff() then raise exception 'Acceso denegado';end if;
 if exists(select 1 from ops_private.push_cola j join public.push_dispositivos d on d.id=j.dispositivo_id where d.user_id=auth.uid() and j.evento like 'prueba:%' and j.creado>now()-interval '1 minute') then raise exception 'Espera un minuto antes de repetir la prueba';end if;
 insert into ops_private.push_cola(dispositivo_id,evento,titulo,cuerpo,ruta) select d.id,'prueba:'||gen_random_uuid(),'Aviso de prueba','Las notificaciones de Estacionómetros están activadas.',case when p.rol='admin' then '/admin' else '/panel' end from public.push_dispositivos d join public.perfiles p on p.user_id=d.user_id where d.user_id=auth.uid() and d.activo;
 get diagnostics n=row_count;perform ops_private.despertar_push();return n;
end $$;
create or replace function public.push_reclamar(p_key text) returns jsonb
language plpgsql security definer set search_path='' as $$declare resultado jsonb;begin
 if p_key is null or not exists(select 1 from ops_private.push_config where id and dispatch_key=p_key) then raise exception 'Acceso denegado';end if;
 with elegidos as(select j.id from ops_private.push_cola j join public.push_dispositivos d on d.id=j.dispositivo_id join public.perfiles p on p.user_id=d.user_id where d.activo and p.activo and j.intentos<6 and j.disponible<=now() and (j.estado='pendiente' or (j.estado='enviando' and j.lease_hasta<now())) order by j.creado limit 20 for update of j skip locked),
 reservados as(update ops_private.push_cola j set estado='enviando',intentos=j.intentos+1,lease_hasta=now()+interval '90 seconds' from elegidos e where j.id=e.id returning j.*)
 select coalesce(jsonb_agg(jsonb_build_object('id',j.id,'evento',j.evento,'titulo',j.titulo,'cuerpo',j.cuerpo,'ruta',j.ruta,'endpoint',d.endpoint,'p256dh',d.p256dh,'auth',d.auth)),'[]') into resultado from reservados j join public.push_dispositivos d on d.id=j.dispositivo_id;
 return resultado;
end $$;
create or replace function public.push_resultado(p_key text,p_id uuid,p_ok boolean,p_invalido boolean,p_error text) returns void
language plpgsql security definer set search_path='' as $$begin
 if p_key is null or not exists(select 1 from ops_private.push_config where id and dispatch_key=p_key) then raise exception 'Acceso denegado';end if;
 update ops_private.push_cola set estado=case when p_ok then 'enviado' when p_invalido or intentos>=6 then 'fallido' else 'pendiente' end,disponible=now()+interval '1 minute'*power(2,least(intentos,6)),error=left(p_error,100),lease_hasta=null where id=p_id;
 if p_invalido then update public.push_dispositivos set activo=false where id=(select dispositivo_id from ops_private.push_cola where id=p_id);end if;
end $$;
revoke all on function public.registrar_push(text,text,text),public.desactivar_push(text),public.probar_push() from public,anon;
grant execute on function public.registrar_push(text,text,text),public.desactivar_push(text),public.probar_push() to authenticated;
revoke all on function public.push_reclamar(text),public.push_resultado(text,uuid,boolean,boolean,text) from public;
grant execute on function public.push_reclamar(text),public.push_resultado(text,uuid,boolean,boolean,text) to anon;
revoke all on all functions in schema ops_private from public,anon,authenticated;
select cron.schedule('estacionometros-push-reintentos','* * * * *','select ops_private.despertar_push();');
commit;
