-- Complemento pendiente de aplicar y verificar antes de publicar el frontend.
begin;
create table public.ordenes_mantenimiento (
 id uuid primary key default gen_random_uuid(),
 parquimetro_id text not null references public.parquimetros(id),
 responsable_id uuid not null references public.perfiles(user_id),
 programado date not null,
 actividad text not null check(length(btrim(actividad)) between 10 and 1000),
 estado text not null default 'programada' check(estado in ('programada','en_atencion','por_validar','cerrada','cancelada')),
 resultado text,
 creado_por uuid not null default auth.uid() references public.perfiles(user_id),
 creado timestamptz not null default now(),
 actualizado timestamptz not null default now()
);
create table public.ordenes_eventos (
 id uuid primary key default gen_random_uuid(),
 orden_id uuid not null references public.ordenes_mantenimiento(id),
 autor_id uuid not null references public.perfiles(user_id),
 estado text not null,
 nota text,
 creado timestamptz not null default now()
);
create index ordenes_responsable_estado on public.ordenes_mantenimiento(responsable_id,estado,programado);
create index ordenes_eventos_orden on public.ordenes_eventos(orden_id,creado);
alter table public.ordenes_mantenimiento enable row level security;
alter table public.ordenes_eventos enable row level security;
revoke all on public.ordenes_mantenimiento,public.ordenes_eventos from public,anon,authenticated;
grant select on public.ordenes_mantenimiento,public.ordenes_eventos to authenticated;
create policy ordenes_lectura on public.ordenes_mantenimiento for select to authenticated using(public.es_admin() or (public.es_staff() and responsable_id=auth.uid()));
create policy ordenes_eventos_lectura on public.ordenes_eventos for select to authenticated using(exists(select 1 from public.ordenes_mantenimiento o where o.id=orden_id));
create function public.programar_mantenimiento(p_parq text,p_responsable uuid,p_fecha date,p_actividad text) returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
 if auth.uid() is null or not public.es_admin() then raise exception 'Solo Administración';end if;
 if p_fecha is null or not exists(select 1 from public.perfiles where user_id=p_responsable and rol='inspector' and activo) then raise exception 'Revisa fecha y responsable activo';end if;
 insert into public.ordenes_mantenimiento(parquimetro_id,responsable_id,programado,actividad) values(p_parq,p_responsable,p_fecha,btrim(p_actividad)) returning id into v_id;
 insert into public.ordenes_eventos(orden_id,autor_id,estado,nota) values(v_id,auth.uid(),'programada',p_actividad);
 return v_id;
end $$;
create function public.actualizar_orden_mantenimiento(p_id uuid,p_estado text,p_nota text) returns void language plpgsql security definer set search_path='' as $$
declare o public.ordenes_mantenimiento;v_admin boolean;
begin
 if auth.uid() is null then raise exception 'Inicia sesión';end if;
 v_admin:=public.es_admin();
 select * into o from public.ordenes_mantenimiento where id=p_id for update;
 if not found or not(v_admin or (public.es_staff() and o.responsable_id=auth.uid())) then raise exception 'Acceso denegado';end if;
 if length(btrim(coalesce(p_nota,'')))<10 then raise exception 'Describe la acción con al menos 10 caracteres';end if;
 if not ((o.estado='programada' and p_estado='en_atencion') or (o.estado='en_atencion' and p_estado='por_validar') or (v_admin and o.estado='por_validar' and p_estado in ('cerrada','en_atencion')) or (v_admin and o.estado in ('programada','en_atencion','por_validar') and p_estado='cancelada')) then raise exception 'Transición inválida';end if;
 update public.ordenes_mantenimiento set estado=p_estado,resultado=btrim(p_nota),actualizado=now() where id=p_id;
 insert into public.ordenes_eventos(orden_id,autor_id,estado,nota) values(p_id,auth.uid(),p_estado,btrim(p_nota));
 if p_estado='cerrada' then insert into public.mantenimiento(parquimetro_id,nota,autor_id) values(o.parquimetro_id,btrim(p_nota),auth.uid());end if;
 -- Cerrar una orden preventiva no restablece automáticamente una falla del aparato.
end $$;
revoke all on function public.programar_mantenimiento(text,uuid,date,text),public.actualizar_orden_mantenimiento(uuid,text,text) from public,anon;
grant execute on function public.programar_mantenimiento(text,uuid,date,text),public.actualizar_orden_mantenimiento(uuid,text,text) to authenticated;
commit;
