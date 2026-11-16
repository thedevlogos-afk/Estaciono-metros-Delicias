begin;
create function public.reasignar_orden_mantenimiento(p_id uuid,p_responsable uuid,p_fecha date,p_nota text) returns void language plpgsql security definer set search_path='' as $$
declare o public.ordenes_mantenimiento;
begin
 if auth.uid() is null or not public.es_admin() then raise exception 'Solo Administración';end if;
 if p_fecha is null or length(btrim(coalesce(p_nota,'')))<10 then raise exception 'Revisa fecha y justificación';end if;
 if not exists(select 1 from public.perfiles where user_id=p_responsable and rol='inspector' and activo) then raise exception 'Responsable no disponible';end if;
 select * into o from public.ordenes_mantenimiento where id=p_id for update;
 if not found or o.estado in ('cerrada','cancelada') then raise exception 'Orden no disponible';end if;
 update public.ordenes_mantenimiento set responsable_id=p_responsable,programado=p_fecha,actualizado=now() where id=p_id;
 insert into public.ordenes_eventos(orden_id,autor_id,estado,nota) values(p_id,auth.uid(),o.estado,'Reasignación: '||o.responsable_id||' → '||p_responsable||'; fecha '||o.programado||' → '||p_fecha||'. '||btrim(p_nota));
end $$;
revoke all on function public.reasignar_orden_mantenimiento(uuid,uuid,date,text) from public,anon;
grant execute on function public.reasignar_orden_mantenimiento(uuid,uuid,date,text) to authenticated;
commit;
