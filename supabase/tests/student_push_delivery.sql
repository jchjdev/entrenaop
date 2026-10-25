begin;
set local statement_timeout='90s';
-- El contrato se prueba también con Dev activado, sin depender de su ajuste
-- operativo ni dejarlo apagado al terminar el ROLLBACK.
do $$begin
 if (select pg_get_expr(d.adbin,d.adrelid)
     from pg_attrdef d join pg_attribute a
       on a.attrelid=d.adrelid and a.attnum=d.adnum
     where d.adrelid='push_private.settings'::regclass and a.attname='enabled')
    is distinct from 'false' then
   raise exception 'El esquema activa push por defecto';
 end if;
end $$;
update push_private.settings set enabled=false,firebase_project_id=null where singleton;
-- Las altas reales ya pueden tener trabajos pendientes. Se apartan solo dentro
-- de esta transacción para que claim_jobs pruebe los fixtures; ROLLBACK devuelve
-- sus fechas originales y nunca consume avisos de usuarios reales.
update push_private.outbox set next_at=clock_timestamp()+interval '1 day'
 where generation>delivered_generation;
do $$
declare a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();coach uuid:=gen_random_uuid();relation uuid:=gen_random_uuid();
 device uuid:=gen_random_uuid();binding_a uuid:=gen_random_uuid();binding_b uuid:=gen_random_uuid();secret text:=repeat('a',64);
 event uuid:=gen_random_uuid();job jsonb;result jsonb;before_generation bigint;idx integer;limit_device uuid;limit_binding uuid;limit_token text;
begin
 insert into auth.users(id,email) values(a,a||'@push.invalid'),(b,b||'@push.invalid'),(coach,coach||'@push.invalid');
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(coach,true,5,'Avisos');
 insert into public.trainer_client_relations(id,trainer_id,client_id) values(relation,coach,a);
 perform set_config('request.jwt.claim.sub',a::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated','aal','aal1')::text,true);
 set local role authenticated;
 if (public.get_my_push_configuration(a)->>'enabled')::boolean then raise exception 'Activa push por defecto';end if;
 begin perform public.register_my_push_device(a,device,secret,binding_a,null,repeat('X',22),'ios');raise exception 'Registra con función apagada';exception when object_not_in_prerequisite_state then null;end;
 reset role;
 update push_private.settings set enabled=true,firebase_project_id='push-fixture' where singleton;
 set local role authenticated;
 result:=public.register_my_push_device(a,device,secret,binding_a,null,repeat('X',22),'ios');
 if public.register_my_push_device(a,device,secret,binding_a,null,repeat('X',22),'ios') is distinct from result then raise exception 'Duplica asociación confirmada';end if;
 begin perform public.get_my_push_device(b,device,secret);raise exception 'Cambia identidad esperada';exception when insufficient_privilege then null;end;
 begin perform public.get_my_push_device(a,device,repeat('b',64));raise exception 'Lee sin secreto de instalación';exception when insufficient_privilege then null;end;
 begin perform public.unregister_my_push_device(a,device,null,binding_a);raise exception 'Revoca sin secreto';exception when invalid_parameter_value then null;end;
 begin perform count(*) from push_private.installations;raise exception 'Lee direcciones directamente';exception when insufficient_privilege then null;end;
 begin perform public.claim_student_push_jobs(5);raise exception 'El alumno usa worker';exception when insufficient_privilege then null;end;
 reset role;
 update push_private.outbox set next_at=clock_timestamp()-interval '1 second' where installation_id=device;
 set local role service_role;
 job:=public.claim_student_push_jobs(5)->0;
 if job is null or public.prepare_student_push_job(device,(job->>'claim_id')::uuid,(job->>'generation')::bigint,binding_a) then raise exception 'Anuncia sin avisos pendientes';end if;
 perform public.finish_student_push_job(device,(job->>'claim_id')::uuid,(job->>'generation')::bigint,binding_a,'skipped');
 reset role;
 insert into trainer_private.student_notices(id,owner_id,relation_id,kind,source_id) values(event,a,relation,'message',gen_random_uuid());
 update push_private.outbox set next_at=clock_timestamp()-interval '1 second' where installation_id=device;
 set local role service_role;
 job:=public.claim_student_push_jobs(5)->0;
 if not public.prepare_student_push_job(device,(job->>'claim_id')::uuid,(job->>'generation')::bigint,binding_a) then raise exception 'No prepara aviso propio';end if;
 if public.claim_student_push_jobs(5)<>'[]'::jsonb then raise exception 'Reclama dos veces el mismo lease';end if;
 reset role;
 insert into trainer_private.student_notices(owner_id,relation_id,kind,source_id) values(a,relation,'form',gen_random_uuid());
 set local role service_role;
 perform public.finish_student_push_job(device,(job->>'claim_id')::uuid,(job->>'generation')::bigint,binding_a,'sent');
 reset role;
 if not exists(select 1 from push_private.outbox where installation_id=device and generation>delivered_generation) then raise exception 'Pierde novedad durante envío';end if;
 update push_private.outbox set next_at=clock_timestamp()-interval '1 second' where installation_id=device;
 set local role service_role;
 job:=public.claim_student_push_jobs(5)->0;
 reset role;
 update push_private.outbox set lease_until=clock_timestamp()-interval '1 second' where installation_id=device;
 select delivered_generation into before_generation from push_private.outbox where installation_id=device;
 set local role service_role;
 perform public.finish_student_push_job(device,(job->>'claim_id')::uuid,(job->>'generation')::bigint,binding_a,'skipped');
 reset role;
 if (select delivered_generation from push_private.outbox where installation_id=device)<>before_generation then raise exception 'Acusa entrega de lease caducado';end if;
 perform set_config('request.jwt.claim.sub',b::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',b,'role','authenticated','aal','aal1')::text,true);
 set local role authenticated;
 result:=public.get_my_push_device(b,device,secret);
 if (result->>'owned')::boolean or result ? 'owner_id' or result ? 'token' then raise exception 'Expone cuenta o dirección anterior';end if;
 begin perform public.register_my_push_device(b,gen_random_uuid(),secret,binding_b,null,repeat('X',22),'ios');raise exception 'Secuestra dirección sin continuidad';exception when insufficient_privilege then null;end;
 perform public.register_my_push_device(b,device,secret,binding_b,binding_a,repeat('X',22),'ios');
 perform set_config('request.jwt.claim.sub',a::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated','aal','aal1')::text,true);
 begin perform public.register_my_push_device(a,device,secret,gen_random_uuid(),binding_a,repeat('X',22),'ios');raise exception 'Alta antigua vuelve a A después de B';exception when serialization_failure then null;end;
 begin perform public.unregister_my_push_device(a,device,secret,binding_a);raise exception 'Baja de A desactiva B';exception when insufficient_privilege then null;end;
 reset role;
 set local role service_role;
 if public.prepare_student_push_job(device,(job->>'claim_id')::uuid,(job->>'generation')::bigint,binding_a) then raise exception 'Lease anterior autoriza enviar a nueva cuenta';end if;
 perform public.retire_invalid_push_device(device,binding_a);
 reset role;
 if not exists(select 1 from push_private.installations where id=device and owner_id=b and active) then raise exception 'Token inválido antiguo retira B';end if;
 set local role authenticated;
 for idx in 1..5 loop
  perform public.register_my_push_device(a,gen_random_uuid(),secret,gen_random_uuid(),null,repeat('Y',22)||idx,'android');
 end loop;
 begin perform public.register_my_push_device(a,gen_random_uuid(),secret,gen_random_uuid(),null,repeat('Y',22)||6,'android');raise exception 'Supera cinco dispositivos activos';exception when program_limit_exceeded then null;end;
 reset role;
 -- Una transferencia también respeta los veinte registros retenidos del destino.
 insert into push_private.installations(id,owner_id,secret_hash,binding_id,platform,active)
 select gen_random_uuid(),b,encode(extensions.digest(secret,'sha256'),'hex'),gen_random_uuid(),'ios',false
 from generate_series(1,19);
 select id,binding_id,token into strict limit_device,limit_binding,limit_token
 from push_private.installations where owner_id=a order by id limit 1;
 perform set_config('request.jwt.claim.sub',b::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',b,'role','authenticated','aal','aal1')::text,true);
 set local role authenticated;
 begin
  perform public.register_my_push_device(b,limit_device,secret,gen_random_uuid(),limit_binding,limit_token,'ios');
  raise exception 'Una transferencia supera veinte dispositivos conservados';
 exception when program_limit_exceeded then null;end;
 reset role;
 if (select owner_id from push_private.installations where id=limit_device)<>a then raise exception 'Transfiere aunque el destino está lleno';end if;
 if has_function_privilege('anon','public.get_my_push_configuration(uuid)','execute') or
  has_function_privilege('authenticated','public.get_student_push_worker_configuration()','execute') then raise exception 'Expone worker o configuración anónima';end if;
end $$;
select 'student_push_delivery: OK' as result;
rollback;
