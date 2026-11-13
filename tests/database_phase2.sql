begin;
select set_config('test.owner',gen_random_uuid()::text,true),set_config('test.op',gen_random_uuid()::text,true),set_config('test.parq',(select id from public.parquimetros where activo order by id limit 1),true),set_config('test.had_admin',(select count(*)::text from public.perfiles where rol='admin'),true);
insert into ops_private.administracion_inicial(email) values('owner-check@example.invalid');
insert into auth.users(id,aud,role,email,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values(current_setting('test.owner')::uuid,'authenticated','authenticated','owner-check@example.invalid',now(),'{}','{"nombre":"Prueba propietario"}',now(),now()),(current_setting('test.op')::uuid,'authenticated','authenticated','op-check@example.invalid',now(),'{}','{"nombre":"Prueba operador","rol":"admin","activo":true}',now(),now());
set local role authenticated;
select set_config('request.jwt.claims',json_build_object('sub',current_setting('test.op'),'role','authenticated')::text,true);
do $$begin
 if public.activar_administrador_inicial() then raise exception 'Otro correo obtiene admin';end if;
 if public.es_staff() then raise exception 'Metadatos dieron privilegios';end if;
end $$;
select set_config('request.jwt.claims',json_build_object('sub',current_setting('test.owner'),'role','authenticated')::text,true);
do $$declare activated boolean;begin
 if current_setting('test.had_admin')='0' then
 activated:=public.activar_administrador_inicial();
 if not activated then raise exception 'Propietario verificado no puede activar';end if;
 if not public.es_admin() then raise exception 'Activación no refleja permiso';end if;
 if public.activar_administrador_inicial() then raise exception 'Bootstrap no es de una sola ocasión';end if;
 end if;
end $$;
reset role;
-- Para los demás tests, perfil sintético de admin aun cuando producción ya tenga uno.
update public.perfiles set rol='admin',activo=true where user_id=current_setting('test.owner')::uuid;
insert into public.tarifas(motivo,fundamento,monto,activa) values('SOLO PRUEBA','Prueba transaccional, no vigente',1,true) returning set_config('test.tarifa',id::text,true);
set local role authenticated;
select set_config('request.jwt.claims',json_build_object('sub',current_setting('test.owner'),'role','authenticated')::text,true);
select public.cambiar_acceso(current_setting('test.op')::uuid,true);
select set_config('request.jwt.claims',json_build_object('sub',current_setting('test.op'),'role','authenticated')::text,true);
select public.turno_operador('iniciar');select public.ubicacion_operador(28.1895,-105.4715,10);
do $$declare blocked boolean:=false;begin
 begin perform public.cambiar_acceso(current_setting('test.owner')::uuid,false);exception when others then blocked:=SQLERRM like '%Solo Administración%';end;
 if not blocked then raise exception 'Operador administra accesos';end if;
end $$;
select set_config('request.jwt.claims',json_build_object('sub',current_setting('test.owner'),'role','authenticated')::text,true);
select public.cambiar_acceso(current_setting('test.op')::uuid,false);
do $$declare r jsonb;rid uuid;blocked boolean:=false;begin
 if exists(select 1 from public.turnos where operador_id=current_setting('test.op')::uuid and fin is null) then raise exception 'Suspensión no cerró turno';end if;
 if exists(select 1 from public.perfiles where user_id=current_setting('test.op')::uuid and (lat is not null or lng is not null)) then raise exception 'Suspensión no limpió GPS';end if;
 r:=public.reportar_falla_v2(gen_random_uuid(),gen_random_uuid(),current_setting('test.parq'),'Prueba reparación','','','','CHECK123',0);
 select id into rid from public.reportes where folio=r->>'folio';
 perform public.atender_reporte(rid,'procedente','Falla confirmada en prueba transaccional');
 if not exists(select 1 from public.parquimetros where id=current_setting('test.parq') and estado='falla_confirmada') then raise exception 'Estado de falla no actualizado';end if;
 perform public.turno_operador('iniciar');
 begin perform public.emitir_multa(gen_random_uuid(),current_setting('test.parq'),'CHECK999',current_setting('test.tarifa')::uuid);exception when others then blocked:=SQLERRM like '%falla confirmada%';end;
 if not blocked then raise exception 'Aparato fallando admite multa';end if;
 perform public.restablecer_aparato(current_setting('test.parq'),'Prueba: reparación realizada y pantalla verificada');
 if not exists(select 1 from public.parquimetros where id=current_setting('test.parq') and estado='operativo') then raise exception 'No restableció aparato';end if;
 if not exists(select 1 from public.mantenimiento where parquimetro_id=current_setting('test.parq')) then raise exception 'No registró mantenimiento';end if;
 perform public.emitir_multa(gen_random_uuid(),current_setting('test.parq'),'CHECK999',current_setting('test.tarifa')::uuid);
 if not exists(select 1 from public.auditoria where entidad='mantenimiento') then raise exception 'Auditoría no registrada';end if;
end $$;
select set_config('request.jwt.claims',json_build_object('sub',current_setting('test.op'),'role','authenticated')::text,true);
do $$begin if exists(select 1 from public.auditoria) then raise exception 'Operador lee auditoría';end if;end $$;
reset role;
select 'OK: bootstrap verificado, metadatos sin privilegios, suspensión con cierre/GPS, reparación, multa posterior y auditoría protegida' as verificacion;
rollback;
