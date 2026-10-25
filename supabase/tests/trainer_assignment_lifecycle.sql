begin;
set local statement_timeout='90s';

do $$
declare coach uuid:=gen_random_uuid();pupil uuid:=gen_random_uuid();other uuid:=gen_random_uuid();rel uuid:=gen_random_uuid();
 tpl uuid;exercise uuid;recipe jsonb;plain uuid:=gen_random_uuid();linked uuid:=gen_random_uuid();with_message uuid:=gen_random_uuid();
 performed uuid:=gen_random_uuid();op uuid:=gen_random_uuid();response jsonb;page jsonb;row jsonb;execution uuid;idx integer;extra uuid;
 notice_count bigint;source_before jsonb;source_after jsonb;
begin
 insert into auth.users(id,email) values(coach,coach||'@lifecycle.invalid'),(pupil,pupil||'@lifecycle.invalid'),(other,other||'@lifecycle.invalid');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values(gen_random_uuid(),coach,'totp','verified',now(),now()),(gen_random_uuid(),other,'totp','verified',now(),now());
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(coach,true,5,'Archivo y borrado con ROLLBACK');
 insert into public.trainer_client_relations(id,trainer_id,client_id) values(rel,coach,pupil);
 perform set_config('fixture.archive_coach',coach::text,true);perform set_config('fixture.archive_pupil',pupil::text,true);
 perform set_config('request.jwt.claim.sub',coach::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 exercise:=public.save_trainer_exercise(gen_random_uuid(),'{"name":"Ejercicio privado","description":"Ensayo","muscle_groups":["espalda"],"equipment":["barra"],"difficulty":"intermedio","exercise_type":"repeticiones"}');
 recipe:=jsonb_build_object('name','Sesión de archivo','blocks',jsonb_build_array(jsonb_build_object('name','Fuerza','format','straight_sets','rounds',1,'rest_after_seconds',0,
  'exercises',jsonb_build_array(jsonb_build_object('exercise_id',exercise,'sets',jsonb_build_array(jsonb_build_object('target_reps',8,'rest_after_seconds',60)))))));
 tpl:=public.save_trainer_workout(gen_random_uuid(),recipe);
 perform public.assign_trainer_workout(plain,rel,tpl,current_date,null);
 perform public.assign_trainer_workout(linked,rel,tpl,current_date,null);
 perform public.assign_trainer_workout(with_message,rel,tpl,current_date,null);
 perform public.assign_trainer_workout(performed,rel,tpl,current_date,null);
 begin perform public.change_trainer_assignment_lifecycle(coach,gen_random_uuid(),plain,0,'delete');raise exception 'Borra pauta pendiente';exception when invalid_parameter_value then null;end;
 perform public.cancel_trainer_assignment(plain);perform public.cancel_trainer_assignment(linked);perform public.cancel_trainer_assignment(with_message);
 reset role;
 select to_jsonb(s) into source_before from public.scheduled_workouts s where id=plain;
 select count(*) into notice_count from trainer_private.student_notices where owner_id=pupil;
 set local role authenticated;
 response:=public.change_trainer_assignment_lifecycle(coach,op,plain,0,'archive');
 if (response->>'archive_revision')::bigint<>1 or response->>'archived_at' is null then raise exception 'No archiva';end if;
 if public.change_trainer_assignment_lifecycle(coach,op,plain,0,'archive')<>response then raise exception 'Reintento de archivo no idempotente';end if;
 begin perform public.change_trainer_assignment_lifecycle(coach,op,plain,0,'restore');raise exception 'Reutiliza identidad con otro contenido';exception when invalid_parameter_value then null;end;
 begin perform public.change_trainer_assignment_lifecycle(coach,gen_random_uuid(),plain,0,'restore');raise exception 'Restaura revisión obsoleta';exception when serialization_failure then null;end;
 if exists(select 1 from jsonb_array_elements(public.list_trainer_assignments_filtered(coach,'current',pupil)) x where x->>'id'=plain::text) then raise exception 'Archivada visible en vista habitual';end if;
 page:=public.list_trainer_assignments_filtered(coach,'archived',pupil);
 if jsonb_array_length(page)<>1 or page->0->>'id'<>plain::text then raise exception 'Filtro archivadas incorrecto';end if;
 page:=public.list_trainer_client_agenda_filtered('archived',coach,pupil,current_date,current_date);
 if page->'items'->0->>'id'<>plain::text then raise exception 'Ficha no muestra archivada';end if;
 if not exists(select 1 from jsonb_array_elements(public.list_trainer_agenda_filtered(coach,'archived',current_date,current_date)) x where x->>'id'=plain::text) then raise exception 'Agenda no muestra archivada';end if;
 perform public.change_trainer_assignment_lifecycle(coach,gen_random_uuid(),plain,1,'restore');
 page:=public.list_trainer_assignments_filtered(coach,'withdrawn',pupil);
 if not exists(select 1 from jsonb_array_elements(page) x where x->>'id'=plain::text and x->>'status'='cancelled') then raise exception 'Restaurar reactiva o esconde pauta';end if;
 reset role;
 select to_jsonb(s) into source_after from public.scheduled_workouts s where id=plain;
 if source_after<>source_before or (select count(*) from trainer_private.student_notices where owner_id=pupil)<>notice_count then raise exception 'Archivar modifica cita o crea avisos';end if;
 -- El marcador externo protege incluso después de retirar una entrega/cola.
 insert into device_private.training_sync_jobs(owner_id,scheduled_id,state) values(pupil,linked,'review');
 set local role authenticated;
 page:=public.list_trainer_assignments_filtered(coach,'withdrawn',pupil);
 select x into row from jsonb_array_elements(page) x where x->>'id'=linked::text;
 if row->>'delete_block_reason'<>'garmin' then raise exception 'No informa vínculo Garmin';end if;
 begin perform public.change_trainer_assignment_lifecycle(coach,gen_random_uuid(),linked,0,'delete');raise exception 'Borra vínculo Garmin';exception when invalid_parameter_value then null;end;
 perform public.change_trainer_assignment_lifecycle(coach,gen_random_uuid(),linked,0,'archive');
 perform public.send_trainer_message(gen_random_uuid(),rel,'Comentario protegido',with_message);
 begin perform public.change_trainer_assignment_lifecycle(coach,gen_random_uuid(),with_message,0,'delete');raise exception 'Borra conversación';exception when invalid_parameter_value then null;end;
 -- Resultado real: iniciar y finalizar mediante las RPC del ejecutor.
 perform set_config('request.jwt.claim.sub',pupil::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal1')::text,true);
 execution:=public.start_scheduled_workout(performed);
 for row in select jsonb_build_object('id',id) from public.workout_execution_sets where execution_id=execution loop
  perform public.complete_workout_set((row->>'id')::uuid,p_actual_reps=>8,p_actual_load_kg=>20);
 end loop;
 perform public.finish_workout_execution(execution,6,'Evidencia protegida',null,null,'manual');
 begin perform public.change_trainer_assignment_lifecycle(pupil,gen_random_uuid(),plain,2,'delete');raise exception 'Alumno borra pauta profesional';exception when insufficient_privilege then null;end;
 reset role;
 if trainer_private.assignment_delete_block(performed)<>'results' then raise exception 'No protege resultado real';end if;
 perform set_config('request.jwt.claim.sub',other::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',other,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 begin perform public.change_trainer_assignment_lifecycle(coach,gen_random_uuid(),plain,2,'delete');raise exception 'Cuenta ajena suplanta propietario';exception when insufficient_privilege then null;end;
 begin perform public.change_trainer_assignment_lifecycle(other,gen_random_uuid(),plain,2,'archive');raise exception 'Otro preparador archiva pauta ajena';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub',coach::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal1')::text,true);
 begin perform public.change_trainer_assignment_lifecycle(coach,gen_random_uuid(),plain,2,'delete');raise exception 'Borra sin MFA';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal2')::text,true);
 op:=gen_random_uuid();response:=public.change_trainer_assignment_lifecycle(coach,op,plain,2,'delete');
 if public.change_trainer_assignment_lifecycle(coach,op,plain,2,'delete')<>response then raise exception 'Reintento de DELETE no idempotente';end if;
 begin perform public.assign_trainer_workout(plain,rel,tpl,current_date,null);raise exception 'Resucita identidad eliminada';exception when invalid_parameter_value then null;end;
 reset role;
 if exists(select 1 from public.scheduled_workouts where id=plain) or exists(select 1 from public.trainer_assignments where scheduled_id=plain) then raise exception 'Conserva cita borrada';end if;
 if not exists(select 1 from public.workout_templates where id=tpl) or not exists(select 1 from public.workout_executions where id=execution) then raise exception 'Borrado destruye plantilla o resultados';end if;
 begin insert into device_private.training_sync_jobs(owner_id,scheduled_id) values(pupil,plain);raise exception 'Enlace tardío resucita cita';exception when foreign_key_violation then null;end;
 -- Archivo antes del LIMIT: 55 retiradas archivadas no vacían la página habitual.
 set local role authenticated;
 for idx in 1..55 loop
  extra:=gen_random_uuid();perform public.assign_trainer_workout(extra,rel,tpl,current_date+1,null);perform public.cancel_trainer_assignment(extra);
  perform public.change_trainer_assignment_lifecycle(coach,gen_random_uuid(),extra,0,'archive');
 end loop;
 extra:=gen_random_uuid();perform public.assign_trainer_workout(extra,rel,tpl,current_date+1,null);
 page:=public.list_trainer_client_agenda_filtered('current',coach,pupil,current_date+1,current_date+1);
 if jsonb_array_length(page->'items')<>1 or page->'items'->0->>'id'<>extra::text or (page->>'has_more')::boolean then raise exception 'Filtro posterior al LIMIT';end if;
 page:=public.list_trainer_client_agenda_filtered('archived',coach,pupil,current_date+1,current_date+1);
 if jsonb_array_length(page->'items')<>50 or not (page->>'has_more')::boolean then raise exception 'Pierde paginación archivadas';end if;
 row:=page->'items'->49;
 page:=public.list_trainer_client_agenda_filtered('archived',coach,pupil,current_date+1,current_date+1,(row->>'scheduled_date')::date,(row->>'id')::uuid);
 if jsonb_array_length(page->'items')<>5 or (page->>'has_more')::boolean then raise exception 'Cursor de archivadas incorrecto';end if;
 begin perform public.list_trainer_agenda_filtered(coach,'bad',current_date,current_date+1);raise exception 'Acepta filtro inválido';exception when invalid_parameter_value then null;end;
 begin perform count(*) from trainer_private.assignment_lifecycle;raise exception 'Lee estado directamente';exception when insufficient_privilege then null;end;
 reset role;
 if has_function_privilege('anon','public.change_trainer_assignment_lifecycle(uuid,uuid,uuid,bigint,text)','execute') or
 has_function_privilege('authenticated','trainer_private.retain_assignment_external_reference()','execute') then raise exception 'Funciones internas expuestas';end if;
end $$;
-- Una push pendiente no se envía por una cita ya eliminada. El aviso original
-- conserva su historia y resuelve como no disponible para su propio alumno.
do $$
declare coach uuid:=current_setting('fixture.archive_coach')::uuid;pupil uuid:=current_setting('fixture.archive_pupil')::uuid;
 device uuid:=gen_random_uuid();binding uuid:=gen_random_uuid();scheduled uuid:=gen_random_uuid();tpl uuid;rel uuid;job jsonb;notice uuid;
begin
 update push_private.notice_jobs set next_at='infinity' where generation>delivered_generation;
 update push_private.settings set enabled=true where singleton;
 insert into push_private.preferences(owner_id,quiet_enabled,timezone) values(pupil,false,'UTC');
 insert into push_private.installations(id,owner_id,secret_hash,binding_id,platform,token,token_hash)
 values(device,pupil,repeat('a',64),binding,'android',device::text,encode(sha256(convert_to(device::text,'UTF8')),'hex'));
 select id into rel from public.trainer_client_relations where trainer_id=coach and client_id=pupil;
 select id into tpl from public.workout_templates where owner_user_id=coach and name='Sesión de archivo' limit 1;
 set local role authenticated;
 perform public.assign_trainer_workout(scheduled,rel,tpl,current_date,null);
 perform public.cancel_trainer_assignment(scheduled);
 perform public.change_trainer_assignment_lifecycle(coach,gen_random_uuid(),scheduled,0,'delete');
 reset role;
 select id into notice from trainer_private.student_notices where source_id=scheduled and owner_id=pupil and kind='assignment' and read_at is null;
 if notice is null then raise exception 'Borrado destruye o lee el historial de avisos';end if;
 update push_private.notice_jobs set next_at=clock_timestamp()-interval '1 second' where installation_id=device;
 set local role service_role;
 job:=public.claim_student_notice_jobs(1)->0;
 if job is null or public.prepare_student_notice_job((job->>'job_id')::uuid,(job->>'claim_id')::uuid,(job->>'generation')::bigint,binding) is not null then raise exception 'Push huérfana por cita borrada';end if;
 reset role;
 perform set_config('request.jwt.claim.sub',pupil::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal1')::text,true);
 set local role authenticated;
 if public.resolve_my_trainer_notice(pupil,notice) is not null then raise exception 'Aviso de cita borrada resuelve un recurso';end if;
 reset role;
 perform set_config('request.jwt.claim.sub',coach::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal2')::text,true);
end $$;
-- La misma condición de PostgREST; las proyecciones Garmin deben seguir sin locks.
set transaction read only;
set local role authenticated;
select public.list_trainer_client_agenda_filtered('all',current_setting('fixture.archive_coach')::uuid,current_setting('fixture.archive_pupil')::uuid,current_date,current_date+1);
select 'trainer_assignment_lifecycle: OK' as result;
rollback;
