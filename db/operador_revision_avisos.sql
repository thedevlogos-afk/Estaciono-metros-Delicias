begin;

create table public.avisos_aparato (
 id uuid primary key default gen_random_uuid(),
 parquimetro_id text not null references public.parquimetros(id),
 operador_id uuid not null references public.perfiles(user_id),
 motivo text not null check (motivo in ('no_acepta_monedas','moneda_no_registrada','sin_corriente','pantalla','botones','dano_fisico','otro')),
 detalle text not null check (length(btrim(detalle)) between 10 and 1000),
 estatus text not null default 'recibido' check (estatus in ('recibido','en_revision','atendido')),
 creado timestamptz not null default now(),
 revisado_por uuid references public.perfiles(user_id),
 revisado_at timestamptz,
 atendido_por uuid references public.perfiles(user_id),
 atendido_at timestamptz
);
create index avisos_aparato_estado_fecha on public.avisos_aparato(estatus,creado desc);
create index avisos_aparato_parquimetro_fecha on public.avisos_aparato(parquimetro_id,creado desc);
alter table public.avisos_aparato enable row level security;
revoke all on public.avisos_aparato from public,anon,authenticated;
grant select on public.avisos_aparato to authenticated;
create policy avisos_aparato_lectura on public.avisos_aparato
 for select to authenticated
 using (public.es_admin() or (public.es_staff() and operador_id=auth.uid()));

create or replace function public.reportar_falla_operador(p_parq text,p_motivo text,p_detalle text) returns uuid
language plpgsql security definer set search_path=''
as $$
declare v_id uuid;
begin
 if auth.uid() is null or not exists (
  select 1 from public.perfiles p
  where p.user_id=auth.uid() and p.rol='inspector' and p.activo
 ) then raise exception 'Solo un operador activo puede reportar desde campo'; end if;
 if not exists(select 1 from public.turnos t where t.operador_id=auth.uid() and t.fin is null) then raise exception 'Inicia un turno'; end if;
 if p_motivo is null or p_motivo not in ('no_acepta_monedas','moneda_no_registrada','sin_corriente','pantalla','botones','dano_fisico','otro')
   or length(btrim(coalesce(p_detalle,''))) not between 10 and 1000 then raise exception 'Revisa el tipo y detalle de la falla'; end if;
 if not exists(select 1 from public.parquimetros q where q.id=p_parq and q.activo) then raise exception 'Parquímetro no disponible'; end if;
 insert into public.avisos_aparato(parquimetro_id,operador_id,motivo,detalle)
 values(p_parq,auth.uid(),p_motivo,left(btrim(p_detalle),1000)) returning id into v_id;
 update public.parquimetros set estado='falla_reportada',revisado_at=now()
 where id=p_parq and estado='operativo';
 insert into public.auditoria(autor_id,accion,entidad,referencia)
 values(auth.uid(),'reporte_falla_operador','avisos_aparato',v_id::text);
 return v_id;
end $$;

create or replace function public.gestionar_aviso_aparato(p_id uuid,p_estatus text) returns void
language plpgsql security definer set search_path=''
as $$
begin
 if auth.uid() is null or not public.es_admin() then raise exception 'Solo Administración'; end if;
 if p_estatus<>'en_revision' then raise exception 'Estado de seguimiento inválido'; end if;
 update public.avisos_aparato
 set estatus='en_revision',revisado_por=auth.uid(),revisado_at=now()
 where id=p_id and estatus='recibido';
 if not found then raise exception 'Aviso inexistente o ya atendido'; end if;
 insert into public.auditoria(autor_id,accion,entidad,referencia)
 values(auth.uid(),'aviso_tomado_revision','avisos_aparato',p_id::text);
end $$;

create or replace function public.restablecer_aparato(p_parq text,p_nota text) returns void
language plpgsql security definer set search_path=''
as $$
begin
 if auth.uid() is null or not public.es_admin() then raise exception 'Solo Administración'; end if;
 if length(trim(coalesce(p_nota,'')))<10 then raise exception 'Describe la reparación y prueba de funcionamiento'; end if;
 update public.parquimetros set estado='operativo',revisado_at=now() where id=p_parq;
 if not found then raise exception 'Aparato no encontrado'; end if;
 insert into public.mantenimiento(parquimetro_id,nota,autor_id)
 values(p_parq,left(p_nota,2000),auth.uid());
 update public.avisos_aparato
 set estatus='atendido',atendido_por=auth.uid(),atendido_at=now()
 where parquimetro_id=p_parq and estatus in ('recibido','en_revision');
end $$;

revoke all on function public.reportar_falla_operador(text,text,text),public.gestionar_aviso_aparato(uuid,text),public.restablecer_aparato(text,text) from public,anon;
grant execute on function public.reportar_falla_operador(text,text,text),public.gestionar_aviso_aparato(uuid,text),public.restablecer_aparato(text,text) to authenticated;
commit;
