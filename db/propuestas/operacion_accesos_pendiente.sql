begin;
create schema if not exists ops_private;
revoke all on schema ops_private from public,anon,authenticated;
create table if not exists ops_private.administracion_inicial(email text primary key);
revoke all on ops_private.administracion_inicial from public,anon,authenticated;
-- La lista autorizada se configura en la base, nunca desde metadatos del usuario.
create or replace function public.activar_administrador_inicial() returns boolean
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then return false;end if;
 perform pg_advisory_xact_lock(83219);
 if exists(select 1 from public.perfiles where rol='admin') then return false;end if;
 if not exists(select 1 from auth.users u join ops_private.administracion_inicial a on lower(u.email)=a.email where u.id=auth.uid() and u.email_confirmed_at is not null) then return false;end if;
 update public.perfiles set rol='admin',activo=true where user_id=auth.uid();return found;
end $$;
revoke all on function public.activar_administrador_inicial() from public,anon;
grant execute on function public.activar_administrador_inicial() to authenticated;
revoke all on function public.nuevo_usuario(),public.estatus_reporte(text) from public,anon,authenticated;
alter table public.parquimetros add column estado text not null default 'operativo' check(estado in ('operativo','falla_reportada','falla_confirmada','mantenimiento')),add column revisado_at timestamptz;
create table public.mantenimiento (
 id uuid primary key default gen_random_uuid(),parquimetro_id text not null references public.parquimetros(id),
 nota text not null,autor_id uuid not null references public.perfiles(user_id),creado timestamptz not null default now()
);
alter table public.mantenimiento enable row level security;
grant select on public.mantenimiento to authenticated;
create policy mantenimiento_lectura on public.mantenimiento for select to authenticated using(public.es_staff());
create table public.auditoria (
 id bigint generated always as identity primary key,autor_id uuid,accion text not null,entidad text not null,referencia text not null,creado timestamptz not null default now()
);
alter table public.auditoria enable row level security;
grant select on public.auditoria to authenticated;
create policy auditoria_admin on public.auditoria for select to authenticated using(public.es_admin());
create or replace function public.auditar_operacion() returns trigger
language plpgsql security definer set search_path='' as $$begin
 insert into public.auditoria(autor_id,accion,entidad,referencia) values(auth.uid(),tg_op,tg_table_name,case when tg_table_name='multas' then to_jsonb(new)->>'folio' when tg_table_name='perfiles' then to_jsonb(new)->>'user_id' else coalesce(to_jsonb(new)->>'id','') end);
 return new;
end $$;
revoke all on function public.auditar_operacion() from public,anon,authenticated;
create trigger aud_multas after insert or update on public.multas for each row execute function public.auditar_operacion();
create trigger aud_perfiles after update on public.perfiles for each row execute function public.auditar_operacion();
create trigger aud_reportes after insert or update on public.reportes for each row execute function public.auditar_operacion();
create trigger aud_mantenimiento after insert on public.mantenimiento for each row execute function public.auditar_operacion();
create or replace function public.actualizar_estado_aparato() returns trigger
language plpgsql security definer set search_path='' as $$begin
 if tg_op='INSERT' then update public.parquimetros set estado='falla_reportada' where id=new.parquimetro_id and estado='operativo';
 elsif new.estatus='procedente' and old.estatus is distinct from new.estatus then update public.parquimetros set estado='falla_confirmada',revisado_at=now() where id=new.parquimetro_id;
 elsif new.estatus='improcedente' and old.estatus is distinct from new.estatus then update public.parquimetros set estado='operativo',revisado_at=now() where id=new.parquimetro_id and estado='falla_reportada' and not exists(select 1 from public.reportes where parquimetro_id=new.parquimetro_id and estatus='pendiente' and id<>new.id);
 end if;return new;
end $$;
revoke all on function public.actualizar_estado_aparato() from public,anon,authenticated;
create trigger reportes_estado after insert or update of estatus on public.reportes for each row execute function public.actualizar_estado_aparato();
create or replace function public.restablecer_aparato(p_parq text,p_nota text) returns void
language plpgsql security definer set search_path='' as $$begin
 if auth.uid() is null or not public.es_admin() then raise exception 'Solo Administración';end if;
 if length(trim(coalesce(p_nota,'')))<10 then raise exception 'Describe la reparación y prueba de funcionamiento';end if;
 update public.parquimetros set estado='operativo',revisado_at=now() where id=p_parq;
 if not found then raise exception 'Aparato no encontrado';end if;
 insert into public.mantenimiento(parquimetro_id,nota,autor_id) values(p_parq,left(p_nota,2000),auth.uid());
end $$;
revoke all on function public.restablecer_aparato(text,text) from public,anon;
grant execute on function public.restablecer_aparato(text,text) to authenticated;
create or replace function public.cambiar_acceso(p_usuario uuid,p_activo boolean) returns void
language plpgsql security definer set search_path='' as $$begin
 if auth.uid() is null or not public.es_admin() then raise exception 'Solo Administración';end if;
 if p_usuario=auth.uid() then raise exception 'No puedes desactivar tu propia cuenta';end if;
 update public.perfiles set activo=p_activo where user_id=p_usuario and rol='inspector';
 if not found then raise exception 'Operador no encontrado';end if;
 if not p_activo then update public.turnos set fin=now() where operador_id=p_usuario and fin is null;update public.perfiles set lat=null,lng=null,ubicacion_at=null,precision_m=null where user_id=p_usuario;end if;
end $$;
revoke all on function public.cambiar_acceso(uuid,boolean) from public,anon;
grant execute on function public.cambiar_acceso(uuid,boolean) to authenticated;
-- Evita cambios de rol por el endpoint genérico: no hacen falta para la operación diaria.
revoke update on public.perfiles from anon,authenticated;
-- Índices de rutas frecuentes.
create index alertas_inspector_reporte on public.alertas(inspector_id,reporte_id);
create index reportes_placa_creado on public.reportes(placa,creado desc);
create index turnos_operador_inicio on public.turnos(operador_id,inicio desc);
create index mantenimiento_parq_fecha on public.mantenimiento(parquimetro_id,creado desc);
commit;
