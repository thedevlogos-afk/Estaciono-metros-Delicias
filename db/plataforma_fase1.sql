-- Aplicada con Supabase MCP; CLI no disponible en el entorno.
-- Evolución aditiva. Los importes/fundamentos se configuran por autoridad, sin semillas ficticias.
begin;
create table public.turnos (
 id uuid primary key default gen_random_uuid(), operador_id uuid not null references public.perfiles(user_id),
 inicio timestamptz not null default now(), fin timestamptz, check(fin is null or fin>=inicio)
);
create unique index turno_abierto on public.turnos(operador_id) where fin is null;
create table public.reporte_accesos (
 solicitud uuid primary key, reporte_id uuid not null unique references public.reportes(id), token_hash text not null
);
create table public.buzon (
 id uuid primary key, folio text not null unique, categoria text not null check(categoria in ('queja','sugerencia')),
 mensaje text not null check(length(mensaje) between 10 and 2000), contacto text,
 creado timestamptz not null default now(), estatus text not null default 'recibido' check(estatus in ('recibido','en_revision','cerrado'))
);
create table public.tarifas (
 id uuid primary key default gen_random_uuid(), motivo text not null, fundamento text not null,
 monto numeric(12,2) not null check(monto>0), activa boolean not null default false,
 creada timestamptz not null default now()
);
create table public.impresiones (
 id uuid primary key default gen_random_uuid(), multa_folio text not null references public.multas(folio),
 operador_id uuid not null references public.perfiles(user_id), creado timestamptz not null default now()
);
alter table public.multas add column emisor_id uuid references public.perfiles(user_id),
 add column turno_id uuid references public.turnos(id), add column solicitud uuid unique,
 add column tarifa_id uuid references public.tarifas(id), add column fundamento text;
create index multas_emisor_fecha on public.multas(emisor_id,fecha desc);
create index reportes_gracia_busqueda on public.reportes(parquimetro_id,placa,gracia_hasta);
alter table public.perfiles add column precision_m double precision;

alter table public.turnos enable row level security;
alter table public.reporte_accesos enable row level security;
alter table public.buzon enable row level security;
alter table public.tarifas enable row level security;
alter table public.impresiones enable row level security;
revoke all on public.reporte_accesos from anon,authenticated;
grant select on public.turnos,public.buzon,public.tarifas,public.impresiones to authenticated;
grant insert,update on public.tarifas to authenticated;
grant update(estatus) on public.buzon to authenticated;
create policy turnos_lectura on public.turnos for select to authenticated using(public.es_admin() or (public.es_staff() and operador_id=auth.uid()));
create policy buzon_admin on public.buzon for select to authenticated using(public.es_admin());
create policy buzon_estado on public.buzon for update to authenticated using(public.es_admin()) with check(public.es_admin());
create policy tarifas_lectura on public.tarifas for select to authenticated using(public.es_staff());
create policy tarifas_alta on public.tarifas for insert to authenticated with check(public.es_admin());
create policy tarifas_edicion on public.tarifas for update to authenticated using(public.es_admin()) with check(public.es_admin());
create policy impresiones_lectura on public.impresiones for select to authenticated using(public.es_admin() or (public.es_staff() and operador_id=auth.uid()));
-- RPCs con permisos acotados: validación explícita porque las escrituras son transaccionales.
create or replace function public.turno_operador(p_accion text) returns uuid
language plpgsql security definer set search_path='' as $$
declare t uuid;
begin
 if auth.uid() is null or not public.es_staff() then raise exception 'Acceso denegado'; end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,1));
 if p_accion='iniciar' then
  select id into t from public.turnos where operador_id=auth.uid() and fin is null;
  if t is null then insert into public.turnos(operador_id) values(auth.uid()) returning id into t; end if;
 elsif p_accion='cerrar' then
  update public.turnos set fin=now() where operador_id=auth.uid() and fin is null returning id into t;
  update public.perfiles set lat=null,lng=null,ubicacion_at=null,precision_m=null where user_id=auth.uid();
 else raise exception 'Acción inválida'; end if;
 return t;
end $$;
create or replace function public.ubicacion_operador(p_lat double precision,p_lng double precision,p_precision double precision) returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.es_staff() or not exists(select 1 from public.turnos where operador_id=auth.uid() and fin is null) then raise exception 'Inicia un turno'; end if;
 if not (p_lat between -90 and 90) or not (p_lng between -180 and 180) or not (p_precision between 0 and 10000) or p_lat is null or p_lng is null or p_precision is null then raise exception 'GPS inválido'; end if;
 update public.perfiles set lat=p_lat,lng=p_lng,ubicacion_at=now(),precision_m=p_precision where user_id=auth.uid();
end $$;
-- Evita que el endpoint antiguo ignore el control de turno.
create or replace function public.ping_ubicacion(p_lat double precision,p_lng double precision) returns void
language sql security invoker set search_path='' as $$ select public.ubicacion_operador(p_lat,p_lng,100); $$;
create or replace function public.trg_rep_alert() returns trigger
language plpgsql security definer set search_path='' as $$
declare candidato uuid;
begin
 select p.user_id into candidato from public.perfiles p
 join public.turnos t on t.operador_id=p.user_id and t.fin is null
 join public.parquimetros q on q.id=new.parquimetro_id
 where p.activo and p.rol='inspector' and p.ubicacion_at>now()-interval '90 seconds'
 and p.lat is not null and p.lng is not null and q.lat is not null and q.lng is not null and p.precision_m<=100
 order by (p.lat-q.lat)^2+((p.lng-q.lng)*cos(radians(q.lat)))^2 limit 1;
 if candidato is not null then insert into public.alertas(reporte_id,inspector_id) values(new.id,candidato); end if;
 return new;
end $$;
create or replace function public.alertar_reporte(p_rep uuid,p_ins uuid default null) returns integer
language plpgsql security definer set search_path='' as $$
declare candidato uuid;
begin
 if auth.uid() is null or not public.es_admin() then raise exception 'Solo Administración'; end if;
 if not exists(select 1 from public.reportes where id=p_rep and estatus='pendiente') then raise exception 'Reporte no pendiente'; end if;
 select p.user_id into candidato from public.perfiles p
 join public.turnos t on t.operador_id=p.user_id and t.fin is null
 join public.reportes r on r.id=p_rep join public.parquimetros q on q.id=r.parquimetro_id
 where p.activo and p.rol='inspector' and p.ubicacion_at>now()-interval '90 seconds' and p.precision_m<=100
 and p.lat is not null and p.lng is not null and (p_ins is null or p.user_id=p_ins)
 order by (p.lat-q.lat)^2+((p.lng-q.lng)*cos(radians(q.lat)))^2 nulls last limit 1;
 if candidato is null then return 0; end if;
 insert into public.alertas(reporte_id,inspector_id) values(p_rep,candidato);
 return 1;
end $$;
create or replace function public.reportar_falla_v2(p_solicitud uuid,p_token uuid,p_parq text,p_falla text,p_detalle text,p_nombre text,p_tel text,p_placa text,p_monto numeric) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.reportes; placa_limpia text:=upper(regexp_replace(coalesce(p_placa,''),'[^A-Za-z0-9]','','g'));
begin
 if p_solicitud is null or p_token is null or length(placa_limpia) not between 3 and 12 or length(trim(coalesce(p_falla,''))) not between 3 and 100 or p_monto is null or p_monto<0 or p_monto>10000 then raise exception 'Revisa los datos del reporte'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_parq||':'||placa_limpia,0));
 select q.* into r from public.reporte_accesos a join public.reportes q on q.id=a.reporte_id where a.solicitud=p_solicitud and a.token_hash=encode(sha256(convert_to(p_token::text,'UTF8')),'hex');
 if r.id is not null then return jsonb_build_object('folio',r.folio,'gracia_hasta',r.gracia_hasta,'servidor',now()); end if;
 if not exists(select 1 from public.parquimetros where id=p_parq and activo) then raise exception 'Parquímetro no disponible'; end if;
 if exists(select 1 from public.reportes where parquimetro_id=p_parq and placa=placa_limpia and gracia_hasta>now()) then raise exception 'Ya existe una gracia activa para esta placa y aparato. Consulta tu comprobante original.'; end if;
 if (select count(*) from public.reportes where placa=placa_limpia and creado>now()-interval '24 hours')>=5 then raise exception 'Límite de reportes; contacta a Administración'; end if;
 insert into public.reportes(folio,parquimetro_id,falla,detalle,nombre,telefono,placa,monto,gracia_hasta)
 values('R-'||upper(replace(gen_random_uuid()::text,'-','')),p_parq,p_falla,left(p_detalle,500),left(p_nombre,80),left(p_tel,20),placa_limpia,p_monto,now()+interval '15 minutes') returning * into r;
 insert into public.reporte_accesos values(p_solicitud,r.id,encode(sha256(convert_to(p_token::text,'UTF8')),'hex'));
 return jsonb_build_object('folio',r.folio,'gracia_hasta',r.gracia_hasta,'servidor',now());
end $$;
create or replace function public.seguir_reporte(p_folio text,p_token uuid) returns jsonb
language sql security definer set search_path='' as $$
 select jsonb_build_object('folio',r.folio,'parquimetro',r.parquimetro_id,'estatus',r.estatus,'gracia_hasta',r.gracia_hasta,'creado',r.creado,'verificado',r.verificado,'servidor',now())
 from public.reportes r join public.reporte_accesos a on a.reporte_id=r.id
 where r.folio=p_folio and a.token_hash=encode(sha256(convert_to(p_token::text,'UTF8')),'hex');
$$;
-- Clientes antiguos conservan contrato; validación/deduplicación pasa por la versión nueva.
create or replace function public.crear_reporte(p_parq text,p_falla text,p_detalle text,p_nombre text,p_tel text,p_placa text,p_monto numeric)
returns table(folio text,gracia_hasta timestamptz) language plpgsql security invoker set search_path='' as $$
declare j jsonb;
begin
 j:=public.reportar_falla_v2(gen_random_uuid(),gen_random_uuid(),p_parq,p_falla,p_detalle,p_nombre,p_tel,p_placa,p_monto);
 return query select j->>'folio',(j->>'gracia_hasta')::timestamptz;
end $$;
create or replace function public.enviar_buzon(p_id uuid,p_categoria text,p_mensaje text,p_contacto text) returns text
language plpgsql security definer set search_path='' as $$
declare f text;
begin
 if p_id is null or length(coalesce(p_mensaje,'')) not between 10 and 2000 or p_categoria not in ('queja','sugerencia') then raise exception 'Revisa tu mensaje'; end if;
 insert into public.buzon(id,folio,categoria,mensaje,contacto) values(p_id,'B-'||upper(replace(p_id::text,'-','')),p_categoria,p_mensaje,left(p_contacto,120)) on conflict(id) do nothing;
 select folio into f from public.buzon where id=p_id; return f;
end $$;
create or replace function public.emitir_multa(p_solicitud uuid,p_parq text,p_placa text,p_tarifa uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare m public.multas; t uuid; tarifa public.tarifas; pl text:=upper(regexp_replace(coalesce(p_placa,''),'[^A-Za-z0-9]','','g'));
begin
 if auth.uid() is null or not public.es_staff() then raise exception 'Acceso denegado'; end if;
 if p_solicitud is null or length(pl) not between 3 and 12 then raise exception 'Datos inválidos'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_parq||':'||pl,0));
 select * into m from public.multas where solicitud=p_solicitud and emisor_id=auth.uid();
 if m.folio is not null then return to_jsonb(m); end if;
 select id into t from public.turnos where operador_id=auth.uid() and fin is null;
 if t is null then raise exception 'Inicia un turno'; end if;
 if not exists(select 1 from public.parquimetros where id=p_parq and activo) then raise exception 'Parquímetro no disponible'; end if;
 if exists(select 1 from public.reportes where parquimetro_id=p_parq and placa=pl and gracia_hasta>now()) then raise exception 'Gracia activa: no se puede emitir'; end if;
 if exists(select 1 from public.reportes where parquimetro_id=p_parq and estatus='procedente') then raise exception 'Aparato con falla confirmada: requiere revisión administrativa'; end if;
 select * into tarifa from public.tarifas where id=p_tarifa and activa;
 if tarifa.id is null then raise exception 'Configura una tarifa y fundamento autorizados'; end if;
 if exists(select 1 from public.multas where parquimetro_id=p_parq and placa=pl and fecha>now()-interval '15 minutes') then raise exception 'Ya existe un ticket reciente para esta placa y aparato'; end if;
 insert into public.multas(folio,placa,monto,motivo,parquimetro_id,emisor_id,turno_id,solicitud,tarifa_id,fundamento)
 values('M-'||upper(replace(gen_random_uuid()::text,'-','')),pl,tarifa.monto,tarifa.motivo,p_parq,auth.uid(),t,p_solicitud,tarifa.id,tarifa.fundamento) returning * into m;
 return to_jsonb(m);
end $$;
drop policy if exists mul_staff on public.multas;
create policy multas_lectura on public.multas for select to authenticated using(public.es_admin() or (public.es_staff() and emisor_id=auth.uid()));
-- No UPDATE/DELETE de multas vía cliente. Pagos existentes continúan vía servidor.
revoke insert,update,delete on public.multas from anon,authenticated;
create or replace function public.registrar_impresion(p_folio text) returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.es_staff() or not exists(select 1 from public.multas where folio=p_folio and (emisor_id=auth.uid() or public.es_admin())) then raise exception 'Acceso denegado'; end if;
 insert into public.impresiones(multa_folio,operador_id) values(p_folio,auth.uid());
end $$;
-- Solo el destinatario puede marcar leída una alerta; identidad inmutable vía permisos de columna.
revoke update on public.alertas from anon,authenticated;
grant update(leida) on public.alertas to authenticated;
create or replace function public.atender_reporte(p_id uuid,p_estatus text,p_nota text) returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.es_staff() then raise exception 'Acceso denegado'; end if;
 if not public.es_admin() and not exists(select 1 from public.alertas where reporte_id=p_id and inspector_id=auth.uid()) then raise exception 'Reporte no asignado'; end if;
 if p_estatus not in ('procedente','improcedente') or length(trim(coalesce(p_nota,'')))<5 then raise exception 'Agrega un resultado y nota de verificación'; end if;
 update public.reportes set estatus=p_estatus,nota_agente=left(p_nota,500),verificado=now(),inspector_id=auth.uid() where id=p_id and estatus='pendiente';
 if not found then raise exception 'Reporte no pendiente'; end if;
end $$;
drop policy if exists rep_sel on public.reportes;
create policy reportes_asignados on public.reportes for select to authenticated using(public.es_admin() or (public.es_staff() and exists(select 1 from public.alertas a where a.reporte_id=reportes.id and a.inspector_id=auth.uid())));
revoke all on function public.turno_operador(text),public.ubicacion_operador(double precision,double precision,double precision),public.emitir_multa(uuid,text,text,uuid),public.registrar_impresion(text),public.alertar_reporte(uuid,uuid),public.atender_reporte(uuid,text,text) from public,anon;
grant execute on function public.turno_operador(text),public.ubicacion_operador(double precision,double precision,double precision),public.emitir_multa(uuid,text,text,uuid),public.registrar_impresion(text),public.alertar_reporte(uuid,uuid),public.atender_reporte(uuid,text,text) to authenticated;
revoke all on function public.reportar_falla_v2(uuid,uuid,text,text,text,text,text,text,numeric),public.seguir_reporte(text,uuid),public.enviar_buzon(uuid,text,text,text) from public;
grant execute on function public.reportar_falla_v2(uuid,uuid,text,text,text,text,text,text,numeric),public.seguir_reporte(text,uuid),public.enviar_buzon(uuid,text,text,text) to anon,authenticated;
revoke all on function public.trg_rep_alert() from public,anon,authenticated;
commit;
