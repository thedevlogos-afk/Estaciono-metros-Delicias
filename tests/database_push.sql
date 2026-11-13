begin;
select set_config('test.op',gen_random_uuid()::text,true),set_config('test.other',gen_random_uuid()::text,true);
insert into auth.users(id,aud,role,email,email_confirmed_at,raw_user_meta_data,created_at,updated_at) values(current_setting('test.op')::uuid,'authenticated','authenticated','push-check@example.invalid',now(),'{}',now(),now()),(current_setting('test.other')::uuid,'authenticated','authenticated','push-other@example.invalid',now(),'{}',now(),now());
update public.perfiles set activo=true where user_id in(current_setting('test.op')::uuid,current_setting('test.other')::uuid);
set local role authenticated;
select set_config('request.jwt.claims',json_build_object('sub',current_setting('test.op'),'role','authenticated')::text,true);
do $$declare blocked boolean:=false;x uuid;begin
 begin perform public.registrar_push('https://127.0.0.1/private',repeat('A',87),repeat('A',22));exception when others then blocked:=SQLERRM like '%inválida%';end;
 if not blocked then raise exception 'Aceptó destino privado';end if;
 x:=public.registrar_push('https://fcm.googleapis.com/fcm/send/test-transaccional',repeat('A',87),repeat('A',22));
 if public.registrar_push('https://fcm.googleapis.com/fcm/send/test-transaccional',repeat('A',87),repeat('A',22))<>x then raise exception 'Suscripción no idempotente';end if;
 perform public.registrar_push_nativo(repeat('T',150));
 if (select count(*) from public.push_dispositivos)<>2 then raise exception 'No registró tipos web/nativo';end if;
 blocked:=false;begin perform public.push_reclamar('clave-invalida');exception when others then blocked:=true;end;
 if not blocked then raise exception 'Cola expuesta';end if;
end $$;
select set_config('request.jwt.claims',json_build_object('sub',current_setting('test.other'),'role','authenticated')::text,true);
do $$declare blocked boolean:=false;begin
 if exists(select 1 from public.push_dispositivos) then raise exception 'Puede leer otro dispositivo';end if;
 begin perform public.registrar_push('https://fcm.googleapis.com/fcm/send/test-transaccional',repeat('A',87),repeat('A',22));exception when others then blocked:=SQLERRM like '%otra sesión%';end;
 if not blocked then raise exception 'Robo de suscripción';end if;
end $$;
reset role;
select 'OK: RLS, destinos, idempotencia, token nativo y secreto de cola' as verificacion;
rollback;
