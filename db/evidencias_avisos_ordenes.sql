begin;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('ordenes-evidencias','ordenes-evidencias',false,5242880,array['image/jpeg','image/png','image/webp']);
create policy evidencias_orden_lectura on storage.objects for select to authenticated using(bucket_id='ordenes-evidencias' and exists(select 1 from public.ordenes_mantenimiento o where o.id::text=(storage.foldername(name))[1]));
create policy evidencias_orden_alta on storage.objects for insert to authenticated with check(bucket_id='ordenes-evidencias' and exists(select 1 from public.ordenes_mantenimiento o where o.id::text=(storage.foldername(name))[1] and o.estado in ('programada','en_atencion','por_validar')));
create function ops_private.notificar_orden() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into ops_private.push_cola(dispositivo_id,evento,titulo,cuerpo,ruta)
 select d.id,'orden:'||new.id||':'||new.estado,'Mantenimiento actualizado','Hay una orden de mantenimiento que requiere tu revisión.',case when p.rol='admin' then '/admin' else '/panel?ver=alertas' end
 from public.push_dispositivos d join public.perfiles p on p.user_id=d.user_id
 where d.activo and p.activo and ((new.estado='por_validar' and p.rol='admin') or (new.estado<>'por_validar' and d.user_id=new.responsable_id)) on conflict do nothing;
 return new;
end $$;
revoke all on function ops_private.notificar_orden() from public,anon,authenticated;
create trigger orden_notificar after insert or update of estado on public.ordenes_mantenimiento for each row execute function ops_private.notificar_orden();
commit;
