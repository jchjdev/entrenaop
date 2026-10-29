-- Metadatos sintéticos: no hay archivos/Bunny reales ni cambios persistentes.
begin;
set local statement_timeout='90s';
-- Repetible aunque el servicio real ya esté activo: este cambio no sale del
-- ROLLBACK y comprueba el comportamiento deshabilitado sin apagarlo fuera.
update trainer_private.media_cleanup_settings set enabled=false where singleton;
do $$
declare actor uuid:=gen_random_uuid();other uuid:=gen_random_uuid();sid uuid:=gen_random_uuid();other_sid uuid:=gen_random_uuid();factor uuid:=gen_random_uuid();
 image_op uuid:=gen_random_uuid();path_a text;path_b text;path_c text;exercise uuid;work uuid:=gen_random_uuid();draft jsonb;raw jsonb;claims jsonb;
 job uuid;lease_a uuid:=gen_random_uuid();lease_b uuid:=gen_random_uuid();result jsonb;report jsonb;batch jsonb;before_count integer;stamp timestamptz;cascade_owner uuid:=gen_random_uuid();
begin
 insert into auth.users(id,email) values(actor,actor||'@media-cleanup.invalid'),(other,other||'@media-cleanup.invalid'),(cascade_owner,cascade_owner||'@media-cleanup.invalid');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values(factor,actor,'totp','verified',now(),now()),(gen_random_uuid(),other,'totp','verified',now(),now());
 insert into auth.sessions(id,user_id,created_at,updated_at) values(sid,actor,now(),now()),(other_sid,other,now(),now());
 insert into public.admin_permissions(user_id) values(actor);
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(actor,true,1,'Ensayo medios'),(other,true,1,'Aislamiento');
 claims:=jsonb_build_object('sub',actor,'session_id',sid,'aal','aal2','role','authenticated');
 perform set_config('request.jwt.claim.sub',actor::text,true);perform set_config('request.jwt.claims',claims::text,true);
 set local role authenticated;
 path_a:=public.reserve_trainer_exercise_image(image_op);path_b:=public.reserve_trainer_exercise_image(gen_random_uuid());
 insert into storage.objects(bucket_id,name) values('trainer-exercise-images',path_a),('trainer-exercise-images',path_b);
 draft:=jsonb_build_object('name','Imagen protegida','description','','video_url',null,'muscle_groups',jsonb_build_array('piernas'),'equipment',jsonb_build_array('ninguno'),
  'difficulty','inicial','exercise_type','repeticiones','image_path',path_b);
 exercise:=public.save_trainer_exercise(gen_random_uuid(),draft);
 -- El body existe en caché, pero el trabajo está descartado antes del barrido.
 raw:=jsonb_build_object('schema',1,'name','Trabajo de foto','description',path_a,'audience','','equipment','','mode','guide','categories','[]'::jsonb,'primary',null,
  'phases',jsonb_build_array(jsonb_build_object('name','','weeks','','instructions','','pending','[]'::jsonb,'replacements','{}'::jsonb,'sessions','[]'::jsonb)));
 perform public.save_trainer_program_work(actor,work,0,raw);
 perform public.discard_trainer_program_work(actor,work,1);
 reset role;
 update trainer_private.exercise_images set created_at=clock_timestamp()-interval '7 days' where trainer_id=actor;
 set local role authenticated;
 report:=public.sweep_exercise_media_cleanup(gen_random_uuid(),'trainer');
 if jsonb_array_length(report->'items')<>2 or(report->>'queued')::integer<>1 then raise exception 'El barrido mezcla imagen sin usos y protegida';end if;
 report:=public.list_exercise_media_cleanup('trainer');
 if(report->'summary'->>'protected')::integer<>1 or strpos(report::text,path_a)>0 then raise exception 'Resumen incorrecto o revela ruta interna';end if;
 select(j->>'job_id')::uuid into job from jsonb_array_elements(report->'items')j where j->>'state'='queued';
 perform set_config('request.jwt.claims',(claims||'{"role":"service_role"}')::text,true);set local role service_role;
 if public.claim_exercise_media_cleanup(3,actor,lease_a,'trainer')<>'[]'::jsonb then raise exception 'La migración activa limpieza por defecto';end if;
 reset role;
 update trainer_private.media_cleanup_settings set enabled=true;
 update public.trainer_access set enabled=false where trainer_id=actor;
 perform set_config('request.jwt.claims',claims::text,true);set local role authenticated;
 if public.list_exercise_media_cleanup('trainer')->'summary'->>'pending'<>'1' then raise exception 'Exige suscripción activa para limpiar propios';end if;
 perform set_config('request.jwt.claims',(claims||'{"role":"service_role"}')::text,true);set local role service_role;
 batch:=public.claim_exercise_media_cleanup(3,actor,lease_a,'trainer');
 if jsonb_array_length(batch)<>1 or(batch->0->>'job_id')::uuid<>job or batch->0->>'state'<>'deleting' then raise exception 'No reclama solo huérfana';end if;
 perform public.finish_exercise_media_cleanup(job,lease_a,false,'not_confirmed');
 reset role;
 if(select image_used from trainer_private.exercise_limits where trainer_id=actor)<>2 then raise exception 'Fallo externo libera cuota';end if;
 update public.trainer_access set enabled=true where trainer_id=actor;
 perform set_config('request.jwt.claims',claims::text,true);set local role authenticated;
 begin perform public.save_trainer_exercise(gen_random_uuid(),draft||jsonb_build_object('name','Intento tras cierre','image_path',path_a));raise exception 'Revive imagen pendiente';exception when invalid_parameter_value then null;end;
 begin perform public.save_trainer_program_work(actor,gen_random_uuid(),0,raw);raise exception 'Reabre caché cerrada como referencia viva';exception when invalid_parameter_value then null;end;
 reset role;
 update trainer_private.media_cleanup_jobs set available_at=clock_timestamp()-interval '1 minute' where id=job;
 perform set_config('request.jwt.claims',(claims||'{"role":"service_role"}')::text,true);set local role service_role;
 batch:=public.claim_exercise_media_cleanup(3,actor,lease_b,'trainer');
 begin perform public.finish_exercise_media_cleanup(job,lease_a,true);raise exception 'Acepta lease ajeno';exception when insufficient_privilege then null;end;
 begin perform public.finish_exercise_media_cleanup(job,lease_b,true);raise exception 'Libera cuota con objeto registrado';exception when invalid_parameter_value then null;end;
 -- Simula únicamente la ausencia de metadata de un archivo ficticio, tras el
 -- DELETE externo que haría el worker. Nunca se usa así en código de producto.
 perform set_config('storage.allow_delete_query','true',true);
 delete from storage.objects where bucket_id='trainer-exercise-images' and name=path_a;
 perform set_config('storage.allow_delete_query','false',true);
 result:=public.finish_exercise_media_cleanup(job,lease_b,true);
 if public.finish_exercise_media_cleanup(job,lease_b,true)<>result then raise exception 'ACK duplicado cambia recibo';end if;
 reset role;
 if(select image_used from trainer_private.exercise_limits where trainer_id=actor)<>1 then raise exception 'No libera exactamente una reserva';end if;
 perform set_config('request.jwt.claims',claims::text,true);set local role authenticated;
 begin perform public.reserve_trainer_exercise_image(image_op);raise exception 'Reutiliza operación de imagen borrada';exception when invalid_parameter_value then null;end;
 begin perform public.save_trainer_program_work(actor,gen_random_uuid(),0,raw);raise exception 'Body histórico revive foto borrada';exception when invalid_parameter_value then null;end;
 report:=public.list_exercise_media_cleanup('trainer');
 if(report->'summary'->>'freed_images')::integer<>1 or(report->'summary'->>'freed_bytes')::bigint<>0 then raise exception 'Mezcla cuota de fotos y bytes físicos';end if;
 -- Una purga nueva encola sin esperar al barrido de 24 horas.
 path_c:=public.reserve_trainer_exercise_image(gen_random_uuid());insert into storage.objects(bucket_id,name) values('trainer-exercise-images',path_c);
 exercise:=public.save_trainer_exercise(gen_random_uuid(),draft||jsonb_build_object('name','Imagen de purga','image_path',path_c));
 result:=public.trash_trainer_catalog_item(gen_random_uuid(),'exercise',exercise);stamp:=(result->>'trashed_at')::timestamptz;
 perform public.purge_trainer_catalog_item(gen_random_uuid(),'exercise',exercise,stamp);
 reset role;
 if not exists(select 1 from trainer_private.media_cleanup_jobs where path=path_c and state='queued') then raise exception 'Purga sin outbox de imagen';end if;
 -- JWT de sesión revocada no puede pedir borrados aunque aún tenga AAL2.
 delete from auth.sessions where id=sid;
 perform set_config('request.jwt.claims',claims::text,true);set local role authenticated;
 begin perform public.queue_exercise_media_cleanup(gen_random_uuid(),'trainer','image',path_b);raise exception 'Acepta sesión revocada';exception when insufficient_privilege then null;end;
 reset role;
 insert into auth.sessions(id,user_id,created_at,updated_at) values(sid,actor,now(),now());
 perform set_config('request.jwt.claim.sub',other::text,true);perform set_config('request.jwt.claims',jsonb_build_object('sub',other,'session_id',other_sid,'aal','aal2','role','authenticated')::text,true);
 set local role authenticated;
 begin perform public.queue_exercise_media_cleanup(gen_random_uuid(),'trainer','image',path_b);raise exception 'Borra archivo ajeno';exception when insufficient_privilege then null;end;
 begin perform public.list_exercise_media_cleanup('official');raise exception 'Trainer consulta limpieza oficial';exception when insufficient_privilege then null;end;
 reset role;
 -- La guarda de tombstones no rompe la cascada preexistente del propietario.
 insert into trainer_private.exercise_limits(trainer_id,image_used) values(cascade_owner,1);
 insert into trainer_private.exercise_images(id,trainer_id,path) values(gen_random_uuid(),cascade_owner,cascade_owner::text||'/'||gen_random_uuid()::text||'.jpg');
 delete from public.profiles where id=cascade_owner;
 if exists(select 1 from trainer_private.exercise_images where trainer_id=cascade_owner) then raise exception 'Bloquea cascada del propietario';end if;
 if has_function_privilege('authenticated','public.finish_exercise_media_cleanup(uuid,uuid,boolean,text)','execute')
  or has_function_privilege('anon','public.list_exercise_media_cleanup(text,timestamptz,uuid,integer)','execute')
  or has_table_privilege('service_role','trainer_private.media_cleanup_jobs','update') then raise exception 'Expone privilegios de limpieza';end if;
end $$;
rollback;
