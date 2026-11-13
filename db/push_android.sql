begin;
alter table public.push_dispositivos add column tipo text not null default 'web' check(tipo in ('web','android')), add column token_nativo text;
create or replace function public.registrar_push_nativo(p_token text) returns uuid
language plpgsql security definer set search_path='' as $$declare x uuid; destino text;begin
 if auth.uid() is null or not public.es_staff() then raise exception 'Acceso denegado';end if;
 if p_token is null or length(p_token)<100 or length(p_token)>4096 or p_token !~ '^[A-Za-z0-9_:-]+$' then raise exception 'Token inválido';end if;
 destino:='firebase-native:'||encode(extensions.digest(p_token,'sha256'),'hex');
 if exists(select 1 from public.push_dispositivos where endpoint=destino and user_id<>auth.uid() and activo) then raise exception 'Cierra la sesión anterior antes de activar avisos';end if;
 insert into public.push_dispositivos(user_id,endpoint,p256dh,auth,tipo,token_nativo) values(auth.uid(),destino,'','','android',p_token)
 on conflict(endpoint) do update set user_id=excluded.user_id,token_nativo=excluded.token_nativo,activo=true returning id into x;return x;
end $$;
create or replace function public.desactivar_push_nativo(p_token text) returns void
language plpgsql security definer set search_path='' as $$begin
 if auth.uid() is null then raise exception 'Acceso denegado';end if;
 update public.push_dispositivos set activo=false where user_id=auth.uid() and token_nativo=p_token;
end $$;
revoke all on function public.registrar_push_nativo(text),public.desactivar_push_nativo(text) from public,anon;
grant execute on function public.registrar_push_nativo(text),public.desactivar_push_nativo(text) to authenticated;
create or replace function public.push_reclamar(p_key text) returns jsonb
language plpgsql security definer set search_path='' as $$declare resultado jsonb;begin
 if p_key is null or not exists(select 1 from ops_private.push_config where id and dispatch_key=p_key) then raise exception 'Acceso denegado';end if;
 with elegidos as(select j.id from ops_private.push_cola j join public.push_dispositivos d on d.id=j.dispositivo_id join public.perfiles p on p.user_id=d.user_id where d.activo and p.activo and j.intentos<6 and j.disponible<=now() and (j.estado='pendiente' or (j.estado='enviando' and j.lease_hasta<now())) order by j.creado limit 20 for update of j skip locked),
 reservados as(update ops_private.push_cola j set estado='enviando',intentos=j.intentos+1,lease_hasta=now()+interval '90 seconds' from elegidos e where j.id=e.id returning j.*)
 select coalesce(jsonb_agg(jsonb_build_object('id',j.id,'evento',j.evento,'titulo',j.titulo,'cuerpo',j.cuerpo,'ruta',j.ruta,'tipo',d.tipo,'token_nativo',d.token_nativo,'endpoint',d.endpoint,'p256dh',d.p256dh,'auth',d.auth)),'[]') into resultado from reservados j join public.push_dispositivos d on d.id=j.dispositivo_id;
 return resultado;
end $$;
commit;
